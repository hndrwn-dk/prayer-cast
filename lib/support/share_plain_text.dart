import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _shareChannel = MethodChannel('prayer_cast/share');

/// Test hook that replaces the system share sheet when non-null.
@visibleForTesting
Future<void> Function(String text)? debugShareText;

/// Opens the system share sheet with [text].
Future<void> sharePlainText(String text) async {
  final override = debugShareText;
  if (override != null) {
    await override(text);
    return;
  }
  await _shareChannel.invokeMethod<void>('shareText', text);
}
