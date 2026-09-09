import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home_delivery/coordinator/prayer_delivery_coordinator.dart';
import '../../home_delivery/ui/theme/prayer_cast_colors.dart';
import '../../home_delivery/ui/theme/prayer_cast_theme.dart';
import '../../home_delivery/ui/widgets/editorial_chrome.dart';
import '../../l10n/l10n_ext.dart';
import '../../prayer_times/prayer_times_providers.dart';
import '../../prayer_times/ui/prayer_settings_page.dart';
import '../compass_heading.dart';
import '../qibla_bearing.dart';
import '../qibla_location.dart';
import '../qibla_providers.dart';
import 'mosque_map_page.dart';
import 'qibla_compass_dial.dart';

/// Compass toward the Kaaba, then a door to nearby OSM mosques.
class QiblaPage extends ConsumerWidget {
  const QiblaPage({super.key, this.coordinator});

  final PrayerDeliveryCoordinator? coordinator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final prefs = ref.watch(prayerPrefsProvider);
    final readingAsync = ref.watch(compassReadingProvider);
    // A stream error means the platform will not talk to us at all; treat it
    // like a missing sensor so the page shows the static bearing.
    final reading = readingAsync.hasError
        ? const CompassReading.unavailable()
        : readingAsync.asData?.value;

