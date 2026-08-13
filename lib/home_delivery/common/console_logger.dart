import 'logger.dart';

/// Simple stdout logger for the app shell (local-only — never leaves device).
final class ConsoleLogger implements HomeDeliveryLogger {
  const ConsoleLogger();

  @override
  void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('D', tag, message, error, stackTrace);
  }

  @override
  void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('I', tag, message, error, stackTrace);
  }

  @override
  void warn(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('W', tag, message, error, stackTrace);
  }

  @override
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('E', tag, message, error, stackTrace);
  }

  void _log(
    String level,
    String? tag,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final prefix = tag == null ? level : '$level/$tag';
    // ignore: avoid_print
    print('[$prefix] $message');
    if (error != null) {
      // ignore: avoid_print
      print('  error: $error');
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print(stackTrace);
    }
  }
}
