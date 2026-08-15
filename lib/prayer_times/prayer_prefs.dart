import 'dart:io';

import 'adzan_voices.dart';
import 'aladhan_client.dart';
import 'indonesia_location.dart';

/// How a prayer is delivered when the alarm fires.
///
/// Missing / unknown prefs values resolve to [cast] so existing installs
/// keep speaker playback unchanged.
enum PrayerDeliveryMode {
  beep,
  adhanPhone,
  cast,
}

extension PrayerDeliveryModeX on PrayerDeliveryMode {
  /// Wire value stored in the line-oriented prefs file.
  String get wire => name;

  static PrayerDeliveryMode parse(String? raw) {
    return switch (raw) {
      'beep' => PrayerDeliveryMode.beep,
      'adhanPhone' => PrayerDeliveryMode.adhanPhone,
      _ => PrayerDeliveryMode.cast,
    };
  }

  /// Voice selection applies to Cast and phone Adhan, not beep.
  bool get usesVoice => this != PrayerDeliveryMode.beep;
}

/// Asr school for Aladhan (`school` query param).
enum PrayerMadhabId {
  shafi, // 0
  hanafi, // 1
}

extension PrayerMadhabIdX on PrayerMadhabId {
  int get aladhanSchool => switch (this) {
        PrayerMadhabId.shafi => 0,
        PrayerMadhabId.hanafi => 1,
      };
}

/// Local prayer-time preferences. Location is free-form for Aladhan global API,
/// with optional GPS coordinates for more accurate timings.
final class PrayerPrefs {
  const PrayerPrefs({
    required this.city,
    required this.country,
    required this.methodId,
    required this.madhabId,
    required this.voiceId,
    required this.configured,
    this.voicesByPrayer = const {},
    this.deliveryByPrayer = const {},
    this.latitude,
    this.longitude,
    this.administrativeArea = '',
  });

  /// City name for Aladhan `timingsByCity` (e.g. London, Tokyo, Singapore).
  final String city;

  /// Country name / ISO (e.g. UK, Japan, Singapore).
  final String country;

  /// Calculation method id: [kemenagMethodId] (-1) or an Aladhan id
  /// (see [AladhanMethods]).
  final int methodId;

  final PrayerMadhabId madhabId;

  /// Default voice when a prayer has no override (non-fajr).
  final String voiceId;

  /// Optional per-prayer voice overrides (`fajr` → `fajr_adhan`, …).
  final Map<String, String> voicesByPrayer;

  /// Optional per-prayer delivery overrides (`fajr` → `beep`, …).
  /// Missing keys mean [PrayerDeliveryMode.cast].
  final Map<String, String> deliveryByPrayer;

  /// GPS latitude when the user used “Gunakan lokasi saya”.
  final double? latitude;

  /// GPS longitude when the user used “Gunakan lokasi saya”.
  final double? longitude;

  /// Kabupaten/kota (or province) from reverse geocode.
  ///
  /// Kemenag ids are kabupaten/kota, not kelurahan. GPS `city` can be a
  /// kelurahan; this hint is used only for local city matching and is
  /// never sent to myQuran.
  final String administrativeArea;

  /// True once the user has saved settings at least once.
  final bool configured;

  /// True when both coordinates are present for Aladhan timings-by-coords.
  bool get hasCoordinates => latitude != null && longitude != null;

  String get displayLocation {
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }

  String voiceFor(String prayerName) {
    final override = voicesByPrayer[prayerName];
    if (override != null && override.isNotEmpty) return override;
    return AdzanVoices.defaultForPrayer(prayerName);
  }

  PrayerDeliveryMode deliveryFor(String prayerName) {
    return PrayerDeliveryModeX.parse(deliveryByPrayer[prayerName]);
  }

