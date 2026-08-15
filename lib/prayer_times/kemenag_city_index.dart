import 'dart:convert';

import 'kemenag_kota_data.dart';

/// One kabupaten/kota row from the bundled myQuran/Kemenag directory.
final class KemenagKota {
  const KemenagKota({required this.id, required this.lokasi});

  final String id;
  final String lokasi;

  bool get isKota => lokasi.toUpperCase().startsWith('KOTA ');
  bool get isKabupaten =>
      lokasi.toUpperCase().startsWith('KAB.') ||
      lokasi.toUpperCase().startsWith('KAB ');
}

/// Fuzzy-matches a typed or reverse-geocoded place name to a Kemenag city id.
///
/// Covers the full bundled directory (all kabupaten/kota myQuran lists),
/// not a short curated subset.
final class KemenagCityIndex {
  KemenagCityIndex(List<KemenagKota> cities) : _cities = List.unmodifiable(cities);

  factory KemenagCityIndex.bundled() =>
      KemenagCityIndex.parseJson(kemenagKotaJson);

  factory KemenagCityIndex.parseJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Kemenag kota list is not a JSON array');
    }
    final cities = <KemenagKota>[];
    for (final raw in decoded) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString() ?? '';
      final name = raw['n']?.toString() ?? raw['lokasi']?.toString() ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      cities.add(KemenagKota(id: id, lokasi: name));
    }
    return KemenagCityIndex(cities);
  }

  final List<KemenagKota> _cities;

  List<KemenagKota> get cities => _cities;

  /// Best match for [city] and optional [adminArea] (province / kabupaten).
  KemenagKota? match({required String city, String? adminArea}) {
    final candidates = <String>[
      city,
      if (adminArea != null && adminArea.trim().isNotEmpty) adminArea,
    ];
    KemenagKota? best;
    var bestScore = 0;
    for (final candidate in candidates) {
      final scored = _bestFor(candidate);
      if (scored != null && scored.score > bestScore) {
        best = scored.kota;
        bestScore = scored.score;
      }
    }
    if (bestScore < 50) return null;
    return best;
  }

  ({KemenagKota kota, int score})? _bestFor(String raw) {
    final query = _normalize(raw);
    if (query.isEmpty) return null;
    final wantsKab = _wantsKabupaten(raw);
    final wantsKota = _wantsKota(raw);
    final jakartaHint = _isJakartaHint(query);

    KemenagKota? best;
    var bestScore = 0;
    for (final kota in _cities) {
      var score = _score(query, kota);
      if (score <= 0) continue;
      if (jakartaHint && kota.id == '1301') {
        score += 20;
      }
      if (wantsKab && kota.isKabupaten) score += 8;
      if (wantsKota && kota.isKota) score += 8;
      if (!wantsKab && !wantsKota && kota.isKota && score >= 90) {
        score += 4;
      }
      if (score > bestScore) {
        best = kota;
        bestScore = score;
      }
    }
    if (best == null) return null;
    return (kota: best, score: bestScore);
  }

  static int _score(String query, KemenagKota kota) {
    final loc = _normalize(kota.lokasi);
    if (loc.isEmpty) return 0;
    if (query == loc) return 100;
    if (loc == query) return 100;
    if (query.length >= 4 && loc.startsWith('$query ')) return 86;
    if (loc.startsWith(query) && query.length >= loc.length - 1) return 84;
    if (query.startsWith('$loc ') && loc.length >= 4) return 78;
    if (query.startsWith(loc) && loc.length >= 5) return 72;
    if (loc.contains(' $query') || loc.contains('$query ')) return 64;
    if (query.contains(loc) && loc.length >= 5) return 60;
    return 0;
  }

  static bool _wantsKabupaten(String raw) {
    final n = raw.toLowerCase();
    return n.contains('kabupaten') ||
        n.contains('kab.') ||
        RegExp(r'\bkab\b').hasMatch(n) ||
        n.contains('regency');
  }

  static bool _wantsKota(String raw) {
    final n = raw.toLowerCase();
    return n.contains('kota') || n.contains('city');
  }

  static bool _isJakartaHint(String query) {
    return query == 'jakarta' ||
        query.startsWith('jakarta ') ||
        query.contains(' jakarta') ||
        query == 'dki jakarta' ||
        query == 'dki';
  }

  static String _normalize(String raw) {
    var s = raw.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[./_,()\-]'), ' ');
    s = s.replaceAll(
      RegExp(
        r'\b(kota|kabupaten|kab|city|regency|administrasi|adm|'
        r'provinsi|province|daerah istimewa|special region|dki|di)\b',
      ),
      ' ',
    );
    // Jakarta municipalities collapse to the single Kemenag "KOTA JAKARTA".
    if (s.contains('jakarta')) {
      s = s.replaceAll(
        RegExp(r'\b(utara|selatan|timur|barat|pusat|north|south|east|west|central)\b'),
        ' ',
      );
    }
    return s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
  }
}
