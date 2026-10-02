# QA Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Testers Community enhancements: Settings legal URLs, a dismissible first-run setup card, Light/Forest/System on every screen, then four captioned Play Store frames.

**Architecture:** Persist setup-card flags and theme choice as small document files next to `app_locale.txt`. Drive `MaterialApp.theme` / `darkTheme` / `themeMode` from that store and stop wrapping routes in `Theme(data: forest())`. Home shows `SetupChecklistCard` until dismissed or required rows complete. Store frames are captured last from the running emulator.

**Tech Stack:** Flutter, Riverpod, `flutter_test`, existing `FileLocaleStore` pattern, `url_launcher`, `flutter gen-l10n`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-10-03-qa-enhancements-design.md`
- Privacy URL must be `https://www.tursinalabs.com/prayercast/privacy`
- Terms URL must be `https://www.tursinalabs.com/prayercast/terms`
- No slide tour, no coach marks
- Do not delete `PrayerCastColors`, `EditorialHairline`, or `cardHairline`
- Forest must look like today when Dark / System-dark
- Default theme is System
- Existing users with `PrayerPrefs.configured == true` never see the setup card
- No emoji in code
- TDD: failing test before production code
- `docs/` is gitignored; `git add -f` any file under `docs/` that must be committed
- After arb edits run `flutter gen-l10n`

## File map

| File | Role |
|------|------|
| `lib/support/app_links.dart` | Privacy + terms constants |
| `lib/support/open_support_url.dart` | `openTermsOfServiceUrl` |
| `lib/l10n/app_en.arb`, `lib/l10n/app_id.arb` | New strings |
| `lib/home_delivery/ui/app_settings_page.dart` | Terms row + theme rows |
| `lib/setup/setup_card_store.dart` | Dismiss / no-speaker / reminders flags |
| `lib/home_delivery/ui/widgets/setup_checklist_card.dart` | Home card UI |
| `lib/main.dart` | Wire stores, card, `themeMode` |
| `lib/prayer_times/ui/prayer_settings_page.dart` | Optional `PrayerSettingsFocus` scroll |
| `lib/theme/app_theme_store.dart` | Persist system/forest/light |
| `lib/home_delivery/ui/theme/prayer_cast_tokens.dart` | Theme-aware colors |
| `docs/play-store-listing.md` | Privacy URL |
| `docs/store/play-screenshot-copy.md` | Overlay copy + capture steps |

---

### Task 1: Legal URLs and Terms row

