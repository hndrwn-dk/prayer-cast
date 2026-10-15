import 'package:prayer_cast/l10n/app_localizations.dart';

/// One countable dhikr: what to say and how many times.
final class DhikrSpec {
  const DhikrSpec({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.target,
  });

  /// Counter key in [DhikrCounterStore].
  final String id;
  final String arabic;
  final String transliteration;
  final String translation;
  final int target;
}

/// The dhikr offered on the counter page.
abstract final class DhikrCatalog {
  /// Prefix for counters that belong to the after-prayer sequence, so they
  /// never share a count with the free counter of the same phrase.
  static const String afterPrayerPrefix = 'after-prayer:';

  /// Tasbih, tahmid, takbir 33x each, then the tahlil once to complete 100
  /// (HR. Muslim no. 597).
  static List<DhikrSpec> afterPrayer(AppLocalizations l10n) {
    final id = l10n.localeName.startsWith('id');
    return [
      DhikrSpec(
        id: '${afterPrayerPrefix}subhanallah',
        arabic: l10n.dhikrSubhanallahArabic,
        transliteration: 'Subhaanallaah',
        translation: l10n.dhikrSubhanallahTranslation,
        target: 33,
      ),
      DhikrSpec(
        id: '${afterPrayerPrefix}alhamdulillah',
        arabic: l10n.dhikrAlhamdulillahArabic,
        transliteration: 'Alhamdulillaah',
        translation: l10n.dhikrAlhamdulillahTranslation,
        target: 33,
      ),
      DhikrSpec(
        id: '${afterPrayerPrefix}allahu-akbar',
        arabic: l10n.dhikrAllahuAkbarArabic,
        transliteration: 'Allaahu akbar',
        translation: l10n.dhikrAllahuAkbarTranslation,
        target: 33,
      ),
      DhikrSpec(
        id: '${afterPrayerPrefix}tahlil',
        arabic:
            'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
        transliteration:
            "Laa ilaaha illallaahu wahdahuu laa syariika lah, lahul mulku wa lahul hamdu, wa huwa 'alaa kulli syai-in qadiir",
        translation: id
            ? 'Tiada tuhan selain Allah Yang Maha Esa, tidak ada sekutu bagi-Nya, bagi-Nya kerajaan dan bagi-Nya segala pujian, dan Dia Mahakuasa atas segala sesuatu.'
            : 'There is no god but Allah alone, with no partner. His is the dominion and to Him be all praise, and He has power over all things.',
        target: 1,
      ),
    ];
  }

  /// Standalone counters for any time: waiting, walking, commuting.
  /// Ids are unchanged from the first counter page so saved counts survive.
  static List<DhikrSpec> free(AppLocalizations l10n) => [
        DhikrSpec(
          id: 'subhanallah',
          arabic: l10n.dhikrSubhanallahArabic,
          transliteration: l10n.dhikrSubhanallah,
          translation: l10n.dhikrSubhanallahTranslation,
          target: 33,
        ),
        DhikrSpec(
          id: 'alhamdulillah',
          arabic: l10n.dhikrAlhamdulillahArabic,
          transliteration: l10n.dhikrAlhamdulillah,
          translation: l10n.dhikrAlhamdulillahTranslation,
          target: 33,
        ),
        DhikrSpec(
          id: 'allahu-akbar',
          arabic: l10n.dhikrAllahuAkbarArabic,
          transliteration: l10n.dhikrAllahuAkbar,
          translation: l10n.dhikrAllahuAkbarTranslation,
          target: 33,
        ),
        DhikrSpec(
          id: 'astaghfirullah',
          arabic: l10n.dhikrAstaghfirullahArabic,
          transliteration: l10n.dhikrAstaghfirullah,
          translation: l10n.dhikrAstaghfirullahTranslation,
          target: 100,
        ),
        DhikrSpec(
          id: 'subhanallah-wabihamdihi',
          arabic: l10n.dhikrSubhanallahWabihamdihiArabic,
          transliteration: l10n.dhikrSubhanallahWabihamdihi,
          translation: l10n.dhikrSubhanallahWabihamdihiTranslation,
          target: 100,
        ),
        DhikrSpec(
          id: 'subhanallah-wabihamdihi-adzim',
          arabic: l10n.dhikrSubhanallahWabihamdihiAdzimArabic,
          transliteration: l10n.dhikrSubhanallahWabihamdihiAdzim,
          translation: l10n.dhikrSubhanallahWabihamdihiAdzimTranslation,
          target: 100,
        ),
        DhikrSpec(
          id: 'la-ilaha-illallah',
          arabic: l10n.dhikrLaIlahaIllallahArabic,
          transliteration: l10n.dhikrLaIlahaIllallah,
          translation: l10n.dhikrLaIlahaIllallahTranslation,
          target: 100,
        ),
      ];
}
