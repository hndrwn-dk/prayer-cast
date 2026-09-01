import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home_delivery/coordinator/prayer_delivery_coordinator.dart';
import '../../home_delivery/ui/theme/prayer_cast_colors.dart';
import '../../home_delivery/ui/theme/prayer_cast_theme.dart';
import '../../home_delivery/ui/widgets/editorial_chrome.dart';
import '../../l10n/l10n_ext.dart';
import '../../prayer_times/prayer_times_providers.dart';
import '../../prayer_times/ui/prayer_settings_page.dart';
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
    final heading = ref.watch(compassHeadingProvider);

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
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('$e')),
            ),
            data: (saved) {
              final fix = resolveQiblaLocation(saved);
              if (fix == null) {
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: _MissingLocation(
                      isId: isId,
                      onOpenSettings: () => _openSettings(context, ref),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _QiblaBody(
                    fix: fix,
                    heading: heading.asData?.value,
                    headingError: heading.hasError,
                    isId: isId,
                    onOpenMosques: () => _openMosques(context, fix),
                    onOpenSettings: () => _openSettings(context, ref),
                  ),
                ),
              );
            },
          ),
        ],
      ),
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

class _QiblaBody extends StatelessWidget {
  const _QiblaBody({
    required this.fix,
    required this.heading,
    required this.headingError,
    required this.isId,
    required this.onOpenMosques,
    required this.onOpenSettings,
  });

  final QiblaFix fix;
  final double? heading;
  final bool headingError;
  final bool isId;
  final VoidCallback onOpenMosques;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final qibla = qiblaBearingDegrees(
      latitude: fix.latitude,
      longitude: fix.longitude,
    );
    final aligned = heading != null && qiblaAligned(heading!, qibla);
    final qiblaCardinal = cardinalLabel(qibla, isId: isId);
    final sourceHint = switch (fix.source) {
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
          fix.label,
          key: const ValueKey<String>('qibla_location_label'),
          style: text.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(sourceHint, style: text.bodySmall),
        const SizedBox(height: 20),
        Center(
          child: QiblaCompassDial(
            qiblaDeg: qibla,
            headingDeg: heading,
            aligned: aligned,
            isId: isId,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '${qibla.round()}\u00B0 $qiblaCardinal',
          key: const ValueKey<String>('qibla_bearing_label'),
          textAlign: TextAlign.center,
          style: text.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          aligned
              ? (isId ? 'Menghadap Kiblat' : 'Facing Qibla')
              : (isId
                    ? 'Putar hingga jarum mengarah ke atas'
                    : 'Turn until the needle points up'),
          key: const ValueKey<String>('qibla_align_label'),
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(
            color: aligned ? PrayerCastColors.leaf : PrayerCastColors.mistDeep,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          heading == null || headingError
              ? (isId
                    ? 'Kompas tidak terbaca. Arah di atas diukur dari utara. Letakkan ponsel mendatar, jauhkan dari logam, dan di iOS izinkan lokasi.'
                    : 'No compass reading. The bearing above is from north. Hold the phone flat, away from metal; on iOS allow location.')
              : (isId
                    ? 'Letakkan ponsel mendatar. Jauhkan dari speaker atau logam.'
                    : 'Hold the phone flat, away from speakers or metal.'),
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
        const SizedBox(height: 22),
        _ForestAction(
          key: const ValueKey<String>('qibla_open_mosques'),
          label: isId ? 'Masjid terdekat' : 'Nearby mosques',
          filled: true,
          onTap: onOpenMosques,
        ),
        const SizedBox(height: 10),
        _ForestAction(
          key: const ValueKey<String>('qibla_open_settings'),
          label: isId ? 'Ubah lokasi' : 'Change location',
          filled: false,
          onTap: onOpenSettings,
        ),
      ],
    );
  }
}

class _MissingLocation extends StatelessWidget {
  const _MissingLocation({required this.isId, required this.onOpenSettings});

  final bool isId;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkSurface(
      borderColor: PrayerCastColors.inkSoft,
      borderWidth: PrayerCastTheme.cardHairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isId ? 'Lokasi belum cukup' : 'Location needed',
            style: text.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isId
                ? 'Simpan kota di Waktu sholat, atau gunakan lokasi saat ini, supaya kiblat bisa dihitung.'
                : 'Save a city in Prayer times, or use current location, so Qibla can be calculated.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          _ForestAction(
            key: const ValueKey<String>('qibla_open_settings'),
            label: isId ? 'Buka Waktu sholat' : 'Open Prayer times',
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
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? PrayerCastColors.leaf : PrayerCastColors.inkSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: PrayerCastTheme.minTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: PrayerCastColors.surfaceRaised,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