**Files:**
- Modify: `lib/support/app_links.dart`
- Modify: `lib/support/open_support_url.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_id.arb`
- Modify: `lib/home_delivery/ui/app_settings_page.dart`
- Modify: `docs/play-store-listing.md` (force-add)
- Test: `test/support/open_support_url_test.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: existing `openExternalUrl(BuildContext, String)`
- Produces: `AppLinks.privacyPolicyUrl`, `AppLinks.termsOfServiceUrl`, `openTermsOfServiceUrl(BuildContext)`

- [ ] **Step 1: Write the failing URL test**

Add to `test/support/open_support_url_test.dart`:

```dart
  test('privacy and terms URLs are the tursinalabs.com/prayercast pages', () {
    expect(
      AppLinks.privacyPolicyUrl,
      'https://www.tursinalabs.com/prayercast/privacy',
    );
    expect(
      AppLinks.termsOfServiceUrl,
      'https://www.tursinalabs.com/prayercast/terms',
    );
  });

  testWidgets('openTermsOfServiceUrl launches the terms URL', (tester) async {
    await pumpAndTap(tester, openTermsOfServiceUrl);
    expect(launched, [Uri.parse(AppLinks.termsOfServiceUrl)]);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/support/open_support_url_test.dart`

Expected: FAIL — `termsOfServiceUrl` / `openTermsOfServiceUrl` not defined, or privacy URL still `https://tursinalabs.com/privacy/prayer-cast`.

- [ ] **Step 3: Write minimal implementation**

`lib/support/app_links.dart`:

```dart
  static const String privacyPolicyUrl =
      'https://www.tursinalabs.com/prayercast/privacy';

  static const String termsOfServiceUrl =
      'https://www.tursinalabs.com/prayercast/terms';
```

`lib/support/open_support_url.dart` — add:

```dart
Future<void> openTermsOfServiceUrl(BuildContext context) {
  return openExternalUrl(context, AppLinks.termsOfServiceUrl);
}
```

In `app_en.arb` after `privacyPolicy`:

```json
  "termsOfService": "Terms of Service",
  "termsOfServiceHint": "Rights and rules for using Prayer Cast"
```

In `app_id.arb`:

```json
  "termsOfService": "Ketentuan layanan",
  "termsOfServiceHint": "Hak dan aturan memakai Prayer Cast"
```

Run: `flutter gen-l10n`

On `AppSettingsPage` add:

```dart
  static const ValueKey<String> termsKey = ValueKey<String>('settings_terms');
```

After the Privacy `_SettingsLink`, add a Terms `_SettingsLink` with `termsKey`, `l10n.termsOfService`, `l10n.termsOfServiceHint`, `onTap: () => openTermsOfServiceUrl(context)`.

In `docs/play-store-listing.md` replace every `https://tursinalabs.com/privacy/prayer-cast` with `https://www.tursinalabs.com/prayercast/privacy`.

In `test/widget_test.dart` after the privacy tap, also tap `AppSettingsPage.termsKey` and expect `launched` to include `Uri.parse(AppLinks.termsOfServiceUrl)`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/support/open_support_url_test.dart test/widget_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add -f lib/support/app_links.dart lib/support/open_support_url.dart \
  lib/l10n/app_en.arb lib/l10n/app_id.arb \
  lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart \
  lib/l10n/app_localizations_id.dart \
  lib/home_delivery/ui/app_settings_page.dart \
  docs/play-store-listing.md \
  test/support/open_support_url_test.dart test/widget_test.dart
git commit -m "$(cat <<'EOF'
Point Settings legal links at the prayercast privacy and terms pages.

EOF
)"
```

---

### Task 2: Setup-card flag store

**Files:**
- Create: `lib/setup/setup_card_store.dart`
- Test: `test/setup/setup_card_store_test.dart`

**Interfaces:**
- Consumes: `dart:io` `File` (same as `FileLocaleStore`)
- Produces:

```dart
final class SetupCardFlags {
  const SetupCardFlags({
    this.dismissed = false,
    this.noSpeaker = false,
    this.remindersSeen = false,
    this.existingUserMigrated = false,
  });

  final bool dismissed;
  final bool noSpeaker;
  final bool remindersSeen;
  final bool existingUserMigrated;

  SetupCardFlags copyWith({
    bool? dismissed,
    bool? noSpeaker,
    bool? remindersSeen,
    bool? existingUserMigrated,
  });
}

abstract interface class SetupCardStore {
  Future<SetupCardFlags> read();
  Future<void> write(SetupCardFlags flags);
}

final class FileSetupCardStore implements SetupCardStore {
  FileSetupCardStore(this._file);
  final File _file;
}

final class MemorySetupCardStore implements SetupCardStore {
  MemorySetupCardStore([this._flags = const SetupCardFlags()]);
  SetupCardFlags _flags;
}

final setupCardStoreProvider = Provider<SetupCardStore>((ref) {
  throw UnimplementedError('setupCardStoreProvider must be overridden');
});
```

File format (four lines, `0` or `1`): `dismissed`, `noSpeaker`, `remindersSeen`, `existingUserMigrated`. Missing file → all false.

- [ ] **Step 1: Write the failing store test**

`test/setup/setup_card_store_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/setup/setup_card_store.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('setup_card_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('missing file reads as all-false flags', () async {
    final store = FileSetupCardStore(File('${dir.path}/setup_card.txt'));
    final flags = await store.read();
    expect(flags.dismissed, isFalse);
    expect(flags.noSpeaker, isFalse);
    expect(flags.remindersSeen, isFalse);
    expect(flags.existingUserMigrated, isFalse);
  });

  test('write then read round-trips flags', () async {
    final store = FileSetupCardStore(File('${dir.path}/setup_card.txt'));
    await store.write(
      const SetupCardFlags(
        dismissed: true,
        noSpeaker: true,
        remindersSeen: true,
        existingUserMigrated: true,
      ),
    );
    final flags = await store.read();
    expect(flags.dismissed, isTrue);
    expect(flags.noSpeaker, isTrue);
    expect(flags.remindersSeen, isTrue);
    expect(flags.existingUserMigrated, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/setup/setup_card_store_test.dart`

Expected: FAIL — `setup_card_store.dart` not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/setup/setup_card_store.dart` matching the interfaces above. `FileSetupCardStore.read` returns defaults if the file is missing or unreadable. `write` creates parent dirs and writes four lines.

`MemorySetupCardStore` keeps `_flags` in memory.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/setup/setup_card_store_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/setup/setup_card_store.dart test/setup/setup_card_store_test.dart
git commit -m "$(cat <<'EOF'
Persist first-run setup-card flags next to locale.

EOF
)"
```

---

### Task 3: Setup checklist card on home

**Files:**
- Create: `lib/home_delivery/ui/widgets/setup_checklist_card.dart`
- Modify: `lib/prayer_times/ui/prayer_settings_page.dart` (add `PrayerSettingsFocus`)
- Modify: `lib/main.dart` (`PrayerCastAppForTest` + `_HomeShell` + bootstrap override)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_id.arb`
- Test: `test/home_delivery/ui/setup_checklist_card_test.dart`

**Interfaces:**
- Consumes: `SetupCardStore`, `SetupCardFlags`, `savedHomeSpeakerProvider`, `prayerPrefsProvider`
- Produces:

```dart
enum PrayerSettingsFocus { none, delivery, reminders }

class PrayerSettingsPage extends ConsumerStatefulWidget {
  const PrayerSettingsPage({
    super.key,
    this.coordinator,
    this.focus = PrayerSettingsFocus.none,
    this.onSaved,
  });
  final PrayerSettingsFocus focus;
  final VoidCallback? onSaved;
}

class SetupChecklistCard extends ConsumerWidget {
  const SetupChecklistCard({
    super.key,
    required this.onOpenSpeaker,
    required this.onOpenPrayerTimes,
    required this.onOpenDelivery,
    required this.onOpenReminders,
  });
  static const Key keyName = ValueKey<String>('setup_checklist_card');
  static const Key dismissKey = ValueKey<String>('setup_card_dismiss');
  static const Key speakerKey = ValueKey<String>('setup_card_speaker');
  static const Key noSpeakerKey = ValueKey<String>('setup_card_no_speaker');
  static const Key prayerKey = ValueKey<String>('setup_card_prayer');
  static const Key deliveryKey = ValueKey<String>('setup_card_delivery');
  static const Key remindersKey = ValueKey<String>('setup_card_reminders');
}

bool shouldShowSetupCard({
  required SetupCardFlags flags,
  required bool prayerConfigured,
}) {
  if (flags.dismissed) return false;
  if (!flags.existingUserMigrated && prayerConfigured) return false;
  if (prayerConfigured &&
      (/* speaker saved is checked by the widget */ true)) {
    // Widget hides when configured AND (saved speaker OR noSpeaker).
  }
  return true;
}
```

Visibility (implement in the widget, not only the helper):

1. If `flags.dismissed` → hide.
2. Else if `!flags.existingUserMigrated && prayerConfigured` → `write(flags.copyWith(dismissed: true, existingUserMigrated: true))` and hide.
3. Else if `!flags.existingUserMigrated` → `write(flags.copyWith(existingUserMigrated: true))` then show.
4. Else if `prayerConfigured && (savedSpeaker != null || flags.noSpeaker)` → hide (required rows done). Reminders unticked does not keep the card visible.
5. Else show.

- [ ] **Step 1: Write the failing card tests**

`test/home_delivery/ui/setup_checklist_card_test.dart` — pump a `ProviderScope` with `MemorySetupCardStore`, `MemoryPrayerPrefsStore`, `homeOnboardingProvider` that returns a speaker or null. Use `MaterialApp` + `PrayerCastTheme.forest()` for the card only (this task does not change theme).

Cases:

```dart
testWidgets('hidden when prayer already configured on first read', ...);
testWidgets('shown for unconfigured prefs', ...);
testWidgets('dismiss hides after restart', ...);
testWidgets('Use this phone reveals delivery row', ...);
testWidgets('saved speaker hides delivery row', ...);
```

Assert `find.byKey(SetupChecklistCard.keyName)` and the row keys.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home_delivery/ui/setup_checklist_card_test.dart`

Expected: FAIL — `SetupChecklistCard` not found.

- [ ] **Step 3: Write minimal implementation**

Add arb strings (EN / ID):

- `setupCardTitle`: "Finish setup" / "Selesaikan pengaturan"
- `setupCardDismiss`: "Dismiss" / "Tutup"
- `setupCardSpeaker`: "Home speaker" / "Speaker rumah"
- `setupCardNoSpeaker`: "Use this phone" / "Pakai HP ini"
- `setupCardPrayer`: "Prayer times" / "Waktu sholat"
- `setupCardDelivery`: "Adhan on this phone" / "Adzan di HP ini"
- `setupCardReminders`: "Reminders" / "Pengingat"

Run: `flutter gen-l10n`

Implement `SetupChecklistCard` as a forest banner (same padding/type as `_ExactAlarmPermissionBanner` in `lib/main.dart`): title, Dismiss, four rows with a done tick (`PremiumIcons` check if one exists, else a text "Done").

`PrayerSettingsPage`: add `focus` and `onSaved`. After first layout, if `focus == delivery` call `Scrollable.ensureVisible` on the delivery section key (`ValueKey('delivery-fajr-...')` is per-prayer — add `static const deliverySectionKey = ValueKey('prayer_settings_delivery_section')` around the delivery block, and `remindersSectionKey` around pre-prayer/iqamah). Call `onSaved` after a successful write.

Wire in `main.dart`:

- `FileSetupCardStore(File(p.join(docs.path, 'setup_card.txt')))`
- override `setupCardStoreProvider`
- In `_HomeHero` column, after permission banners and **before** `_NextAdhanJewel`, insert the card when the widget says visible. Spec says below the hero and above the speaker band — place it **after** `_NextAdhanJewel` / `_PlaceAndPresence` and **before** the speaker sliver. Do not put it above the countdown.

`_openPrayerSettings({PrayerSettingsFocus focus = none})` passes `onSaved` that writes `remindersSeen` when `focus == reminders`.

`PrayerCastAppForTest` overrides `setupCardStoreProvider` with `MemorySetupCardStore()`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/home_delivery/ui/setup_checklist_card_test.dart test/widget_test.dart test/prayer_times/ui/prayer_settings_page_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/setup lib/home_delivery/ui/widgets/setup_checklist_card.dart \
  lib/prayer_times/ui/prayer_settings_page.dart lib/main.dart \
  lib/l10n test/home_delivery/ui/setup_checklist_card_test.dart
git commit -m "$(cat <<'EOF'
Add a dismissible first-run setup card on home.

EOF
)"
```

---

### Task 4: Theme store and MaterialApp themeMode

**Files:**
- Create: `lib/theme/app_theme_store.dart`
- Modify: `lib/main.dart` (`PrayerCastApp.build`)
- Test: `test/theme/app_theme_store_test.dart`

**Interfaces:**
- Consumes: `File` next to locale
- Produces:

```dart
enum AppThemeChoice { system, forest, light }

ThemeMode themeModeFor(AppThemeChoice choice) => switch (choice) {
  AppThemeChoice.system => ThemeMode.system,
  AppThemeChoice.forest => ThemeMode.dark,
  AppThemeChoice.light => ThemeMode.light,
};

abstract interface class AppThemeStore {
  Future<AppThemeChoice> read();
  Future<void> write(AppThemeChoice choice);
}

final class FileAppThemeStore implements AppThemeStore { ... }
final class MemoryAppThemeStore implements AppThemeStore { ... }

final appThemeStoreProvider = Provider<AppThemeStore>((ref) {
  throw UnimplementedError('appThemeStoreProvider must be overridden');
});

final appThemeProvider =
    StateNotifierProvider<AppThemeController, AppThemeChoice>((ref) {
  return AppThemeController(ref.watch(appThemeStoreProvider));
});
```

File `app_theme.txt` contains one word: `system`, `forest`, or `light`. Missing file → `system`.

- [ ] **Step 1: Write the failing store test**

`test/theme/app_theme_store_test.dart`:

```dart
test('missing file is system', () async { ... });
test('write forest then read forest', () async { ... });
test('themeModeFor maps forest to ThemeMode.dark', () {
  expect(themeModeFor(AppThemeChoice.forest), ThemeMode.dark);
  expect(themeModeFor(AppThemeChoice.light), ThemeMode.light);
  expect(themeModeFor(AppThemeChoice.system), ThemeMode.system);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/app_theme_store_test.dart`

Expected: FAIL — library not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/theme/app_theme_store.dart` as above (copy `FileLocaleStore` I/O). Wire in `main()`:

```dart
final themeStore = FileAppThemeStore(File(p.join(docs.path, 'app_theme.txt')));
```

Override `appThemeStoreProvider`. In `PrayerCastApp`:

```dart
final themeChoice = ref.watch(appThemeProvider);
return MaterialApp(
  theme: PrayerCastTheme.light(),
  darkTheme: PrayerCastTheme.forest(),
  themeMode: themeModeFor(themeChoice),
  // existing locale + home
);
```

`PrayerCastAppForTest` overrides `appThemeStoreProvider` with `MemoryAppThemeStore()`.

Do **not** remove per-page `Theme(data: forest())` in this task.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/theme/app_theme_store_test.dart test/widget_test.dart`

Expected: PASS (home still looks forest because wrappers remain).

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_theme_store.dart lib/main.dart \
  test/theme/app_theme_store_test.dart
git commit -m "$(cat <<'EOF'
Persist Light, Forest, or System and honor it on MaterialApp.

EOF
)"
```

---

### Task 5: Theme-aware tokens and drop forest wrappers

**Files:**
- Create: `lib/home_delivery/ui/theme/prayer_cast_tokens.dart`
- Modify: `lib/home_delivery/ui/widgets/editorial_chrome.dart`
- Modify: every `Theme(data: PrayerCastTheme.forest())` call site listed below
- Test: `test/home_delivery/ui/theme/prayer_cast_tokens_test.dart`

**Call sites to unwrap** (search `PrayerCastTheme.forest()` and remove the wrapping `Theme` widget; keep `forestSystemUi` / `mistSystemUi` via tokens):

- `lib/home_delivery/ui/app_settings_page.dart`
- `lib/home_delivery/ui/speaker_setup_page.dart`
- `lib/prayer_times/ui/prayer_settings_page.dart`
- `lib/prayer_times/ui/location_disclosure.dart`
- `lib/prayer_times/ui/notification_disclosure.dart`
- `lib/home_delivery/ui/delivery_log_page.dart`
- `lib/prayer_tracker/ui/prayer_tracker_page.dart`
- `lib/prayer_tracker/ui/prayer_tracker_stats_page.dart`
- `lib/qibla/ui/qibla_page.dart`
- `lib/qibla/ui/mosque_map_page.dart`
- `lib/home_delivery/ui/spiritual_benefits_page.dart`
- `lib/main.dart` home `AnnotatedRegion` (use token overlay)

**Interfaces:**
- Consumes: `Theme.of(context).brightness` and `Theme.of(context).colorScheme`
- Produces:

```dart
abstract final class PrayerCastTokens {
  static bool isForest(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context);
  static Color onSurface(BuildContext context);
  static Color hairline(BuildContext context); // dawn on both
  static SystemUiOverlayStyle systemUi(BuildContext context);
}
```

`surface` = `PrayerCastColors.ink` when forest, `PrayerCastColors.surface` when light. `onSurface` = `surfaceRaised` when forest, `ink` when light. `hairline` = `PrayerCastColors.dawn`. `systemUi` = `forestSystemUi` or `mistSystemUi`.

Replace hardcoded `PrayerCastColors.ink` **backgrounds** and `AnnotatedRegion` overlays on those pages with `PrayerCastTokens.surface` / `systemUi`. Do not recolor dawn hairlines to something else. Do not delete `PrayerCastColors`.

- [ ] **Step 1: Write the failing token test**

```dart
testWidgets('forest brightness uses ink surface', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: PrayerCastTheme.light(),
      darkTheme: PrayerCastTheme.forest(),
      themeMode: ThemeMode.dark,
      home: Builder(
        builder: (context) {
          expect(PrayerCastTokens.isForest(context), isTrue);
          expect(PrayerCastTokens.surface(context), PrayerCastColors.ink);
          return const SizedBox();
        },
      ),
    ),
  );
});

