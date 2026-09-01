import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prayer_cast/home_delivery/coordinator/adzan_cast_tester.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/prayer_times/location_resolver.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';

export 'package:prayer_cast/l10n/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String prayerDisplayName(AppLocalizations l10n, String name) {
  return switch (name) {
    'fajr' => l10n.prayerFajr,
    'dhuhr' => l10n.prayerDhuhr,
    'asr' => l10n.prayerAsr,
    'maghrib' => l10n.prayerMaghrib,
    'isha' => l10n.prayerIsha,
    _ => name,
  };
}

String voiceDisplayName(AppLocalizations l10n, String voiceId) {
  return switch (voiceId) {
    'fajr_adhan' => l10n.voiceFajr,
    'standard_adhan' => l10n.voiceStandard,
    'makkah' => l10n.voiceTestTone,
    _ => voiceId,
  };
}

String deliveryDisplayName(AppLocalizations l10n, PrayerDeliveryMode mode) {
  return switch (mode) {
    PrayerDeliveryMode.beep => l10n.deliveryBeep,
    PrayerDeliveryMode.takbir => l10n.deliveryTakbir,
    PrayerDeliveryMode.adhanPhone => l10n.deliveryAdhanPhone,
    PrayerDeliveryMode.cast => l10n.deliveryCast,
  };
}

String locationFailureMessage(
  AppLocalizations l10n,
  LocationResolveFailure failure,
) {
  return switch (failure.code) {
    LocationResolveCode.serviceOff => l10n.locationServiceOff,
    LocationResolveCode.denied => l10n.locationDenied,
    LocationResolveCode.deniedForever => l10n.locationDeniedForever,
    LocationResolveCode.timeout => l10n.locationTimeout,
    LocationResolveCode.unavailable => l10n.locationUnavailable,
  };
}

/// Maps GPS failures to l10n. Never returns [Object.toString] (e.g. TimeoutException).
String locationErrorMessage(AppLocalizations l10n, Object error) {
  if (error is LocationResolveFailure) {
    return locationFailureMessage(l10n, error);
  }
  if (error is TimeoutException) {
    return l10n.locationTimeout;
  }
  return l10n.locationUnavailable;
}

String castFailureMessage(AppLocalizations l10n, AdzanCastTestFailure failure) {
  return switch (failure.code) {
    AdzanCastFailCode.busy => l10n.castBusy,
    AdzanCastFailCode.noSpeaker => l10n.castNoSpeaker,
    AdzanCastFailCode.emptyAudio => l10n.castEmptyAudio,
    AdzanCastFailCode.mediaRejected =>
      l10n.castMediaRejected(failure.hits ?? 0),
    AdzanCastFailCode.noFetch => l10n.castNoFetch,
    AdzanCastFailCode.generic =>
      l10n.castFailed(failure.detail ?? failure.toString()),
  };
}
