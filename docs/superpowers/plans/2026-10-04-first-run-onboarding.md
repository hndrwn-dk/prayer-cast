# First-run onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A first install finishes speaker-or-phone, prayer times, and the permission prompts on their own screens, then lands on the current home with no setup card and at most one permission line.

**Architecture:** An onboarding record on disk names the current step and the step Back returns to. `OnboardingGate` is `MaterialApp.home`. It sends existing configured installs straight to `_HomeShell`. Every other step is a screen in `lib/setup/ui/` that reuses speaker scan, prayer settings, and the existing permission calls. Home drops `SetupChecklistCard` and the stack of three permission cards.

**Tech Stack:** Flutter, flutter_riverpod, existing `PrayerPrefsStore`, `SpeakerSetupPage`, `PrayerSettingsPage`, `PostNotificationsPermission`, `ExactAlarmPlatform`.

## Global Constraints

- Onboarding is its own route before home. Home stays the current next-adhan screen.
- Speaker or phone always continues into the related step, then prayer times.
- Empty speaker scan offers "Pakai audio di HP aja" and continues to the phone step. It does not return to step 1.
- Phone choices are `adhanPhone` and `beep` only. Takbir is not offered.
- Notification and exact-alarm screens advance when the system request returns, including when it is denied.
- Battery is the only skip. Skip and open both set `completed` and open home.
- Missing onboarding file plus `PrayerPrefs.configured == true` writes `completed` and opens home.
- Write `audio` before the first onboarding screen is shown.
- Back from home does not return to onboarding.
- While the step is not `completed`, hide home's permission line and the speaker page's battery banner.
- After completion, home shows at most one recovery line: notifications, then exact alarm, then battery.
- Copy is English and Indonesian via `l10n`.
- No coach marks, no global skip, no second copy of the speaker or prayer-times forms.
- No emoji in code.

---

### Task 1: Onboarding record

**Files:**
- Create: `lib/setup/onboarding_store.dart`
- Test: `test/setup/onboarding_store_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `enum OnboardingStep { audio, speaker, phone, prayer, notifications, alarm, battery, completed }`, `class OnboardingRecord`, `abstract interface class OnboardingStore`, `FileOnboardingStore`, `MemoryOnboardingStore`, `onboardingStoreProvider`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

void main() {
  test('missing file is not started', () async {
    final file = File(
      '${Directory.systemTemp.path}/onboarding_missing_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    final record = await FileOnboardingStore(file).read();
    expect(record.step, isNull);
    expect(record.back, isNull);
  });

  test('round trip keeps step and back target', () async {
    final file = File(
      '${Directory.systemTemp.path}/onboarding_round_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    final store = FileOnboardingStore(file);
    await store.write(
      const OnboardingRecord(
        step: OnboardingStep.phone,
        back: OnboardingStep.speaker,
      ),
    );
    final record = await store.read();
    expect(record.step, OnboardingStep.phone);
    expect(record.back, OnboardingStep.speaker);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/setup/onboarding_store_test.dart`

Expected: FAIL. `onboarding_store.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OnboardingStep {
  audio,
  speaker,
  phone,
  prayer,
  notifications,
  alarm,
  battery,
  completed,
}

final class OnboardingRecord {
  const OnboardingRecord({this.step, this.back});

  /// Null means the file was missing: onboarding has not started.
  final OnboardingStep? step;
  final OnboardingStep? back;

  static const notStarted = OnboardingRecord();
}

abstract interface class OnboardingStore {
  Future<OnboardingRecord> read();
  Future<void> write(OnboardingRecord record);
}

final class MemoryOnboardingStore implements OnboardingStore {
  MemoryOnboardingStore([this._record = OnboardingRecord.notStarted]);

  OnboardingRecord _record;

  @override
  Future<OnboardingRecord> read() async => _record;

  @override
  Future<void> write(OnboardingRecord record) async => _record = record;
}

final class FileOnboardingStore implements OnboardingStore {
  FileOnboardingStore(this._file);

  final File _file;

  @override
  Future<OnboardingRecord> read() async {
    if (!await _file.exists()) return OnboardingRecord.notStarted;
    try {
      final lines = (await _file.readAsLines())
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.isEmpty) return OnboardingRecord.notStarted;
      return OnboardingRecord(
        step: _parse(lines[0]),
        back: lines.length > 1 ? _parse(lines[1]) : null,
      );
    } catch (_) {
      return OnboardingRecord.notStarted;
    }
  }

  OnboardingStep? _parse(String raw) {
    if (raw == '-') return null;
    for (final step in OnboardingStep.values) {
      if (step.name == raw) return step;
    }
    return null;
  }

  @override
  Future<void> write(OnboardingRecord record) async {
    await _file.parent.create(recursive: true);
    final step = record.step?.name ?? '-';
    final back = record.back?.name ?? '-';
    await _file.writeAsString('$step\n$back\n');
  }
}

final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
  throw UnimplementedError('onboardingStoreProvider must be overridden');
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/setup/onboarding_store_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/setup/onboarding_store.dart test/setup/onboarding_store_test.dart
git commit -m "Add an onboarding step record."
```

