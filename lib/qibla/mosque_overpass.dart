import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'qibla_bearing.dart';

/// Overpass and Nominatim both ask for an identifiable client with a way to
/// reach the maintainer; anonymous agents get rate-limited first.
const kPrayerCastOverpassUserAgent =
    'PrayerCast/1.0.19 (com.tursinalabs.prayer_cast; https://tursinalabs.com)';

/// Minimum radius that may early-stop the ladder. Stopping at 2 km left dense
/// cities with a handful of pins when the previous fixed 5 km search returned
/// many more (Marine Parade: 5 at 2 km, 16 at 5 km, zero post-process loss).
const kMosqueEarlyStopMinRadiusMeters = 5000;

/// Failover pair. Both front the same `overpass-api.de` cluster, so a timeout
/// on one is worth retrying on the other before giving up on a radius tier.
const kOverpassInterpreterUrls = [
  'https://lz4.overpass-api.de/api/interpreter',
  'https://z.overpass-api.de/api/interpreter',
];

const kNominatimSearchUrl = 'https://nominatim.openstreetmap.org/search';

/// Radius ladder, widest last. A tier that already answers well enough stops
/// the climb, so dense cities never pay for a 10 km query.
const kMosqueSearchRadiiMeters = [2000, 5000, 10000];

/// "Well enough" for the ladder above.
const kMosqueEnoughResults = 5;

/// Hard ceiling across every tier, retry, and failover combined. Past this the
/// caller gets whatever is cached, or an empty list.
const kMosqueSearchBudget = Duration(seconds: 25);

/// Two OSM objects closer than this with similar (or absent) names are the
/// same building mapped twice — typically a node inside its own way.
const kMosqueDedupeMeters = 50.0;

/// Whether a POI reads as a full mosque or a smaller prayer room. Only used
/// for the label on unnamed rows and for the marker shape.
enum NearbyMosqueKind { mosque, prayerRoom }

final class NearbyMosque {
  const NearbyMosque({
    required this.id,
    required this.name,
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.bearingDegrees,
  });

  final String id;

  /// Raw OSM name, empty when the POI is unnamed. Unnamed rows are kept on
  /// purpose — a musholla with no `name` is still somewhere to pray — and
  /// fall back to [label].
  final String name;

  final NearbyMosqueKind kind;
  final double latitude;
  final double longitude;

  /// Straight-line metres from the search origin.
  final double distanceMeters;

  /// Straight-line bearing from the search origin, clockwise from true north.
  final double bearingDegrees;

  bool get isNamed => name.trim().isNotEmpty;

  String label({required bool isId}) {
    if (isNamed) return name.trim();
    return switch (kind) {
      NearbyMosqueKind.mosque => isId ? 'Masjid' : 'Mosque',
      NearbyMosqueKind.prayerRoom => isId ? 'Musholla' : 'Prayer room',
    };
  }

  /// Hand-off to the phone's map app. [label] is what the pin is called there.
  Uri geoUri(String label) {
    final q = Uri.encodeComponent('$latitude,$longitude($label)');
    return Uri.parse('geo:$latitude,$longitude?q=$q');
  }

  /// Same POI measured from a different origin. Cached answers are reused for
  /// anywhere in the same ~1 km cell, so distances are recomputed on read.
  NearbyMosque relativeTo({
    required double latitude,
    required double longitude,
  }) {
    return NearbyMosque(
      id: id,
      name: name,
      kind: kind,
      latitude: this.latitude,
      longitude: this.longitude,
      distanceMeters: haversineMeters(
        fromLat: latitude,
        fromLng: longitude,
        toLat: this.latitude,
        toLng: this.longitude,
      ),
      bearingDegrees: initialBearingDegrees(
        fromLat: latitude,
        fromLng: longitude,
        toLat: this.latitude,
        toLng: this.longitude,
      ),
    );
  }

  NearbyMosque withName(String name, NearbyMosqueKind kind) {
    return NearbyMosque(
      id: id,
      name: name,
      kind: kind,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters,
      bearingDegrees: bearingDegrees,
    );
  }
}

/// One Overpass answer plus the ladder tier that produced it. The radius is
/// what the UI calls "current radius" when deciding to offer "Search here".
final class MosqueSearchPage {
  const MosqueSearchPage({required this.mosques, required this.radiusMeters});

