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

  static const ahmedAlHaddad = AdzanVoiceOption(
    id: 'ahmed_al_haddad',
    displayName: 'Ahmed Al-Haddad',
  );

  static const mansurAlZahrane = AdzanVoiceOption(
    id: 'mansur_al_zahrane',
    displayName: 'Mansur Al Zahrane',
  );

  static const misharyRashidAlafasy = AdzanVoiceOption(
    id: 'mishary_rashid_alafasy',
    displayName: 'Mishary Rashid Alafasy',
  );

  static const misharyRashidAlafasyFajr = AdzanVoiceOption(
    id: 'mishary_rashid_alafasy_fajr',
    displayName: 'Mishary Rashid Alafasy - Fajr',
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

  static const List<AdzanVoiceOption> all = [
    fajr,
    standard,
    ahmedAlHaddad,
    mansurAlZahrane,
    misharyRashidAlafasyFajr,
    misharyRashidAlafasy,
    muhammadRamadanSaad,
    nurdinHamzaAlMaghriby,
    aliIbnAhmadMala,
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
