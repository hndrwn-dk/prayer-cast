# Play Console — foreground services (Prayer Cast)

`targetSdk` is `flutter.targetSdkVersion` (36 / Android 16 as of this writing).
Apps targeting Android 14+ must declare each FGS type on **Monitor and
improve → App content**.

`AdzanForegroundService` is **specialUse**. It does not play audio. It
holds a partial wake lock and a high-perf Wi-Fi lock, posts an
alarm-category notification with a full-screen intent, and starts
`MainActivity` so Dart can Cast adhan (HOME) or play beep / phone adhan.

Google Cast SDK `MediaNotificationService` stays **mediaPlayback**.

Do not declare `USE_EXACT_ALARM`. The app uses `SCHEDULE_EXACT_ALARM` only.

## specialUse — copy into Play Console

**Foreground service type:** `specialUse`

**Use case (manual, if not in the preset list):**
Scheduled prayer alarm wake (exact-alarm azan).

**Description of the app functionality using this type:**

```
Prayer Cast fires AlarmManager.setAlarmClock at T−120s before each
scheduled prayer. AdzanAlarmReceiver (exported=false) starts
AdzanForegroundService. That service:

1. startForeground as specialUse with an ongoing alarm-category
   notification ("Menyiapkan adzan") and a full-screen intent.
2. Holds PARTIAL_WAKE_LOCK and WifiLock(WIFI_MODE_FULL_HIGH_PERF) so
   mDNS / Cast discovery works with the screen off.
3. Sends a PendingIntent that launches MainActivity (BAL opt-in on
   API 34+). Dart PrayerDeliveryCoordinator then Casts adhan to the
   saved home speaker when presence is HOME, or plays a local beep /
   phone adhan when the user chose those modes.

The service itself never calls MediaPlayer, AudioTrack, MediaSession,
or audioplayers. Cast-only / away stays silent on the phone unless
that prayer is set to beep or phone adhan.
```

**Why this is not mediaPlayback / shortService / connectedDevice:**

```
mediaPlayback is for continuing audio or video playback from this
process. AdzanForegroundService does not play media. Phone beep /
phone adhan run later in Flutter after MainActivity starts. Speaker
audio is played by the Cast device; Cast SDK MediaNotificationService
is a separate mediaPlayback service.

shortService (~3 minutes) is too short: Cast discovery + loadMedia
and a full adhan can exceed that. The wake lock is capped at 10
minutes.

connectedDevice does not apply: this service does not talk to the
speaker. Dart does, after the activity starts.
```

**User impact if the task is deferred (does not start immediately):**

```
The exact-alarm fire would not keep CPU/Wi-Fi up or launch the
delivery activity. Adhan would miss at azan time, especially
overnight / screen-off, when mDNS fails without the high-perf Wi-Fi
lock.
```

**User impact if the task is interrupted (paused or restarted):**

```
Cast session setup or local beep / phone adhan would abort
mid-delivery. The next prayer is rescheduled only if Dart finished
that step before the service was killed.
```

**Demo video (record this):**

1. Open Prayer Cast. Grant exact-alarm and notification permission.
2. Save a home speaker, or set one prayer to beep.
3. Use the in-app next-alarm test so a wake fires soon.
4. Lock the phone / turn the screen off.
5. Show the "Menyiapkan adzan" notification and the app coming to
   the foreground.
6. Cast path: speaker plays; phone stays silent unless that prayer
   is beep or phone adhan.
7. Show the ongoing FGS notification during the wake window.

## mediaPlayback — Cast SDK only

**Foreground service type:** `mediaPlayback`

**Use case:** Media Playback

**Description:**

```
Google Cast SDK MediaNotificationService
(com.google.android.gms.cast.framework.media.MediaNotificationService).
Continues the Cast media notification and session controls while
adhan plays on the saved home speaker. This is Google's service, not
AdzanForegroundService. Prayer Cast does not implement a second
mediaPlayback service.
```

**User impact if deferred / interrupted:**

```
The Cast session notification and transport controls would not stay
visible while adhan plays on the speaker. Playback on the speaker
may still continue; the phone would lose the standard Cast media
notification.
```

**Demo video:** same Cast delivery as above; show the Cast media
notification while the speaker is playing.

## Manifest property (already in the APK)

`android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE` on
`.AdzanForegroundService`:

```
Exact-alarm prayer wake: hold CPU and high-perf Wi-Fi locks and launch MainActivity so Dart can Cast adhan to the home speaker or play beep/phone adhan. This service does not play media.
```

## Full-screen intent (keep; already required)

`USE_FULL_SCREEN_INTENT` stays. On Pixel / API 34+, background
`startActivity` from the FGS is BAL-blocked unless the notification
uses a full-screen intent (and the PendingIntent has creator BAL
opt-in). Declare this as **alarm** core functionality on App content
so the permission can be granted by default.

## Manual smoke (no device install from this change)

Do not `flutter install` or adb-install over a live debug APK.

After the user sideloads a matching-signature build and opens the app
once:

- Alarm still fires at T−120; FGS notification appears.
- Cast-only + HOME: speaker plays; phone silent.
- Cast-only + AWAY: phone silent (no fallback) unless that prayer is
  beep or phone adhan.
- Beep / phone adhan: Flutter audioplayers plays after MainActivity
  starts; FGS still does not play.
- `adb shell dumpsys activity services` for
  `AdzanForegroundService` shows type `specialUse` on API 34+.

Store listing copy: [play-store-listing.md](play-store-listing.md).
Data safety: [play-data-safety.md](play-data-safety.md).