---

### Task 2: Gate existing installs to home and new installs to audio

**Files:**
- Create: `lib/setup/onboarding_controller.dart`
- Create: `lib/setup/ui/onboarding_gate.dart`
- Modify: `lib/main.dart` (boot file, `PrayerCastApp.home`, `PrayerCastAppForTest` overrides)
- Test: `test/setup/onboarding_gate_test.dart`
- Test: `test/widget_test.dart` (the unconfigured shell test)

**Interfaces:**
- Consumes: `OnboardingStore`, `OnboardingRecord`, `OnboardingStep`, `prayerPrefsProvider`, `prayerPrefsStoreProvider`
- Produces: `OnboardingController.go(WidgetRef ref, OnboardingStep step, {OnboardingStep? back})`, `OnboardingController.resolve(WidgetRef ref)`, `OnboardingGate`

- [ ] **Step 1: Write the failing test**

`test/setup/onboarding_gate_test.dart` pumps `PrayerCastAppForTest`.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_database.dart';
import 'package:prayer_cast/main.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

void main() {
  testWidgets('fresh install opens the audio step, not home', (tester) async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);
    final store = MemoryOnboardingStore();

    await tester.pumpWidget(
      PrayerCastAppForTest(database: db, onboarding: store),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('onboarding_audio_speaker')), findsOneWidget);
    expect(find.text('ADZAN BERIKUTNYA'), findsNothing);
    expect(await store.read(), isNot(OnboardingRecord.notStarted));
    expect((await store.read()).step, OnboardingStep.audio);
  });

  testWidgets('configured install opens home and marks onboarding completed', (
    tester,
  ) async {
    final db = DeliveryDatabase.memory();
    addTearDown(db.close);
    final store = MemoryOnboardingStore();

    await tester.pumpWidget(
      PrayerCastAppForTest(
        database: db,
        onboarding: store,
        prayerPrefs: PrayerPrefs.defaults.copyWith(configured: true),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('ADZAN BERIKUTNYA'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_audio_speaker')), findsNothing);
    expect((await store.read()).step, OnboardingStep.completed);
  });
}
```

In `test/widget_test.dart`, the test `app shell loads speaker and prayer entry points` pumps `PrayerCastAppForTest` with default prefs (`configured: false`). Change its expectations from home copy to the audio step: `find.byKey(const ValueKey('onboarding_audio_speaker'))` finds one widget, and `find.text('ADZAN BERIKUTNYA')` finds nothing. Leave `_pumpHomeAtSize` tests on home; those pass `configured: true`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/setup/onboarding_gate_test.dart`

Expected: FAIL. `PrayerCastAppForTest` has no `onboarding` parameter and the audio key is absent.

- [ ] **Step 3: Write minimal implementation**

`lib/setup/onboarding_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/setup/onboarding_store.dart';

abstract final class OnboardingController {
  static Future<OnboardingRecord> resolve(WidgetRef ref) async {
    final store = ref.read(onboardingStoreProvider);
    final current = await store.read();
    if (current.step != null) return current;
    final prefs = await ref.read(prayerPrefsProvider.future);
    final next = OnboardingRecord(
      step: prefs.configured ? OnboardingStep.completed : OnboardingStep.audio,
    );
    await store.write(next);
    return next;
  }

  static Future<void> go(
    WidgetRef ref,
    OnboardingStep step, {
    OnboardingStep? back,
  }) async {
    await ref.read(onboardingStoreProvider).write(
      OnboardingRecord(step: step, back: back),
    );
    ref.invalidate(onboardingStepProvider);
  }
}

final onboardingStepProvider = FutureProvider<OnboardingRecord>((ref) async {
  return ref.watch(onboardingStoreProvider).read();
});
```

`lib/setup/ui/onboarding_gate.dart` is a `ConsumerStatefulWidget`. `initState` calls `OnboardingController.resolve`. Until that future completes, show an empty `Scaffold` whose color is `PrayerCastTokens.surface`. Then:

- `completed` → `home`
- anything else → `OnboardingAudioStep` for this task only (the later tasks replace the body switch)

`OnboardingAudioStep` in this task is a placeholder column with two `TextButton`s keyed `onboarding_audio_speaker` and `onboarding_audio_phone`, labels from the new l10n keys below. Taps are wired in Task 3. No back button.

`PrayerCastApp.build` sets `home:` to `OnboardingGate(home: _HomeShell(...), ...)`. Pass the same `exactAlarm` and `coordinator` the shell already takes.

In `main()`, next to `setupCardStore`, create `FileOnboardingStore(File(p.join(docs.path, 'onboarding.txt')))` and override `onboardingStoreProvider`.

`PrayerCastAppForTest` gains `final OnboardingStore? onboarding` and overrides `onboardingStoreProvider` with `onboarding ?? MemoryOnboardingStore()`.

Add to `lib/l10n/app_en.arb` and `lib/l10n/app_id.arb`, then run `flutter gen-l10n`:

- `onboardingAudioEyebrow`: "Setup" / "Pengaturan"
- `onboardingAudioTitle`: "Where should the adhan play?" / "Adzan diputar di mana?"
- `onboardingAudioSpeaker`: "Home speaker" / "Speaker rumah"
- `onboardingAudioPhone`: "This phone" / "HP ini"

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/setup/onboarding_gate_test.dart test/widget_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/setup/onboarding_controller.dart lib/setup/ui/onboarding_gate.dart lib/main.dart lib/l10n test/setup/onboarding_gate_test.dart test/widget_test.dart
git commit -m "Open onboarding before home for a new install."
```

---

### Task 3: Audio choice continues to speaker or phone

**Files:**
- Modify: `lib/setup/ui/onboarding_gate.dart`
- Create: `lib/setup/ui/onboarding_audio_step.dart`
- Test: `test/setup/onboarding_audio_step_test.dart`

**Interfaces:**
- Consumes: `OnboardingController.go`
- Produces: `OnboardingAudioStep`. Speaker tap writes `OnboardingStep.speaker` with `back: OnboardingStep.audio`. Phone tap writes `OnboardingStep.phone` with `back: OnboardingStep.audio`.

- [ ] **Step 1: Write the failing test**

Pump a `ProviderScope` with `MemoryOnboardingStore` already at `audio`, `MaterialApp` with `OnboardingAudioStep` as home, locale `id`.

```dart
await tester.tap(find.byKey(const ValueKey('onboarding_audio_speaker')));
await tester.pump();
expect((await store.read()).step, OnboardingStep.speaker);
expect((await store.read()).back, OnboardingStep.audio);
```

A second test taps `onboarding_audio_phone` and expects `step: phone`, `back: audio`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/setup/onboarding_audio_step_test.dart`

Expected: FAIL. Taps do not write the step.

- [ ] **Step 3: Write minimal implementation**

`OnboardingAudioStep` is a `ConsumerWidget` using `ForestScaffold` and `EditorialPageHeader` with `onBack: null`. Two full-width buttons:

```dart
FilledButton(
  key: const ValueKey('onboarding_audio_speaker'),
  onPressed: () => OnboardingController.go(
    ref,
    OnboardingStep.speaker,
    back: OnboardingStep.audio,
  ),
  child: Text(l10n.onboardingAudioSpeaker),
)
TextButton(
  key: const ValueKey('onboarding_audio_phone'),
  onPressed: () => OnboardingController.go(
    ref,
    OnboardingStep.phone,
    back: OnboardingStep.audio,
  ),
  child: Text(l10n.onboardingAudioPhone),
)
```

`OnboardingGate` switches on `record.step`: `speaker` and `phone` still render `OnboardingAudioStep` until Tasks 4 and 5. `audio` renders `OnboardingAudioStep`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/setup/onboarding_audio_step_test.dart test/setup/onboarding_gate_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/setup/ui/onboarding_audio_step.dart lib/setup/ui/onboarding_gate.dart test/setup/onboarding_audio_step_test.dart
git commit -m "Send the audio choice to speaker or phone."
```

---

### Task 4: Phone step saves adhan or beep

**Files:**
- Create: `lib/setup/ui/onboarding_phone_step.dart`
- Modify: `lib/setup/ui/onboarding_gate.dart`
- Modify: `lib/setup/onboarding_controller.dart`
- Test: `test/setup/onboarding_phone_step_test.dart`

**Interfaces:**
- Consumes: `OnboardingController.go`, `PrayerPrefs.withDefaultDelivery`, `prayerPrefsStoreProvider`
- Produces: `OnboardingController.setDelivery(WidgetRef ref, PrayerDeliveryMode mode)`, `OnboardingPhoneStep`

- [ ] **Step 1: Write the failing test**

Store starts at `phone` with `back: audio`. Prefs store is `MemoryPrayerPrefsStore(PrayerPrefs.defaults)`.

```dart
await tester.tap(find.byKey(const ValueKey('onboarding_phone_adhan')));
await tester.pump();
expect((await prefs.read()).defaultDeliveryMode, PrayerDeliveryMode.adhanPhone);
expect((await store.read()).step, OnboardingStep.prayer);
expect((await store.read()).back, OnboardingStep.phone);
```

Second test taps `onboarding_phone_beep` and expects `PrayerDeliveryMode.beep`. There is no takbir button: `find.text('Takbir di HP')` finds nothing.

Back test: tap `onboarding_back`, expect `step: audio`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/setup/onboarding_phone_step_test.dart`

Expected: FAIL. The phone step does not exist.

- [ ] **Step 3: Write minimal implementation**

Add to `OnboardingController`:

```dart
static Future<void> setDelivery(WidgetRef ref, PrayerDeliveryMode mode) async {
  final store = ref.read(prayerPrefsStoreProvider);
  final current = await store.read();
  await store.write(current.withDefaultDelivery(mode));
  ref.invalidate(prayerPrefsProvider);
}
```

`OnboardingPhoneStep` header back calls `OnboardingController.go(ref, record.back!, back: null)` when `record.back` is non-null. Buttons:

```dart
onPressed: () async {
  await OnboardingController.setDelivery(ref, PrayerDeliveryMode.adhanPhone);
  await OnboardingController.go(
    ref,
    OnboardingStep.prayer,
    back: OnboardingStep.phone,
  );
}
```

The beep button uses `PrayerDeliveryMode.beep` and key `onboarding_phone_beep`.

l10n:

- `onboardingPhoneTitle`: "How should this phone play it?" / "HP ini memutarnya bagaimana?"
- `onboardingPhoneAdhan`: "Adhan on this phone" / "Adzan di HP"
- `onboardingPhoneBeep`: "Beep on this phone" / "Beep di HP"

`OnboardingGate` renders `OnboardingPhoneStep(record: record)` for `OnboardingStep.phone`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/setup/onboarding_phone_step_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/setup/ui/onboarding_phone_step.dart lib/setup/ui/onboarding_gate.dart lib/setup/onboarding_controller.dart lib/l10n test/setup/onboarding_phone_step_test.dart
git commit -m "Save phone adhan or beep during onboarding."
```

---

### Task 5: Speaker step, empty-scan phone fallback, hide battery banner

**Files:**
- Modify: `lib/home_delivery/ui/speaker_setup_page.dart`
- Modify: `lib/setup/ui/onboarding_gate.dart`
- Test: `test/home_delivery/ui/speaker_setup_page_test.dart`
- Test: `test/setup/onboarding_speaker_step_test.dart`

**Interfaces:**
- Consumes: `SpeakerSetupPage`, `OnboardingController.setDelivery`, `OnboardingController.go`
- Produces: `SpeakerSetupPage({bool onboarding = false, VoidCallback? onUsePhoneAudio})`. `onboarding: true` hides `OemBatteryBanner`. `onUsePhoneAudio` shows key `onboarding_use_phone_audio` on the empty scan.

- [ ] **Step 1: Write the failing test**

In `speaker_setup_page_test.dart`, pump with an empty discovery result and:

```dart
SpeakerSetupPage(
  onboarding: true,
  onUsePhoneAudio: () => tappedPhone = true,
)
```

Expect `find.byType(OemBatteryBanner)` finds nothing even when `batteryUnrestrictedProvider` is false. Tap `onboarding_use_phone_audio` and expect `tappedPhone` is true.

`onboarding_speaker_step_test.dart`: store is `speaker` with `back: audio`. A saved speaker provider that returns a receiver after the page reports save is heavy; instead call the gate's advance helper directly in the test by tapping a test-only path:

The gate listens to `savedHomeSpeakerProvider`. Test overrides it to a `FutureProvider` that first returns null, then a `CastReceiver`. On the second emission, delivery becomes `cast` and the step becomes `prayer` with `back: speaker`.

Empty path: the speaker page's phone button is the gate callback:

```dart
onUsePhoneAudio: () => OnboardingController.go(
  ref,
  OnboardingStep.phone,
  back: OnboardingStep.speaker,
),
```

Test that callback by tapping the empty-state button and expecting `step: phone`, `back: speaker`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/setup/onboarding_speaker_step_test.dart`

Expected: FAIL. `SpeakerSetupPage` does not take `onboarding` or `onUsePhoneAudio`.

- [ ] **Step 3: Write minimal implementation**

`SpeakerSetupPage` constructor:

```dart
const SpeakerSetupPage({
  super.key,
  this.onboarding = false,
  this.onUsePhoneAudio,
});

final bool onboarding;
final VoidCallback? onUsePhoneAudio;
```

Where the battery banner is inserted (`if (!batteryUnrestricted)`), also require `!widget.onboarding`.

`_EmptyState` gains `final VoidCallback? onUsePhoneAudio`. When non-null, add a `TextButton` under the retry button:

```dart
TextButton(
  key: const ValueKey('onboarding_use_phone_audio'),
  onPressed: onUsePhoneAudio,
  child: Text(l10n.onboardingUsePhoneAudio),
)
```

l10n: `onboardingUsePhoneAudio`: "Use this phone instead" / "Pakai audio di HP aja".

`OnboardingGate` for `OnboardingStep.speaker` builds `SpeakerSetupPage(onboarding: true, onUsePhoneAudio: ...)`. A `ref.listen` on `savedHomeSpeakerProvider`: when the value changes from null to a saved speaker and the step is `speaker`, call `setDelivery(ref, PrayerDeliveryMode.cast)` then `go(ref, OnboardingStep.prayer, back: OnboardingStep.speaker)`.

Header back on that page, when `onboarding` is true, pops nothing; the gate passes `onBack` by wrapping the page. `SpeakerSetupPage` already has its own back. Add `final VoidCallback? onBack` and use it instead of `Navigator.maybePop` when non-null. The gate passes `onBack` that writes `record.back` (`audio`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/setup/onboarding_speaker_step_test.dart test/home_delivery/ui/speaker_setup_page_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/home_delivery/ui/speaker_setup_page.dart lib/setup/ui/onboarding_gate.dart lib/l10n test/setup/onboarding_speaker_step_test.dart test/home_delivery/ui/speaker_setup_page_test.dart
git commit -m "Continue onboarding from a speaker or from phone audio."
```

---

### Task 6: Prayer times block until configured

**Files:**
- Modify: `lib/setup/ui/onboarding_gate.dart`
- Create: `lib/setup/ui/onboarding_prayer_step.dart`
- Test: `test/setup/onboarding_prayer_step_test.dart`

**Interfaces:**
- Consumes: `PrayerSettingsPage`, `prayerPrefsProvider`
- Produces: `OnboardingPrayerStep`. Opening settings and returning with `configured == false` stays on `prayer`. Returning with `configured == true` writes `notifications` with `back: prayer`.

- [ ] **Step 1: Write the failing test**

Use `PrayerSettingsPage`'s save only if a harness already exists. Otherwise the step exposes key `onboarding_open_prayer` and, on return, reads prefs.

```dart
// Prefs stay unconfigured. Tap open, pop the route, step remains prayer.
await tester.tap(find.byKey(const ValueKey('onboarding_open_prayer')));
await tester.pumpAndSettle();
navigator.pop();
await tester.pump();
expect((await store.read()).step, OnboardingStep.prayer);
```

Second case: `MemoryPrayerPrefsStore` is swapped to `configured: true` before the route pops. Expect `step: notifications`, `back: prayer`.

Back writes `record.back` (`phone` or `speaker`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/setup/onboarding_prayer_step_test.dart`

Expected: FAIL. Prayer step is missing.

- [ ] **Step 3: Write minimal implementation**

`OnboardingPrayerStep` shows the title and one button. The button pushes the existing `PrayerSettingsPage`. After `await Navigator.push`, read `prayerPrefsStoreProvider`. If `configured` is true, `go(notifications, back: prayer)`. If false, stay.

l10n:

- `onboardingPrayerTitle`: "Set prayer times" / "Atur waktu sholat"
- `onboardingPrayerAction`: "Choose city and method" / "Pilih kota dan metode"

Gate renders this widget for `OnboardingStep.prayer`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/setup/onboarding_prayer_step_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/setup/ui/onboarding_prayer_step.dart lib/setup/ui/onboarding_gate.dart lib/l10n test/setup/onboarding_prayer_step_test.dart
git commit -m "Advance onboarding only after prayer times are saved."
```

---

### Task 7: Notification and exact-alarm steps advance when denied

**Files:**
- Create: `lib/setup/ui/onboarding_permission_step.dart`
- Modify: `lib/setup/ui/onboarding_gate.dart`
- Test: `test/setup/onboarding_permission_step_test.dart`

**Interfaces:**
- Consumes: `PostNotificationsPermission`, `ExactAlarmPlatform.requestExactAlarmPermission`
- Produces: `OnboardingPermissionStep({required String title, required String body, required String action, required Future<void> Function() onRequest, required Key actionKey, required VoidCallback onFinished})`

- [ ] **Step 1: Write the failing test**

```dart
var requests = 0;
await tester.pumpWidget(_host(
  step: OnboardingStep.notifications,
  request: () async {
    requests++;
    return false; // denied
  },
));
await tester.tap(find.byKey(const ValueKey('onboarding_notifications_continue')));
await tester.pump();
expect(requests, 1);
expect((await store.read()).step, OnboardingStep.alarm);
expect((await store.read()).back, OnboardingStep.notifications);
```

Alarm test: request throws or returns denied, step becomes `battery`, back is `alarm`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/setup/onboarding_permission_step_test.dart`

Expected: FAIL. Permission step is missing.

- [ ] **Step 3: Write minimal implementation**

`OnboardingPermissionStep` shows title, body, and one button. `onPressed` awaits `onRequest()` inside try/catch, then always calls `onFinished`.

Gate:

- `notifications`: title `l10n.notificationsBlockedTitle`, body `l10n.notificationsBlockedBody`, action `l10n.notificationsBlockedAllow`. The action runs `PostNotificationsPermission().request()` and ignores the bool. `onFinished` writes `alarm` with `back: notifications`.
- `alarm`: title `l10n.exactAlarmTitle`, body `l10n.exactAlarmBody`, action `l10n.exactAlarmOpenSettings`. The action calls `exactAlarm.requestExactAlarmPermission()` when non-null. `onFinished` writes `battery` with `back: alarm`.

Pass `ExactAlarmPlatform?` into `OnboardingGate` from `PrayerCastApp`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/setup/onboarding_permission_step_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/setup/ui/onboarding_permission_step.dart lib/setup/ui/onboarding_gate.dart test/setup/onboarding_permission_step_test.dart
git commit -m "Continue onboarding after each permission prompt."
```

---

### Task 8: Battery skip finishes onboarding and shows home

**Files:**
- Create: `lib/setup/ui/onboarding_battery_step.dart`
- Modify: `lib/setup/ui/onboarding_gate.dart`
- Test: `test/setup/onboarding_battery_step_test.dart`

**Interfaces:**
- Consumes: `oemBatterySettingsProvider.open`, `OnboardingController.go`
- Produces: `OnboardingBatteryStep`. Both `onboarding_battery_open` and `onboarding_battery_skip` write `OnboardingStep.completed` with `back: null`.

- [ ] **Step 1: Write the failing test**

```dart
await tester.tap(find.byKey(const ValueKey('onboarding_battery_skip')));
await tester.pump();
expect((await store.read()).step, OnboardingStep.completed);
expect((await store.read()).back, isNull);
expect(find.text('ADZAN BERIKUTNYA'), findsOneWidget);
```

Open test: a fake `OemBatterySettingsPlatform.open` increments a counter, then the step is `completed` and home is visible.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/setup/onboarding_battery_step_test.dart`

Expected: FAIL. Battery step is missing.

- [ ] **Step 3: Write minimal implementation**

`OnboardingBatteryStep` has the open button and a `TextButton` skip. Both paths:

```dart
Future<void> _finish() async {
  await OnboardingController.go(ref, OnboardingStep.completed);
}
```

Open awaits `ref.read(oemBatterySettingsProvider).open()` then `_finish`. Skip calls `_finish` only.

l10n:

- `onboardingBatteryTitle`: "Keep the adhan on while the phone sleeps" / "Agar adzan tetap jalan saat HP tidur"
- `onboardingBatteryOpen`: "Open battery settings" / "Buka pengaturan baterai"
- `onboardingBatterySkip`: "Not now" / "Nanti"

Gate: `completed` returns the `home` widget passed in. Because this is `MaterialApp.home` and not a pushed route, the system back button leaves the app instead of returning to battery.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/setup/onboarding_battery_step_test.dart test/setup/onboarding_gate_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/setup/ui/onboarding_battery_step.dart lib/setup/ui/onboarding_gate.dart lib/l10n test/setup/onboarding_battery_step_test.dart
git commit -m "Finish onboarding after the battery step."
```

---

### Task 9: Home drops the checklist and shows one permission line

**Files:**
- Modify: `lib/main.dart` (`_HomeHero` banners and the `SetupChecklistCard` sliver)
- Create: `lib/setup/ui/home_permission_line.dart`
- Modify: `test/widget_test.dart`
- Delete: `lib/home_delivery/ui/widgets/setup_checklist_card.dart`
- Delete: `test/home_delivery/ui/setup_checklist_card_test.dart`
- Modify: callers of `setupCardStoreProvider` / `_markRemindersSeen` so the project still analyzes. Delete `lib/setup/setup_card_store.dart` and its boot override when nothing references them.

**Interfaces:**
- Consumes: `postNotificationsGrantedProvider`, `exactAlarmPermissionGrantedProvider`, `batteryUnrestrictedProvider`, `onboardingStepProvider`
- Produces: `HomePermissionLine`. It renders nothing when onboarding is not `completed`. When completed, it renders the first missing item only.

- [ ] **Step 1: Write the failing test**

Add to `test/widget_test.dart` a configured home (`_pumpHomeAtSize` already sets `configured: true`) that overrides notifications to false and exact alarm to false. Expect `find.byKey(const ValueKey('home_permission_recovery'))` finds one widget, and `find.byKey(const ValueKey('exact_alarm_banner'))` finds nothing. The checklist key finds nothing.

Remove `_ExactAlarmPermissionBanner`, `_NotificationPermissionBanner`, and `OemBatteryBanner` from `_HomeHero`. `OemBatteryBanner.bannerKey` is `oem_battery_banner`. The recovery line uses `home_permission_recovery` and is the only permission prompt on home.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL. The checklist is still present or three banners still stack.

- [ ] **Step 3: Write minimal implementation**

Remove the `SetupChecklistCard` sliver and `_markRemindersSeen`.

Replace the three `if` banners in `_HomeHero` with one `HomePermissionLine`. Priority inside that widget:

```dart
if (!notificationsGranted) {
  return _line(l10n.onboardingRecoveryNotifications, onRequestNotifications);
}
if (!canSchedule) {
  return _line(l10n.onboardingRecoveryAlarm, onRequestExactAlarm);
}
if (showBattery) {
  return _line(l10n.onboardingRecoveryBattery, onOpenBatterySettings);
}
return const SizedBox.shrink();
```

`showBattery` keeps today's rule: restricted and (next adhan configured or a speaker is saved).

l10n recovery strings are one short line each, not the old card body.

Delete the checklist widget, its test, and `setup_card_store.dart` after `dart analyze` shows no remaining references. Remove the `setup_card.txt` boot wiring in `main()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart test/setup`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/setup lib/l10n test/widget_test.dart
git add -u lib/home_delivery/ui/widgets/setup_checklist_card.dart test/home_delivery/ui/setup_checklist_card_test.dart lib/setup/setup_card_store.dart
git commit -m "Show one permission line on home after onboarding."
```

---

### Task 10: Spec pointer

**Files:**
- Modify: `docs/superpowers/specs/2026-10-03-qa-enhancements-design.md`

- [ ] **Step 1: Replace section 1's body with a pointer**

Under the heading `## 1. First-run checklist card`, replace the checklist design with:

```markdown
Replaced by `docs/superpowers/specs/2026-10-04-first-run-onboarding-design.md`. Do not build the home checklist card.
```

Leave sections 2–4 (theme, legal, store frames) as they are.

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-10-03-qa-enhancements-design.md docs/superpowers/specs/2026-10-04-first-run-onboarding-design.md docs/superpowers/plans/2026-10-04-first-run-onboarding.md
git commit -m "Point the QA spec at first-run onboarding."
```
