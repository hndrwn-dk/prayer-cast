# Adzan Home Delivery Layer — Technical Specification

**Project:** Tursina Labs — Prayer Times App
**Component:** `home_delivery` (presence → coordination → cast)
**Version:** 0.1 (draft)
**Status:** Design accepted, not yet implemented

---

## 1. Purpose

Play the adzan on smart speakers at home, at the correct time, **exactly once**, without
requiring an account, a cloud backend, or GPS permission.

This document covers three subsystems only:

| Subsystem | Answers the question |
|---|---|
| **Presence** | Is the user physically at home right now? |
| **Coordination** | Of the N devices at home, which one plays? |
| **Delivery** | How does audio actually reach the speaker? |

Prayer time calculation, UI, notifications and habit tracking are **out of scope** here.

---

## 2. Design constraints

These are non-negotiable and shape every decision below.

1. **Offline-first.** No internet required at azan time. Audio is bundled in the app,
   served from the device itself. No CDN, no signed URLs.
2. **No account.** No login, no server-side user record.
3. **No location permission in the default path.** GPS/geofencing is opt-in only,
   for a specific fallback case (§3.5).
4. **No multicast entitlement.** iOS `com.apple.developer.networking.multicast`
   requires an Apple application and approval. We must not need it. This rules out
   raw UDP multicast for peer coordination (§4.2).
5. **Fail silent, never fail loud.** A missed adzan is bad. A double adzan at 04:40
   is worse, and an adzan playing when nobody is home is worst.

---

## 3. Presence detection

### 3.1 Core idea

> If the phone can see the user's known Cast speaker on the LAN, the user is home.
> That is the definition, not a proxy for it.

This is stronger than geofencing (which is off by 50–200 m and drains battery), needs
zero location permission, and is exactly the signal we care about — because if we can't
reach the speaker, we can't play anyway.

### 3.2 Signals

| ID | Signal | Weight | Permission cost |
|---|---|---|---|
| **A** | A saved home Cast target is discoverable via mDNS | 1.0 | Local Network (iOS) only |
| **B** | LAN mDNS fingerprint matches saved home fingerprint | 0.6 | Local Network (iOS) only |
| **C** | Wi-Fi BSSID matches saved home BSSID | 0.5 | Location (both platforms) — **opt-in** |
| **D** | Geofence around home | 0.4 | Background location — **opt-in** |

Default install uses **A + B only**.

### 3.3 LAN fingerprint (Signal B)

During "Set this as my home" onboarding, browse these service types for 8 seconds:

```
_googlecast._tcp
_airplay._tcp
_raop._tcp
_hap._tcp
_spotify-connect._tcp
_printer._tcp
```

Store the **set of stable service instance identifiers** (Cast `id` TXT field where
available, else `instanceName@serviceType`), salted-hashed with a per-install salt:

```
fingerprint = { sha256(salt || instanceId) : instance in discovered }
```

At evaluation time, compute Jaccard similarity against the saved set.
`J >= 0.4` with at least 2 overlapping entries ⇒ Signal B true.

Hashing is not for security — it keeps a readable inventory of the user's home
devices out of the app's storage and any future backup/export.

### 3.4 State machine

```
              A or B true (1 scan)
   UNKNOWN ─────────────────────────► HOME
      │                                 │
      │ 2 consecutive false scans       │ 2 consecutive false scans
      │ spanning >= 90s                 │ spanning >= 90s
      ▼                                 ▼
    AWAY ◄────────────────────────────────
```

**Hysteresis is mandatory.** Cast devices drop off mDNS transiently when the TV they're
attached to powers down, when the AP re-associates the client, and during Android Doze
Wi-Fi throttling. A single failed scan must never flip state to AWAY.

### 3.5 Fallback for sleeping speakers

Some Chromecast dongles attached to a switched-off TV stop advertising entirely.
If a user reports "it thinks I'm not home", surface an opt-in toggle:

> **Speaker sleeps when TV is off** → enables Signal C (Wi-Fi BSSID).

Only this toggle requests location permission, and the copy must say why.
Never request it at first launch.

### 3.6 Scan scheduling

Do **not** scan at T+0. mDNS discovery takes 2–5 s and the radio may be asleep.

| Time | Action |
|---|---|
| T−120 s | Wake, acquire Wi-Fi lock, run presence scan (budget 8 s, early-exit on Signal A) |
| T−90 s | Presence decided; if AWAY, cancel session and release locks |
| T−30 s | Open coordination window (§4) |
| T−5 s | Leader starts local HTTP server, pre-connects Cast session |
| T+0 | `loadMedia` |

Cache the last presence result with a timestamp. Results older than 10 minutes are stale.

---

## 4. Coordination (leader election)

