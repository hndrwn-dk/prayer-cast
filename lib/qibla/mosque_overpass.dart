import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'qibla_bearing.dart';

const kPrayerCastOverpassUserAgent =
    'PrayerCast/1.0.14 (com.tursinalabs.prayer_cast; https://tursinalabs.com)';

/// Public Overpass interpreters. `overpass-api.de` often returns 504 when busy.
const kOverpassInterpreterUrls = [
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.osm.ch/api/interpreter',
  'https://overpass-api.de/api/interpreter',
];

const kNominatimSearchUrl = 'https://nominatim.openstreetmap.org/search';

final class NearbyMosque {
  const NearbyMosque({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceMeters;

  Uri get geoUri {
    final q = Uri.encodeComponent('$latitude,$longitude($name)');
    return Uri.parse('geo:$latitude,$longitude?q=$q');
  }
}

final class MosqueOverpassFailure implements Exception {
  const MosqueOverpassFailure(this.message, {this.busy = false});
  final String message;
  final bool busy;

  @override
  String toString() => message;

  String hint({required bool isId}) {
    if (busy) {
      return isId
          ? 'Server peta sedang sibuk. Tekan Coba lagi.'
          : 'The map server is busy. Tap Try again.';
    }
    return message;
  }
}

/// Nearby mosques from OpenStreetMap via public Overpass APIs (HTTPS).
///
/// Uses a bounding-box query (nodes + ways only). `nwr` + `around:` often
/// times out on public interpreters, which then looks like "no mosques"
/// even when OSM tiles already draw mosque icons.
final class MosqueOverpassClient {
  MosqueOverpassClient({
    http.Client? httpClient,
    List<String>? endpoints,
    this.nominatimSearchUrl = kNominatimSearchUrl,
    this.radiusMeters = 5000,
    this.limit = 40,
    this.requestTimeout = const Duration(seconds: 25),
  }) : _http = httpClient ?? http.Client(),
       endpoints = List<String>.unmodifiable(
         endpoints ?? kOverpassInterpreterUrls,
       );

  final http.Client _http;
  final List<String> endpoints;
  final String nominatimSearchUrl;
  final int radiusMeters;
  final int limit;
  final Duration requestTimeout;

  Future<List<NearbyMosque>> nearby({
    required double latitude,
    required double longitude,
  }) async {
    final query = _overpassQuery(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
    final body = 'data=${Uri.encodeQueryComponent(query)}';
    const headers = {
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'Accept': 'application/json',
      'User-Agent': kPrayerCastOverpassUserAgent,
    };

    Object? lastError;
    var sawBusy = false;
    List<NearbyMosque> overpassHits = const [];
    List<NearbyMosque>? emptyOverpass;
    for (final endpoint in endpoints) {
      try {
        final response = await _http
            .post(Uri.parse(endpoint), headers: headers, body: body)
            .timeout(requestTimeout);
        if (_isBusyStatus(response.statusCode)) {
          sawBusy = true;
          lastError = MosqueOverpassFailure(
            'Overpass HTTP ${response.statusCode}',
            busy: true,
          );
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = MosqueOverpassFailure(
            'Overpass HTTP ${response.statusCode}',
          );
          continue;
        }
        if (_overpassTimedOut(response.body)) {
          sawBusy = true;
          lastError = const MosqueOverpassFailure(
            'Overpass query timed out',
            busy: true,
          );
          continue;
        }
        final parsed = parseOverpassMosques(
          response.body,
          fromLat: latitude,
          fromLng: longitude,
          limit: limit,
          maxDistanceMeters: radiusMeters.toDouble(),
        );
        if (parsed.isNotEmpty) {
          overpassHits = parsed;
          break;
        }
        emptyOverpass = parsed;
      } on TimeoutException catch (e) {
        sawBusy = true;
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      }
    }
    if (overpassHits.isNotEmpty) return overpassHits;
    final fromNominatim = await _nominatimNearby(
      latitude: latitude,
      longitude: longitude,
    );
    if (fromNominatim != null && fromNominatim.isNotEmpty) {
      return fromNominatim;
    }
    if (emptyOverpass != null) return emptyOverpass;
    throw MosqueOverpassFailure(
      lastError?.toString() ?? 'Overpass unavailable',
      busy: sawBusy,
    );
  }

  Future<List<NearbyMosque>?> _nominatimNearby({
    required double latitude,
    required double longitude,
  }) async {
    final chunks = <List<NearbyMosque>>[];
    for (final term in ['masjid', 'mosque', 'musholla']) {
      final hits = await _nominatimSearch(
        query: term,
        latitude: latitude,
        longitude: longitude,
      );
      if (hits != null && hits.isNotEmpty) chunks.add(hits);
    }
    if (chunks.isEmpty) return null;
    return mergeMosqueLists(chunks.first, [
      for (final extra in chunks.skip(1)) ...extra,
    ], limit: limit);
  }

  Future<List<NearbyMosque>?> _nominatimSearch({
    required String query,
    required double latitude,
    required double longitude,
  }) async {
    final box = mosqueSearchBbox(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
    final uri = Uri.parse(nominatimSearchUrl).replace(
      queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'limit': '$limit',
        'bounded': '1',
        'extratags': '1',
        'viewbox':
            '${box.west.toStringAsFixed(5)},${box.north.toStringAsFixed(5)},'
            '${box.east.toStringAsFixed(5)},${box.south.toStringAsFixed(5)}',
      },
    );
    try {
      final response = await _http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': kPrayerCastOverpassUserAgent,
            },
          )
          .timeout(requestTimeout);
      if (_isBusyStatus(response.statusCode)) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return parseNominatimMosques(
        response.body,
        fromLat: latitude,
        fromLng: longitude,
        limit: limit,
        maxDistanceMeters: radiusMeters.toDouble(),
      );
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    } on FormatException {
      return null;
    } on MosqueOverpassFailure {
      return null;
    }
  }

  /// Forward-geocode a typed street address via Nominatim (no API key).
  Future<({double latitude, double longitude, String name})?> geocodeAddress({
    required String query,
    double? nearLat,
    double? nearLng,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final params = <String, String>{'q': q, 'format': 'jsonv2', 'limit': '1'};
    if (nearLat != null && nearLng != null) {
      final box = mosqueSearchBbox(
        latitude: nearLat,
        longitude: nearLng,
        radiusMeters: 25000,
      );
      params['viewbox'] =
          '${box.west.toStringAsFixed(5)},${box.north.toStringAsFixed(5)},'
          '${box.east.toStringAsFixed(5)},${box.south.toStringAsFixed(5)}';
      params['bounded'] = '0';
    }
    final uri = Uri.parse(nominatimSearchUrl).replace(queryParameters: params);
    final response = await _http
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': kPrayerCastOverpassUserAgent,
          },
        )
        .timeout(requestTimeout);
    if (_isBusyStatus(response.statusCode)) {
      throw const MosqueOverpassFailure('Nominatim is busy', busy: true);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MosqueOverpassFailure('Nominatim HTTP ${response.statusCode}');
    }
    return parseNominatimGeocode(response.body);
  }

