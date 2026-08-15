# Play Console Data safety — Prayer Cast

Use this when filling the Data safety form for `com.tursinalabs.prayer_cast`.
Answers match app behavior as of 15 August 2026.

Play definition: **Collected** means transmitted off the device. Data that
stays only on the phone is **not** collected.

Privacy policy URL in Play Console must be the Prayer Cast page, not the
generic studio policy:

https://tursinalabs.com/privacy/prayer-cast

## Overview

**Does your app collect or share any of the required user data types?**
Yes.

Declare collection/sharing because:

- Location (city/country or GPS) is sent to Aladhan, or for Indonesia a
  city id is sent to myQuran (`api.myquran.com`) for Kemenag jadwal, and
  when GPS is used, to Android Geocoder / Google Play services.
- Google Cast / Google Mobile Services may process device or other IDs.

Tursina Labs does **not** operate a backend for this app and does **not**
receive prayer times, location, speaker list, or delivery logs.

## Location

### Approximate location

| Field | Answer |
| --- | --- |
| Collected? | Yes |
| Shared? | Yes |
| Shared with | Aladhan (`api.aladhan.com`) as city + country when fetching prayer times, or as approximate `lat` / `lng` when the user used optional GPS. For Indonesia with the Kemenag method, only a city id + date go to myQuran (`api.myquran.com`) — not coordinates. Android Geocoder / Google Play services when the user taps "Use current location" (reverse geocode to city/country). |
| Purpose | App functionality |
| Optional? | Yes |
| Ephemeral? | No |
| Encrypted in transit? | Yes (HTTPS) |
| Users can request deletion? | Yes. Clear app data or uninstall. Tursina Labs has no server copy. |
| Sold? | No |
| Used for advertising? | No |
| Shared with Tursina Labs? | No |

City and country can be typed by the user or filled from reverse geocoding.
Non-Indonesia schedules send city + country (or approximate coords) to
Aladhan. Indonesia + Kemenag sends only the matched city id to myQuran.

The Prayer Cast privacy page at
https://tursinalabs.com/privacy/prayer-cast lists `api.myquran.com` as the
Kemenag jadwal host alongside Aladhan.

### Precise location

| Field | Answer |
| --- | --- |
| Collected? | No |
| Shared? | No |

The app does **not** declare `ACCESS_FINE_LOCATION`. Optional GPS uses
coarse / approximate location only, to fill city and country. Approximate
coordinates may still be sent to Aladhan timings-by-coordinates and to
Android Geocoder; declare that under Approximate location, not Precise.

Location is **not** used to decide whether the user is home. Home
detection uses an on-device LAN fingerprint only. Speaker scan on
API 33+ uses `NEARBY_WIFI_DEVICES` (`neverForLocation`), not location.

## Device or other IDs

| Field | Answer |
| --- | --- |
| Collected by Tursina Labs? | No |
| Shared? | Yes |
| Shared with | Google, through Google Cast / Google Play services during speaker discovery and Cast sessions. Google may process device or network identifiers under Google Cast / Play services policies. |
| Purpose | App functionality |
| Optional? | Yes (only if the user uses Cast / picks a home speaker) |
| Encrypted in transit? | Yes (handled by Google Play services) |
| Users can request deletion? | Yes, insofar as Google provides that under its policies. Tursina Labs has no copy. |
| Sold? | No |
| Used for advertising? | No |
| Shared with Tursina Labs? | No |

Do **not** declare the LAN fingerprint (home Wi-Fi identity) as collected.
It stays on the device and is not GPS.

## Do not declare

Do not add these data types. The app does not collect or share them:

- Name, email, user IDs, or other account info (no accounts)
- Contacts
- Photos, videos, or files
- Audio files uploaded to a developer server (adhan audio is bundled; LAN
  serve to the speaker is local-network only)
- Financial info
- Health and fitness
- Messages
- Calendar
- App activity / analytics we operate
- Web browsing
- Advertising ID or ads data
- Crash logs we operate (no crash reporter we run)
- Performance / diagnostics we operate

## Ko-fi

If the user taps Support, the system browser opens
https://ko-fi.com/hendrawandaryonokarso. That is the user leaving the app.
Prayer Cast does not collect donation or payment data. Do not declare
financial info.

Donations do not unlock features.

## Local network audio

When adhan is cast, the phone serves the audio file over HTTP on the home
LAN to the saved speaker. The Cast device fetches that URL; the Android
app process does not open cleartext HTTP (no global
`usesCleartextTraffic`). That traffic is not collected by Tursina Labs and
is not transmitted to a developer server. Do not declare it as collected
files or audio.

## On-device only (not collected)

These stay on the phone and must not be declared as collected:

- Prayer prefs (city, country, optional GPS coords, method, Asr school,
  voice, delivery mode)
- Saved Cast speaker id/name
- LAN fingerprint
- Household election secret derived from the saved Cast id
- Prayer schedule cache
- Delivery log SQLite (prayer name, times, HOME/AWAY, speaker name, outcome)
- Locale preference

Users delete this by clearing app data or uninstalling.

## Reviewer notes

- In-app copy: "Data stays only on your phone." / "Data hanya tersimpan di
  ponsel Anda." That refers to Tursina Labs not receiving a copy. Location
  still leaves the device toward Aladhan, myQuran (Indonesia Kemenag
  jadwal), or the geocoder when those features run.
- Policy page and this form must stay aligned. If behavior changes, update
  both https://tursinalabs.com/privacy/prayer-cast and this file.
- Foreground service types and Play Console FGS copy: [play-fgs.md](play-fgs.md).
- Store listing copy and feature graphic: [play-store-listing.md](play-store-listing.md).
