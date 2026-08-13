// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Prayer Cast';

  @override
  String get homeEyebrow => 'Home';

  @override
  String get homeHeadline => 'Adhan at home,\nonce.';

  @override
  String get homeSubhead =>
      'Played on your home speaker only when you are actually home — no account, no GPS.';

  @override
  String get nextAdhanEyebrow => 'Next adhan';

  @override
  String nextAdhanHero(String name, String time) {
    return '$name · $time';
  }

  @override
  String get homeDetected => 'home detected';

  @override
  String get notHome => 'not home';

  @override
  String get checkingHome => 'checking home';

  @override
  String get speakerNotSelected => 'Speaker not selected yet';

  @override
  String get speakerCardEmpty => 'No speaker selected';

  @override
  String speakerNamed(String name) {
    return 'Speaker: $name';
  }

  @override
  String get speakerLoading => 'Speaker…';

  @override
  String get prayerNotConfigured => 'Prayer times not set yet';

  @override
  String get prayerLoading => 'Prayer times…';

  @override
  String nextPrayer(String name, String time) {
    return 'Next: $name $time';
  }

  @override
  String get speakerHome => 'Home speaker';

  @override
  String get speakerHomeScanHint => 'Scan and pick a Cast speaker';

  @override
  String get speakerHomeChangeHint => 'Change home speaker';

  @override
  String get changeHomeSpeaker => 'Speaker';

  @override
  String get prayerTimes => 'Prayer times';

  @override
  String get prayerTimesHint => 'City, method, and today’s schedule';

  @override
  String get deviceEyebrow => 'Device';

  @override
  String get scheduleEyebrow => 'Schedule';

  @override
  String get dataOnDeviceOnly => 'Data stays only on your phone.';

  @override
  String get exactAlarmTitle => 'Exact alarm permission needed';

  @override
  String get exactAlarmBody =>
      'Without this permission, adhan cannot be scheduled while the phone sleeps.';

  @override
  String get exactAlarmOpenSettings => 'Open alarm settings';

  @override
  String get language => 'Language';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get back => 'Back';

  @override
  String get save => 'Save';

  @override
  String get saving => 'Saving…';

  @override
  String get city => 'City';

  @override
  String get country => 'Country';

  @override
  String get prayerFajr => 'Fajr';

  @override
  String get prayerDhuhr => 'Dhuhr';

  @override
  String get prayerAsr => 'Asr';

  @override
  String get prayerMaghrib => 'Maghrib';

  @override
  String get prayerIsha => 'Isha';

  @override
  String get madhabShafi => 'Asr madhhab · Shafi’i';

  @override
  String get madhabHanafi => 'Asr madhhab · Hanafi';

  @override
  String get madhabAsrOnlyHint => 'Only Asr changes. Hanafi Asr is later.';

  @override
  String get voiceFajr => 'Fajr adhan';

  @override
  String get voiceStandard => 'Standard adhan';

  @override
  String get voiceTestTone => 'Test tone';

  @override
  String get pillGps => 'GPS';

  @override
  String get pillManual => 'manual';

  @override
  String get pillAuto => 'auto';

  @override
  String get pillFajrOnly => 'fajr only';

  @override
  String get useCurrentLocation => 'Use current location';

  @override
  String get detectingLocation => 'Detecting location…';

  @override
  String get noLocationYet => 'No location yet';

  @override
  String get changeCityCountry => 'Change city / country';

  @override
  String get hideCityForm => 'Hide city form';

  @override
  String get calculationMethod => 'Calculation method';

  @override
  String get fetchSchedule => 'Fetch schedule';

  @override
  String get fetchingSchedule => 'Fetching schedule…';

  @override
  String get todaysSchedule => 'Today’s schedule';

  @override
  String get scheduleVoiceHint =>
      'Choose how each prayer is delivered, then test';

  @override
  String get scheduleEmptyHint => 'Tap Fetch schedule or Use current location.';

  @override
  String morePrayers(int count) {
    return '+ $count more times';
  }

  @override
  String get hide => 'Hide';

  @override
  String locationResolved(String place) {
    return 'Location: $place';
  }

  @override
  String loadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get prayerSaved => 'Prayer times saved';

  @override
  String saveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get needLocationOrCity =>
      'Use current location, or enter city and country first';

  @override
  String castSent(String prayer, String voice) {
    return '$prayer adhan sent to home speaker ($voice).';
  }

  @override
  String get deliveryBeep => 'Beep on phone';

  @override
  String get deliveryAdhanPhone => 'Adhan on phone';

  @override
  String get deliveryCast => 'Cast';

  @override
  String get beepPlayed => 'Beep played on this phone.';

  @override
  String adhanPhonePlayed(String prayer, String voice) {
    return '$prayer adhan played on this phone ($voice).';
  }

  @override
  String phonePlayFailed(String error) {
    return 'Could not play on this phone: $error';
  }

  @override
  String get locationServiceOff =>
      'Location services are off. Turn on GPS and try again.';

  @override
  String get locationDenied =>
      'Location permission denied. Allow location access for automatic detection.';

  @override
  String get locationDeniedForever =>
      'Location permission blocked. Open app settings and enable location.';

  @override
  String get castBusy => 'A test cast is already in progress…';

  @override
  String get castNoSpeaker => 'Pick a home speaker first in Home speaker.';

  @override
  String get castEmptyAudio => 'Adhan audio is empty.';

  @override
  String castMediaRejected(int hits) {
    return 'Speaker rejected the media (hits=$hits). Keep phone and speaker on the same Wi‑Fi, not guest/VPN.';
  }

  @override
  String get castNoFetch =>
      'Speaker did not fetch audio from the phone (0 requests). Check same Wi‑Fi, turn off VPN, and reselect the home speaker.';

  @override
  String castFailed(String error) {
    return 'Failed to cast to speaker: $error';
  }

  @override
  String get speakerSetupTitle => 'Home speaker';

  @override
  String get speakerSetupIntro =>
      'Group speakers in Google Home first, then pick the group here.';

  @override
  String speakersFound(int count) {
    return '$count speakers found';
  }

  @override
  String get reachableNow => 'reachable now';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get scanning => 'Scanning…';

  @override
  String get searchingForSpeakers => 'Searching for speakers…';

  @override
  String get noSpeakersFoundTitle => 'No speakers found';

  @override
  String get noSpeakersFoundGuidance =>
      'Make sure your phone and speaker are on the same Wi‑Fi network';

  @override
  String get speakerScanRetry => 'Try again';

  @override
  String get openLocalNetworkSettings => 'Open settings';

  @override
  String speakerSaved(String name) {
    return '$name saved as home speaker';
  }

  @override
  String speakerSaveFailed(String error) {
    return 'Failed to save speaker: $error';
  }

  @override
  String get speakerNoneFound =>
      'No Cast speakers on this Wi‑Fi. Make sure your Xiaomi / Google Home speaker is on, on the same Wi‑Fi, and visible in the Google Home app.';

  @override
  String get speakerOnlyTvsFound =>
      'Only TVs were found — they are hidden here. Group speakers in Google Home, or turn on a speaker on this Wi‑Fi.';

  @override
  String speakerScanFailed(String error) {
    return 'Failed to scan speakers. Make sure Wi‑Fi is on and local network permission is allowed.\n$error';
  }

  @override
  String speakerIpDebug(String address) {
    return 'IP: $address';
  }

  @override
  String get supportOnKofi => 'Support on Ko-fi';

  @override
  String get dryRunTitle => 'Test scheduled adhan';

  @override
  String get dryRunHint =>
      'Runs the real alarm path (wake, presence, then Cast, beep, or phone) — not the speaker test button. Replaces the next alarm until it fires.';

  @override
  String get dryRunIn10Minutes => 'In 10 minutes';

  @override
  String get dryRunIn1Hour => 'In 1 hour';

  @override
  String dryRunScheduled(String time) {
    return 'Test adhan at $time';
  }

  @override
  String dryRunFailed(String error) {
    return 'Could not schedule test adhan: $error';
  }
}
