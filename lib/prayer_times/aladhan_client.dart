import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';

/// One day of Aladhan prayer timings (local wall-clock strings → DateTime).
final class AladhanDaySchedule {
  const AladhanDaySchedule({
    required this.date,
    required this.timezone,
    required this.latitude,
    required this.longitude,
    required this.slots,
    required this.methodName,
  });

  final DateTime date;
  final String timezone;
  final double latitude;
  final double longitude;
  final List<NextPrayer> slots;
  final String methodName;

  Map<String, Object?> toJson() => {
        'date': date.toIso8601String(),
        'timezone': timezone,
        'latitude': latitude,
        'longitude': longitude,
        'methodName': methodName,
        'slots': [
          for (final s in slots)
            {
              'name': s.name,
              'scheduledAt': s.scheduledAt.toIso8601String(),
              'voiceId': s.voiceId,
            },
        ],
      };

  static AladhanDaySchedule fromJson(Map<String, dynamic> json) {
    final slotsRaw = json['slots'];
    final slots = <NextPrayer>[];
    if (slotsRaw is List) {
      for (final raw in slotsRaw) {
        if (raw is! Map) continue;
        final name = raw['name']?.toString() ?? '';
        final at = DateTime.tryParse(raw['scheduledAt']?.toString() ?? '');
        if (name.isEmpty || at == null) continue;
        slots.add(
          NextPrayer(
            name: name,
            scheduledAt: at,
            voiceId: raw['voiceId']?.toString() ?? 'standard_adhan',
          ),
        );
      }
    }
    return AladhanDaySchedule(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      timezone: json['timezone']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      methodName: json['methodName']?.toString() ?? 'Aladhan',
      slots: slots,
    );
  }
}

/// Aladhan calculation method (https://aladhan.com/prayer-times-api).
final class AladhanMethod {
  const AladhanMethod({required this.id, required this.label});

  final int id;
  final String label;
}

/// Common Aladhan methods for the settings dropdown.
abstract final class AladhanMethods {
  static const List<AladhanMethod> common = [
    AladhanMethod(id: 11, label: 'MUIS (Singapore)'),
    AladhanMethod(id: 3, label: 'Muslim World League'),
    AladhanMethod(id: 2, label: 'ISNA (North America)'),
    AladhanMethod(id: 5, label: 'Egyptian General Authority'),
    AladhanMethod(id: 4, label: 'Umm Al-Qura (Makkah)'),
    AladhanMethod(id: 1, label: 'Karachi'),
    AladhanMethod(id: 7, label: 'Tehran'),
    AladhanMethod(id: 12, label: 'UOIF (France)'),
    AladhanMethod(id: 13, label: 'Diyanet (Turkey)'),
    AladhanMethod(id: 9, label: 'Kuwait'),
    AladhanMethod(id: 10, label: 'Qatar'),
    AladhanMethod(id: 8, label: 'Gulf Region'),
    AladhanMethod(id: 0, label: 'Jafari (Shia)'),
  ];
}

/// HTTP client for api.aladhan.com.
final class AladhanClient {
  AladhanClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const _host = 'api.aladhan.com';

  final http.Client _http;

  /// Timings by free-form address (city, country, etc.).
  Future<AladhanDaySchedule> timingsByAddress({
    required String address,
    required DateTime day,
    required int methodId,
    required int school, // 0 = Shafi, 1 = Hanafi
    String voiceId = 'standard_adhan',
  }) async {
    final date = _formatDate(day);
    final uri = Uri.https(_host, '/v1/timingsByAddress/$date', {
      'address': address,
      'method': '$methodId',
      'school': '$school',
    });
    return _fetch(uri, day: day, voiceId: voiceId);
  }

  /// Timings by city + country names.
  Future<AladhanDaySchedule> timingsByCity({
    required String city,
    required String country,
    required DateTime day,
    required int methodId,
    required int school,
    String voiceId = 'standard_adhan',
  }) async {
    final date = _formatDate(day);
    final uri = Uri.https(_host, '/v1/timingsByCity/$date', {
      'city': city,
      'country': country,
      'method': '$methodId',
      'school': '$school',
    });
    return _fetch(uri, day: day, voiceId: voiceId);
  }

  /// Timings by GPS coordinates.
  Future<AladhanDaySchedule> timingsByCoordinates({
    required double latitude,
    required double longitude,
    required DateTime day,
    required int methodId,
    required int school,
    String voiceId = 'standard_adhan',
  }) async {
    final date = _formatDate(day);
    final uri = Uri.https(_host, '/v1/timings/$date', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'method': '$methodId',
      'school': '$school',
    });
    return _fetch(uri, day: day, voiceId: voiceId);
  }

  Future<AladhanDaySchedule> _fetch(
    Uri uri, {
    required DateTime day,
    required String voiceId,
  }) async {
    final response = await _http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw AladhanApiFailure(
        'Aladhan HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AladhanApiFailure('Aladhan response is not a JSON object');
    }
    if (decoded['code'] != 200) {
      throw AladhanApiFailure('Aladhan error: ${decoded['status']}');
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const AladhanApiFailure('Aladhan data missing');
    }
    final timings = data['timings'];
    final meta = data['meta'];
    if (timings is! Map || meta is! Map) {
      throw const AladhanApiFailure('Aladhan timings/meta missing');
    }

    final localDay = DateTime(day.year, day.month, day.day);
    NextPrayer slot(String name, String key) {
      final raw = timings[key]?.toString() ?? '';
      final hhmm = raw.split(' ').first; // strip "(+08)" etc.
      final parts = hhmm.split(':');
      if (parts.length < 2) {
        throw AladhanApiFailure('Bad timing for $key: $raw');
      }
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return NextPrayer(
        name: name,
        scheduledAt: DateTime(localDay.year, localDay.month, localDay.day, hour, minute),
        voiceId: voiceId,
      );
    }

    final method = meta['method'];
    final methodName = method is Map
        ? (method['name']?.toString() ?? 'Aladhan')
        : 'Aladhan';

    return AladhanDaySchedule(
      date: localDay,
      timezone: meta['timezone']?.toString() ?? '',
      latitude: (meta['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (meta['longitude'] as num?)?.toDouble() ?? 0,
      methodName: methodName,
      slots: [
        slot('fajr', 'Fajr'),
        slot('dhuhr', 'Dhuhr'),
        slot('asr', 'Asr'),
        slot('maghrib', 'Maghrib'),
        slot('isha', 'Isha'),
      ],
    );
  }

  static String _formatDate(DateTime day) {
    final dd = day.day.toString().padLeft(2, '0');
    final mm = day.month.toString().padLeft(2, '0');
    return '$dd-$mm-${day.year}';
  }

  void close() => _http.close();
}

final class AladhanApiFailure implements Exception {
  const AladhanApiFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