### 4.1 Problem

Ayah's phone, Ibu's phone, a tablet in the kitchen and an old phone acting as a hub are
all at home and all scheduled to fire Maghrib at 19:02. Without coordination the speaker
receives four `loadMedia` calls and the family hears a stuttering, restarting adzan.

Exactly one device must cast, and if it fails, another must take over within seconds.

### 4.2 Transport — why not multicast

Raw UDP multicast is the obvious choice and is wrong here:

- **iOS** requires the multicast entitlement (Apple approval, weeks of delay, can be denied).
- **Android** requires `WifiManager.MulticastLock`, and many consumer APs drop or
  rate-limit multicast via IGMP snooping and multicast-to-unicast conversion.

**Use Bonjour/NSD for discovery and plain unicast UDP for messaging.** Bonjour is
available on iOS through `NWBrowser`/`NetService` without the multicast entitlement,
and on Android through `NsdManager`.

### 4.3 Peer advertisement

Each participating device advertises:

```
service type : _adzan._tcp
instance     : adzan-<first 8 chars of deviceId>
port         : ephemeral UDP listener port
TXT:
  v    = 1                    # protocol version
  id   = <deviceId>           # UUIDv4, persisted, NOT a hardware identifier
  pri  = <0-100>              # priority, see 4.4
  st   = idle|claiming|leading|playing
  fp   = <8 hex chars>        # short home fingerprint hash, see 4.5
```

`deviceId` is a random UUID generated at first launch and stored locally. It must not be
derived from IMEI, MAC, IDFV or anything else identifying — this is a household
coordination token, nothing more.

### 4.4 Priority

Higher priority wins. Computed fresh at each election.

| Device state | Priority |
|---|---|
| Dedicated hub (headless companion build) | 100 |
| Tablet, plugged in, screen on | 60 |
| Phone, plugged in | 40 |
| Phone, on battery, >50% | 25 |
| Phone, on battery, <=50% | 10 |
| Battery saver active, or clock skew detected | 0 (never leads) |

Tie-break by lexicographic comparison of `deviceId`. Deterministic across all peers.

### 4.5 Session identity

All peers must agree on *which* adzan they are electing for, without negotiating.
Derive it independently:

```
sessionId = sha256( prayerName || floor(scheduledEpoch / 60) || homeFingerprintShort )[0:16]
```

Because it is anchored to the scheduled minute and the home network, two devices in two
different houses never collide, and a device whose prayer calculation differs by a minute
will produce a different sessionId — treat that as a bug and log it (§6).

### 4.6 Protocol

Messages are JSON over unicast UDP to each discovered peer.

```
CLAIM   { t:"CLAIM",   sid, id, pri, now }
LEAD    { t:"LEAD",    sid, id }
PLAYING { t:"PLAYING", sid, id }
YIELD   { t:"YIELD",   sid, id, reason }
```

Timeline, all relative to scheduled azan time T:

| Window | Behaviour |
|---|---|
| T−30 → T−22 | Every device broadcasts `CLAIM` to all peers, every 2 s. Collect peers' claims. |
| T−22 | Each device independently ranks `(pri, deviceId)` over `{self} ∪ claimants`. |
| T−22 → T−20 | Winner sends `LEAD`. Losers set state `idle` and start the failover timer. |
| T−20 → T+0 | Leader prepares: HTTP server up, Cast session connected, volume set. |
| T+0 | Leader calls `loadMedia`, then broadcasts `PLAYING`. |
| T+0 → T+4 | Followers wait for `PLAYING`. |
| T+4 | If no `PLAYING` heard, rank-2 device promotes itself and casts. |
| T+8, T+12 | Rank-3, rank-4 in turn. |

`YIELD` lets a device drop out early — e.g. it just entered battery saver, or its
Cast connection failed during preparation. A `YIELD` from the current leader triggers
immediate promotion rather than waiting for the timeout.

### 4.7 Clock skew

Each `CLAIM` carries the sender's `now` (epoch ms). On receipt, compute
`skew = |now_local − now_peer|`.

- `skew <= 3000 ms` → normal.
- `skew > 3000 ms` → the device with the minority clock sets its own priority to 0 for
  this session and logs a `CLOCK_SKEW` event. If there is no majority (2 devices only),
  the lower `deviceId` leads.

### 4.8 Belt and braces: receiver-side check

Before `loadMedia`, the leader queries the Cast session's current media status. If the
receiver is already playing a `contentId` matching our adzan for this `sessionId`,
**abort and log `SUPPRESSED_ALREADY_PLAYING`.** Never trust the election alone.

### 4.9 Single-device case

If zero peers respond by T−22, the device leads immediately. No penalty, no waiting.
The common case (one phone, one speaker) must not pay for the multi-device machinery.

