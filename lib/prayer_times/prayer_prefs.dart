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
  takbir,
  adhanPhone,
  cast,
}

extension PrayerDeliveryModeX on PrayerDeliveryMode {
  /// Wire value stored in the line-oriented prefs file.
  String get wire => name;

  static PrayerDeliveryMode parse(String? raw) {
    return switch (raw) {
      'beep' => PrayerDeliveryMode.beep,
      'takbir' => PrayerDeliveryMode.takbir,
      'adhanPhone' => PrayerDeliveryMode.adhanPhone,
      _ => PrayerDeliveryMode.cast,
    };
  }

  /// Voice selection applies to Cast and phone Adhan, not beep/takbir.
  bool get usesVoice =>
      this != PrayerDeliveryMode.beep && this != PrayerDeliveryMode.takbir;
}

enum PrePrayerAlertSound {
  beep,
  takbir,
}

extension PrePrayerAlertSoundX on PrePrayerAlertSound {
  String get wire => name;

  static PrePrayerAlertSound parse(String? raw) {
    return switch (raw) {
      'takbir' => PrePrayerAlertSound.takbir,
      _ => PrePrayerAlertSound.beep,
    };
  }
}

/// Sound for the post-adhan iqamah nudge (global; offsets are per-prayer).
enum IqamahSound {
  silent,
  chime,
}

extension IqamahSoundX on IqamahSound {
  String get wire => name;

  static IqamahSound parse(String? raw) {
    return switch (raw) {
      'silent' => IqamahSound.silent,
      _ => IqamahSound.chime,
    };
  }
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
    this.volumesByPrayer = const {},
    this.defaultDeliveryMode = PrayerDeliveryMode.cast,
    this.defaultsMigrated = false,
    this.latitude,
    this.longitude,
    this.administrativeArea = '',
    this.prePrayerAlertMinutes = 0,
    this.prePrayerAlertSound = PrePrayerAlertSound.beep,
    this.iqamahMinutesByPrayer = const {},
    this.iqamahSound = IqamahSound.chime,
    this.travelScheduleUpdates = false,
    this.castFallbackToPhone = true,
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
  /// Missing keys inherit [defaultDeliveryMode].
  final Map<String, String> deliveryByPrayer;

  /// Global default when a prayer has no delivery override.
  final PrayerDeliveryMode defaultDeliveryMode;

  /// True after the one-shot default/override migration has run.
  final bool defaultsMigrated;

  /// Opt-in Cast volume per prayer (0–1). Missing key / null = leave speaker.
  final Map<String, double> volumesByPrayer;

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

  /// Minutes before azan for a pre-prayer reminder notification (0 = off).
  final int prePrayerAlertMinutes;

  /// Sound for the pre-prayer reminder notification.
  final PrePrayerAlertSound prePrayerAlertSound;

  /// Minutes after adhan for the iqamah nudge (`0` = off).
  /// Missing keys fall back to [defaultIqamahMinutesFor].
  final Map<String, int> iqamahMinutesByPrayer;

  /// Global iqamah sound (one control for all prayers).
  final IqamahSound iqamahSound;

  /// When Cast fails, play on phone (full Adhan if presence was HOME, else chime).
  final bool castFallbackToPhone;

  /// When true, refresh city/times if the phone has moved ~25 km.
  final bool travelScheduleUpdates;

  /// True once the user has saved settings at least once.
  final bool configured;

  /// True when both coordinates are present for Aladhan timings-by-coords.
  bool get hasCoordinates => latitude != null && longitude != null;

  String get displayLocation {
    if (city.isEmpty) return country;
    if (country.isEmpty) return city;
    return '$city, $country';
  }

  static const List<String> prayerKeys = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  String voiceFor(String prayerName) {
    final override = voicesByPrayer[prayerName];
    if (override != null && override.isNotEmpty) return override;
    if (voiceId.isNotEmpty) return voiceId;
    return AdzanVoices.defaultForPrayer(prayerName);
  }

  PrayerDeliveryMode deliveryFor(String prayerName) {
    final raw = deliveryByPrayer[prayerName];
    if (raw == null || raw.isEmpty) return defaultDeliveryMode;
    return PrayerDeliveryModeX.parse(raw);
  }

  bool hasDeliveryOverride(String prayerName) =>
      deliveryByPrayer.containsKey(prayerName);

  bool hasVoiceOverride(String prayerName) {
    final raw = voicesByPrayer[prayerName];
    return raw != null && raw.isNotEmpty;
  }

  /// Materialize every prayer's current effective delivery/voice as overrides,
  /// set defaults from majority, then keep effective values unchanged.
  PrayerPrefs migrateDefaultsIfNeeded() {
    if (defaultsMigrated) return this;

    final deliveryExplicit = <String, String>{};
    final voiceExplicit = <String, String>{};
    for (final prayer in prayerKeys) {
      deliveryExplicit[prayer] = deliveryFor(prayer).wire;
      voiceExplicit[prayer] = voiceFor(prayer);
    }

    final defaultDelivery = _majorityDelivery(deliveryExplicit.values);
    final defaultVoice = _majorityString(voiceExplicit.values) ?? voiceId;

    return copyWith(
      deliveryByPrayer: deliveryExplicit,
      voicesByPrayer: voiceExplicit,
      defaultDeliveryMode: defaultDelivery,
      voiceId: defaultVoice,
      defaultsMigrated: true,
    );
  }

