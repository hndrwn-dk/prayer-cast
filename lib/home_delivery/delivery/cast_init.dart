import 'dart:io';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart' as cast;

/// Initializes the Google Cast SDK (required before discovery / loadMedia).
///
/// Uses the Default Media Receiver app id so any Cast speaker can play
/// audio/mpeg or audio/wav without a custom Cast receiver.
Future<void> initGoogleCast() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;

  const appId = cast.GoogleCastDiscoveryCriteria.kDefaultApplicationId;
  final cast.GoogleCastOptions options;
  if (Platform.isIOS) {
    options = cast.IOSGoogleCastOptions(
      cast.GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
      stopCastingOnAppTerminated: false,
    );
  } else {
    options = cast.GoogleCastOptionsAndroid(
      appId: appId,
      stopCastingOnAppTerminated: false,
    );
  }
  await cast.GoogleCastContext.instance.setSharedInstanceWithOptions(options);
}