  static bool _overpassTimedOut(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return false;
      final remark = decoded['remark']?.toString().toLowerCase() ?? '';
      return remark.contains('timed out') || remark.contains('timeout');
    } catch (_) {
      return false;
    }
  }

  static bool _isBusyStatus(int status) =>
      status == 429 || status == 502 || status == 503 || status == 504;

  static String _overpassQuery({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) {
    final box = mosqueSearchBbox(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
    final bbox =
        '(${box.south.toStringAsFixed(5)},${box.west.toStringAsFixed(5)},'
        '${box.north.toStringAsFixed(5)},${box.east.toStringAsFixed(5)})';
    return '[out:json][timeout:20];'
        '('
        'node["religion"="muslim"]$bbox;'
        'way["religion"="muslim"]$bbox;'
        'node["religion"="islam"]$bbox;'
        'way["religion"="islam"]$bbox;'
        'node["amenity"="mosque"]$bbox;'
        'way["amenity"="mosque"]$bbox;'
        'node["building"="mosque"]$bbox;'
        'way["building"="mosque"]$bbox;'
        'node["amenity"="place_of_worship"]["name"~"masjid|mosque|musholl|mushola|musala|mushalla|musolla|surau",i]$bbox;'
        'way["amenity"="place_of_worship"]["name"~"masjid|mosque|musholl|mushola|musala|mushalla|musolla|surau",i]$bbox;'
        ');'
        'out center tags;';
  }
}

/// Square bounding box around a point. Overpass wants south,west,north,east.
({double south, double west, double north, double east}) mosqueSearchBbox({
  required double latitude,
  required double longitude,
  required int radiusMeters,
}) {
  final latRad = latitude * math.pi / 180;
  final dLat = radiusMeters / 111320.0;
  final cosLat = math.cos(latRad).abs();
  final dLon = radiusMeters / (111320.0 * (cosLat < 0.2 ? 0.2 : cosLat));
  return (
    south: latitude - dLat,
    west: longitude - dLon,
    north: latitude + dLat,
    east: longitude + dLon,
  );
}

/// Dedupes OSM ids, nearest first.
List<NearbyMosque> mergeMosqueLists(
  List<NearbyMosque> primary,
  List<NearbyMosque> extra, {
  int limit = 40,
}) {
  final seen = <String>{};
  final merged = <NearbyMosque>[];
  for (final mosque in [...primary, ...extra]) {
    if (!seen.add(mosque.id)) continue;
    merged.add(mosque);
  }
  merged.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  if (merged.length <= limit) return merged;
  return merged.sublist(0, limit);
}

/// Parses an Overpass `out center tags` JSON body. Used by tests with fixtures.
List<NearbyMosque> parseOverpassMosques(
  String body, {
  required double fromLat,
  required double fromLng,
  int limit = 40,
  double? maxDistanceMeters,
  String unnamedId = 'Masjid',
  String unnamedEn = 'Mosque',
  bool indonesianNames = true,
}) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const MosqueOverpassFailure('Overpass response is not a JSON object');
  }
  final elements = decoded['elements'];
  if (elements is! List) return const [];

  final seen = <String>{};
  final mosques = <NearbyMosque>[];
  for (final raw in elements) {
    if (raw is! Map) continue;
    final type = raw['type']?.toString() ?? '';
    final osmId = raw['id']?.toString() ?? '';
    if (type.isEmpty || osmId.isEmpty) continue;
    final id = '$type:$osmId';
    if (!seen.add(id)) continue;

    final coords = _elementCoords(raw);
    if (coords == null) continue;
    final tags = _tagsMap(raw['tags']);
    if (!looksLikeMosque(tags)) continue;
    final name = _mosqueName(
      tags,
      unnamed: indonesianNames ? unnamedId : unnamedEn,
    );
    final distance = haversineMeters(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: coords.$1,
      toLng: coords.$2,
    );
    if (maxDistanceMeters != null && distance > maxDistanceMeters) continue;
    mosques.add(
      NearbyMosque(
        id: id,
        name: name,
        latitude: coords.$1,
        longitude: coords.$2,
        distanceMeters: distance,
      ),
    );
  }
  mosques.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  if (mosques.length <= limit) return mosques;
  return mosques.sublist(0, limit);
}