  PrayerPrefs copyWith({
    String? city,
    String? country,
    int? methodId,
    PrayerMadhabId? madhabId,
    String? voiceId,
    bool? configured,
    Map<String, String>? voicesByPrayer,
    Map<String, String>? deliveryByPrayer,
    double? latitude,
    double? longitude,
    String? administrativeArea,
    bool clearCoordinates = false,
    bool clearAdministrativeArea = false,
  }) {
    return PrayerPrefs(
      city: city ?? this.city,
      country: country ?? this.country,
      methodId: methodId ?? this.methodId,
      madhabId: madhabId ?? this.madhabId,
      voiceId: voiceId ?? this.voiceId,
      configured: configured ?? this.configured,
      voicesByPrayer: voicesByPrayer ?? this.voicesByPrayer,
      deliveryByPrayer: deliveryByPrayer ?? this.deliveryByPrayer,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      administrativeArea: clearAdministrativeArea
          ? ''
          : (administrativeArea ?? this.administrativeArea),
    );
  }

  PrayerPrefs withVoiceFor(String prayerName, String voiceId) {
    final next = Map<String, String>.from(voicesByPrayer);
    next[prayerName] = voiceId;
    return copyWith(
      voicesByPrayer: next,
      voiceId: prayerName == 'fajr' ? this.voiceId : voiceId,
    );
  }

  PrayerPrefs withDeliveryFor(String prayerName, PrayerDeliveryMode mode) {
    final next = Map<String, String>.from(deliveryByPrayer);
    next[prayerName] = mode.wire;
    return copyWith(deliveryByPrayer: next);
  }

  static const PrayerPrefs defaults = PrayerPrefs(
    city: 'Singapore',
    country: 'Singapore',
    methodId: 11,
    madhabId: PrayerMadhabId.shafi,
    voiceId: 'standard_adhan',
    configured: false,
    voicesByPrayer: {
      'fajr': 'fajr_adhan',
      'dhuhr': 'standard_adhan',
      'asr': 'standard_adhan',
      'maghrib': 'standard_adhan',
      'isha': 'standard_adhan',
    },
  );
}

/// Port for reading/writing [PrayerPrefs].
abstract interface class PrayerPrefsStore {
  Future<PrayerPrefs> read();

  Future<void> write(PrayerPrefs prefs);
}

/// In-memory store for tests.
final class MemoryPrayerPrefsStore implements PrayerPrefsStore {
  MemoryPrayerPrefsStore([PrayerPrefs? initial])
      : _prefs = initial ?? PrayerPrefs.defaults;

  PrayerPrefs _prefs;

  @override
  Future<PrayerPrefs> read() async => _prefs;

  @override
  Future<void> write(PrayerPrefs prefs) async => _prefs = prefs;
}

/// File-backed prefs (line-oriented, backward-tolerant).
///
/// ```
/// city
/// country
/// methodId
/// madhabId
/// voiceId
/// configured(0|1)
/// fajr=fajr_adhan,...
/// latitude (optional)
/// longitude (optional)
/// fajr=cast,dhuhr=beep,... (optional; missing = all cast)
/// administrativeArea (optional; kabupaten/kota match hint)
/// ```
final class FilePrayerPrefsStore implements PrayerPrefsStore {
  FilePrayerPrefsStore(this._file);

  final File _file;

  @override
  Future<PrayerPrefs> read() async {
    if (!await _file.exists()) return PrayerPrefs.defaults;
    try {
      final lines = (await _file.readAsString()).split('\n');
      // Legacy format started with cityId like "singapore" / method enum name.
      final city = lines.isNotEmpty && lines[0].isNotEmpty
          ? _migrateCity(lines[0])
          : 'Singapore';
      final country = lines.length > 1 && lines[1].isNotEmpty
          ? _migrateCountry(lines[1], city)
          : 'Singapore';
      final methodId = _parseMethod(lines.length > 2 ? lines[2] : '11');
      final madhabId = _parseMadhab(lines.length > 3 ? lines[3] : 'shafi');
      final voiceId = lines.length > 4 && lines[4].isNotEmpty
          ? lines[4]
          : 'standard_adhan';
      final configured = lines.length > 5 && lines[5].trim() == '1';
      final voicesByPrayer =
          lines.length > 6 ? _parseVoices(lines[6]) : const <String, String>{};
      final latitude = lines.length > 7 ? double.tryParse(lines[7].trim()) : null;
      final longitude =
          lines.length > 8 ? double.tryParse(lines[8].trim()) : null;
      final deliveryByPrayer = lines.length > 9
          ? _parseDelivery(lines[9])
          : const <String, String>{};
      final administrativeArea =
          lines.length > 10 ? lines[10].trim() : '';
      return PrayerPrefs(
        city: city,
        country: country,
        methodId: methodId,
        madhabId: madhabId,
        voiceId: voiceId,
        configured: configured,
        voicesByPrayer: voicesByPrayer,
        deliveryByPrayer: deliveryByPrayer,
        latitude: latitude,
        longitude: longitude,
        administrativeArea: administrativeArea,
      );
    } catch (_) {
      return PrayerPrefs.defaults;
    }
  }

