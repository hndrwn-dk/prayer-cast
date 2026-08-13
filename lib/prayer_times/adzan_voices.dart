/// Bundled adzan voice options (`assets/audio/{id}.mp3` or `.wav`).
final class AdzanVoiceOption {
  const AdzanVoiceOption({
    required this.id,
    required this.displayName,
  });

  final String id;
  final String displayName;
}

/// Catalog of voices shipped in assets.
abstract final class AdzanVoices {
  static const fajr = AdzanVoiceOption(
    id: 'fajr_adhan',
    displayName: 'Fajr adhan',
  );

  static const standard = AdzanVoiceOption(
    id: 'standard_adhan',
    displayName: 'Standard adhan',
  );

  static const makkahTone = AdzanVoiceOption(
    id: 'makkah',
    displayName: 'Test tone',
  );

  static const List<AdzanVoiceOption> all = [
    fajr,
    standard,
    makkahTone,
  ];

  static AdzanVoiceOption? byId(String id) {
    for (final voice in all) {
      if (voice.id == id) return voice;
    }
    return null;
  }

  /// Subuh uses fajr recording; other prayers use standard.
  static String defaultForPrayer(String prayerName) {
    if (prayerName == 'fajr') return fajr.id;
    return standard.id;
  }

  static const AdzanVoiceOption defaultVoice = standard;
}