  final List<NearbyMosque> mosques;
  final int radiusMeters;
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

/// Nearby mosques from OpenStreetMap via the public Overpass API (HTTPS).
///
/// One tag-union `around:` query per radius tier, no name matching: OSM tags
/// decide what counts, so a "Masjid Road" never shows up and an unnamed
/// musholla still does.
final class MosqueOverpassClient {
  MosqueOverpassClient({
    http.Client? httpClient,
    List<String>? endpoints,
    List<int>? radiiMeters,
    this.nominatimSearchUrl = kNominatimSearchUrl,
    this.enoughResults = kMosqueEnoughResults,
    this.limit = 60,
    this.requestTimeout = const Duration(seconds: 12),
    this.totalBudget = kMosqueSearchBudget,
    DateTime Function()? clock,
  }) : _http = httpClient ?? http.Client(),
       _clock = clock ?? DateTime.now,
       endpoints = List<String>.unmodifiable(
         endpoints ?? kOverpassInterpreterUrls,
       ),
       radiiMeters = List<int>.unmodifiable(
         radiiMeters ?? kMosqueSearchRadiiMeters,
       );

  final http.Client _http;
  final DateTime Function() _clock;
  final List<String> endpoints;
  final List<int> radiiMeters;
  final String nominatimSearchUrl;

  /// Hits at which a radius tier is good enough to stop the ladder.
  final int enoughResults;

  final int limit;

  /// Per-request ceiling. Also clamped by whatever is left of [totalBudget].
  final Duration requestTimeout;

  /// Ceiling across every tier, retry, and failover.
  final Duration totalBudget;

  /// Endpoint that answered last, tried first next time.
  int _endpoint = 0;

  Future<MosqueSearchPage> nearby({
    required double latitude,
    required double longitude,
  }) async {
    final deadline = _clock().add(totalBudget);
    const headers = {
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'Accept': 'application/json',
      'User-Agent': kPrayerCastOverpassUserAgent,
    };

    Object? lastError;
    var sawBusy = false;
    var anyAnswer = false;
    var best = const MosqueSearchPage(mosques: [], radiusMeters: 0);

    for (final radius in radiiMeters) {
      final body =
          'data=${Uri.encodeQueryComponent(mosqueOverpassQuery(latitude: latitude, longitude: longitude, radiusMeters: radius))}';
      var answered = false;
      for (var hop = 0; hop < endpoints.length && !answered; hop++) {
        final remaining = deadline.difference(_clock());
        if (remaining <= Duration.zero) {
          return _settle(best, anyAnswer, lastError, sawBusy);
        }
        final index = (_endpoint + hop) % endpoints.length;
        final timeout = remaining < requestTimeout ? remaining : requestTimeout;
        try {
          final response = await _http
              .post(Uri.parse(endpoints[index]), headers: headers, body: body)
              .timeout(timeout);
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
          final parsed = parseOverpassMosquesDetailed(
            response.body,
            fromLat: latitude,
            fromLng: longitude,
            limit: limit,
          );
          answered = true;
          anyAnswer = true;
          _endpoint = index;
          developer.log(
            'tier ${radius}m raw=${parsed.stats.rawElements} '
            'afterFilter=${parsed.stats.afterFilter} '
            'afterDedupe=${parsed.stats.afterDedupe} '
            'afterCap=${parsed.stats.afterCap}',
            name: 'mosque.overpass',
          );
          final mosques = parsed.mosques;
          if (mosques.length > best.mosques.length) {
            best = MosqueSearchPage(mosques: mosques, radiusMeters: radius);
          }
          // Never early-stop on the 2 km tier alone — dense cities often hit
          // the bar there while a 5 km search still has far more mosques.
          if (mosques.length >= enoughResults &&
              radius >= kMosqueEarlyStopMinRadiusMeters) {
            return MosqueSearchPage(mosques: mosques, radiusMeters: radius);
          }
        } on TimeoutException catch (e) {
          sawBusy = true;
          lastError = e;
        } on SocketException catch (e) {
          lastError = e;
        } on http.ClientException catch (e) {
          lastError = e;
        } on FormatException catch (e) {
          lastError = e;
        } on MosqueOverpassFailure catch (e) {
          lastError = e;
        }
      }
    }
    return _settle(best, anyAnswer, lastError, sawBusy);
  }

