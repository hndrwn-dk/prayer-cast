import 'dart:convert';
import 'dart:io';

import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';

import 'aladhan_client.dart';
import 'prayer_prefs.dart';

/// [NextPrayerProvider] using Aladhan Prayer Times API (global cities).
///
/// Fetches today + tomorrow on demand and picks the next obligatory slot.
/// Successful fetches are written to [scheduleCacheFile] so a cold process
/// can still arm the next wake offline.
final class AdhanNextPrayerProvider implements NextPrayerProvider {
  AdhanNextPrayerProvider({
    required PrayerPrefsStore store,
    AladhanClient? client,
    File? scheduleCacheFile,
  })  : _store = store,
        _client = client ?? AladhanClient(),
        _scheduleCacheFile = scheduleCacheFile;

  final PrayerPrefsStore _store;
  final AladhanClient _client;
  final File? _scheduleCacheFile;

  AladhanDaySchedule? _cachedToday;
  AladhanDaySchedule? _cachedTomorrow;
  String? _cacheKey;

  @override
  Future<NextPrayer> next({required DateTime after}) async {
    final prefs = await _store.read();
    final schedules = await schedulesAround(prefs: prefs, after: after);
    final localAfter = after.toLocal();
    for (final day in schedules) {
      for (final slot in day.slots) {
        if (slot.scheduledAt.isAfter(localAfter)) {
          return NextPrayer(
            name: slot.name,
            scheduledAt: slot.scheduledAt,
            voiceId: prefs.voiceFor(slot.name),
          );
        }
      }
    }
    final last = schedules.last.slots.first;
    return NextPrayer(
      name: last.name,
      scheduledAt: last.scheduledAt.add(const Duration(days: 1)),
      voiceId: prefs.voiceFor(last.name),
    );
  }

  /// Today’s schedule for UI (uses cache when possible).
  Future<AladhanDaySchedule> scheduleForDay({
    required PrayerPrefs prefs,
    required DateTime day,
  }) async {
    final days = await schedulesAround(prefs: prefs, after: day);
    final local = DateTime(day.year, day.month, day.day);
    for (final d in days) {
      if (d.date.year == local.year &&
          d.date.month == local.month &&
          d.date.day == local.day) {
        return _withVoices(d, prefs);
      }
    }
    return _withVoices(days.first, prefs);
  }

  Future<List<AladhanDaySchedule>> schedulesAround({
    required PrayerPrefs prefs,
    required DateTime after,
  }) async {
    final local = after.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final tomorrow = today.add(const Duration(days: 1));
    final key =
        '${prefs.city}|${prefs.country}|${prefs.latitude}|${prefs.longitude}|'
        '${prefs.methodId}|${prefs.madhabId.name}|${today.toIso8601String()}';
    if (_cacheKey != key || _cachedToday == null || _cachedTomorrow == null) {
      final school = prefs.madhabId.aladhanSchool;
      try {
        final fetchedToday = await _fetch(prefs, today, school);
        final fetchedTomorrow = await _fetch(prefs, tomorrow, school);
        _cachedToday = fetchedToday;
        _cachedTomorrow = fetchedTomorrow;
        _cacheKey = key;
        await _writeDiskCache(
          key,
          [fetchedToday, fetchedTomorrow],
          locationKey: _locationKey(prefs),
        );
      } catch (e) {
        final disk = await _readDiskCache();
        if (disk != null &&
            disk.days.isNotEmpty &&
            _diskCovers(disk, prefs: prefs, after: after)) {
          _cachedToday = disk.days[0];
          _cachedTomorrow =
              disk.days.length > 1 ? disk.days[1] : disk.days[0];
          _cacheKey = key;
        } else {
          rethrow;
        }
      }
    }
    return [
      _withVoices(_cachedToday!, prefs),
      _withVoices(_cachedTomorrow!, prefs),
    ];
  }

  Future<AladhanDaySchedule> _fetch(
    PrayerPrefs prefs,
    DateTime day,
    int school,
  ) {
    if (prefs.hasCoordinates) {
      return _client.timingsByCoordinates(
        latitude: prefs.latitude!,
        longitude: prefs.longitude!,
        day: day,
        methodId: prefs.methodId,
        school: school,
        voiceId: prefs.voiceId,
      );
    }
    if (prefs.city.isNotEmpty && prefs.country.isNotEmpty) {
      return _client.timingsByCity(
        city: prefs.city,
        country: prefs.country,
        day: day,
        methodId: prefs.methodId,
        school: school,
        voiceId: prefs.voiceId,
      );
    }
    final address = prefs.displayLocation;
    return _client.timingsByAddress(
      address: address,
      day: day,
      methodId: prefs.methodId,
      school: school,
      voiceId: prefs.voiceId,
    );
  }

  static AladhanDaySchedule _withVoices(
    AladhanDaySchedule day,
    PrayerPrefs prefs,
  ) {
    return AladhanDaySchedule(
      date: day.date,
      timezone: day.timezone,
      latitude: day.latitude,
      longitude: day.longitude,
      methodName: day.methodName,
      slots: [
        for (final s in day.slots)
          NextPrayer(
            name: s.name,
            scheduledAt: s.scheduledAt,
            voiceId: prefs.voiceFor(s.name),
          ),
      ],
    );
  }

  /// Clears in-memory day cache (call after prefs save).
  void invalidateCache() {
    _cacheKey = null;
    _cachedToday = null;
    _cachedTomorrow = null;
  }

  static String _locationKey(PrayerPrefs prefs) =>
      '${prefs.city}|${prefs.country}|${prefs.latitude}|${prefs.longitude}|'
      '${prefs.methodId}|${prefs.madhabId.name}';

  bool _diskCovers(
    ({String key, String locationKey, List<AladhanDaySchedule> days}) disk, {
    required PrayerPrefs prefs,
    required DateTime after,
  }) {
    final loc = _locationKey(prefs);
    final locationOk =
        disk.locationKey == loc || disk.key.startsWith('$loc|');
    if (!locationOk) return false;
    final localAfter = after.toLocal();
    return disk.days.any(
      (d) => d.slots.any((s) => s.scheduledAt.isAfter(localAfter)),
    );
  }

  Future<void> _writeDiskCache(
    String key,
    List<AladhanDaySchedule> days, {
    required String locationKey,
  }) async {
    final file = _scheduleCacheFile;
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'key': key,
          'locationKey': locationKey,
          'days': [for (final d in days) d.toJson()],
        }),
      );
    } catch (_) {}
  }

  Future<({String key, String locationKey, List<AladhanDaySchedule> days})?>
      _readDiskCache() async {
    final file = _scheduleCacheFile;
    if (file == null || !await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final key = map['key']?.toString();
      final rawDays = map['days'];
      if (key == null || rawDays is! List) return null;
      final days = <AladhanDaySchedule>[];
      for (final raw in rawDays) {
        if (raw is Map<String, dynamic>) {
          days.add(AladhanDaySchedule.fromJson(raw));
        } else if (raw is Map) {
          days.add(AladhanDaySchedule.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
      if (days.isEmpty) return null;
      final locationKey =
          map['locationKey']?.toString() ?? key.split('|').take(6).join('|');
      return (key: key, locationKey: locationKey, days: days);
    } catch (_) {
      return null;
    }
  }
}
