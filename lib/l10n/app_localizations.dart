import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer Cast'**
  String get appTitle;

  /// No description provided for @homeEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeEyebrow;

  /// No description provided for @homeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Adhan at home,\nonce.'**
  String get homeHeadline;

  /// No description provided for @homeSubhead.
  ///
  /// In en, this message translates to:
  /// **'Played on your home speaker only when you are actually home — no account, no GPS.'**
  String get homeSubhead;

  /// No description provided for @nextAdhanEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Next adhan'**
  String get nextAdhanEyebrow;

  /// No description provided for @nextAdhanHero.
  ///
  /// In en, this message translates to:
  /// **'{name} · {time}'**
  String nextAdhanHero(String name, String time);

  /// No description provided for @adhanCountdownNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get adhanCountdownNow;

  /// No description provided for @adhanCountdownIn.
  ///
  /// In en, this message translates to:
  /// **'in {clock}'**
  String adhanCountdownIn(String clock);

  /// No description provided for @homeDetected.
  ///
  /// In en, this message translates to:
  /// **'home detected'**
  String get homeDetected;

  /// No description provided for @notHome.
  ///
  /// In en, this message translates to:
  /// **'not home'**
  String get notHome;

  /// No description provided for @checkingHome.
  ///
  /// In en, this message translates to:
  /// **'checking home'**
  String get checkingHome;

  /// No description provided for @speakerNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Speaker not selected yet'**
  String get speakerNotSelected;

  /// No description provided for @speakerCardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No speaker selected'**
  String get speakerCardEmpty;

  /// No description provided for @speakerNamed.
  ///
  /// In en, this message translates to:
  /// **'Speaker: {name}'**
  String speakerNamed(String name);

  /// No description provided for @speakerLoading.
  ///
  /// In en, this message translates to:
  /// **'Speaker…'**
  String get speakerLoading;

  /// No description provided for @prayerNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Prayer times not set yet'**
  String get prayerNotConfigured;

  /// No description provided for @prayerLoading.
  ///
  /// In en, this message translates to:
  /// **'Prayer times…'**
  String get prayerLoading;

  /// No description provided for @nextPrayer.
  ///
  /// In en, this message translates to:
  /// **'Next: {name} {time}'**
  String nextPrayer(String name, String time);

  /// No description provided for @speakerHome.
  ///
  /// In en, this message translates to:
  /// **'Home speaker'**
  String get speakerHome;

  /// No description provided for @speakerHomeScanHint.
  ///
  /// In en, this message translates to:
  /// **'Scan and pick a Cast speaker'**
  String get speakerHomeScanHint;

  /// No description provided for @speakerHomeChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Change home speaker'**
  String get speakerHomeChangeHint;

  /// No description provided for @changeHomeSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get changeHomeSpeaker;

  /// No description provided for @prayerTimes.
  ///
  /// In en, this message translates to:
  /// **'Prayer times'**
  String get prayerTimes;

  /// No description provided for @prayerTimesHint.
  ///
  /// In en, this message translates to:
  /// **'City, method, and today’s schedule'**
  String get prayerTimesHint;

  /// No description provided for @deviceEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceEyebrow;

  /// No description provided for @scheduleEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleEyebrow;

  /// No description provided for @dataOnDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Data stays only on your phone.'**
  String get dataOnDeviceOnly;

  /// Tooltip / accessibility label for the home privacy policy link
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @exactAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Exact alarm permission needed'**
  String get exactAlarmTitle;

  /// No description provided for @exactAlarmBody.
  ///
  /// In en, this message translates to:
  /// **'Without this permission, adhan cannot be scheduled while the phone sleeps.'**
  String get exactAlarmBody;

  /// No description provided for @exactAlarmOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open alarm settings'**
  String get exactAlarmOpenSettings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Indonesia'**
  String get languageIndonesian;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerFajr;

  /// No description provided for @prayerDhuhr.
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayerDhuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayerIsha;

  /// No description provided for @madhabShafi.
  ///
  /// In en, this message translates to:
  /// **'Asr madhhab · Shafi’i'**
  String get madhabShafi;

  /// No description provided for @madhabHanafi.
  ///
  /// In en, this message translates to:
  /// **'Asr madhhab · Hanafi'**
  String get madhabHanafi;

  /// No description provided for @madhabAsrOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Only Asr changes. Hanafi Asr is later.'**
  String get madhabAsrOnlyHint;

  /// No description provided for @voiceFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr adhan'**
  String get voiceFajr;

  /// No description provided for @voiceStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard adhan'**
  String get voiceStandard;

  /// No description provided for @voiceTestTone.
  ///
  /// In en, this message translates to:
  /// **'Test tone'**
  String get voiceTestTone;

  /// No description provided for @pillGps.
  ///
  /// In en, this message translates to:
  /// **'GPS'**
  String get pillGps;

  /// No description provided for @pillManual.
  ///
  /// In en, this message translates to:
  /// **'manual'**
  String get pillManual;

  /// No description provided for @pillAuto.
  ///
  /// In en, this message translates to:
  /// **'auto'**
  String get pillAuto;

  /// No description provided for @pillFajrOnly.
  ///
  /// In en, this message translates to:
  /// **'fajr only'**
  String get pillFajrOnly;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get useCurrentLocation;

  /// No description provided for @detectingLocation.
  ///
  /// In en, this message translates to:
  /// **'Detecting location…'**
  String get detectingLocation;

  /// No description provided for @noLocationYet.
  ///
  /// In en, this message translates to:
  /// **'No location yet'**
  String get noLocationYet;

  /// No description provided for @changeCityCountry.
  ///
  /// In en, this message translates to:
  /// **'Change city / country'**
  String get changeCityCountry;

  /// No description provided for @hideCityForm.
  ///
  /// In en, this message translates to:
  /// **'Hide city form'**
  String get hideCityForm;

  /// No description provided for @calculationMethod.
  ///
  /// In en, this message translates to:
  /// **'Calculation method'**
  String get calculationMethod;

  /// No description provided for @methodKemenag.
  ///
  /// In en, this message translates to:
  /// **'Kemenag (Indonesia)'**
  String get methodKemenag;

  /// No description provided for @madhabKemenagHint.
  ///
  /// In en, this message translates to:
  /// **'Kemenag publishes Asr; the madhhab setting does not change it.'**
  String get madhabKemenagHint;

  /// No description provided for @kemenagFallback.
  ///
  /// In en, this message translates to:
  /// **'Kemenag unavailable ({reason}). Using Aladhan MUIS.'**
  String kemenagFallback(String reason);

  /// No description provided for @fetchSchedule.
  ///
  /// In en, this message translates to:
  /// **'Fetch schedule'**
  String get fetchSchedule;

  /// No description provided for @fetchingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Fetching schedule…'**
  String get fetchingSchedule;

  /// No description provided for @todaysSchedule.
  ///
  /// In en, this message translates to:
  /// **'Today’s schedule'**
  String get todaysSchedule;

  /// No description provided for @scheduleVoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Choose how each prayer is delivered, then test'**
  String get scheduleVoiceHint;

  /// No description provided for @scheduleEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Fetch schedule or Use current location.'**
  String get scheduleEmptyHint;

  /// No description provided for @morePrayers.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more times'**
  String morePrayers(int count);

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @locationResolved.
  ///
  /// In en, this message translates to:
  /// **'Location: {place}'**
  String locationResolved(String place);

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String loadFailed(String error);

  /// No description provided for @prayerSaved.
  ///
  /// In en, this message translates to:
  /// **'Prayer times saved'**
  String get prayerSaved;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String saveFailed(String error);

  /// No description provided for @needLocationOrCity.
  ///
  /// In en, this message translates to:
  /// **'Use current location, or enter city and country first'**
  String get needLocationOrCity;

  /// No description provided for @castSent.
  ///
  /// In en, this message translates to:
  /// **'{prayer} adhan sent to home speaker ({voice}).'**
  String castSent(String prayer, String voice);

  /// No description provided for @deliveryBeep.
  ///
  /// In en, this message translates to:
  /// **'Beep on phone'**
  String get deliveryBeep;

  /// No description provided for @deliveryAdhanPhone.
  ///
  /// In en, this message translates to:
  /// **'Adhan on phone'**
  String get deliveryAdhanPhone;

  /// No description provided for @deliveryCast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get deliveryCast;

  /// No description provided for @beepPlayed.
  ///
  /// In en, this message translates to:
  /// **'Beep played on this phone.'**
  String get beepPlayed;

  /// No description provided for @adhanPhonePlayed.
  ///
  /// In en, this message translates to:
  /// **'{prayer} adhan played on this phone ({voice}).'**
  String adhanPhonePlayed(String prayer, String voice);

  /// No description provided for @phonePlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play on this phone: {error}'**
  String phonePlayFailed(String error);

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are off. Turn on GPS and try again.'**
  String get locationServiceOff;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Allow location access for automatic detection.'**
  String get locationDenied;

  /// No description provided for @locationDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission blocked. Open app settings and enable location.'**
  String get locationDeniedForever;

  /// No description provided for @castBusy.
  ///
  /// In en, this message translates to:
  /// **'A test cast is already in progress…'**
  String get castBusy;

  /// No description provided for @castNoSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Pick a home speaker first in Home speaker.'**
  String get castNoSpeaker;

  /// No description provided for @castEmptyAudio.
  ///
  /// In en, this message translates to:
  /// **'Adhan audio is empty.'**
  String get castEmptyAudio;

  /// No description provided for @castMediaRejected.
  ///
  /// In en, this message translates to:
  /// **'Speaker rejected the media (hits={hits}). Keep phone and speaker on the same Wi‑Fi, not guest/VPN.'**
  String castMediaRejected(int hits);

  /// No description provided for @castNoFetch.
  ///
  /// In en, this message translates to:
  /// **'Speaker did not fetch audio from the phone (0 requests). Check same Wi‑Fi, turn off VPN, and reselect the home speaker.'**
  String get castNoFetch;

  /// No description provided for @castFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to cast to speaker: {error}'**
  String castFailed(String error);

  /// No description provided for @speakerSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Home speaker'**
  String get speakerSetupTitle;

  /// No description provided for @speakerSetupIntro.
  ///
  /// In en, this message translates to:
  /// **'Group speakers in Google Home first, then pick the group here.'**
  String get speakerSetupIntro;

  /// No description provided for @speakerGroupDelayHint.
  ///
  /// In en, this message translates to:
  /// **'Cast groups (Xiaomi, mixed brands, and some others) often start adhan late or stay silent. For on-time playback, pick a single speaker in the room that must hear it.'**
  String get speakerGroupDelayHint;

  /// No description provided for @speakerGroupMayDelay.
  ///
  /// In en, this message translates to:
  /// **'May start late'**
  String get speakerGroupMayDelay;

  /// No description provided for @speakersFound.
  ///
  /// In en, this message translates to:
  /// **'{count} speakers found'**
  String speakersFound(int count);

  /// No description provided for @reachableNow.
  ///
  /// In en, this message translates to:
  /// **'reachable now'**
  String get reachableNow;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// No description provided for @searchingForSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Searching for speakers…'**
  String get searchingForSpeakers;

  /// No description provided for @noSpeakersFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'No speakers found'**
  String get noSpeakersFoundTitle;

  /// No description provided for @noSpeakersFoundGuidance.
  ///
  /// In en, this message translates to:
  /// **'Make sure your phone and speaker are on the same Wi‑Fi network'**
  String get noSpeakersFoundGuidance;

  /// No description provided for @speakerScanRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get speakerScanRetry;

  /// No description provided for @openLocalNetworkSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openLocalNetworkSettings;

  /// No description provided for @speakerSaved.
  ///
  /// In en, this message translates to:
  /// **'{name} saved as home speaker'**
  String speakerSaved(String name);

  /// No description provided for @removeHomeSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Remove default speaker'**
  String get removeHomeSpeaker;

  /// No description provided for @removeHomeSpeakerConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove default speaker?'**
  String get removeHomeSpeakerConfirmTitle;

  /// No description provided for @removeHomeSpeakerConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Prayer Cast will stop using this speaker. Your Google Home devices are not deleted.'**
  String get removeHomeSpeakerConfirmBody;

  /// No description provided for @removeHomeSpeakerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeHomeSpeakerConfirm;

  /// No description provided for @removeHomeSpeakerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get removeHomeSpeakerCancel;

  /// No description provided for @homeSpeakerRemoved.
  ///
  /// In en, this message translates to:
  /// **'Home speaker removed'**
  String get homeSpeakerRemoved;

  /// No description provided for @selectSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Select speakers'**
  String get selectSpeakers;

  /// No description provided for @speakersSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String speakersSelected(int count);

  /// No description provided for @deleteSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteSpeaker;

  /// No description provided for @speakerHiddenUntilRescan.
  ///
  /// In en, this message translates to:
  /// **'Removed from this list. Scan again to find it.'**
  String get speakerHiddenUntilRescan;

  /// No description provided for @speakerSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save speaker: {error}'**
  String speakerSaveFailed(String error);

  /// No description provided for @speakerNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No Cast speakers on this Wi‑Fi. Make sure your Xiaomi / Google Home speaker is on, on the same Wi‑Fi, and visible in the Google Home app.'**
  String get speakerNoneFound;

  /// No description provided for @speakerOnlyTvsFound.
  ///
  /// In en, this message translates to:
  /// **'Only TVs were found — they are hidden here. Group speakers in Google Home, or turn on a speaker on this Wi‑Fi.'**
  String get speakerOnlyTvsFound;

  /// No description provided for @speakerScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to scan speakers. Make sure Wi‑Fi is on and local network permission is allowed.\n{error}'**
  String speakerScanFailed(String error);

  /// No description provided for @speakerIpDebug.
  ///
  /// In en, this message translates to:
  /// **'IP: {address}'**
  String speakerIpDebug(String address);

  /// Tooltip / accessibility label for the home Ko-fi support icon
  ///
  /// In en, this message translates to:
  /// **'Support on Ko-fi'**
  String get supportOnKofi;

  /// No description provided for @dryRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Test scheduled adhan'**
  String get dryRunTitle;

  /// No description provided for @dryRunHint.
  ///
  /// In en, this message translates to:
  /// **'Runs the real alarm path (wake, presence, then Cast, beep, or phone) — not the speaker test button. Replaces the next alarm until it fires.'**
  String get dryRunHint;

  /// No description provided for @dryRunIn1Minute.
  ///
  /// In en, this message translates to:
  /// **'In 1 minute'**
  String get dryRunIn1Minute;

  /// No description provided for @dryRunIn5Minutes.
  ///
  /// In en, this message translates to:
  /// **'In 5 minutes'**
  String get dryRunIn5Minutes;

  /// No description provided for @dryRunScheduled.
  ///
  /// In en, this message translates to:
  /// **'Test adhan at {time}'**
  String dryRunScheduled(String time);

  /// No description provided for @dryRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not schedule test adhan: {error}'**
  String dryRunFailed(String error);

  /// No description provided for @locationDisclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'Location is optional'**
  String get locationDisclosureTitle;

  /// No description provided for @locationDisclosureBody.
  ///
  /// In en, this message translates to:
  /// **'GPS is optional. It is used only to fill city and country so Prayer Cast can fetch prayer times.\n\nIt is not used to decide whether you are home. Home uses the Wi-Fi / LAN fingerprint on this phone.\n\nLocation stays on this device except when sent to Aladhan and the system geocoder, as described in the privacy policy.\n\nYou can type city and country instead.'**
  String get locationDisclosureBody;

  /// No description provided for @locationDisclosureContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get locationDisclosureContinue;

  /// No description provided for @locationDisclosureTypeCity.
  ///
  /// In en, this message translates to:
  /// **'Type city instead'**
  String get locationDisclosureTypeCity;

  /// No description provided for @spiritualBenefitsSection.
  ///
  /// In en, this message translates to:
  /// **'Spiritual benefits'**
  String get spiritualBenefitsSection;

  /// No description provided for @sunnahPracticesSection.
  ///
  /// In en, this message translates to:
  /// **'Sunnah practices'**
  String get sunnahPracticesSection;

  /// No description provided for @sayingSection.
  ///
  /// In en, this message translates to:
  /// **'Saying'**
  String get sayingSection;

  /// No description provided for @noteSection.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteSection;

  /// No description provided for @spiritualBenefitsTeaser.
  ///
  /// In en, this message translates to:
  /// **'{name} · {line}'**
  String spiritualBenefitsTeaser(String name, String line);

  /// No description provided for @spiritualBenefitsDryRunTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} (dry-run)'**
  String spiritualBenefitsDryRunTitle(String name);

  /// No description provided for @fajrTeaser.
  ///
  /// In en, this message translates to:
  /// **'Spiritual awakening and consciousness'**
  String get fajrTeaser;

  /// No description provided for @fajrBenefit1.
  ///
  /// In en, this message translates to:
  /// **'Blessed time for remembrance and reflection'**
  String get fajrBenefit1;

  /// No description provided for @fajrBenefit2.
  ///
  /// In en, this message translates to:
  /// **'Protection throughout the day'**
  String get fajrBenefit2;

  /// No description provided for @fajrBenefit3.
  ///
  /// In en, this message translates to:
  /// **'Spiritual awakening and consciousness'**
  String get fajrBenefit3;

  /// No description provided for @fajrBenefit4.
  ///
  /// In en, this message translates to:
  /// **'Better focus and productivity'**
  String get fajrBenefit4;

  /// No description provided for @fajrSunnah1.
  ///
  /// In en, this message translates to:
  /// **'Pray 2 Sunnah rakats before Fajr'**
  String get fajrSunnah1;

  /// No description provided for @fajrSunnah2.
  ///
  /// In en, this message translates to:
  /// **'Recite morning adhkar after prayer'**
  String get fajrSunnah2;

  /// No description provided for @fajrSunnah3.
  ///
  /// In en, this message translates to:
  /// **'Read Quran until sunrise'**
  String get fajrSunnah3;

  /// No description provided for @fajrSunnah4.
  ///
  /// In en, this message translates to:
  /// **'Make dua during the blessed time'**
  String get fajrSunnah4;

  /// No description provided for @fajrSaying.
  ///
  /// In en, this message translates to:
  /// **'Whoever prays Fajr in congregation, it is as if he prayed the whole night.'**
  String get fajrSaying;

  /// No description provided for @dhuhrTeaser.
  ///
  /// In en, this message translates to:
  /// **'Midday spiritual recharge'**
  String get dhuhrTeaser;

  /// No description provided for @dhuhrBenefit1.
  ///
  /// In en, this message translates to:
  /// **'Break from worldly activities'**
  String get dhuhrBenefit1;

  /// No description provided for @dhuhrBenefit2.
  ///
  /// In en, this message translates to:
  /// **'Midday spiritual recharge'**
  String get dhuhrBenefit2;

  /// No description provided for @dhuhrBenefit3.
  ///
  /// In en, this message translates to:
  /// **'Connection with the community'**
  String get dhuhrBenefit3;

  /// No description provided for @dhuhrBenefit4.
  ///
  /// In en, this message translates to:
  /// **'Time for gratitude and reflection'**
  String get dhuhrBenefit4;

  /// No description provided for @dhuhrSunnah1.
  ///
  /// In en, this message translates to:
  /// **'Pray 4 Sunnah rakats before Dhuhr'**
  String get dhuhrSunnah1;

  /// No description provided for @dhuhrSunnah2.
  ///
  /// In en, this message translates to:
  /// **'Pray 2 Sunnah rakats after Dhuhr'**
  String get dhuhrSunnah2;

  /// No description provided for @dhuhrSunnah3.
  ///
  /// In en, this message translates to:
  /// **'Make dua between Dhuhr and Asr'**
  String get dhuhrSunnah3;

  /// No description provided for @dhuhrSunnah4.
  ///
  /// In en, this message translates to:
  /// **'Seek forgiveness (Istighfar)'**
  String get dhuhrSunnah4;

  /// No description provided for @dhuhrNote.
  ///
  /// In en, this message translates to:
  /// **'The middle prayer that brings balance to our day and reminds us of our purpose.'**
  String get dhuhrNote;

  /// No description provided for @asrTeaser.
  ///
  /// In en, this message translates to:
  /// **'Protection from afternoon negligence'**
  String get asrTeaser;

  /// No description provided for @asrBenefit1.
  ///
  /// In en, this message translates to:
  /// **'Protection from afternoon negligence'**
  String get asrBenefit1;

  /// No description provided for @asrBenefit2.
  ///
  /// In en, this message translates to:
  /// **'Preparation for evening'**
  String get asrBenefit2;

  /// No description provided for @asrBenefit3.
  ///
  /// In en, this message translates to:
  /// **'Strengthening of faith'**
  String get asrBenefit3;

  /// No description provided for @asrBenefit4.
  ///
  /// In en, this message translates to:
  /// **'Community bonding'**
  String get asrBenefit4;

  /// No description provided for @asrSunnah1.
  ///
  /// In en, this message translates to:
  /// **'Pray 4 Sunnah rakats before Asr (voluntary/nafl)'**
  String get asrSunnah1;

  /// No description provided for @asrSunnah2.
  ///
  /// In en, this message translates to:
  /// **'Make dhikr and remembrance'**
  String get asrSunnah2;

  /// No description provided for @asrSunnah3.
  ///
  /// In en, this message translates to:
  /// **'Prepare for Maghrib'**
  String get asrSunnah3;

  /// No description provided for @asrSunnah4.
  ///
  /// In en, this message translates to:
  /// **'Seek Allah\'s forgiveness'**
  String get asrSunnah4;

  /// No description provided for @asrNote.
  ///
  /// In en, this message translates to:
  /// **'Allah swears by this time in Surah Al-Asr, emphasizing its importance for believers.'**
  String get asrNote;

  /// No description provided for @maghribTeaser.
  ///
  /// In en, this message translates to:
  /// **'Gratitude for the day\'s blessings'**
  String get maghribTeaser;

  /// No description provided for @maghribBenefit1.
  ///
  /// In en, this message translates to:
  /// **'Gratitude for the day\'s blessings'**
  String get maghribBenefit1;

  /// No description provided for @maghribBenefit2.
  ///
  /// In en, this message translates to:
  /// **'Family gathering time'**
  String get maghribBenefit2;

  /// No description provided for @maghribBenefit3.
  ///
  /// In en, this message translates to:
  /// **'Breaking of the fast (if fasting)'**
  String get maghribBenefit3;

  /// No description provided for @maghribBenefit4.
  ///
  /// In en, this message translates to:
  /// **'Peaceful transition to evening'**
  String get maghribBenefit4;

  /// No description provided for @maghribSunnah1.
  ///
  /// In en, this message translates to:
  /// **'Pray 2 Sunnah rakats after Maghrib'**
  String get maghribSunnah1;

  /// No description provided for @maghribSunnah2.
  ///
  /// In en, this message translates to:
  /// **'Break fast with dates and water'**
  String get maghribSunnah2;

  /// No description provided for @maghribSunnah3.
  ///
  /// In en, this message translates to:
  /// **'Recite evening adhkar'**
  String get maghribSunnah3;

  /// No description provided for @maghribSunnah4.
  ///
  /// In en, this message translates to:
  /// **'Spend time with family'**
  String get maghribSunnah4;

  /// No description provided for @maghribNote.
  ///
  /// In en, this message translates to:
  /// **'The time of Allah\'s mercy and acceptance of duas, especially at sunset.'**
  String get maghribNote;

  /// No description provided for @ishaTeaser.
  ///
  /// In en, this message translates to:
  /// **'Peaceful end to the day'**
  String get ishaTeaser;

  /// No description provided for @ishaBenefit1.
  ///
  /// In en, this message translates to:
  /// **'Completion of daily prayers'**
  String get ishaBenefit1;

  /// No description provided for @ishaBenefit2.
  ///
  /// In en, this message translates to:
  /// **'Peaceful end to the day'**
  String get ishaBenefit2;

  /// No description provided for @ishaBenefit3.
  ///
  /// In en, this message translates to:
  /// **'Preparation for rest'**
  String get ishaBenefit3;

  /// No description provided for @ishaBenefit4.
  ///
  /// In en, this message translates to:
  /// **'Night of worship opportunity'**
  String get ishaBenefit4;

  /// No description provided for @ishaSunnah1.
  ///
  /// In en, this message translates to:
  /// **'Pray 2 Sunnah rakats after Isha'**
  String get ishaSunnah1;

  /// No description provided for @ishaSunnah2.
  ///
  /// In en, this message translates to:
  /// **'Pray Witr (odd-numbered prayer)'**
  String get ishaSunnah2;

  /// No description provided for @ishaSunnah3.
  ///
  /// In en, this message translates to:
  /// **'Recite Quran before sleep'**
  String get ishaSunnah3;

  /// No description provided for @ishaSunnah4.
  ///
  /// In en, this message translates to:
  /// **'Make istighfar before bed'**
  String get ishaSunnah4;

  /// No description provided for @ishaNote.
  ///
  /// In en, this message translates to:
  /// **'The final prayer that brings peace to the heart and prepares the soul for rest.'**
  String get ishaNote;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
