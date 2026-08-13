/// Injected logger for the home_delivery layer.
///
/// WHY: Field failures in presence/election/cast are nearly impossible to
/// reproduce; every subsystem must log through one interface so tests can
/// assert and so we never scatter `print()` calls. Spec observability is
/// local-only (§6) — this logger never leaves the device.
abstract interface class HomeDeliveryLogger {
  void debug(String message, {String? tag, Object? error, StackTrace? stackTrace});

  void info(String message, {String? tag, Object? error, StackTrace? stackTrace});

  void warn(String message, {String? tag, Object? error, StackTrace? stackTrace});

  void error(String message, {String? tag, Object? error, StackTrace? stackTrace});
}

/// No-op logger used by default in unit tests.
final class SilentLogger implements HomeDeliveryLogger {
  const SilentLogger();

  @override
  void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {}

  @override
  void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {}

  @override
  void warn(String message, {String? tag, Object? error, StackTrace? stackTrace}) {}

  @override
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {}
}