  /// Best answer seen, an honest empty list if Overpass replied but had
  /// nothing, or a retryable failure if nothing replied at all.
  MosqueSearchPage _settle(
    MosqueSearchPage best,
    bool anyAnswer,
    Object? lastError,
    bool sawBusy,
  ) {
    if (best.mosques.isNotEmpty) return best;
    if (anyAnswer) {
      return MosqueSearchPage(
        mosques: const [],
        radiusMeters: radiiMeters.last,
      );
    }
    throw MosqueOverpassFailure(
      lastError?.toString() ?? 'Overpass unavailable',
      busy: sawBusy,
    );
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
}

/// Tag-union query for one radius tier.
///
/// `out center` keeps ways and relations to a single coordinate instead of
/// their full geometry, which is the difference between a few kB and a few
/// hundred on a dense city.
String mosqueOverpassQuery({
  required double latitude,
  required double longitude,
  required int radiusMeters,
}) {
  final around =
      'around:$radiusMeters,${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
  return '[out:json][timeout:20];'
      '('
      'nwr["amenity"="place_of_worship"]["religion"="muslim"]($around);'
      'nwr["building"="mosque"]($around);'
      'nwr["room"="prayer_room"]($around);'
      ');'
      'out center 60;';
}

/// Square bounding box around a point. Used for the Nominatim viewbox.
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

/// Counts at each post-processing stage. Used to diagnose coverage loss
/// without guessing which filter ate the rows.
final class MosqueParseStats {
  const MosqueParseStats({
    required this.rawElements,
    required this.afterFilter,
    required this.afterDedupe,
    required this.afterCap,
  });

  /// Elements Overpass returned (before any local filtering).
  final int rawElements;

  /// Survived [looksLikeMosque] (includes the retired-place gate).
  final int afterFilter;

  /// Survived [dedupeNearbyMosques].
  final int afterDedupe;

  /// After the client-side [limit] cap.
  final int afterCap;
}

final class MosqueParseResult {
  const MosqueParseResult({required this.mosques, required this.stats});

  final List<NearbyMosque> mosques;
  final MosqueParseStats stats;
}

/// Parses an Overpass `out center` JSON body, nearest first.
List<NearbyMosque> parseOverpassMosques(
  String body, {
  required double fromLat,
  required double fromLng,
  int limit = 60,
}) {
  return parseOverpassMosquesDetailed(
    body,
    fromLat: fromLat,
    fromLng: fromLng,
    limit: limit,
  ).mosques;
}

/// Same as [parseOverpassMosques], plus per-stage counts for diagnostics.
MosqueParseResult parseOverpassMosquesDetailed(
  String body, {
  required double fromLat,
  required double fromLng,
  int limit = 60,
}) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const MosqueOverpassFailure('Overpass response is not a JSON object');
  }
  final elements = decoded['elements'];
  if (elements is! List) {
    return const MosqueParseResult(
      mosques: [],
      stats: MosqueParseStats(
        rawElements: 0,
        afterFilter: 0,
        afterDedupe: 0,
        afterCap: 0,
      ),
    );
  }

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
    final name = _mosqueName(tags);
    mosques.add(
      NearbyMosque(
        id: id,
        name: name,
        kind: mosqueKindFor(tags, name),
        latitude: coords.$1,
        longitude: coords.$2,
        distanceMeters: haversineMeters(
          fromLat: fromLat,
          fromLng: fromLng,
          toLat: coords.$1,
          toLng: coords.$2,
        ),
        bearingDegrees: initialBearingDegrees(
          fromLat: fromLat,
          fromLng: fromLng,
          toLat: coords.$1,
          toLng: coords.$2,
        ),
      ),
    );
  }
  final afterFilter = mosques.length;
  final deduped = dedupeNearbyMosques(mosques);
  final capped = deduped.length <= limit
      ? deduped
      : deduped.sublist(0, limit);
  return MosqueParseResult(
    mosques: capped,
    stats: MosqueParseStats(
      rawElements: elements.length,
      afterFilter: afterFilter,
      afterDedupe: deduped.length,
      afterCap: capped.length,
    ),
  );
}

/// Collapses the copies OSM keeps of one building — a `place_of_worship` node
/// sitting inside its own `building=mosque` way, a relation over both — into
/// a single row. Two POIs merge only when they are within [withinMeters] *and*
/// their names look like the same place (see [mosqueNamesSimilar]).
List<NearbyMosque> dedupeNearbyMosques(
  List<NearbyMosque> mosques, {
  double withinMeters = kMosqueDedupeMeters,
}) {
  final sorted = [...mosques]
    ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  final kept = <NearbyMosque>[];
  for (final candidate in sorted) {
    var merged = false;
    for (var i = 0; i < kept.length; i++) {
      final other = kept[i];
      final gap = haversineMeters(
        fromLat: other.latitude,
        fromLng: other.longitude,
        toLat: candidate.latitude,
        toLng: candidate.longitude,
      );
      if (gap > withinMeters) continue;
      if (!mosqueNamesSimilar(other.name, candidate.name)) continue;
      // Keep the nearest geometry, but take a name over no name.
      if (!other.isNamed && candidate.isNamed) {
        kept[i] = other.withName(candidate.name, candidate.kind);
      }
      merged = true;
      break;
    }
    if (!merged) kept.add(candidate);
  }
  return kept;
}