---

## 5. Delivery

### 5.1 Local media server

Cast receivers fetch media over HTTP. To stay offline we serve it ourselves.

- `shelf` server bound to `0.0.0.0`, ephemeral port.
- Route: `GET /azan/{voiceId}.mp3`
- **Range requests are mandatory** — Cast issues `Range: bytes=0-` and some receivers
  will not play without a correct `206 Partial Content`. Implement:
  `Accept-Ranges: bytes`, `Content-Range`, exact `Content-Length`, `Content-Type: audio/mpeg`.
- Bind a per-session random path token: `/azan/{sessionId}/{voiceId}.mp3`. Prevents any
  other LAN device from probing the endpoint.
- Lifetime: start T−5 s, stop on Cast `IDLE`/`FINISHED` or T+180 s, whichever first.

### 5.2 Choosing the advertised IP

Do not use the first non-loopback interface. Enumerate interfaces and select the one
whose subnet contains the target Cast device's IP. On a phone with VPN, hotspot and
Wi-Fi simultaneously active, getting this wrong is the single most common cause of
"speaker connects then goes silent".

If no interface shares a subnet with the target, abort with `NO_ROUTE_TO_RECEIVER`.

### 5.3 Cast session

Using `flutter_chrome_cast`:

1. Discover, match saved target by Cast device `id` (not friendly name — users rename).
2. Connect session.
3. **Save the receiver's current volume**, then set to the configured per-prayer level.
4. `loadMedia` with `GoogleCastMediaInformation(streamType: buffered, ...)`.
5. On `FINISHED`, restore the saved volume, then end the session.

Step 3/5 matters: silently leaving a Nest Mini at 90% after Maghrib is a bug report
waiting to happen.

Once media is loaded, playback continues even if the app is killed — so the app only
needs a few seconds of execution at T+0, not the full duration of the adzan.

### 5.4 Multi-room

**Prefer a Google Home speaker group over parallel Cast sessions.** A group appears as a
single Cast device and Google handles sync. Parallel sessions to individual speakers
drift by 200–800 ms and sound like an echo through a house.

Onboarding should detect that the user has multiple speakers and link them to the
Google Home app to create a group, rather than trying to sync ourselves.

### 5.5 Platform wake-up

**Android**

- `AlarmManager.setAlarmClock()` — survives Doze, and the visible alarm icon is honest.
- Permission: `SCHEDULE_EXACT_ALARM` (request at runtime).
  Do **not** ship `USE_EXACT_ALARM` without checking Play policy — it is scoped to
  alarm-clock and calendar apps and a rejection will block your release.
- On fire: start a foreground service (`specialUse` type — not
  `mediaPlayback`; the service holds locks and launches the activity, it
  does not play audio) holding:
  - `PARTIAL_WAKE_LOCK`
  - `WifiLock(WIFI_MODE_FULL_HIGH_PERF)` — **without this, mDNS discovery fails
    intermittently when the screen is off.** This is the number one cause of
    "works when I'm holding the phone, fails overnight".
- Schedule only the next 1 alarm; reschedule on fire. Do not queue 30 days.

**iOS**

- No exact background execution exists. Be honest about this in the UI.
- Best effort: `UIBackgroundModes: audio` with an active `AVAudioSession` and a silent
  keepalive track. Works while the app has been opened recently and the device is charging.
- Required Info.plist:
  ```xml
  <key>NSLocalNetworkUsageDescription</key>
  <string>Digunakan untuk menemukan speaker di rumah Anda agar adzan bisa diputar.</string>
  <key>NSBonjourServices</key>
  <array>
    <string>_googlecast._tcp</string>
    <string>_adzan._tcp</string>
  </array>
  ```
- Ship a clear in-app explanation: for reliable unattended adzan, run the hub build on an
  always-on device. Do not overpromise iOS reliability in the store listing.

---

## 6. Observability

Local-only. Nothing leaves the device. This is a user-facing feature, not telemetry.

### 6.1 Schema

```sql
CREATE TABLE delivery_log (
  id              INTEGER PRIMARY KEY,
  session_id      TEXT NOT NULL,
  prayer          TEXT NOT NULL,
  scheduled_at    INTEGER NOT NULL,   -- epoch ms
  fired_at        INTEGER,
  presence_state  TEXT,               -- HOME | AWAY | UNKNOWN
  presence_signal TEXT,               -- A | B | C | D | NONE
  role            TEXT,               -- LEADER | FOLLOWER | SOLO | PROMOTED
  peer_count      INTEGER,
  target_id       TEXT,
  target_name     TEXT,
  outcome         TEXT NOT NULL,
  detail          TEXT,
  latency_ms      INTEGER             -- loadMedia call → PLAYING state
);
```

