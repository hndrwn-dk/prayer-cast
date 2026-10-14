import 'package:prayer_cast/dhikr/models/adhkar_content.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';

/// Authentic morning and evening adhkar content.
/// Sources: Hisnul Muslim (Fortress of the Muslim), authenticated hadith.
abstract final class AdhkarContentData {
  /// Morning adhkar (after Fajr until Dhuhr).
  static List<AdhkarContent> morning(AppLocalizations l10n) {
    return [
      // Ayat al-Kursi
      AdhkarContent(
        arabic: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
        translation: l10n.localeName.startsWith('id')
            ? 'Allah, tidak ada tuhan selain Dia. Yang Maha Hidup, Yang terus menerus mengurus (makhluk-Nya), tidak mengantuk dan tidak tidur. Milik-Nya apa yang ada di langit dan apa yang ada di bumi. Tidak ada yang dapat memberi syafaat di sisi-Nya tanpa izin-Nya. Dia mengetahui apa yang di hadapan mereka dan apa yang di belakang mereka, dan mereka tidak mengetahui sesuatu apa pun dari ilmu-Nya melainkan apa yang Dia kehendaki. Kursi-Nya meliputi langit dan bumi. Dan Dia tidak merasa berat memelihara keduanya, dan Dia Mahatinggi, Mahabesar.'
            : 'Allah - there is no deity except Him, the Ever-Living, the Sustainer of existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.',
        count: 1,
      ),

      // Surah Al-Ikhlas
      AdhkarContent(
        arabic: 'قُلْ هُوَ اللَّهُ أَحَدٌ * اللَّهُ الصَّمَدُ * لَمْ يَلِدْ وَلَمْ يُولَدْ * وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
        translation: l10n.localeName.startsWith('id')
            ? 'Katakanlah (Muhammad), "Dialah Allah, Yang Maha Esa. Allah tempat meminta segala sesuatu. (Dia) tidak beranak dan tidak pula diperanakkan. Dan tidak ada sesuatu yang setara dengan Dia."'
            : 'Say, "He is Allah, [who is] One, Allah, the Eternal Refuge. He neither begets nor is born, nor is there to Him any equivalent."',
        count: 3,
      ),

      // Surah Al-Falaq
      AdhkarContent(
        arabic: 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ * مِن شَرِّ مَا خَلَقَ * وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ * وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ * وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
        translation: l10n.localeName.startsWith('id')
            ? 'Katakanlah, "Aku berlindung kepada Tuhan Yang Menguasai subuh, dari kejahatan makhluk-Nya, dan dari kejahatan malam apabila telah gelap gulita, dan dari kejahatan (perempuan) tukang sihir yang meniup pada buhul-buhul, dan dari kejahatan pendengki apabila dia dengki."'
            : 'Say, "I seek refuge in the Lord of daybreak from the evil of that which He created and from the evil of darkness when it settles and from the evil of the blowers in knots and from the evil of an envier when he envies."',
        count: 3,
      ),

      // Surah An-Nas
      AdhkarContent(
        arabic: 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ * مَلِكِ النَّاسِ * إِلَٰهِ النَّاسِ * مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ * الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ * مِنَ الْجِنَّةِ وَالنَّاسِ',
        translation: l10n.localeName.startsWith('id')
            ? 'Katakanlah, "Aku berlindung kepada Tuhan manusia, Raja manusia, Sembahan manusia, dari kejahatan (bisikan) setan yang biasa bersembunyi, yang membisikkan (kejahatan) ke dalam dada manusia, dari (golongan) jin dan manusia."'
            : 'Say, "I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer - who whispers [evil] into the breasts of mankind - from among the jinn and mankind."',
        count: 3,
      ),

      // Subhanallah wa bihamdihi
      AdhkarContent(
        arabic: 'سُبْحَانَ اللهِ وَبِحَمْدِهِ',
        translation: l10n.localeName.startsWith('id')
            ? 'Maha Suci Allah dengan segala pujian-Nya'
            : 'Glory be to Allah and praise Him',
        count: 100,
      ),

      // La ilaha illallah wahdahu
      AdhkarContent(
        arabic: 'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
        translation: l10n.localeName.startsWith('id')
            ? 'Tiada tuhan selain Allah Yang Maha Esa, tidak ada sekutu bagi-Nya, bagi-Nya kerajaan dan bagi-Nya segala pujian, dan Dia Mahakuasa atas segala sesuatu'
            : 'There is no god but Allah alone, with no partner or associate. His is the dominion and to Him be all praise, and He has power over all things',
        count: 10,
      ),
    ];
  }