  static PrayerDeliveryMode _majorityDelivery(Iterable<String> wires) {
    final counts = <String, int>{};
    for (final wire in wires) {
      counts[wire] = (counts[wire] ?? 0) + 1;
    }
    String? best;
    var bestCount = -1;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return PrayerDeliveryModeX.parse(best);
  }

  static String? _majorityString(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      if (value.isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    String? best;
    var bestCount = -1;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  /// Null means do not change Cast volume for this prayer.
  double? volumeFor(String prayerName) => volumesByPrayer[prayerName];

  /// Allowed iqamah offsets: 0 (off), 5, 10, 15, 20 minutes after adhan.
  static int defaultIqamahMinutesFor(String prayerName) {
    return prayerName == 'maghrib' ? 5 : 10;
  }

  static int normalizeIqamahMinutes(int raw) {
    if (raw == 5 || raw == 10 || raw == 15 || raw == 20) return raw;
    return 0;
  }

  int iqamahMinutesFor(String prayerName) {
    final raw = iqamahMinutesByPrayer[prayerName];
    if (raw == null) return defaultIqamahMinutesFor(prayerName);
    return normalizeIqamahMinutes(raw);
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
    Map<String, double>? volumesByPrayer,
    Map<String, int>? iqamahMinutesByPrayer,
    IqamahSound? iqamahSound,
    PrayerDeliveryMode? defaultDeliveryMode,
    bool? defaultsMigrated,
    double? latitude,
    double? longitude,
    String? administrativeArea,
    bool clearCoordinates = false,
    bool clearAdministrativeArea = false,
    int? prePrayerAlertMinutes,
    PrePrayerAlertSound? prePrayerAlertSound,
    bool? travelScheduleUpdates,
    bool? castFallbackToPhone,
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
      volumesByPrayer: volumesByPrayer ?? this.volumesByPrayer,
      iqamahMinutesByPrayer:
          iqamahMinutesByPrayer ?? this.iqamahMinutesByPrayer,
      iqamahSound: iqamahSound ?? this.iqamahSound,
      defaultDeliveryMode: defaultDeliveryMode ?? this.defaultDeliveryMode,
      defaultsMigrated: defaultsMigrated ?? this.defaultsMigrated,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      administrativeArea: clearAdministrativeArea
          ? ''
          : (administrativeArea ?? this.administrativeArea),
      prePrayerAlertMinutes:
          prePrayerAlertMinutes ?? this.prePrayerAlertMinutes,
      prePrayerAlertSound: prePrayerAlertSound ?? this.prePrayerAlertSound,
      travelScheduleUpdates:
          travelScheduleUpdates ?? this.travelScheduleUpdates,
      castFallbackToPhone: castFallbackToPhone ?? this.castFallbackToPhone,
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

  PrayerPrefs clearDeliveryOverride(String prayerName) {
    final next = Map<String, String>.from(deliveryByPrayer)..remove(prayerName);
    return copyWith(deliveryByPrayer: next);
  }

  PrayerPrefs clearVoiceOverride(String prayerName) {
    final next = Map<String, String>.from(voicesByPrayer)..remove(prayerName);
    return copyWith(voicesByPrayer: next);
  }

  /// [volume] null clears the opt-in and restores "leave speaker alone".
  PrayerPrefs withVolumeFor(String prayerName, double? volume) {
    final next = Map<String, double>.from(volumesByPrayer);
    if (volume == null) {
      next.remove(prayerName);
    } else {
      next[prayerName] = volume.clamp(0.0, 1.0);
    }
    return copyWith(volumesByPrayer: next);
  }

  PrayerPrefs withIqamahMinutesFor(String prayerName, int minutes) {
    final next = Map<String, int>.from(iqamahMinutesByPrayer);
    next[prayerName] = normalizeIqamahMinutes(minutes);
    return copyWith(iqamahMinutesByPrayer: next);
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
    iqamahMinutesByPrayer: {
      'fajr': 10,
      'dhuhr': 10,
      'asr': 10,
      'maghrib': 5,
      'isha': 10,
    },
    defaultDeliveryMode: PrayerDeliveryMode.cast,
    defaultsMigrated: true,
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
  Future<PrayerPrefs> read() async => _prefs.migrateDefaultsIfNeeded();

  @override
  Future<void> write(PrayerPrefs prefs) async =>
      _prefs = prefs.migrateDefaultsIfNeeded();
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
/// prePrayerAlertMinutes (0|10|15; optional; default 0)
/// travelScheduleUpdates (always written 0; auto-travel GPS was removed)
/// prePrayerAlertSound (beep|takbir; optional; default beep)
/// castFallbackToPhone (0|1; optional; default 1)
/// volumesByPrayer fajr=0.5,... (optional; missing keys = leave speaker alone)
/// iqamahMinutesByPrayer fajr=10,... (optional; missing → Maghrib 5 / else 10)
/// iqamahSound (silent|chime; optional; default chime)
/// defaultDeliveryMode (beep|takbir|adhanPhone|cast; optional; default cast)
/// defaultsMigrated (0|1; optional; default 0 → run one-shot migrate)
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
      final preAlert = lines.length > 11
          ? int.tryParse(lines[11].trim()) ?? 0
          : 0;
      final alertSound = lines.length > 13
          ? PrePrayerAlertSoundX.parse(lines[13].trim())
          : PrePrayerAlertSound.beep;
      final castFallback = lines.length > 14
          ? lines[14].trim() != '0'
          : true;
      final volumesByPrayer = lines.length > 15
          ? _parseVolumes(lines[15])
          : const <String, double>{};
      final iqamahMinutesByPrayer = lines.length > 16
          ? _parseIqamahMinutes(lines[16])
          : PrayerPrefs.defaults.iqamahMinutesByPrayer;
      final iqamahSound = lines.length > 17
          ? IqamahSoundX.parse(lines[17].trim())
          : IqamahSound.chime;
      final defaultDelivery = lines.length > 18
          ? PrayerDeliveryModeX.parse(lines[18].trim())
          : PrayerDeliveryMode.cast;
      final defaultsMigrated = lines.length > 19
          ? lines[19].trim() == '1'
          : false;
      final prefs = PrayerPrefs(
        city: city,
        country: country,
        methodId: methodId,
        madhabId: madhabId,
        voiceId: voiceId,
        configured: configured,
        voicesByPrayer: voicesByPrayer,
        deliveryByPrayer: deliveryByPrayer,
        volumesByPrayer: volumesByPrayer,
        iqamahMinutesByPrayer: iqamahMinutesByPrayer,
        iqamahSound: iqamahSound,
        defaultDeliveryMode: defaultDelivery,
        defaultsMigrated: defaultsMigrated,
        latitude: latitude,
        longitude: longitude,
        administrativeArea: administrativeArea,
        prePrayerAlertMinutes: _normalizePreAlertMinutes(preAlert),
        travelScheduleUpdates: false,
        prePrayerAlertSound: alertSound,
        castFallbackToPhone: castFallback,
      );
      return prefs.migrateDefaultsIfNeeded();
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
    final volumes = prefs.volumesByPrayer.entries
        .map((e) => '${e.key}=${e.value.toStringAsFixed(2)}')
        .join(',');
    final iqamah = [
      for (final prayer in const [
        'fajr',
        'dhuhr',
        'asr',
        'maghrib',
        'isha',
      ])
        '$prayer=${prefs.iqamahMinutesFor(prayer)}',
    ].join(',');
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
      '${prefs.administrativeArea}\n'
      '${prefs.prePrayerAlertMinutes}\n'
      '0\n'
      '${prefs.prePrayerAlertSound.wire}\n'
      '${prefs.castFallbackToPhone ? 1 : 0}\n'
      '$volumes\n'
      '$iqamah\n'
      '${prefs.iqamahSound.wire}\n'
      '${prefs.defaultDeliveryMode.wire}\n'
      '${prefs.defaultsMigrated ? 1 : 0}\n',
    );
  }

  static int _normalizePreAlertMinutes(int raw) {
    if (raw == 10 || raw == 15) return raw;
    return 0;
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
          entry.value == 'takbir' ||
          entry.value == 'adhanPhone' ||
          entry.value == 'cast') {
        out[entry.key] = entry.value;
      }
    }
    return out;
  }

  static Map<String, double> _parseVolumes(String raw) {
    if (raw.trim().isEmpty) return const {};
    final out = <String, double>{};
    for (final part in raw.split(',')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      final key = part.substring(0, idx).trim();
      final value = double.tryParse(part.substring(idx + 1).trim());
      if (key.isEmpty || value == null) continue;
      out[key] = value.clamp(0.0, 1.0);
    }
    return out;
  }

  static Map<String, int> _parseIqamahMinutes(String raw) {
    if (raw.trim().isEmpty) {
      return Map<String, int>.from(PrayerPrefs.defaults.iqamahMinutesByPrayer);
    }
    final out = <String, int>{};
    for (final part in raw.split(',')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      final key = part.substring(0, idx).trim();
      final value = int.tryParse(part.substring(idx + 1).trim());
      if (key.isEmpty || value == null) continue;
      out[key] = PrayerPrefs.normalizeIqamahMinutes(value);
    }
    return out.isEmpty
        ? Map<String, int>.from(PrayerPrefs.defaults.iqamahMinutesByPrayer)
        : out;
  }
}
