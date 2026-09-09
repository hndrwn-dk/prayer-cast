import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../home_delivery/ui/theme/prayer_cast_colors.dart';
import '../../home_delivery/ui/theme/prayer_cast_theme.dart';
import '../../home_delivery/ui/widgets/editorial_chrome.dart';
import '../../l10n/l10n_ext.dart';
import '../../prayer_times/location_resolver.dart';
import '../../support/open_support_url.dart';
import '../mosque_overpass.dart';
import '../mosque_repository.dart';
import '../qibla_bearing.dart';
import '../qibla_location.dart';
import '../qibla_providers.dart';

/// Dark raster basemap. Still OpenStreetMap data, rendered by CARTO, so both
/// get credited.
const kMosqueDarkTileUrl =
    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

const kOpenStreetMapCopyrightUrl = 'https://www.openstreetmap.org/copyright';

/// GPS outcome for the mosque search. [fix] is null when the OS refused or
/// never produced a position.
typedef MosqueOriginOutcome = ({QiblaFix? fix, bool permissionDenied});

/// Test hook: skip Geolocator and hand back a canned outcome.
@visibleForTesting
Future<MosqueOriginOutcome> Function()? debugMosqueSearchOrigin;

/// How long the screen waits for GPS before falling back. Bounded on purpose:
/// a permission dialog left unanswered must not leave a spinner behind.
const Duration _originPatience = Duration(seconds: 12);

Future<MosqueOriginOutcome> _liveOrigin(QiblaFix saved) async {
  final override = debugMosqueSearchOrigin;
  if (override != null) return override();
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return (fix: null, permissionDenied: true);
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (fix: null, permissionDenied: true);
    }
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationResolver.preciseSettings,
      );
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }
    if (pos == null) return (fix: null, permissionDenied: false);
    return (
      fix: QiblaFix(
        latitude: pos.latitude,
        longitude: pos.longitude,
        label: saved.label,
        source: QiblaLocationSource.coordinates,
      ),
      permissionDenied: false,
    );
  } catch (_) {
    return (fix: null, permissionDenied: false);
  }
}

/// Nearby mosques from OpenStreetMap, drawn on a dark OSM basemap.
///
/// The search origin is locked to GPS. It only moves when the user types an
/// address or taps "Search here" after panning well away — panning alone
/// never re-queries, so the list does not shuffle under a scrolling thumb.
class MosqueMapPage extends ConsumerStatefulWidget {
  const MosqueMapPage({super.key, required this.fix});

  final QiblaFix fix;

  @override
  ConsumerState<MosqueMapPage> createState() => _MosqueMapPageState();
}

class _MosqueMapPageState extends ConsumerState<MosqueMapPage> {
  final MapController _map = MapController();
  final TextEditingController _address = TextEditingController();

  /// Null while GPS is still being resolved, and after a refusal that left
  /// nothing trustworthy to measure from.
  QiblaFix? _origin;

  var _resolvingOrigin = true;
  var _gpsDenied = false;
  var _geocoding = false;
  String? _selectedId;
  String? _geocodeError;

  /// Metres between the search origin and where the camera now sits.
  var _panMeters = 0.0;

  MosqueQuery? get _query {
    final origin = _origin;
    if (origin == null) return null;
    return (latitude: origin.latitude, longitude: origin.longitude);
  }