testWidgets('light brightness uses mist surface', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: PrayerCastTheme.light(),
      darkTheme: PrayerCastTheme.forest(),
      themeMode: ThemeMode.light,
      home: Builder(
        builder: (context) {
          expect(PrayerCastTokens.isForest(context), isFalse);
          expect(PrayerCastTokens.surface(context), PrayerCastColors.surface);
          return const SizedBox();
        },
      ),
    ),
  );
});
```

Add a widget test that pumps `AppSettingsPage` under `ThemeMode.light` **without** a forest `Theme` wrapper and expects `Theme.of(context).brightness == Brightness.light` from a context inside the page.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home_delivery/ui/theme/prayer_cast_tokens_test.dart`

Expected: FAIL — tokens library missing, or settings page still forces dark.

- [ ] **Step 3: Write minimal implementation**

Add `prayer_cast_tokens.dart`. Unwrap every `Theme(data: PrayerCastTheme.forest(), child: ...)` listed above. Point scaffold / `ColoredBox` backgrounds at `PrayerCastTokens.surface(context)` where they currently use `PrayerCastColors.ink` as a full-screen fill. Home `_HomeHero` `ColoredBox(color: PrayerCastColors.canopyDeep)` becomes canopyDeep in forest and `PrayerCastColors.atmosphere` in light.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/home_delivery/ui/theme/prayer_cast_tokens_test.dart test/widget_test.dart test/home_delivery/ui/setup_checklist_card_test.dart test/prayer_times/ui/prayer_settings_page_test.dart test/qibla/mosque_map_page_test.dart`

Expected: PASS. If a test finds dark-only copy contrast issues, fix tokens on that widget — do not restore a forest `Theme` wrapper.

- [ ] **Step 5: Commit**

```bash
git add lib/home_delivery/ui/theme/prayer_cast_tokens.dart \
  lib/home_delivery/ui lib/prayer_times/ui lib/prayer_tracker/ui \
  lib/qibla/ui lib/main.dart \
  test/home_delivery/ui/theme/prayer_cast_tokens_test.dart