  @override
  Future<void> write(PrayerPrefs prefs) async {
    await _file.parent.create(recursive: true);
    final voices = prefs.voicesByPrayer.entries
        .map((e) => '${e.key}=${e.value}')
        .join(',');
    final delivery = prefs.deliveryByPrayer.entries
        .map((e) => '${e.key}=${e.value}')
        .join(',');
    final latLine = prefs.latitude?.toString() ?? '';
    final lngLine = prefs.longitude?.toString() ?? '';
    await _file.writeAsString(
      '${prefs.city}\n'
      '${prefs.country}\n'
      '${prefs.methodId}\n'
      '${prefs.madhabId.name}\n'
      '${prefs.voiceId}\n'
      '${prefs.configured ? 1 : 0}\n'
      '$voices\n'
      '$latLine\n'
      '$lngLine\n'
      '$delivery\n'
      '${prefs.administrativeArea}\n',
    );
  }

  static String _migrateCity(String raw) {
    // Old curated ids → display names.
    return switch (raw) {
      'singapore' => 'Singapore',
      'jakarta' => 'Jakarta',
      'bandung' => 'Bandung',
      'surabaya' => 'Surabaya',
      'yogyakarta' => 'Yogyakarta',
      'medan' => 'Medan',
      'makassar' => 'Makassar',
      'semarang' => 'Semarang',
      'palembang' => 'Palembang',
      'denpasar' => 'Denpasar',
      'balikpapan' => 'Balikpapan',
      'pontianak' => 'Pontianak',
      'manado' => 'Manado',
      // Old enum method accidentally stored in city slot — ignore.
      'indonesian' ||
      'muslimWorldLeague' ||
      'egyptian' =>
        'Singapore',
      _ => raw,
    };
  }

  static String _migrateCountry(String raw, String city) {
    // Old second line was method enum name.
    if (raw == 'indonesian' ||
        raw == 'muslimWorldLeague' ||
        raw == 'singapore' ||
        raw == 'egyptian' ||
        raw == 'shafi' ||
        raw == 'hanafi') {
      return switch (city) {
        'Jakarta' ||
        'Bandung' ||
        'Surabaya' ||
        'Yogyakarta' ||
        'Medan' ||
        'Makassar' ||
        'Semarang' ||
        'Palembang' ||
        'Denpasar' ||
        'Balikpapan' ||
        'Pontianak' ||
        'Manado' =>
          'Indonesia',
        'Singapore' => 'Singapore',
        _ => 'Singapore',
      };
    }
    return raw;
  }

  static int _parseMethod(String raw) {
    final asInt = int.tryParse(raw);
    if (asInt != null) return asInt;
    return switch (raw) {
      'indonesian' => kemenagMethodId,
      'muslimWorldLeague' => 3,
      'singapore' => 11,
      'egyptian' => 5,
      _ => 11,
    };
  }

  static PrayerMadhabId _parseMadhab(String raw) {
    for (final value in PrayerMadhabId.values) {
      if (value.name == raw) return value;
    }
    return PrayerMadhabId.shafi;
  }

  static Map<String, String> _parseVoices(String raw) {
    if (raw.trim().isEmpty) return const {};
    final out = <String, String>{};
    for (final part in raw.split(',')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      final key = part.substring(0, idx).trim();
      final value = part.substring(idx + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      out[key] = value;
    }
    return out;
  }

  static Map<String, String> _parseDelivery(String raw) {
    final parsed = _parseVoices(raw);
    if (parsed.isEmpty) return const {};
    final out = <String, String>{};
    for (final entry in parsed.entries) {
      if (entry.value == 'beep' ||
          entry.value == 'adhanPhone' ||
          entry.value == 'cast') {
        out[entry.key] = entry.value;
      }
    }
    return out;
  }
}
