import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';

import 'aladhan_client.dart';
import 'kemenag_city_index.dart';

/// HTTP client for Kemenag-equivalent jadwal via myQuran v2 sholat.
///
/// Official Kemenag SIHAT (`sihat.kemenag.dev`) requires a developer token
/// and an IP allowlist, which a Play-distributed app cannot use. myQuran
/// v2 (`api.myquran.com`) is a public HTTPS API, license "bebas untuk
/// dipergunakan" (free), that serves per-city official-style jadwal
/// (Imsak/Subuh/Dzuhur/Ashar/Maghrib/Isya) for every kabupaten/kota.
///
/// Requests send only a city id + date — never GPS coordinates.
final class KemenagClient {
  KemenagClient({
    http.Client? httpClient,
    KemenagCityIndex? cityIndex,
  })  : _http = httpClient ?? http.Client(),
        _cities = cityIndex ?? KemenagCityIndex.bundled();

  static const _host = 'api.myquran.com';
  static const methodDisplayName = 'Kemenag (Indonesia)';
  static const sourceKey = 'kemenag';

  final http.Client _http;
  final KemenagCityIndex _cities;

  KemenagKota? matchCity({required String city, String? adminArea}) {
    return _cities.match(city: city, adminArea: adminArea);
  }

  /// Resolve [city] (and optional [adminArea]) then fetch one local day.
  Future<AladhanDaySchedule> timingsForPlace({
    required String city,
    String? adminArea,
    required DateTime day,
    double latitude = 0,
    double longitude = 0,
    String voiceId = 'standard_adhan',
  }) async {
    final kota = matchCity(city: city, adminArea: adminArea);
    if (kota == null) {
      throw KemenagCityNotFound(
        'No Kemenag city match for "$city"'
        '${adminArea == null || adminArea.isEmpty ? '' : ' / "$adminArea"'}',
      );
    }
    return timingsForCityId(
      cityId: kota.id,
      day: day,
      latitude: latitude,
      longitude: longitude,
      voiceId: voiceId,
      lokasi: kota.lokasi,
    );
  }

  Future<AladhanDaySchedule> timingsForCityId({
    required String cityId,
    required DateTime day,
    double latitude = 0,
    double longitude = 0,
    String voiceId = 'standard_adhan',
    String? lokasi,
  }) async {
    final uri = Uri.https(
      _host,
      '/v2/sholat/jadwal/$cityId/${day.year}/${day.month}/${day.day}',
    );
    final response = await _http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw KemenagApiFailure(
        'Kemenag HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const KemenagApiFailure('Kemenag response is not a JSON object');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (map['status'] != true) {
      throw KemenagApiFailure('Kemenag error: ${map['message'] ?? map['status']}');
    }
    return parseJadwal(
      map,
      day: day,
      latitude: latitude,
      longitude: longitude,
      voiceId: voiceId,
      fallbackLokasi: lokasi,
    );
  }

  /// Parses a myQuran v2 `/sholat/jadwal/{id}/{y}/{m}/{d}` body.
  /// Imsak is ignored — the app has no sixth adhan slot.
  static AladhanDaySchedule parseJadwal(
    Map<String, dynamic> body, {
    required DateTime day,
    double latitude = 0,
    double longitude = 0,
    String voiceId = 'standard_adhan',
    String? fallbackLokasi,
  }) {
    final data = body['data'];
    if (data is! Map) {
      throw const KemenagApiFailure('Kemenag data missing');
    }
    final dataMap = Map<String, dynamic>.from(data);
    final jadwal = dataMap['jadwal'];
    if (jadwal is! Map) {
      throw const KemenagApiFailure('Kemenag jadwal missing');
    }
    final times = Map<String, dynamic>.from(jadwal);
    final localDay = DateTime(day.year, day.month, day.day);

    NextPrayer slot(String name, List<String> keys) {
      String? raw;
      for (final key in keys) {
        final value = times[key]?.toString();
        if (value != null && value.trim().isNotEmpty) {
          raw = value.trim();
          break;
        }
      }
      if (raw == null) {
        throw KemenagApiFailure('Kemenag missing timing for $name');
      }
      final hhmm = raw.split(' ').first;
      final parts = hhmm.split(':');
      if (parts.length < 2) {
        throw KemenagApiFailure('Bad Kemenag timing for $name: $raw');
      }
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return NextPrayer(
        name: name,
        scheduledAt: DateTime(
          localDay.year,
          localDay.month,
          localDay.day,
          hour,
          minute,
        ),
        voiceId: voiceId,
      );
    }

    final lokasi = dataMap['lokasi']?.toString() ?? fallbackLokasi ?? '';
    return AladhanDaySchedule(
      date: localDay,
      timezone: '',
      latitude: latitude,
      longitude: longitude,
      methodName: lokasi.isEmpty
          ? methodDisplayName
          : '$methodDisplayName · $lokasi',
      sourceKey: sourceKey,
      slots: [
        slot('fajr', const ['subuh', 'Subuh']),
        slot('dhuhr', const ['dzuhur', 'Dzuhur', 'zuhur']),
        slot('asr', const ['ashar', 'Ashar', 'asar']),
        slot('maghrib', const ['maghrib', 'Maghrib']),
        slot('isha', const ['isya', 'Isya', 'isha']),
      ],
    );
  }

  void close() => _http.close();
}

final class KemenagApiFailure implements Exception {
  const KemenagApiFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

final class KemenagCityNotFound implements Exception {
  const KemenagCityNotFound(this.message);
  final String message;

  @override
  String toString() => message;
}