    return Theme(
      data: PrayerCastTheme.forest(),
      child: ForestScrollScaffold(
        header: EditorialPageHeader(
          eyebrow: isId ? 'Arah sholat' : 'Prayer direction',
          title: isId ? 'Kiblat' : 'Qibla',
          backTooltip: l10n.back,
          onBack: () => Navigator.of(context).maybePop(),
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 10),
        ),
        slivers: [
          prefs.when(
            loading: () => _pageSliver(
              child: _LoadingLocation(
                isId: isId,
                onOpenSettings: () => _openSettings(context, ref),
              ),
            ),
            // Prefs could not be read, so there is no saved location to work
            // from. Point at the manual picker instead of a raw error.
            error: (e, _) => _pageSliver(
              child: _MissingLocation(
                isId: isId,
                readFailed: true,
                onOpenSettings: () => _openSettings(context, ref),
              ),
            ),
            data: (saved) {
              final fix = resolveQiblaLocation(saved);
              if (fix == null) {
                return _pageSliver(
                  child: _MissingLocation(
                    isId: isId,
                    onOpenSettings: () => _openSettings(context, ref),
                  ),
                );
              }
              return _pageSliver(
                child: _QiblaBody(
                  fix: fix,
                  reading: reading,
                  isId: isId,
                  onOpenMosques: () => _openMosques(context, fix),
                  onOpenSettings: () => _openSettings(context, ref),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget _pageSliver({required Widget child}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverToBoxAdapter(child: child),
    );
  }

  Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => PrayerSettingsPage(coordinator: coordinator),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    ref.invalidate(prayerPrefsProvider);
  }

  Future<void> _openMosques(BuildContext context, QiblaFix fix) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => MosqueMapPage(fix: fix),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

class _QiblaBody extends ConsumerStatefulWidget {
  const _QiblaBody({
    required this.fix,
    required this.reading,
    required this.isId,
    required this.onOpenMosques,
    required this.onOpenSettings,
  });

  final QiblaFix fix;

  /// Null until the compass stream produces its first sample.
  final CompassReading? reading;
  final bool isId;
  final VoidCallback onOpenMosques;
  final VoidCallback onOpenSettings;

  @override
  ConsumerState<_QiblaBody> createState() => _QiblaBodyState();
}

class _QiblaBodyState extends ConsumerState<_QiblaBody> {
  /// Some phones report sensors present and then never deliver a heading.
  /// After this long without one, show the static bearing rather than a dial
  /// that cannot move.
  static const Duration _headingGrace = Duration(seconds: 4);

  final QiblaAlignmentLatch _latch = QiblaAlignmentLatch();
  Timer? _graceTimer;
  bool _graceExpired = false;
  bool _calibrationDismissed = false;
  late double _qibla;

  @override
  void initState() {
    super.initState();
    _qibla = _bearingFor(widget.fix);
    _prefetchMosques();
    _syncGraceTimer();
    _consumeReading();
  }

  @override
  void didUpdateWidget(covariant _QiblaBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fix.latitude != widget.fix.latitude ||
        oldWidget.fix.longitude != widget.fix.longitude) {
      _qibla = _bearingFor(widget.fix);
      _prefetchMosques();
    }
    _syncGraceTimer();
    _consumeReading();
  }

  /// Warms the nearby-mosque cache while the user reads the compass, so
  /// "Nearby mosques" opens with a list. Cache-aware: a warm cell costs
  /// nothing and never reaches the network.
  void _prefetchMosques() {
    unawaited(
      ref
          .read(mosqueRepositoryProvider)
          .prefetch(
            latitude: widget.fix.latitude,
            longitude: widget.fix.longitude,
          ),
    );
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  /// Runs only while a heading is still expected, so nothing is left ticking
  /// once the dial is live or the platform said it has no compass.
  void _syncGraceTimer() {
    final reading = widget.reading;
    final waiting =
        !_graceExpired &&
        reading?.headingDeg == null &&
        reading?.availability != CompassAvailability.unavailable;
    if (waiting) {
      _graceTimer ??= Timer(_headingGrace, () {
        if (mounted) setState(() => _graceExpired = true);
      });
      return;
    }
    _graceTimer?.cancel();
    _graceTimer = null;
  }

  static double _bearingFor(QiblaFix fix) {
    return qiblaBearingDegrees(
      latitude: fix.latitude,
      longitude: fix.longitude,
    );
  }

  /// One tap on the rising edge only; the latch swallows edge jitter.
  void _consumeReading() {
    final lockedOn = _latch.update(widget.reading?.headingDeg, _qibla);
    if (lockedOn && _isForeground) {
      ref.read(qiblaHapticsProvider).alignedTap();
    }
  }

  /// No buzzing while the app sits in the background.
  bool get _isForeground {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isId = widget.isId;
    final reading = widget.reading;
    final aligned = _latch.aligned;
    final cardinal = cardinalLabel(_qibla, isId: isId);

    final headingDeg = reading?.headingDeg;
    final hasHeading = headingDeg != null;
    // Unavailable outright, or sensors that promised a heading and never
    // delivered one. Either way, no dead dial.
    final noCompass =
        reading?.availability == CompassAvailability.unavailable ||
        (!hasHeading && _graceExpired);
    final showCalibration =
        hasHeading &&
        (reading?.needsCalibration ?? false) &&
        !_calibrationDismissed;

    final sourceHint = switch (widget.fix.source) {
      QiblaLocationSource.coordinates =>
        isId ? 'Lokasi perkiraan' : 'Approximate location',
      QiblaLocationSource.cityCatalog =>
        isId ? 'Pusat kota tersimpan' : 'Saved city centre',
      QiblaLocationSource.mapPin => isId ? 'Titik di peta' : 'Map pin',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.fix.label,
          key: const ValueKey<String>('qibla_location_label'),
          style: text.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(sourceHint, style: text.bodySmall),
        const SizedBox(height: 20),
        if (hasHeading)
          Center(
            child: QiblaCompassDial(
              qiblaDeg: _qibla,
              headingDeg: headingDeg,
              aligned: aligned,
              isId: isId,
            ),
          )
        else if (noCompass)
          _NoCompassNotice(bearingDeg: _qibla, cardinal: cardinal, isId: isId)
        else
          const Center(
            key: ValueKey<String>('qibla_compass_probing'),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          ),
        const SizedBox(height: 18),
        Text(
          '${_qibla.round()}\u00B0 $cardinal',
          key: const ValueKey<String>('qibla_bearing_label'),
          textAlign: TextAlign.center,
          style: text.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          _alignLabel(
            aligned: aligned,
            hasHeading: hasHeading,
            noCompass: noCompass,
          ),
          key: const ValueKey<String>('qibla_align_label'),
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(
            color: aligned ? PrayerCastColors.leaf : PrayerCastColors.mistDeep,
          ),
        ),
        if (showCalibration) ...[
          const SizedBox(height: 14),
          _CalibrationNotice(
            isId: isId,
            onDismiss: () => setState(() => _calibrationDismissed = true),
          ),
        ],
        if (!noCompass) ...[
          const SizedBox(height: 14),
          Text(
            isId
                ? 'Letakkan ponsel mendatar. Jauhkan dari speaker atau logam.'
                : 'Hold the phone flat, away from speakers or metal.',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ],
        const SizedBox(height: 22),
        _ForestAction(
          key: const ValueKey<String>('qibla_open_mosques'),
          label: isId ? 'Masjid terdekat' : 'Nearby mosques',
          filled: false,
          onTap: widget.onOpenMosques,
        ),
        const SizedBox(height: 10),
        _ForestAction(
          key: const ValueKey<String>('qibla_open_settings'),
          label: isId ? 'Ubah lokasi' : 'Change location',
          filled: false,
          onTap: widget.onOpenSettings,
        ),
      ],
    );
  }

  String _alignLabel({
    required bool aligned,
    required bool hasHeading,
    required bool noCompass,
  }) {
    final isId = widget.isId;
    if (hasHeading) {
      if (aligned) return isId ? 'Menghadap kiblat' : 'Facing qibla';
      return isId
          ? 'Putar hingga jarum mengarah ke atas'
          : 'Turn until the needle points up';
    }
    if (noCompass) {
      return isId
          ? 'Searah jarum jam dari utara sejati'
          : 'Clockwise from true north';
    }
    return isId ? 'Membaca kompas' : 'Reading the compass';
  }
}

/// Live compass missing: keep the page useful with the static bearing and say
/// so plainly, instead of leaving a dial that never moves.
class _NoCompassNotice extends StatelessWidget {
  const _NoCompassNotice({
    required this.bearingDeg,
    required this.cardinal,
    required this.isId,
  });

  final double bearingDeg;
  final String cardinal;
  final bool isId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final degrees = '${bearingDeg.round()}\u00B0';
    return InkSurface(
      key: const ValueKey<String>('qibla_no_compass'),
      borderColor: PrayerCastColors.inkSoft,
      borderWidth: PrayerCastTheme.cardHairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isId
                ? 'Kompas langsung tidak tersedia'
                : 'Live compass unavailable',
            style: text.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isId
                ? 'Ponsel ini tidak melaporkan arah, jadi dial disembunyikan. Kiblat berada $degrees ($cardinal) searah jarum jam dari utara sejati.'
                : 'This phone reports no heading, so the dial is hidden. Qibla is $degrees ($cardinal) clockwise from true north.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isId
                ? 'Cari utara dengan peta atau kompas lain, lalu berputar sebesar sudut itu.'
                : 'Find north with a map or a separate compass, then turn by that angle.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Platform reported a coarse heading. Hint only: the needle keeps running.
class _CalibrationNotice extends StatelessWidget {
  const _CalibrationNotice({required this.isId, required this.onDismiss});

  final bool isId;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkSurface(
      key: const ValueKey<String>('qibla_calibration_notice'),
      borderColor: PrayerCastColors.dawn,
      borderWidth: PrayerCastTheme.cardHairline,
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isId ? 'Akurasi kompas rendah' : 'Compass accuracy is low',
            style: text.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            isId
                ? 'Gerakkan ponsel membentuk angka delapan, jauh dari logam. Jarum tetap berjalan.'
                : 'Wave the phone in a figure eight, away from metal. The needle keeps working.',
            style: text.bodySmall,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('qibla_calibration_dismiss'),
              onPressed: onDismiss,
              child: Text(isId ? 'Tutup' : 'Dismiss'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prefs are still being read. Bounded: if the read never lands, swap to the
/// manual picker rather than spinning forever.
class _LoadingLocation extends StatefulWidget {
  const _LoadingLocation({required this.isId, required this.onOpenSettings});

  final bool isId;
  final VoidCallback onOpenSettings;

  @override
  State<_LoadingLocation> createState() => _LoadingLocationState();
}

class _LoadingLocationState extends State<_LoadingLocation> {
  static const Duration _patience = Duration(seconds: 6);

  Timer? _timer;
  bool _gaveUp = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_patience, () {
      if (mounted) setState(() => _gaveUp = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gaveUp) {
      return _MissingLocation(
        isId: widget.isId,
        readFailed: true,
        onOpenSettings: widget.onOpenSettings,
      );
    }
    return const Padding(
      key: ValueKey<String>('qibla_location_loading'),
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// No usable location: either permission never landed or nothing is saved.
/// Either way the way out is the manual picker in Prayer times.
class _MissingLocation extends StatelessWidget {
  const _MissingLocation({
    required this.isId,
    required this.onOpenSettings,
    this.readFailed = false,
  });

  final bool isId;
  final bool readFailed;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = readFailed
        ? (isId ? 'Pengaturan tidak terbaca' : 'Settings could not be read')
        : (isId ? 'Lokasi belum ada' : 'Location needed');
    final body = readFailed
        ? (isId
              ? 'Pengaturan tersimpan tidak terbaca, jadi kiblat belum punya lokasi. Buka Waktu sholat dan pilih kota secara manual.'
              : 'Saved settings could not be read, so Qibla has no location yet. Open Prayer times and pick a city manually.')
        : (isId
              ? 'Izin lokasi mungkin ditolak, atau belum ada kota tersimpan. Pilih kota secara manual di Waktu sholat, atau gunakan lokasi saat ini, lalu kiblat dihitung dari situ.'
              : 'Location permission may be denied, or no city is saved yet. Pick a city manually in Prayer times, or use current location there, and Qibla is calculated from it.');
    return InkSurface(
      borderColor: PrayerCastColors.inkSoft,
      borderWidth: PrayerCastTheme.cardHairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: 8),
          Text(body, style: text.bodyMedium),
          const SizedBox(height: 16),
          _ForestAction(
            key: const ValueKey<String>('qibla_open_settings'),
            label: isId ? 'Pilih lokasi' : 'Choose location',
            filled: true,
            onTap: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _ForestAction extends StatelessWidget {
  const _ForestAction({
    super.key,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;

  /// Solid leaf primary. False draws an outline, for actions that should not
  /// compete with the compass.
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: filled ? PrayerCastColors.leaf : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: filled
            ? BorderSide.none
            : const BorderSide(
                color: PrayerCastColors.mistDeep,
                width: PrayerCastTheme.cardHairline,
              ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          height: PrayerCastTheme.minTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: filled
                    ? PrayerCastColors.surfaceRaised
                    : PrayerCastColors.mist,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