double? _jsonDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}

/// First Nominatim search hit, or null if the list is empty.
({double latitude, double longitude, String name})? parseNominatimGeocode(
  String body,
) {
  final decoded = jsonDecode(body);
  if (decoded is! List) {
    throw const MosqueOverpassFailure('Nominatim response is not a JSON list');
  }
  if (decoded.isEmpty) return null;
  final raw = decoded.first;
  if (raw is! Map) return null;
  final lat = _jsonDouble(raw['lat']);
  final lon = _jsonDouble(raw['lon']);
  if (lat == null || lon == null) return null;
  final named = raw['name']?.toString().trim() ?? '';
  final display = raw['display_name']?.toString().trim() ?? '';
  final name = named.isNotEmpty
      ? named
      : (display.isEmpty ? 'Pin' : display.split(',').first.trim());
  return (latitude: lat, longitude: lon, name: name);
}

/// Parses Nominatim search JSON (`jsonv2`). Used by tests with fixtures.
List<NearbyMosque> parseNominatimMosques(
  String body, {
  required double fromLat,
  required double fromLng,
  int limit = 40,
  double? maxDistanceMeters,
  String unnamedId = 'Masjid',
  String unnamedEn = 'Mosque',
  bool indonesianNames = true,
}) {
  final decoded = jsonDecode(body);
  if (decoded is! List) {
    throw const MosqueOverpassFailure('Nominatim response is not a JSON list');
  }

  final seen = <String>{};
  final mosques = <NearbyMosque>[];
  for (final raw in decoded) {
    if (raw is! Map) continue;
    final osmType = raw['osm_type']?.toString() ?? '';
    final osmId = raw['osm_id']?.toString() ?? '';
    if (osmType.isEmpty || osmId.isEmpty) continue;
    final id = '$osmType:$osmId';
    if (!seen.add(id)) continue;

    final lat = _jsonDouble(raw['lat']);
    final lon = _jsonDouble(raw['lon']);
    if (lat == null || lon == null) continue;

    final extra = _tagsMap(raw['extratags']);
    final nominatimType = raw['type']?.toString() ?? '';
    final nominatimClass =
        raw['class']?.toString() ?? raw['category']?.toString() ?? '';
    final displayName = raw['display_name']?.toString() ?? '';
    final shortName = raw['name']?.toString().trim() ?? '';
    final tags = <dynamic, dynamic>{
      ...extra,
      if (nominatimClass == 'amenity' || nominatimType == 'mosque')
        'amenity': nominatimType == 'mosque' ? 'mosque' : nominatimType,
      'name': shortName.isNotEmpty
          ? shortName
          : displayName.split(',').first.trim(),
    };
    if (!looksLikeMosque(tags)) continue;

    final name = _mosqueName(
      tags,
      unnamed: indonesianNames ? unnamedId : unnamedEn,
    );
    final distance = haversineMeters(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: lat,
      toLng: lon,
    );
    if (maxDistanceMeters != null && distance > maxDistanceMeters) continue;
    mosques.add(
      NearbyMosque(
        id: id,
        name: name,
        latitude: lat,
        longitude: lon,
        distanceMeters: distance,
      ),
    );
  }
  mosques.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  if (mosques.length <= limit) return mosques;
  return mosques.sublist(0, limit);
}