### 6.2 Outcome codes

```
PLAYED                     cast succeeded, receiver reported PLAYING
SUPPRESSED_AWAY            presence said AWAY
SUPPRESSED_NOT_LEADER      another device led
SUPPRESSED_ALREADY_PLAYING receiver-side duplicate check tripped
SUPPRESSED_USER_DND        user's quiet hours / guest mode
FAILED_NO_TARGET           saved speaker not discoverable
FAILED_NO_ROUTE            no interface on receiver's subnet
FAILED_CAST_CONNECT        session connect timeout
FAILED_LOAD_MEDIA          loadMedia error from receiver
FAILED_ALARM_MISSED        fired more than 60s late (OEM battery killer)
CLOCK_SKEW                 skew > 3s detected during election
```

### 6.3 UI

A simple list: last 30 attempts, prayer, time, outcome badge, and a one-line plain
explanation. When `FAILED_ALARM_MISSED` appears twice in a week, surface a link to
the OEM battery-optimisation settings page (Xiaomi, Oppo, Vivo, Samsung all need this
and none of them make it discoverable).

---

## 7. Module layout

```
lib/home_delivery/
  presence/
    presence_service.dart        # state machine, hysteresis, scheduling
    lan_fingerprint.dart         # mDNS browse + Jaccard similarity
    presence_state.dart
  coordination/
    peer_registry.dart           # NSD/Bonjour advertise + browse
    election.dart                # CLAIM/LEAD/PLAYING/YIELD, timers, failover
    device_identity.dart         # deviceId, priority calculation
    session_id.dart
  delivery/
    media_server.dart            # shelf + Range support
    interface_selector.dart      # pick the LAN IP on the receiver's subnet
    cast_client.dart             # flutter_chrome_cast wrapper, volume save/restore
    delivery_orchestrator.dart   # ties presence → election → cast
  logging/
    delivery_log_dao.dart
    outcome.dart
  platform/
    exact_alarm.dart             # MethodChannel → Android AlarmManager
    audio_keepalive.dart         # iOS AVAudioSession
android/.../ExactAlarmPlugin.kt
android/.../AdzanForegroundService.kt
```

**Dependency rule:** `presence` and `coordination` must not import `delivery`.
The orchestrator is the only module that knows about all three.

---

## 8. Test matrix

Unit and integration tests are cheap here; do not skip them, this layer is
almost impossible to debug in the field.

| Scenario | Expected |
|---|---|
| Solo phone, speaker present | `SOLO` / `PLAYED`, no election delay |
| Two phones, both home | Exactly one `PLAYED`, one `SUPPRESSED_NOT_LEADER` |
| Leader killed at T−10 s | Rank-2 promotes, `PLAYED` at ~T+4 s |
| Leader's Wi-Fi drops at T−1 s | `YIELD` → immediate promotion |
| Both phones away | Two `SUPPRESSED_AWAY`, zero casts |
| One phone home, one away | Home phone `SOLO`, away phone `SUPPRESSED_AWAY` |
| Phone clock 5 min fast | Fast phone priority 0, logs `CLOCK_SKEW`, does not lead |
| Speaker unplugged | `FAILED_NO_TARGET`, no crash, retry not attempted |
| VPN active on phone | Correct interface chosen or clean `FAILED_NO_ROUTE` |
| Two houses, same SSID name | Different `sessionId`, no cross-talk |
| App killed after `loadMedia` | Adzan continues playing to completion |
| Airplane mode at T−60 s | `SUPPRESSED_AWAY` (not a crash, not a retry loop) |

Simulate multi-device tests with two emulators plus one physical device on the same LAN.
A fake Cast receiver (a small Dart HTTP + Cast v2 stub) makes CI possible without hardware.

---

## 9. Open questions

1. **Should the hub build be a separate app or a build flavour?** Flavour is less work;
   a separate Play listing is more discoverable for the power-user segment.
2. **Resume interrupted media?** If the speaker was playing music, Cast interrupts it and
   does not resume. Capturing and restoring prior state is possible but fragile. Deferred.
3. **Speaker group detection** — can we detect that the user has a group configured and
   nudge them, or must onboarding just ask?
4. **Multi-fingerprint homes** — mesh Wi-Fi with separate 2.4/5 GHz SSIDs can yield two
   different fingerprints. Consider storing a list of home fingerprints, not one.

---

## 10. Non-goals for v1

- Apple HomePod scheduled playback (no public API exists; AirPlay from foreground only).
- Alexa (separate skill + Lambda; different product track entirely).
- Cloud sync of settings between family devices.
- Playing anything other than the bundled adzan files.