/// True when two OSM names refer to the same place.
///
/// Distance is checked by the caller. Here: merge an unnamed twin with a
/// named one (node inside its way), or two names whose distinctive tokens
/// match after stripping generic mosque words. Sharing only "Masjid" /
/// "Mosque" / "Jami" / … is **not** similarity — those tokens are stripped
/// first, and an empty remainder does not count as a match.
bool mosqueNamesSimilar(String a, String b) {
  final aBlank = a.trim().isEmpty;
  final bBlank = b.trim().isEmpty;
  if (aBlank && bBlank) return true;
  if (aBlank || bBlank) return true;

  final left = normalizeMosqueName(a);
  final right = normalizeMosqueName(b);
  // Both were named, but only generic tokens remained — not the same place.
  if (left.isEmpty || right.isEmpty) return false;
  if (left == right) return true;
  return left.contains(right) || right.contains(left);
}

final _nameNoisePattern = RegExp(
  r'\b(masjid|mesjid|mosque|musholla|mushola|musholah|musala|mushalla|musolla|surau|langgar|jami|jamik|jamek|jame|raya|agung|besar|al|an|ar|as|at|ad|ul)\b',
);
final _nonWordPattern = RegExp(r'[^a-z0-9]+');

/// Strips punctuation and the generic words nearly every mosque name carries,
/// so "Masjid Al-Ikhlas" and "Al Ikhlas" compare equal. Remaining empty means
/// the name had no distinctive tokens — that is not a match on its own.
String normalizeMosqueName(String raw) {
  final stripped = raw
      .toLowerCase()
      .replaceAll(_nonWordPattern, ' ')
      .replaceAll(_nameNoisePattern, ' ');
  return stripped.split(' ').where((word) => word.isNotEmpty).join(' ');
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

double? _jsonDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
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

/// True for places that exist in OSM but not on the ground: explicitly
/// disused, ruined, or tagged as under construction on this element.
///
/// Only matches `disused:*` key prefixes, `historic=ruins`, and a
/// `construction=*` tag on the element itself — never a substring anywhere
/// else in the tag set.
bool isRetiredPlace(Map<dynamic, dynamic> tags) {
  for (final key in tags.keys) {
    if (key.toString().toLowerCase().startsWith('disused:')) return true;
  }
  if (tags['historic']?.toString() == 'ruins') return true;
  if (tags.containsKey('construction')) return true;
  return false;
}

/// True when OSM tags — never the name — say this is somewhere Muslims pray.
bool looksLikeMosque(Map<dynamic, dynamic> tags) {
  if (isRetiredPlace(tags)) return false;
  final religion = (tags['religion']?.toString() ?? '').toLowerCase();
  if (religion.isNotEmpty && religion != 'muslim' && religion != 'islam') {
    return false;
  }
  if (tags['building']?.toString() == 'mosque') return true;
  if (tags['room']?.toString() == 'prayer_room') return true;
  return tags['amenity']?.toString() == 'place_of_worship' &&
      (religion == 'muslim' || religion == 'islam');
}

final _mosqueTitlePattern = RegExp(
  r'^(masjid|mesjid|mosque|jamek)\b',
  caseSensitive: false,
);

/// A full mosque only when the building says so or the name opens with
/// "Masjid". Everything else reads as a prayer room, which is the safer
/// label for an unnamed POI.
NearbyMosqueKind mosqueKindFor(Map<dynamic, dynamic> tags, String name) {
  if (tags['building']?.toString() == 'mosque') return NearbyMosqueKind.mosque;
  if (_mosqueTitlePattern.hasMatch(name.trim())) {
    return NearbyMosqueKind.mosque;
  }
  return NearbyMosqueKind.prayerRoom;
}

String _mosqueName(Map<dynamic, dynamic> tags) {
  for (final key in ['name', 'name:id', 'name:en', 'alt_name']) {
    final value = tags[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}
