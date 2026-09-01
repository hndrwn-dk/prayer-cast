import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../qibla_bearing.dart';
import '../qibla_location.dart';
import '../qibla_providers.dart';

/// Test hook: skip Geolocator and optionally replace the search origin.
@visibleForTesting
Future<QiblaFix?> Function()? debugMosqueSearchOrigin;

Future<QiblaFix> _liveOrSavedOrigin(QiblaFix saved) async {
  final override = debugMosqueSearchOrigin;
  if (override != null) {
    return await override() ?? saved;
  }
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return saved;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      return saved;
    }
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationResolver.preciseSettings,
      );
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }
    if (pos == null) return saved;
    return QiblaFix(
      latitude: pos.latitude,
      longitude: pos.longitude,
      label: saved.label,
      source: QiblaLocationSource.coordinates,
    );
  } catch (_) {
    return saved;
  }
}

/// Nearby mosques from OpenStreetMap, drawn on OSM tiles.
class MosqueMapPage extends ConsumerStatefulWidget {
  const MosqueMapPage({super.key, required this.fix});

  final QiblaFix fix;

  @override
  ConsumerState<MosqueMapPage> createState() => _MosqueMapPageState();
}

class _MosqueMapPageState extends ConsumerState<MosqueMapPage> {
  final MapController _map = MapController();
  final TextEditingController _address = TextEditingController();
  String? _selectedId;
  late QiblaFix _origin = widget.fix;
  var _pinnedByUser = false;
  var _geocoding = false;
  String? _geocodeError;
  Timer? _moveDebounce;

  MosqueQuery get _query =>
      (latitude: _origin.latitude, longitude: _origin.longitude);

  @override
  void initState() {
    super.initState();
    unawaited(_refreshOrigin());
  }

  Future<void> _refreshOrigin() async {
    if (_pinnedByUser) return;
    final next = await _liveOrSavedOrigin(widget.fix);
    if (!mounted || _pinnedByUser) return;
    if (next.latitude == _origin.latitude &&
        next.longitude == _origin.longitude) {
      return;
    }
    setState(() => _origin = next);
    try {
      _map.move(LatLng(next.latitude, next.longitude), 15);
    } catch (_) {}
  }

  void _searchAt(LatLng point) {
    if (haversineMeters(
          fromLat: _origin.latitude,
          fromLng: _origin.longitude,
          toLat: point.latitude,
          toLng: point.longitude,
        ) <
        30) {
      return;
    }
    _pinnedByUser = true;
    setState(() {
      _origin = QiblaFix(
        latitude: point.latitude,
        longitude: point.longitude,
        label: widget.fix.label,
        source: QiblaLocationSource.mapPin,
      );
      _selectedId = null;
    });
  }

