# First-run onboarding

**Date:** 2026-10-04  
**Status:** Draft — awaiting review  
**Product:** Prayer Cast (Flutter / Android)  
**Replaces:** section "1. First-run checklist card" in `docs/superpowers/specs/2026-10-03-qa-enhancements-design.md`

## Problem

Home currently stacks three permission cards (exact alarm, notifications, battery) above the next-adhan time, then a beige "Selesaikan pengaturan" checklist. The time is pushed down, and setup does not belong on home.

## Goals

- A first install sees a short sequence of its own screens, then the current home.
- Home after that sequence is the existing next-adhan screen: time, prayer name, city, and the paths to Speaker, prayer times, tracker, and qibla.
- Speaker-or-phone is not the end of setup. Each choice continues into the step that belongs to it, then prayer times.
- Notification and exact-alarm prompts happen once each, on their own screens, before the first arrival at home.
- Battery is one skippable step. Home never shows three permission cards at once.

## Non-goals

- Coach marks, spotlights, or a slide deck on top of home.
- A new speaker scanner, prayer-times editor, or permission API.
- Offering takbir during onboarding. Takbir stays in prayer settings.
- A global "skip setup" that lands on home before prayer times are saved.
- Changing theme, legal links, or Play Store frames.

## Decisions

| Topic | Choice |
|--------|--------|
| Where setup lives | Its own route, before home |
| Home | Current next-adhan screen, no checklist card |
| Audio | Speaker or this phone, then the related step |
| No speaker found | "Pakai audio di HP aja" continues into the phone step |
| Phone audio | Adzan di HP or Beep di HP |
| Prayer times | Existing prayer settings |
| Notifications, exact alarm | One screen each, existing request |
| Battery | Existing settings button, skippable |
| Existing installs | Prayer times already configured, and onboarding never started: go straight to home |
| Finished | Flag set only after the battery step (opened or skipped) |

## Screens

One step per screen. Back returns to the previous onboarding step. The first step does not open home. Copy is English and Indonesian (`l10n`). Chrome matches the app: eyebrow, title, one primary action, a quiet text action when there is an alternate.

1. **Where does the adhan play?**
   - Speaker rumah
   - HP ini
2. **The step that belongs to that choice.**
   - Speaker: the existing speaker scan. Saving a speaker sets delivery to `cast` and continues to prayer times.
   - Empty scan: **Pakai audio di HP aja**. No speaker is saved. The flow continues to the phone step below. It does not return to step 1.
   - HP: **Adzan di HP** (`adhanPhone`) or **Beep di HP** (`beep`). Saving either continues to prayer times.
3. **Prayer times.** The existing prayer settings page. Continuing requires `configured == true`.
4. **Notifications.** One sentence and one button. The button runs the existing notification request. When the system dialog returns, granted or denied, the flow continues.
5. **Exact alarm.** Same shape, existing exact-alarm request. Granted or denied, the flow continues.
6. **Battery.** Existing "open battery settings" action, plus skip. Either choice sets onboarding finished and opens home.

## Home afterwards

Remove `SetupChecklistCard` from home. Do not show the exact-alarm card, the notification card, and the battery card together above the time.

If something needed for a reliable adhan is still missing, home shows one line, in this order: notifications, then exact alarm, then battery. Tapping it opens that existing request or settings page. When that item is resolved, the line shows the next missing item, or disappears. The dry-run armed banner is unchanged.

## Who sees it

Persist one step id on device, same file style as locale. Missing file means `notStarted`. Ids: `audio`, `speaker`, `phone`, `prayer`, `notifications`, `alarm`, `battery`, `completed`.

- `completed` → home. Back from home does not return to onboarding.
- `notStarted` and prayer prefs `configured == true` → this install already had prayer times. Write `completed` and open home. Do not show onboarding.
- `notStarted` and not configured → write `audio` before the first screen is shown, so a later save of prayer times does not look like an existing install.
- Any other id → resume that step, including when prayer times were saved midway.

Denial of a system permission does not trap the user on that step. Resume uses the stored step, not "permission still missing".

## What is reused

- Speaker scan and save (`SpeakerSetupPage` behavior, delivery `cast`).
- Prayer settings save (`configured`).
- `PrayerDeliveryMode.adhanPhone` and `PrayerDeliveryMode.beep`.
- Notification request, exact-alarm request, battery settings intent.

No second copy of those forms. Onboarding is a route that hosts or pushes those existing screens and decides the next step. While the stored step is not `completed`, home's permission line and the speaker page's battery banner stay hidden. Battery is only step `battery`.

## Tests

- Fresh prefs, not configured: the first frame is the audio choice, not home.
- Configured prefs and `notStarted`: home, and the checklist card is absent.
- Speaker choice opens the scan. Empty scan's phone action leads to adzan/beep, not back to step 1.
- Adzan and beep each persist that delivery mode.
- Saving a speaker persists `cast` and advances to prayer times.
- Prayer settings cannot advance until `configured` is true.
- Notification and exact-alarm steps advance when the request returns denied.
- Skip battery sets `completed` and shows home.
- Home with several permissions missing shows one recovery line, not three cards.

## Risks

- A configured flag written during onboarding must not take the existing-user shortcut. The in-progress mark is written at step 1, before prayer settings.
- Light and Forest both have to show these screens. Use the same tokens as the rest of the app.
