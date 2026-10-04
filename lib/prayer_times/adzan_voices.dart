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

  static const fajrMansurAlZahrane = AdzanVoiceOption(
    id: 'fajr_mansur_al_zahrane',
    displayName: 'Mansur Al Zahrane - Fajr',
  );

  static const fajrMisharyRashidAlafasy = AdzanVoiceOption(
    id: 'fajr_mishary_rashid_alafasy',
    displayName: 'Mishary Rashid Alafasy - Fajr',
  );

  static const beep = AdzanVoiceOption(
    id: 'beep',
    displayName: 'Beep',
  );

  static const longBeep = AdzanVoiceOption(
    id: 'long_beep',
    displayName: 'Long beep',
  );

  static const standard = AdzanVoiceOption(
    id: 'standard_adhan',
    displayName: 'Standard adhan',
  );

  static const ahmedAlHaddad = AdzanVoiceOption(
    id: 'ahmed_al_haddad',
    displayName: 'Ahmed Al-Haddad',
  );

  static const misharyRashidAlafasy = AdzanVoiceOption(
    id: 'mishary_rashid_alafasy',
    displayName: 'Mishary Rashid Alafasy',
  );

  static const muhammadRamadanSaad = AdzanVoiceOption(
    id: 'muhammad_ramadan_saad',
    displayName: 'Muhammad Ramadan Saad',
  );

  static const nurdinHamzaAlMaghriby = AdzanVoiceOption(
    id: 'nurdin_hamza_al_maghriby',
    displayName: 'NurDin Hamza Al Maghriby',
  );

  static const aliIbnAhmadMala = AdzanVoiceOption(
    id: 'ali_ibn_ahmad_mala',
    displayName: 'Ali ibn Ahmad Mala',
  );

  /// Subuh: fajr recordings, then short/long beep.
  static const List<AdzanVoiceOption> fajrVoices = [
    fajr,
    fajrMansurAlZahrane,
    fajrMisharyRashidAlafasy,
    beep,
    longBeep,
  ];

  /// Dzuhur / Asar / Maghrib / Isya: non-fajr recordings, then short/long beep.
  static const List<AdzanVoiceOption> standardVoices = [
    standard,
    ahmedAlHaddad,
    misharyRashidAlafasy,
    muhammadRamadanSaad,
    nurdinHamzaAlMaghriby,
    aliIbnAhmadMala,
    beep,
    longBeep,
  ];

  /// Union of every selectable voice (for lookups / tests).
  static const List<AdzanVoiceOption> all = [
    fajr,
    fajrMansurAlZahrane,
    fajrMisharyRashidAlafasy,
    standard,
    ahmedAlHaddad,
    misharyRashidAlafasy,
    muhammadRamadanSaad,
    nurdinHamzaAlMaghriby,
    aliIbnAhmadMala,
    beep,
    longBeep,
  ];

  static List<AdzanVoiceOption> forPrayer(String prayerName) {
    if (prayerName == 'fajr') return fajrVoices;
    return standardVoices;
  }

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

  /// Maps legacy / wrong-slot ids onto a voice that exists for [prayerName].
  static String resolve(String voiceId, {required String prayerName}) {
    final mapped = switch (voiceId) {
      'mishary_rashid_alafasy_fajr' => fajrMisharyRashidAlafasy.id,
      'mansur_al_zahrane' || 'mansur_al_zahrane_fajr' => fajrMansurAlZahrane.id,
      'makkah' => defaultForPrayer(prayerName),
      _ => voiceId,
    };
    final allowed = forPrayer(prayerName);
    for (final voice in allowed) {
      if (voice.id == mapped) return mapped;
    }
    return defaultForPrayer(prayerName);
  }

  static const AdzanVoiceOption defaultVoice = standard;
}
