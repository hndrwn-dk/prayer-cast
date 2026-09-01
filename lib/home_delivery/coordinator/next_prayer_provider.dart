/// Next prayer after a given instant.
///
/// Prayer-time calculation is out of scope for this repo (spec §1). Callers
/// inject a real calc engine when one exists; this layer only needs the next
/// name + scheduled azan epoch + voice id.
final class NextPrayer {
  const NextPrayer({
    required this.name,
    required this.scheduledAt,
    required this.voiceId,
  });

  /// Prayer name wire value (e.g. `maghrib`).
  final String name;

  /// Scheduled azan epoch (T), not the wake epoch.
  final DateTime scheduledAt;

  /// Bundled voice id → `assets/audio/{voiceId}.mp3`.
  final String voiceId;
}

/// Port for the upcoming prayer (injected — never computed here).
abstract interface class NextPrayerProvider {
  Future<NextPrayer> next({
    required DateTime after,
    bool preferCache = false,
  });
}

/// PLACEHOLDER for wiring / local dev only.
///
/// Do NOT ship as the production prayer-time engine. Spec §1 puts calculation
/// outside this repo. Replace with the real calc provider when it lands.
///
/// Returns a fixed sequence relative to [anchor], cycling forever. Default
/// schedule is five daily slots at +2m / +4m / +6m / +8m / +10m from the
/// first [next] call's [after] (or [anchor] if set).
final class StaticNextPrayerProvider implements NextPrayerProvider {
  StaticNextPrayerProvider({
    List<NextPrayer>? sequence,
    this.voiceId = 'standard_adhan',
    DateTime? anchor,
  })  : _sequence = sequence,
        _anchor = anchor;

  final List<NextPrayer>? _sequence;
  final String voiceId;
  final DateTime? _anchor;

  @override
  Future<NextPrayer> next({
    required DateTime after,
    bool preferCache = false,
  }) async {
    final sequence = _sequence ?? _defaultSequence(after);
    for (final prayer in sequence) {
      if (prayer.scheduledAt.isAfter(after)) return prayer;
    }
    // Wrap: schedule the first slot one day after the last.
    final last = sequence.last;
    return NextPrayer(
      name: sequence.first.name,
      scheduledAt: last.scheduledAt.add(const Duration(days: 1)),
      voiceId: sequence.first.voiceId,
    );
  }

  List<NextPrayer> _defaultSequence(DateTime after) {
    final base = _anchor ?? after;
    const names = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    return [
      for (var i = 0; i < names.length; i++)
        NextPrayer(
          name: names[i],
          scheduledAt: base.add(Duration(minutes: 2 * (i + 1))),
          // Subuh uses fajr recording; other prayers use [voiceId] (standard).
          voiceId: names[i] == 'fajr' ? 'fajr_adhan' : voiceId,
        ),
    ];
  }
}
