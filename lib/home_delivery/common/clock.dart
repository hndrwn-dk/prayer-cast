/// Injectable clock for hysteresis and schedule anchoring.
///
/// WHY: Presence hysteresis (§3.4) and azan-relative scheduling (§3.6) must
/// not depend on wall-clock drift across awaits. Tests advance time explicitly;
/// production uses [SystemClock].
abstract interface class Clock {
  DateTime now();
}

/// Wall-clock [Clock].
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Mutable clock for unit tests.
final class FakeClock implements Clock {
  FakeClock(DateTime initial) : _now = initial;

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration delta) {
    _now = _now.add(delta);
  }

  void set(DateTime value) {
    _now = value;
  }
}