(double, double)? _elementCoords(Map<dynamic, dynamic> raw) {
  final lat = (raw['lat'] as num?)?.toDouble();
  final lon = (raw['lon'] as num?)?.toDouble();
  if (lat != null && lon != null) return (lat, lon);
  final center = raw['center'];
  if (center is Map) {
    final cLat = (center['lat'] as num?)?.toDouble();
    final cLon = (center['lon'] as num?)?.toDouble();
    if (cLat != null && cLon != null) return (cLat, cLon);
  }
  return null;
}

Map<dynamic, dynamic> _tagsMap(Object? raw) {
  return raw is Map ? raw : const {};
}

final _mosqueNamePattern = RegExp(
  r'masjid|mosque|musholl|mushola|musala|mushalla|musolla|surau|langgar',
  caseSensitive: false,
);

final _notAMosqueName = RegExp(
  r'kubur|cemetery|grave|makam|school|sekolah|association|universit|college',
  caseSensitive: false,
);

const _nonWorshipAmenities = {
  'school',
  'college',
  'kindergarten',
  'university',
  'grave_yard',
  'cemetery',
  'crematorium',
  'community_centre',
  'social_facility',
  'office',
};

/// True for mosque / musholla POIs; drops schools, graves, and other religions.
bool looksLikeMosque(Map<dynamic, dynamic> tags) {
  if (tags.containsKey('highway') ||
      tags.containsKey('railway') ||
      tags.containsKey('waterway')) {
    return false;
  }
  final amenity = tags['amenity']?.toString() ?? '';
  final building = tags['building']?.toString() ?? '';
  final landuse = tags['landuse']?.toString() ?? '';
  if (_nonWorshipAmenities.contains(amenity) ||
      amenity == 'grave_yard' ||
      landuse == 'cemetery' ||
      building == 'school') {
    return false;
  }
  final religion = (tags['religion']?.toString() ?? '').toLowerCase();
  if (religion.isNotEmpty && religion != 'muslim' && religion != 'islam') {
    return false;
  }
  if (amenity == 'mosque' || building == 'mosque') return true;
  final named = [
    tags['name'],
    tags['name:id'],
    tags['name:en'],
    tags['alt_name'],
  ].whereType<Object>().map((e) => e.toString()).join(' ');
  final namedMosque = _mosqueNamePattern.hasMatch(named);
  if (_notAMosqueName.hasMatch(named) && !namedMosque) return false;
  if (amenity == 'place_of_worship' &&
      (religion == 'muslim' || religion == 'islam' || namedMosque)) {
    return true;
  }
  if (!namedMosque) return false;
  return building.isNotEmpty || amenity.isEmpty;
}

String _mosqueName(Map<dynamic, dynamic> tags, {required String unnamed}) {
  for (final key in ['name', 'name:id', 'name:en', 'alt_name']) {
    final value = tags[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return unnamed;
}
