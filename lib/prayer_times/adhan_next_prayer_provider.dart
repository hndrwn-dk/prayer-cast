import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';

import 'aladhan_client.dart';
import 'prayer_prefs.dart';

/// [NextPrayerProvider] using Aladhan Prayer Times API (global cities).
///
/// Fetches today + tomorrow on demand and picks the next obligatory slot.
/// Requires network when the in-memory cache is cold.
final class AdhanNextPrayerProvider implements NextPrayerProvider {
  AdhanNextPrayerProvider({
    required PrayerPrefsStore store,
    AladhanClient? client,
  })  : _store = store,
        _client = client ?? AladhanClient();

  final PrayerPrefsStore _store;
  final AladhanClient _client;

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
      final fetchedToday = await _fetch(prefs, today, school);
      final fetchedTomorrow = await _fetch(prefs, tomorrow, school);
      _cachedToday = fetchedToday;
      _cachedTomorrow = fetchedTomorrow;
      _cacheKey = key;
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
}
