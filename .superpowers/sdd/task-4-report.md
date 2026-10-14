# Task 4 Report
Implemented `AdhkarContentData.morning/evening` (lib/dhikr/data/adhkar_content_data.dart) and tests (test/dhikr/data/adhkar_content_data_test.dart), content verbatim from brief.
Deviation: brief used `l10n.languageCode`, which doesn't exist on AppLocalizations; used `l10n.localeName.startsWith('id')`.

## TDD
RED: `flutter test test/dhikr/data/adhkar_content_data_test.dart` -> "Undefined name 'AdhkarContentData'" (class absent).
GREEN: same command -> "+6: All tests passed!"; full suite run; `flutter analyze lib/dhikr test/dhikr` clean.

## Files
lib/dhikr/data/adhkar_content_data.dart, test/dhikr/data/adhkar_content_data_test.dart

## Concerns
Content not independently scholar-verified (taken from brief). Morning set is short (no Hisnul Muslim sayyid al-istighfar etc.); morning/evening duplicate Surah text. Tasbih 100x morning and 33/33/34 evening follow brief; no transliteration.

## Fix Report

**Findings addressed:**
- Issue 1: Replaced `*` separators with `۝` in the 6 surah texts (Ikhlas, Falaq, Nas; morning and evening).
- Issue 2: Added an Indonesian locale test that checks translations differ from English.

**Changes:**
- lib/dhikr/data/adhkar_content_data.dart: lines 21, 30, 39, 80, 89, 98
- test/dhikr/data/adhkar_content_data_test.dart: new 'Indonesian locale differs from English' test

**Tests:**
- Command: flutter test test/dhikr/data/adhkar_content_data_test.dart
- Output: +7: All tests passed!

**Commit:** 83254fc fix(dhikr): use verse-end marks in surah text and test id locale