  /// Panning is only worth re-querying past a quarter of the radius that
  /// produced the current list; anything closer is already covered.
  bool _offersSearchHere(int radiusMeters) {
    return _origin != null &&
        _panMeters > (radiusMeters / 4).clamp(150.0, 2500.0);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_lockToGps());
  }

  @override
  void dispose() {
    _address.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _lockToGps() async {
    final outcome = await _liveOrigin(widget.fix).timeout(
      _originPatience,
      onTimeout: () => (fix: null, permissionDenied: false),
    );
    if (!mounted) return;
    final live = outcome.fix;
    setState(() {
      _resolvingOrigin = false;
      _gpsDenied = live == null && outcome.permissionDenied;
      _origin = live ?? _savedFallback(denied: outcome.permissionDenied);
      _panMeters = 0;
    });
    _centreOn(_origin);
  }

  /// With permission off, a saved city centre can be tens of kilometres away;
  /// distances from it would be fiction. Only a real saved fix is reused.
  QiblaFix? _savedFallback({required bool denied}) {
    if (denied && widget.fix.source != QiblaLocationSource.coordinates) {
      return null;
    }
    return widget.fix;
  }

  void _centreOn(QiblaFix? fix, {double zoom = 15}) {
    if (fix == null) return;
    try {
      _map.move(LatLng(fix.latitude, fix.longitude), zoom);
    } catch (_) {
      // Map not laid out yet; initialCenter already covers this frame.
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event.source == MapEventSource.mapController) return;
    if (event is! MapEventMoveEnd && event is! MapEventFlingAnimationEnd) {
      return;
    }
    final origin = _origin;
    if (origin == null) return;
    final centre = event.camera.center;
    final drift = haversineMeters(
      fromLat: origin.latitude,
      fromLng: origin.longitude,
      toLat: centre.latitude,
      toLng: centre.longitude,
    );
    if ((drift - _panMeters).abs() < 20) return;
    setState(() => _panMeters = drift);
  }

  /// Explicit hand-off of the search origin to wherever the camera is.
  void _searchHere() {
    final centre = _map.camera.center;
    setState(() {
      _origin = QiblaFix(
        latitude: centre.latitude,
        longitude: centre.longitude,
        label: widget.fix.label,
        source: QiblaLocationSource.mapPin,
      );
      _gpsDenied = false;
      _selectedId = null;
      _panMeters = 0;
    });
  }

  String _biasedAddressQuery(String typed) {
    final q = typed.trim();
    final label = widget.fix.label.trim();
    if (q.isEmpty || label.isEmpty) return q;
    final city = label.split(',').first.trim();
    if (city.isEmpty) return q;
    if (q.toLowerCase().contains(city.toLowerCase())) return q;
    return '$q, $label';
  }

  Future<void> _submitAddress() async {
    final typed = _address.text.trim();
    if (typed.isEmpty || _geocoding) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _geocoding = true;
      _geocodeError = null;
    });
    final isId = Localizations.localeOf(context).languageCode == 'id';
    try {
      final hit = await ref
          .read(mosqueOverpassClientProvider)
          .geocodeAddress(
            query: _biasedAddressQuery(typed),
            nearLat: _origin?.latitude ?? widget.fix.latitude,
            nearLng: _origin?.longitude ?? widget.fix.longitude,
          );
      if (!mounted) return;
      if (hit == null) {
        setState(() {
          _geocoding = false;
          _geocodeError = isId
              ? 'Alamat tidak ditemukan.'
              : 'Address not found.';
        });
        return;
      }
      setState(() {
        _geocoding = false;
        _gpsDenied = false;
        _origin = QiblaFix(
          latitude: hit.latitude,
          longitude: hit.longitude,
          label: hit.name,
          source: QiblaLocationSource.mapPin,
        );
        _selectedId = null;
        _panMeters = 0;
      });
      _centreOn(_origin, zoom: 16);
    } on MosqueOverpassFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _geocoding = false;
        _geocodeError = e.hint(isId: isId);
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _geocoding = false;
        _geocodeError = isId
            ? 'Server peta sedang sibuk. Coba lagi.'
            : 'The map server is busy. Try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _geocoding = false;
        _geocodeError = isId
            ? 'Gagal mencari alamat.'
            : 'Could not search that address.';
      });
    }
  }

  void _select(String id) {
    setState(() => _selectedId = id);
  }

  void _selectAndCentre(NearbyMosque mosque) {
    setState(() => _selectedId = mosque.id);
    try {
      _map.move(
        LatLng(mosque.latitude, mosque.longitude),
        _map.camera.zoom < 15 ? 15 : _map.camera.zoom,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final query = _query;
    final search = query == null
        ? null
        : ref.watch(nearbyMosquesProvider(query));
    final result = search?.asData?.value;
    final radiusMeters = (result?.radiusMeters ?? 0) > 0
        ? result!.radiusMeters
        : kMosqueSearchRadiiMeters.first;
    final offersSearchHere = _offersSearchHere(radiusMeters);
    final centre = LatLng(
      _origin?.latitude ?? widget.fix.latitude,
      _origin?.longitude ?? widget.fix.longitude,
    );

    return Theme(
      data: PrayerCastTheme.forest(),
      child: ForestScaffold(
        header: EditorialPageHeader(
          eyebrow: isId ? 'Arah sholat' : 'Prayer direction',
          title: isId ? 'Masjid terdekat' : 'Nearby mosques',
          backTooltip: l10n.back,
          onBack: () => Navigator.of(context).maybePop(),
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 10),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  _MosqueMapBody(
                    map: _map,
                    centre: centre,
                    origin: _origin,
                    mosques: result?.mosques ?? const [],
                    selectedId: _selectedId,
                    showCrosshair: offersSearchHere,
                    onSelect: _select,
                    onMapEvent: _onMapEvent,
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: _AddressSearchBar(
                      controller: _address,
                      isId: isId,
                      geocoding: _geocoding,
                      error: _geocodeError,
                      onSubmitted: _submitAddress,
                    ),
                  ),
                  if (offersSearchHere)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SearchHereButton(
                          isId: isId,
                          onTap: _searchHere,
                        ),
                      ),
                    ),
                  // Only before the first answer: a background refresh must
                  // not throw a spinner over rows the user is already reading.
                  if (_resolvingOrigin ||
                      (result == null && (search?.isLoading ?? false)))
                    const IgnorePointer(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (query != null && (search?.hasError ?? false))
                    ColoredBox(
                      color: PrayerCastColors.ink.withValues(alpha: 0.72),
                      child: _MosqueError(
                        isId: isId,
                        message: search!.error is MosqueOverpassFailure
                            ? (search.error! as MosqueOverpassFailure).hint(
                                isId: isId,
                              )
                            : '${search.error}',
                        onRetry: () =>
                            ref.invalidate(nearbyMosquesProvider(query)),
                      ),
                    ),
                ],
              ),
            ),
            if (_origin == null)
              _NoOriginNotice(
                isId: isId,
                resolving: _resolvingOrigin,
                denied: _gpsDenied,
              )
            else if (result != null && result.mosques.isEmpty)
              _MosqueList(
                mosques: const [],
                result: result,
                selectedId: _selectedId,
                isId: isId,
                origin: _origin!,
                onSelect: _selectAndCentre,
                onOpenExternal: _openExternal,
              )
            else if (result != null)
              Expanded(
                flex: 3,
                child: _MosqueList(
                  mosques: result.mosques,
                  result: result,
                  selectedId: _selectedId,
                  isId: isId,
                  origin: _origin!,
                  onSelect: _selectAndCentre,
                  onOpenExternal: _openExternal,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openExternal(NearbyMosque mosque) {
    final isId = Localizations.localeOf(context).languageCode == 'id';
    openExternalUrl(
      context,
      mosque.geoUri(mosque.label(isId: isId)).toString(),
    );
  }
}

/// Permission is off and there is nothing honest to measure from. Say why in
/// one line and point at the address field, rather than spinning or erroring.
class _NoOriginNotice extends StatelessWidget {
  const _NoOriginNotice({
    required this.isId,
    required this.resolving,
    required this.denied,
  });

  final bool isId;
  final bool resolving;
  final bool denied;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final String body;
    if (resolving) {
      body = isId ? 'Mencari lokasi Anda...' : 'Finding your location...';
    } else if (denied) {
      body = isId
          ? 'Izin lokasi mati, jadi jarak tidak bisa dihitung. Cari alamat di atas untuk melihat masjid di sekitarnya.'
          : 'Location permission is off, so distances cannot be measured. Search an address above to see mosques around it.';
    } else {
      body = isId
          ? 'Lokasi belum terbaca. Cari alamat di atas untuk melihat masjid di sekitarnya.'
          : 'No location yet. Search an address above to see mosques around it.';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            body,
            key: const ValueKey<String>('mosque_map_no_origin'),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 8),
          const _MapCredit(),
        ],
      ),
    );
  }
}