  /// Evening adhkar (after Asr until Isha).
  static List<AdhkarContent> evening(AppLocalizations l10n) {
    return [
      // Ayat al-Kursi
      AdhkarContent(
        arabic: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
        translation: l10n.localeName.startsWith('id')
            ? 'Allah, tidak ada tuhan selain Dia. Yang Maha Hidup, Yang terus menerus mengurus (makhluk-Nya), tidak mengantuk dan tidak tidur. Milik-Nya apa yang ada di langit dan apa yang ada di bumi. Tidak ada yang dapat memberi syafaat di sisi-Nya tanpa izin-Nya. Dia mengetahui apa yang di hadapan mereka dan apa yang di belakang mereka, dan mereka tidak mengetahui sesuatu apa pun dari ilmu-Nya melainkan apa yang Dia kehendaki. Kursi-Nya meliputi langit dan bumi. Dan Dia tidak merasa berat memelihara keduanya, dan Dia Mahatinggi, Mahabesar.'
            : 'Allah - there is no deity except Him, the Ever-Living, the Sustainer of existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.',
        count: 1,
      ),

      // Surah Al-Ikhlas
      AdhkarContent(
        arabic: 'قُلْ هُوَ اللَّهُ أَحَدٌ * اللَّهُ الصَّمَدُ * لَمْ يَلِدْ وَلَمْ يُولَدْ * وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
        translation: l10n.localeName.startsWith('id')
            ? 'Katakanlah (Muhammad), "Dialah Allah, Yang Maha Esa. Allah tempat meminta segala sesuatu. (Dia) tidak beranak dan tidak pula diperanakkan. Dan tidak ada sesuatu yang setara dengan Dia."'
            : 'Say, "He is Allah, [who is] One, Allah, the Eternal Refuge. He neither begets nor is born, nor is there to Him any equivalent."',
        count: 3,
      ),

      // Surah Al-Falaq
      AdhkarContent(
        arabic: 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ * مِن شَرِّ مَا خَلَقَ * وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ * وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ * وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ',
        translation: l10n.localeName.startsWith('id')
            ? 'Katakanlah, "Aku berlindung kepada Tuhan Yang Menguasai subuh, dari kejahatan makhluk-Nya, dan dari kejahatan malam apabila telah gelap gulita, dan dari kejahatan (perempuan) tukang sihir yang meniup pada buhul-buhul, dan dari kejahatan pendengki apabila dia dengki."'
            : 'Say, "I seek refuge in the Lord of daybreak from the evil of that which He created and from the evil of darkness when it settles and from the evil of the blowers in knots and from the evil of an envier when he envies."',
        count: 3,
      ),

      // Surah An-Nas
      AdhkarContent(
        arabic: 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ * مَلِكِ النَّاسِ * إِلَٰهِ النَّاسِ * مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ * الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ * مِنَ الْجِنَّةِ وَالنَّاسِ',
        translation: l10n.localeName.startsWith('id')
            ? 'Katakanlah, "Aku berlindung kepada Tuhan manusia, Raja manusia, Sembahan manusia, dari kejahatan (bisikan) setan yang biasa bersembunyi, yang membisikkan (kejahatan) ke dalam dada manusia, dari (golongan) jin dan manusia."'
            : 'Say, "I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer - who whispers [evil] into the breasts of mankind - from among the jinn and mankind."',
        count: 3,
      ),

      // Tasbih, Tahmid, Takbir
      AdhkarContent(
        arabic: 'سُبْحَانَ اللهِ',
        translation: l10n.localeName.startsWith('id')
            ? 'Maha Suci Allah'
            : 'Glory be to Allah',
        count: 33,
      ),
      AdhkarContent(
        arabic: 'اَلْحَمْدُ لِلَّه',
        translation: l10n.localeName.startsWith('id')
            ? 'Segala puji bagi Allah'
            : 'All praise is due to Allah',
        count: 33,
      ),
      AdhkarContent(
        arabic: 'اَللهُ أَكْبَرُ',
        translation: l10n.localeName.startsWith('id')
            ? 'Allah Maha Besar'
            : 'Allah is the Greatest',
        count: 34,
      ),

      // La ilaha illallah wahdahu
      AdhkarContent(
        arabic: 'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
        translation: l10n.localeName.startsWith('id')
            ? 'Tiada tuhan selain Allah Yang Maha Esa, tidak ada sekutu bagi-Nya, bagi-Nya kerajaan dan bagi-Nya segala pujian, dan Dia Mahakuasa atas segala sesuatu'
            : 'There is no god but Allah alone, with no partner or associate. His is the dominion and to Him be all praise, and He has power over all things',
        count: 10,
      ),
    ];
  }
}