  void _onMapEvent(MapEvent event) {
    if (event.source == MapEventSource.mapController) return;
    if (event is! MapEventMoveEnd && event is! MapEventFlingAnimationEnd) {
      return;
    }
    final center = event.camera.center;
    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _searchAt(center);
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
            nearLat: _origin.latitude,
            nearLng: _origin.longitude,
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
      _pinnedByUser = true;
      final point = LatLng(hit.latitude, hit.longitude);
      setState(() {
        _geocoding = false;
        _origin = QiblaFix(
          latitude: hit.latitude,
          longitude: hit.longitude,
          label: hit.name,
          source: QiblaLocationSource.mapPin,
        );
        _selectedId = null;
      });
      try {
        _map.move(point, 16);
      } catch (_) {}
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

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _address.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isId = Localizations.localeOf(context).languageCode == 'id';
    final mosques = ref.watch(nearbyMosquesProvider(_query));
    final here = LatLng(_origin.latitude, _origin.longitude);

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
                    here: here,
                    mosques: mosques.asData?.value ?? const [],
                    selectedId: _selectedId,
                    onSelect: (id) => setState(() => _selectedId = id),
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
                  if (mosques.isLoading)
                    const IgnorePointer(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (mosques.hasError)
                    ColoredBox(
                      color: PrayerCastColors.ink.withValues(alpha: 0.72),
                      child: _MosqueError(
                        isId: isId,
                        message: mosques.error is MosqueOverpassFailure
                            ? (mosques.error! as MosqueOverpassFailure).hint(
                                isId: isId,
                              )
                            : '${mosques.error}',
                        onRetry: () =>
                            ref.invalidate(nearbyMosquesProvider(_query)),
                      ),
                    ),
                ],
              ),
            ),
            mosques.maybeWhen(
              data: (list) {
                if (list.isEmpty) {
                  return _MosqueList(
                    mosques: list,
                    selectedId: _selectedId,
                    isId: isId,
                    origin: _origin,
                    onSelect: (mosque) {
                      setState(() => _selectedId = mosque.id);
                    },
                    onOpenExternal: (mosque) =>
                        openExternalUrl(context, mosque.geoUri.toString()),
                  );
                }
                return Expanded(
                  flex: 3,
                  child: _MosqueList(
                    mosques: list,
                    selectedId: _selectedId,
                    isId: isId,
                    origin: _origin,
                    onSelect: (mosque) {
                      setState(() => _selectedId = mosque.id);
                    },
                    onOpenExternal: (mosque) =>
                        openExternalUrl(context, mosque.geoUri.toString()),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
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
    required this.here,
    required this.mosques,
    required this.selectedId,
    required this.onSelect,
    required this.onMapEvent,
  });

  final MapController map;
  final LatLng here;
  final List<NearbyMosque> mosques;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final void Function(MapEvent event) onMapEvent;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: map,
      options: MapOptions(
        initialCenter: here,
        initialZoom: 15,
        backgroundColor: PrayerCastColors.ink,
        onMapEvent: onMapEvent,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.tursinalabs.prayer_cast',
        ),
        MarkerLayer(
          markers: [
            for (final mosque in mosques)
              Marker(
                key: ValueKey<String>('mosque_marker_${mosque.id}'),
                point: LatLng(mosque.latitude, mosque.longitude),
                width: selectedId == mosque.id ? 28 : 22,
                height: selectedId == mosque.id ? 28 : 22,
                child: GestureDetector(
                  onTap: () => onSelect(mosque.id),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selectedId == mosque.id
                          ? PrayerCastColors.dawn
                          : PrayerCastColors.leaf,
                      shape: BoxShape.circle,
                      border: const Border.fromBorderSide(
                        BorderSide(
                          color: PrayerCastColors.surfaceRaised,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const IgnorePointer(
          child: Center(
            child: SizedBox(
              key: ValueKey<String>('mosque_map_center_pin'),
              width: 28,
              height: 28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: PrayerCastColors.dawn,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: PrayerCastColors.surfaceRaised, width: 2),
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
                color: PrayerCastColors.mist.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  onTap: () => openExternalUrl(
                    context,
                    'https://www.openstreetmap.org/copyright',
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '\u00A9 OpenStreetMap contributors',
                      style: TextStyle(
                        fontFamily: PrayerCastTheme.bodyFont,
                        fontSize: 11,
                        color: PrayerCastColors.ink,
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

class _MosqueList extends StatelessWidget {
  const _MosqueList({
    required this.mosques,
    required this.selectedId,
    required this.isId,
    required this.origin,
    required this.onSelect,
    required this.onOpenExternal,
  });

  final List<NearbyMosque> mosques;
  final String? selectedId;
  final bool isId;
  final QiblaFix origin;
  final ValueChanged<NearbyMosque> onSelect;
  final ValueChanged<NearbyMosque> onOpenExternal;

  String get _originHint {
    if (origin.source == QiblaLocationSource.mapPin) {
      return isId
          ? 'Jarak dari pin sesi ini. Buka lagi halaman ini untuk kembali ke GPS.'
          : 'Distances are from this visit. Reopen the page to use GPS again.';
    }
    if (origin.source == QiblaLocationSource.cityCatalog) {
      return isId
          ? 'Jarak dari pusat kota. Izinkan GPS atau cari alamat.'
          : 'Distances are from the city centre. Allow GPS or search an address.';
    }
    return isId
        ? 'Jarak dari GPS saat ini. Cari alamat hanya untuk kunjungan ini.'
        : 'Distances are from your current GPS. Search is only for this visit.';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (mosques.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text(
          isId
              ? 'Tidak ada masjid dalam 5 km di peta ini.\n$_originHint'
              : 'No mosques within 5 km on this map.\n$_originHint',
          key: const ValueKey<String>('mosque_map_empty'),
          style: text.bodySmall,
        ),
      );
    }
    final shown = mosques.take(12).toList();
    return ListView.separated(
      key: const ValueKey<String>('mosque_map_list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: shown.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            _originHint,
            key: const ValueKey<String>('mosque_map_origin_hint'),
            style: text.bodySmall,
          );
        }
        final mosque = shown[index - 1];
        final selected = mosque.id == selectedId;
        return Material(
          color: selected
              ? PrayerCastColors.canopy
              : PrayerCastColors.canopyDeep,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => onSelect(mosque),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mosque.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDistanceMeters(
                            mosque.distanceMeters,
                            isId: isId,
                          ),
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: ValueKey<String>('mosque_open_${mosque.id}'),
                    onPressed: () => onOpenExternal(mosque),
                    child: Text(
                      isId ? 'Peta' : 'Maps',
                      style: const TextStyle(
                        fontFamily: PrayerCastTheme.bodyFont,
                        color: PrayerCastColors.dawnSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