git commit -m "$(cat <<'EOF'
Honor Light and Forest from MaterialApp on every screen.

EOF
)"
```

---

### Task 6: Theme picker in Settings

**Files:**
- Modify: `lib/home_delivery/ui/app_settings_page.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_id.arb`
- Test: `test/widget_test.dart` or `test/home_delivery/ui/app_settings_page_test.dart`

**Interfaces:**
- Consumes: `appThemeProvider`, `AppThemeChoice`
- Produces: Settings keys

```dart
  static const ValueKey<String> themeSystemKey = ValueKey('settings_theme_system');
  static const ValueKey<String> themeForestKey = ValueKey('settings_theme_forest');
  static const ValueKey<String> themeLightKey = ValueKey('settings_theme_light');
```

Reuse `_LanguageChoice` (or a copy `_ThemeChoice`) under a new eyebrow `l10n.themeEyebrow`.

Strings:

- EN: `themeEyebrow` "Theme", `themeHint` "Forest is the current dark look", `themeSystem` "System default", `themeForest` "Forest", `themeLight` "Light"
- ID: `themeEyebrow` "Tema", `themeHint` "Forest adalah tampilan gelap saat ini", `themeSystem` "Ikuti sistem", `themeForest` "Forest", `themeLight` "Terang"

- [ ] **Step 1: Write the failing settings test**

Pump `AppSettingsPage` with `MemoryAppThemeStore(AppThemeChoice.system)`. Tap `themeForestKey`. Expect `store.read()` == `forest` and a descendant `MaterialApp` / `Theme` brightness dark after `pump`. Tap `themeLightKey`. Expect light.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home_delivery/ui/app_settings_theme_test.dart`