class _SearchHereButton extends StatelessWidget {
  const _SearchHereButton({required this.isId, required this.onTap});

  final bool isId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PrayerCastColors.leaf,
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      child: InkWell(
        key: const ValueKey<String>('mosque_map_search_here'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.my_location,
                size: 16,
                color: PrayerCastColors.surfaceRaised,
              ),
              const SizedBox(width: 8),
              Text(
                isId ? 'Cari di sini' : 'Search here',
                style: const TextStyle(
                  fontFamily: PrayerCastTheme.bodyFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PrayerCastColors.surfaceRaised,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressSearchBar extends StatelessWidget {
  const _AddressSearchBar({
    required this.controller,
    required this.isId,
    required this.geocoding,
    required this.error,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool isId;
  final bool geocoding;
  final String? error;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PrayerCastColors.surfaceRaised,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('mosque_map_address_field'),
                    controller: controller,
                    enabled: !geocoding,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSubmitted(),
                    style: const TextStyle(
                      fontFamily: PrayerCastTheme.bodyFont,
                      fontSize: 14,
                      color: PrayerCastColors.ink,
                    ),
                    cursorColor: PrayerCastColors.canopy,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: PrayerCastColors.surfaceRaised,
                      hintText: isId
                          ? 'Alamat atau kode pos'
                          : 'Address or postcode',
                      hintStyle: const TextStyle(
                        fontFamily: PrayerCastTheme.bodyFont,
                        fontSize: 13,
                        color: PrayerCastColors.quiet,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                    ),
                  ),
                ),
                if (geocoding)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    key: const ValueKey<String>('mosque_map_address_search'),
                    onPressed: onSubmitted,
                    tooltip: isId ? 'Cari' : 'Search',
                    icon: const Icon(Icons.search, color: PrayerCastColors.ink),
                  ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                child: Text(
                  error!,
                  key: const ValueKey<String>('mosque_map_address_error'),
                  style: const TextStyle(
                    fontFamily: PrayerCastTheme.bodyFont,
                    fontSize: 12,
                    color: PrayerCastColors.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MosqueMapBody extends StatelessWidget {
  const _MosqueMapBody({
    required this.map,
    required this.centre,
    required this.origin,
    required this.mosques,
    required this.selectedId,
    required this.showCrosshair,
    required this.onSelect,
    required this.onMapEvent,
  });

  final MapController map;
  final LatLng centre;
  final QiblaFix? origin;
  final List<NearbyMosque> mosques;
  final String? selectedId;

  /// Only while "Search here" is on offer, so the crosshair means something.
  final bool showCrosshair;

  final ValueChanged<String> onSelect;
  final void Function(MapEvent event) onMapEvent;

  @override
  Widget build(BuildContext context) {
    final here = origin;
    return FlutterMap(
      mapController: map,
      options: MapOptions(
        initialCenter: centre,
        initialZoom: 15,
        backgroundColor: PrayerCastColors.ink,
        onMapEvent: onMapEvent,
      ),
      children: [
        TileLayer(
          urlTemplate: kMosqueDarkTileUrl,
          userAgentPackageName: 'com.tursinalabs.prayer_cast',
        ),
        if (here != null)
          MarkerLayer(
            markers: [
              Marker(
                key: const ValueKey<String>('mosque_map_origin_marker'),
                point: LatLng(here.latitude, here.longitude),
                width: 18,
                height: 18,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: PrayerCastColors.dawn,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: PrayerCastColors.ink, width: 3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final mosque in mosques)
              Marker(
                key: ValueKey<String>('mosque_marker_${mosque.id}'),
                point: LatLng(mosque.latitude, mosque.longitude),
                width: selectedId == mosque.id ? 30 : 22,
                height: selectedId == mosque.id ? 30 : 22,
                child: GestureDetector(
                  onTap: () => onSelect(mosque.id),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selectedId == mosque.id
                          ? PrayerCastColors.dawn
                          : PrayerCastColors.leaf,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(
                          color: selectedId == mosque.id
                              ? PrayerCastColors.surfaceRaised
                              : PrayerCastColors.canopyDeep,
                          width: selectedId == mosque.id ? 3 : 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (showCrosshair)
          const IgnorePointer(
            child: Center(
              child: SizedBox(
                key: ValueKey<String>('mosque_map_center_pin'),
                width: 26,
                height: 26,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: PrayerCastColors.mist, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: PrayerCastColors.ink.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  key: const ValueKey<String>('mosque_map_credit'),
                  onTap: () =>
                      openExternalUrl(context, kOpenStreetMapCopyrightUrl),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '\u00A9 OpenStreetMap contributors \u00A9 CARTO',
                      style: TextStyle(
                        fontFamily: PrayerCastTheme.bodyFont,
                        fontSize: 10,
                        color: PrayerCastColors.mist,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ODbL credit for the list, which can be scrolled with the map off screen.
class _MapCredit extends StatelessWidget {
  const _MapCredit();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey<String>('mosque_list_credit'),
      onTap: () => openExternalUrl(context, kOpenStreetMapCopyrightUrl),
      child: Text(
        'Data \u00A9 OpenStreetMap contributors (ODbL) \u00B7 tiles \u00A9 CARTO',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _MosqueList extends StatefulWidget {
  const _MosqueList({
    required this.mosques,
    required this.result,
    required this.selectedId,
    required this.isId,
    required this.origin,
    required this.onSelect,
    required this.onOpenExternal,
  });

  final List<NearbyMosque> mosques;
  final MosqueSearchResult result;
  final String? selectedId;
  final bool isId;
  final QiblaFix origin;
  final ValueChanged<NearbyMosque> onSelect;
  final ValueChanged<NearbyMosque> onOpenExternal;

  @override
  State<_MosqueList> createState() => _MosqueListState();
}

class _MosqueListState extends State<_MosqueList> {
  final Map<String, GlobalKey> _rowKeys = {};

  @override
  void didUpdateWidget(covariant _MosqueList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedId;
    if (selected == null || selected == oldWidget.selectedId) return;
    // A tap on a pin should bring its row into view, not leave the user
    // hunting for the highlight. Best effort: a row the list has not built
    // yet has no context to scroll to, and the highlight still lands.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _rowKeys[selected]?.currentContext;
      if (row == null || !mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          row,
          alignment: 0.3,
          duration: const Duration(milliseconds: 220),
        ),
      );
    });
  }

  String get _originHint {
    final isId = widget.isId;
    if (widget.origin.source == QiblaLocationSource.mapPin) {
      return isId
          ? 'Jarak dari titik yang Anda cari.'
          : 'Distances are from the place you searched.';
    }
    if (widget.origin.source == QiblaLocationSource.cityCatalog) {
      return isId
          ? 'Jarak dari pusat kota tersimpan.'
          : 'Distances are from your saved city centre.';
    }
    return isId
        ? 'Jarak garis lurus dari GPS saat ini.'
        : 'Straight-line distances from your current GPS.';
  }

  String get _privacyCopy =>
      widget.isId ? 'Pencarian tidak disimpan.' : "Searches aren't saved.";

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isId = widget.isId;
    if (widget.mosques.isEmpty) {
      final km = (widget.result.radiusMeters / 1000).round();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isId
                  ? 'Tidak ada masjid dalam $km km dari titik ini.\n$_originHint'
                  : 'No mosques within $km km of this point.\n$_originHint',
              key: const ValueKey<String>('mosque_map_empty'),
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            const _MapCredit(),
          ],
        ),
      );
    }
    final shown = widget.mosques.take(12).toList();
    return ListView.separated(
      key: const ValueKey<String>('mosque_map_list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: shown.length + 2,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.result.stale)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    isId
                        ? 'Jaringan tidak tersedia. Menampilkan hasil tersimpan.'
                        : 'No network. Showing saved results.',
                    key: const ValueKey<String>('mosque_map_stale'),
                    style: text.bodySmall?.copyWith(
                      color: PrayerCastColors.dawnSoft,
                    ),
                  ),
                ),
              Text(
                _originHint,
                key: const ValueKey<String>('mosque_map_origin_hint'),
                style: text.bodySmall,
              ),
            ],
          );
        }
        if (index == shown.length + 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _privacyCopy,
                  key: const ValueKey<String>('mosque_map_privacy'),
                  style: text.bodySmall,
                ),
                const SizedBox(height: 4),
                const _MapCredit(),
              ],
            ),
          );
        }
        final mosque = shown[index - 1];
        return _MosqueRow(
          key: _rowKeys.putIfAbsent(mosque.id, GlobalKey.new),
          mosque: mosque,
          selected: mosque.id == widget.selectedId,
          isId: isId,
          onTap: () => widget.onSelect(mosque),
          onOpenExternal: () => widget.onOpenExternal(mosque),
        );
      },
    );
  }
}

class _MosqueRow extends StatelessWidget {
  const _MosqueRow({
    super.key,
    required this.mosque,
    required this.selected,
    required this.isId,
    required this.onTap,
    required this.onOpenExternal,
  });

  final NearbyMosque mosque;
  final bool selected;
  final bool isId;
  final VoidCallback onTap;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final distance =
        '${formatDistanceMeters(mosque.distanceMeters, isId: isId)} \u00B7 '
        '${cardinalLabel(mosque.bearingDegrees, isId: isId)}';
    return Material(
      color: selected ? PrayerCastColors.canopy : PrayerCastColors.canopyDeep,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: ValueKey<String>('mosque_row_${mosque.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Icon(
                mosque.kind == NearbyMosqueKind.mosque
                    ? Icons.mosque_outlined
                    : Icons.meeting_room_outlined,
                size: 18,
                color: selected
                    ? PrayerCastColors.dawnSoft
                    : PrayerCastColors.mistDeep,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mosque.label(isId: isId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(distance, style: text.bodySmall),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey<String>('mosque_open_${mosque.id}'),
                onPressed: onOpenExternal,
                tooltip: isId ? 'Buka di peta' : 'Open in maps',
                icon: const Icon(
                  Icons.directions_outlined,
                  color: PrayerCastColors.dawnSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MosqueError extends StatelessWidget {
  const _MosqueError({
    required this.isId,
    required this.message,
    required this.onRetry,
  });

  final bool isId;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isId
                ? 'Gagal memuat masjid dari OpenStreetMap.'
                : 'Could not load mosques from OpenStreetMap.',
            textAlign: TextAlign.center,
            style: text.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: text.bodySmall),
          const SizedBox(height: 16),
          TextButton(
            key: const ValueKey<String>('mosque_map_retry'),
            onPressed: onRetry,
            child: Text(
              isId ? 'Coba lagi' : 'Try again',
              style: const TextStyle(color: PrayerCastColors.dawnSoft),
            ),
          ),
        ],
      ),
    );
  }
}
