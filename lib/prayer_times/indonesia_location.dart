/// Sentinel [PrayerPrefs.methodId] for official Kemenag jadwal (not Aladhan).
const int kemenagMethodId = -1;

/// Default Aladhan method for Singapore and other non-Indonesia locations.
const int defaultAladhanMethodId = 11; // MUIS

/// Documented Aladhan method used when Kemenag city-match or HTTP fails.
/// Times are then Aladhan MUIS, never labeled as Kemenag.
const int kemenagAladhanFallbackMethodId = 11;

bool isKemenagMethod(int methodId) => methodId == kemenagMethodId;

/// True when [raw] is Indonesia (ISO, English, or common Indonesian names).
bool isIndonesiaCountry(String raw) {
  final n = _normalizeCountry(raw);
  if (n.isEmpty) return false;
  if (n == 'id' || n == 'idn' || n == 'ri' || n == 'nkri') return true;
  if (n == 'indonesia') return true;
  if (n == 'republik indonesia' || n == 'republic of indonesia') return true;
  if (n == 'republikindonesia') return true;
  return false;
}

/// Auto-select Kemenag when the country *becomes* Indonesia; restore the
/// previous Aladhan method when it leaves. Does not lock a manual Aladhan
/// pick while the country stays Indonesia.
int methodIdForCountryChange({
  required String previousCountry,
  required String nextCountry,
  required int currentMethodId,
  int previousAladhanMethodId = defaultAladhanMethodId,
}) {
  final wasId = isIndonesiaCountry(previousCountry);
  final isId = isIndonesiaCountry(nextCountry);
  if (!wasId && isId) return kemenagMethodId;
  if (wasId && !isId && isKemenagMethod(currentMethodId)) {
    return _aladhanOrDefault(previousAladhanMethodId);
  }
  return currentMethodId;
}

/// GPS / "use current location": Indonesia → Kemenag; leaving Indonesia
/// while still on Kemenag → previous Aladhan method (MUIS 11 by default).
int methodIdForLocationDetect({
  required String country,
  required int currentMethodId,
  int previousAladhanMethodId = defaultAladhanMethodId,
}) {
  if (isIndonesiaCountry(country)) return kemenagMethodId;
  if (isKemenagMethod(currentMethodId)) {
    return _aladhanOrDefault(previousAladhanMethodId);
  }
  return currentMethodId;
}

String scheduleSourceKey(int methodId) =>
    isKemenagMethod(methodId) ? 'kemenag' : 'aladhan';

int _aladhanOrDefault(int methodId) {
  if (isKemenagMethod(methodId)) return defaultAladhanMethodId;
  return methodId;
}

String _normalizeCountry(String raw) {
  final collapsed = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return collapsed
      .replaceAll('.', '')
      .replaceAll(',', '')
      .replaceAll("'", '');
}