Expected: FAIL — keys missing.

- [ ] **Step 3: Write minimal implementation**

Add arb keys, `flutter gen-l10n`, Settings section between Language and Adhan history. `onTap` → `ref.read(appThemeProvider.notifier).setChoice(...)`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/home_delivery/ui/app_settings_theme_test.dart test/widget_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/home_delivery/ui/app_settings_page.dart lib/l10n \
  test/home_delivery/ui/app_settings_theme_test.dart
git commit -m "$(cat <<'EOF'
Add System, Forest, and Light theme choices in Settings.

EOF
)"
```

---

### Task 7: Four Play Store frames

**Files:**
- Create: `docs/store/play-screenshot-copy.md` (force-add)
- Create: `lib/home_delivery/ui/widgets/play_store_caption_bar.dart` (overlay used only when capturing)
- Do not commit large PNGs unless the user asks

**Interfaces:**
- Consumes: installed debug build on `emulator-5554`
- Produces: caption bar widget + written capture recipe

Overlay copy (verbatim):

| File stem | EN | ID |
|-----------|----|----|
| `01-next-adhan` | Adhan at the right time, even when the phone sleeps. | Adzan di waktunya, termasuk saat HP tidur. |
| `02-home-speaker` | Adhan on the speaker at home. | Adzan di speaker rumah. |
| `03-phone-adhan` | No speaker? Play adhan or a beep on the phone. | Tanpa speaker? Adzan atau beep di HP. |
| `04-reminders` | Nudge before azan, and again at iqamah. | Pengingat sebelum azan, dan lagi saat iqamah. |

- [ ] **Step 1: Write the failing caption-bar test**

```dart
testWidgets('caption bar shows the English overlay', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: PlayStoreCaptionBar(text: 'Adhan on the speaker at home.'),
    ),
  );
  expect(find.text('Adhan on the speaker at home.'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home_delivery/ui/play_store_caption_bar_test.dart`

Expected: FAIL — widget missing.

- [ ] **Step 3: Write minimal implementation**

`PlayStoreCaptionBar`: full-width panel, `PrayerCastColors.canopyDeep` (or `PrayerCastTokens.surface` if capturing in Light), dawn `EditorialHairline`, Fraunces 22 / Atkinson 16, 24px padding. Place at the **top** of the capture stack so the nav bar stays clean.

`docs/store/play-screenshot-copy.md` lists the four shots, EN/ID lines, and commands:

```bash
adb -s emulator-5554 exec-out screencap -p > docs/store/play-screenshots/01-next-adhan-en.png
```

Capture after: home with a configured next prayer; speaker band with a name; Prayer settings delivery section; Prayer settings reminders section. Hide the setup card (Dismiss) before shot 1. Status bar: use emulator clean clock if possible. Produce `*-en.png` and `*-id.png` (switch language in Settings between passes).

- [ ] **Step 4: Run the caption test**

Run: `flutter test test/home_delivery/ui/play_store_caption_bar_test.dart`

Expected: PASS

Then tell the user: install the build on `emulator-5554` and capture. Do not start a new emulator.

- [ ] **Step 5: Commit the widget and copy doc, not PNGs**

```bash
git add lib/home_delivery/ui/widgets/play_store_caption_bar.dart \
  test/home_delivery/ui/play_store_caption_bar_test.dart
git add -f docs/store/play-screenshot-copy.md
git commit -m "$(cat <<'EOF'
Add Play Store caption chrome and the four-shot capture recipe.

EOF
)"
```

---

## Self-review

| Spec requirement | Task |
|------------------|------|
| Setup card, dismiss, existing-user skip | 2, 3 |
| Speaker / prayer / no-speaker delivery / reminders rows | 3 |
| Light + Forest + System on every screen | 4, 5, 6 |
| Forest colors and hairlines kept | 5 |
| Privacy + Terms URLs | 1 |
| Four overlay store frames | 7 |
| Screenshots after in-app work | 7 last |
| No slides / coach marks | none added |

No TBD. `AppThemeChoice`, `SetupCardFlags`, `PrayerSettingsFocus`, and URL strings are the same in every task that names them.
