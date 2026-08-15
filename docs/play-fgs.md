# Play Console — foreground services (Prayer Cast)

`targetSdk` is `flutter.targetSdkVersion` (36 / Android 16 as of this writing).
Apps targeting Android 14+ must declare each FGS type on **Monitor and
improve → App content**.

`AdzanForegroundService` is **specialUse**: a scheduled alarm wake, not
user-initiated playback. It holds a partial wake lock and a high-perf Wi-Fi
lock, posts an alarm-category notification with a full-screen intent, and
runs the delivery in a headless Flutter engine started in the service
process, so Dart Casts adhan (HOME) without waiting for `MainActivity`.

Google Cast SDK `MediaNotificationService` is declared **mediaPlayback**,
but see [Verified: the Cast media notification does not
appear](#verified-the-cast-media-notification-does-not-appear) — as of
1.0.0+1 that service never actually starts.

Do not declare `USE_EXACT_ALARM`. The app uses `SCHEDULE_EXACT_ALARM` only.

## Verified: the Cast media notification does not appear

Checked 2026-08-15 against `play-services-cast-framework` 21.5.0 and
`flutter_chrome_cast` 1.4.6, plus a Pixel 8 Pro running the current build.

`CastContextMethodChannel.setSharedInstance` in `flutter_chrome_cast` never
calls `CastOptions.Builder.setCastMediaOptions(...)`, so `build()` falls back
to the SDK's static default. Disassembling `CastOptions.<clinit>` shows that
default is:

```java
new CastMediaOptions.Builder()
    .setMediaSessionEnabled(false)
    .setNotificationOptions(null)
    .build()
```

A bare `new CastMediaOptions.Builder()` would enable both, but this static
fallback explicitly turns them off. `MediaNotificationService`
`.isNotificationOptionsValid(CastOptions)` returns false as soon as
`getNotificationOptions()` is null, so the Cast SDK never starts the service.

Device corroboration: the package has exactly one notification channel,
`adzan_delivery_alarm`. Channels persist once created, so the absence of a
Cast media channel proves `MediaNotificationService` has never posted.

Consequence: `FOREGROUND_SERVICE_MEDIA_PLAYBACK` is declared for a service
that never runs. Any "casting" indicator visible during adhan is posted by
Google Play services or Google Home, not by Prayer Cast, and must not be
presented as this app's mediaPlayback service in a Play review video.

The merged-manifest report shows both the
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission and the
`MediaNotificationService` `<service>` are added by the app's own manifest,
not merged from the Cast library, so dropping them is a plain deletion and
needs no `tools:node="remove"`. Plain `FOREGROUND_SERVICE` is merged from the
library and stays regardless.

## Verified: notifications are a runtime permission the app never requests

`POST_NOTIFICATIONS` is declared in the manifest, but nothing in `lib/`
requests it — `permission_handler` is wired only to the nearby-Wi-Fi scan. On
API 33+ that leaves it denied, and a denied app cannot show the
`AdzanForegroundService` notification at all: the post is enqueued and
dropped. Delivery still works; the notification is simply invisible.

Until the app asks at runtime, granting it means
**Settings → Apps → Prayer Cast → Notifications**. Any demo recording of the
specialUse notification depends on this being granted first.

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

1. Open Prayer Cast. Grant exact-alarm permission, and grant
   notifications from **Settings → Apps → Prayer Cast →
   Notifications** — the app does not prompt for it.
2. Save a home speaker, or set one prayer to beep.
3. Use the in-app next-alarm test so a wake fires soon. It replaces
   the next armed alarm, so do not use it when a real prayer is
   being relied on.
4. Lock the phone / turn the screen off.
5. Show the notification — title "Menyiapkan adzan", body the prayer
   wire value (e.g. `dhuhr`) — and the app coming to the foreground.
6. Cast path: speaker plays; phone stays silent unless that prayer
   is beep or phone adhan.
7. Show the ongoing FGS notification during the wake window, then
   disappearing after delivery.

## mediaPlayback — Cast SDK only

> Not true of 1.0.0+1. The service never starts — see [Verified: the Cast
> media notification does not
> appear](#verified-the-cast-media-notification-does-not-appear). The copy
> below is what was submitted for 1.0.0+1 and is kept so the docs match the
> uploaded AAB. Either drop the declaration or supply real
> `NotificationOptions` at the next version bump.

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

**Demo video:** there is nothing to film for this type in 1.0.0+1. Do not
point at a system casting chip and call it this service. Resolve the
declaration instead — either remove `FOREGROUND_SERVICE_MEDIA_PLAYBACK` and
the `MediaNotificationService` `<service>` from the app manifest, or give the
Cast SDK a `CastMediaOptions` with non-null `NotificationOptions` via an
app-owned `OptionsProvider` so the notification genuinely exists.

## Manifest property (already in the APK)

`android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE` on
`.AdzanForegroundService`:

```
Exact-alarm prayer wake: hold CPU and high-perf Wi-Fi locks and launch MainActivity so Dart can Cast adhan to the home speaker or play beep/phone adhan. This service does not play media.
```

## Console form answers

The "Foreground service permissions" form lists the permissions and asks
which tasks need them:

- `FOREGROUND_SERVICE_MEDIA_PLAYBACK` — check **Media playback**. Not
  "Show picture in picture", not "Other". Only while the permission is still
  declared; the goal is to stop declaring it.
- `FOREGROUND_SERVICE_SPECIAL_USE` — check **Other** (the only option),
  then paste the specialUse description above.

## Full-screen intent (keep; already required)

`USE_FULL_SCREEN_INTENT` stays for lockscreen / screen-off presentation.

Console form answers:

- **Core functionality:** Alarm clock
- **Pre-granted at installation:** Yes

**Description:**

```
Prayer Cast schedules an exact alarm for each of the five daily prayers
and uses a full-screen intent so the adhan surfaces on a locked,
screen-off phone at prayer time.
```

Answering No means users must grant it themselves, and full-screen
notifications degrade to a 60-second floating window. Delivery itself no
longer depends on this permission: Dart runs inside the foreground
service, so if the pre-grant review ever stalls a release, No does not
stop the adhan.

## Manual smoke (no device install from this change)

Do not `flutter install` or adb-install over a live debug APK.

After the user sideloads a matching-signature build and opens the app
once:

- Alarm still fires at T−120; FGS notification appears — only if
  notifications are allowed for the app. Check with
  `adb shell cmd appops get com.tursinalabs.prayer_cast POST_NOTIFICATION`;
  `ignore` means the notification is enqueued and dropped.
- Cast-only + HOME: speaker plays; phone silent.
- Cast-only + AWAY: phone silent (no fallback) unless that prayer is
  beep or phone adhan.
- Beep / phone adhan: Flutter audioplayers plays after MainActivity
  starts; FGS still does not play.
- `adb shell dumpsys activity services` for
  `AdzanForegroundService` shows type `specialUse` on API 34+.

Store listing copy: [play-store-listing.md](play-store-listing.md).
Data safety: [play-data-safety.md](play-data-safety.md).
