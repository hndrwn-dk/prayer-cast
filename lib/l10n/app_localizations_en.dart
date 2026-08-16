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
  String get adhanCountdownNow => 'now';

  @override
  String adhanCountdownIn(String clock) {
    return 'in $clock';
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
  String get privacyPolicy => 'Privacy policy';

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
  String get methodKemenag => 'Kemenag (Indonesia)';

  @override
  String get madhabKemenagHint =>
      'Kemenag publishes Asr; the madhhab setting does not change it.';

  @override
  String kemenagFallback(String reason) {
    return 'Kemenag unavailable ($reason). Using Aladhan MUIS.';
  }

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
  String get speakerGroupDelayHint =>
      'Cast groups (Xiaomi, mixed brands, and some others) often start adhan late or stay silent. For on-time playback, pick a single speaker in the room that must hear it.';

  @override
  String get speakerGroupMayDelay => 'May start late';

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

  @override
  String get locationDisclosureTitle => 'Location is optional';

  @override
  String get locationDisclosureBody =>
      'GPS is optional. It is used only to fill city and country so Prayer Cast can fetch prayer times.\n\nIt is not used to decide whether you are home. Home uses the Wi-Fi / LAN fingerprint on this phone.\n\nLocation stays on this device except when sent to Aladhan and the system geocoder, as described in the privacy policy.\n\nYou can type city and country instead.';

  @override
  String get locationDisclosureContinue => 'Continue';

  @override
  String get locationDisclosureTypeCity => 'Type city instead';

  @override
  String get spiritualBenefitsSection => 'Spiritual benefits';

  @override
  String get sunnahPracticesSection => 'Sunnah practices';

  @override
  String get sayingSection => 'Saying';

  @override
  String get noteSection => 'Note';

  @override
  String spiritualBenefitsTeaser(String name, String line) {
    return '$name · $line';
  }

  @override
  String spiritualBenefitsDryRunTitle(String name) {
    return '$name (dry-run)';
  }

  @override
  String get fajrTeaser => 'Spiritual awakening and consciousness';

  @override
  String get fajrBenefit1 => 'Blessed time for remembrance and reflection';

  @override
  String get fajrBenefit2 => 'Protection throughout the day';

  @override
  String get fajrBenefit3 => 'Spiritual awakening and consciousness';

  @override
  String get fajrBenefit4 => 'Better focus and productivity';

  @override
  String get fajrSunnah1 => 'Pray 2 Sunnah rakats before Fajr';

  @override
  String get fajrSunnah2 => 'Recite morning adhkar after prayer';

  @override
  String get fajrSunnah3 => 'Read Quran until sunrise';

  @override
  String get fajrSunnah4 => 'Make dua during the blessed time';

  @override
  String get fajrSaying =>
      'Whoever prays Fajr in congregation, it is as if he prayed the whole night.';

  @override
  String get dhuhrTeaser => 'Midday spiritual recharge';

  @override
  String get dhuhrBenefit1 => 'Break from worldly activities';

  @override
  String get dhuhrBenefit2 => 'Midday spiritual recharge';

  @override
  String get dhuhrBenefit3 => 'Connection with the community';

  @override
  String get dhuhrBenefit4 => 'Time for gratitude and reflection';

  @override
  String get dhuhrSunnah1 => 'Pray 4 Sunnah rakats before Dhuhr';

  @override
  String get dhuhrSunnah2 => 'Pray 2 Sunnah rakats after Dhuhr';

  @override
  String get dhuhrSunnah3 => 'Make dua between Dhuhr and Asr';

  @override
  String get dhuhrSunnah4 => 'Seek forgiveness (Istighfar)';

  @override
  String get dhuhrNote =>
      'The middle prayer that brings balance to our day and reminds us of our purpose.';

  @override
  String get asrTeaser => 'Protection from afternoon negligence';

  @override
  String get asrBenefit1 => 'Protection from afternoon negligence';

  @override
  String get asrBenefit2 => 'Preparation for evening';

  @override
  String get asrBenefit3 => 'Strengthening of faith';

  @override
  String get asrBenefit4 => 'Community bonding';

  @override
  String get asrSunnah1 => 'Pray 4 Sunnah rakats before Asr (voluntary/nafl)';

  @override
  String get asrSunnah2 => 'Make dhikr and remembrance';

  @override
  String get asrSunnah3 => 'Prepare for Maghrib';

  @override
  String get asrSunnah4 => 'Seek Allah\'s forgiveness';

  @override
  String get asrNote =>
      'Allah swears by this time in Surah Al-Asr, emphasizing its importance for believers.';

  @override
  String get maghribTeaser => 'Gratitude for the day\'s blessings';

  @override
  String get maghribBenefit1 => 'Gratitude for the day\'s blessings';

  @override
  String get maghribBenefit2 => 'Family gathering time';

  @override
  String get maghribBenefit3 => 'Breaking of the fast (if fasting)';

  @override
  String get maghribBenefit4 => 'Peaceful transition to evening';

  @override
  String get maghribSunnah1 => 'Pray 2 Sunnah rakats after Maghrib';

  @override
  String get maghribSunnah2 => 'Break fast with dates and water';

  @override
  String get maghribSunnah3 => 'Recite evening adhkar';

  @override
  String get maghribSunnah4 => 'Spend time with family';

  @override
  String get maghribNote =>
      'The time of Allah\'s mercy and acceptance of duas, especially at sunset.';

  @override
  String get ishaTeaser => 'Peaceful end to the day';

  @override
  String get ishaBenefit1 => 'Completion of daily prayers';

  @override
  String get ishaBenefit2 => 'Peaceful end to the day';

  @override
  String get ishaBenefit3 => 'Preparation for rest';

  @override
  String get ishaBenefit4 => 'Night of worship opportunity';

  @override
  String get ishaSunnah1 => 'Pray 2 Sunnah rakats after Isha';

  @override
  String get ishaSunnah2 => 'Pray Witr (odd-numbered prayer)';

  @override
  String get ishaSunnah3 => 'Recite Quran before sleep';

  @override
  String get ishaSunnah4 => 'Make istighfar before bed';

  @override
  String get ishaNote =>
      'The final prayer that brings peace to the heart and prepares the soul for rest.';
}
