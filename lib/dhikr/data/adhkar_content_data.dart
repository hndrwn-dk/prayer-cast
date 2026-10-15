import 'package:prayer_cast/dhikr/models/adhkar_content.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';

/// Morning and evening adhkar, following the order and counts in
/// Hisnul Muslim (Sa'id al-Qahthani). Items that change wording between
/// morning and evening (ashbahnā / amsainā, "this day" / "this night",
/// an-nusyūr / al-maṣīr) have separate morning and evening entries.
///
/// Translations are paraphrased renderings, not quoted from a published
/// translation. Have a teacher check the text before each release.
abstract final class AdhkarContentData {
  /// Morning adhkar (after Fajr until Dhuhr).
  static List<AdhkarContent> morning(AppLocalizations l10n) {
    final id = _isId(l10n);
    return [
      ..._opening(id),
      AdhkarContent(
        id: 'asbahna',
        arabic:
            'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَٰذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَٰذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ',
        transliteration:
            "Ashbahnaa wa ashbahal mulku lillaah, walhamdu lillaah, laa ilaaha illallaahu wahdahuu laa syariika lah, lahul mulku wa lahul hamdu wa huwa 'alaa kulli syai-in qadiir. Rabbi as-aluka khaira maa fii haadzal yaum, wa khaira maa ba'dah, wa a'uudzu bika min syarri maa fii haadzal yaum, wa syarri maa ba'dah. Rabbi a'uudzu bika minal kasali wa suu-il kibar. Rabbi a'uudzu bika min 'adzaabin fin naari wa 'adzaabin fil qabr.",
        translation: id
            ? 'Kami memasuki pagi dan kerajaan pun milik Allah di pagi ini. Segala puji bagi Allah. Tiada tuhan selain Allah semata, tiada sekutu bagi-Nya; milik-Nya kerajaan dan pujian, dan Dia Mahakuasa atas segala sesuatu. Wahai Rabbku, aku memohon kebaikan hari ini dan sesudahnya, dan aku berlindung kepada-Mu dari keburukan hari ini dan sesudahnya. Wahai Rabbku, aku berlindung kepada-Mu dari kemalasan dan buruknya masa tua. Wahai Rabbku, aku berlindung kepada-Mu dari azab neraka dan azab kubur.'
            : 'We have entered the morning, and the dominion this morning belongs to Allah. All praise is for Allah. There is no god but Allah alone, without partner; His is the dominion and the praise, and He has power over all things. My Lord, I ask You for the good of this day and what follows it, and I seek refuge in You from the evil of this day and what follows it. My Lord, I seek refuge in You from laziness and the misery of old age. My Lord, I seek refuge in You from punishment in the Fire and punishment in the grave.',
        count: 1,
        source: id ? 'HR. Muslim' : 'Muslim',
      ),
      AdhkarContent(
        id: 'bika-asbahna',
        arabic:
            'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ',
        transliteration:
            'Allaahumma bika ashbahnaa, wa bika amsainaa, wa bika nahyaa, wa bika namuutu, wa ilaikan nusyuur.',
        translation: id
            ? 'Ya Allah, dengan-Mu kami memasuki pagi dan dengan-Mu kami memasuki petang, dengan-Mu kami hidup dan dengan-Mu kami mati, dan kepada-Mu kami dibangkitkan.'
            : 'O Allah, by You we enter the morning and by You we enter the evening, by You we live and by You we die, and to You is the resurrection.',
        count: 1,
        source: id ? 'HR. at-Tirmidzi' : 'at-Tirmidhi',
      ),
      ..._middle(id),
      AdhkarContent(
        id: 'adada-khalqihi',
        arabic:
            'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
        transliteration:
            "Subhaanallaahi wa bihamdih, 'adada khalqih, wa ridhaa nafsih, wa zinata 'arsyih, wa midaada kalimaatih.",
        translation: id
            ? 'Maha Suci Allah dan segala puji bagi-Nya, sebanyak jumlah makhluk-Nya, seridha diri-Nya, seberat timbangan Arsy-Nya, dan sebanyak tinta kalimat-Nya.'
            : 'Glory be to Allah and praise be to Him, as many times as the number of His creation, as much as pleases Him, as heavy as His Throne, and as much as the ink of His words.',
        count: 3,
        source: id ? 'HR. Muslim' : 'Muslim',
      ),
      ..._closing(id),
    ];
  }

  /// Evening adhkar (after Asr until Isha).
  static List<AdhkarContent> evening(AppLocalizations l10n) {
    final id = _isId(l10n);
    return [
      ..._opening(id),
      AdhkarContent(
        id: 'amsaina',
        arabic:
            'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ، رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَٰذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَٰذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ',
        transliteration:
            "Amsainaa wa amsal mulku lillaah, walhamdu lillaah, laa ilaaha illallaahu wahdahuu laa syariika lah, lahul mulku wa lahul hamdu wa huwa 'alaa kulli syai-in qadiir. Rabbi as-aluka khaira maa fii haadzihil lailah, wa khaira maa ba'dahaa, wa a'uudzu bika min syarri maa fii haadzihil lailah, wa syarri maa ba'dahaa. Rabbi a'uudzu bika minal kasali wa suu-il kibar. Rabbi a'uudzu bika min 'adzaabin fin naari wa 'adzaabin fil qabr.",
        translation: id
            ? 'Kami memasuki petang dan kerajaan pun milik Allah di petang ini. Segala puji bagi Allah. Tiada tuhan selain Allah semata, tiada sekutu bagi-Nya; milik-Nya kerajaan dan pujian, dan Dia Mahakuasa atas segala sesuatu. Wahai Rabbku, aku memohon kebaikan malam ini dan sesudahnya, dan aku berlindung kepada-Mu dari keburukan malam ini dan sesudahnya. Wahai Rabbku, aku berlindung kepada-Mu dari kemalasan dan buruknya masa tua. Wahai Rabbku, aku berlindung kepada-Mu dari azab neraka dan azab kubur.'
            : 'We have entered the evening, and the dominion this evening belongs to Allah. All praise is for Allah. There is no god but Allah alone, without partner; His is the dominion and the praise, and He has power over all things. My Lord, I ask You for the good of this night and what follows it, and I seek refuge in You from the evil of this night and what follows it. My Lord, I seek refuge in You from laziness and the misery of old age. My Lord, I seek refuge in You from punishment in the Fire and punishment in the grave.',
        count: 1,
        source: id ? 'HR. Muslim' : 'Muslim',
      ),
      AdhkarContent(
        id: 'bika-amsaina',
        arabic:
            'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ',
        transliteration:
            'Allaahumma bika amsainaa, wa bika ashbahnaa, wa bika nahyaa, wa bika namuutu, wa ilaikal mashiir.',
        translation: id
            ? 'Ya Allah, dengan-Mu kami memasuki petang dan dengan-Mu kami memasuki pagi, dengan-Mu kami hidup dan dengan-Mu kami mati, dan kepada-Mu tempat kembali.'
            : 'O Allah, by You we enter the evening and by You we enter the morning, by You we live and by You we die, and to You is the final return.',
        count: 1,
        source: id ? 'HR. at-Tirmidzi' : 'at-Tirmidhi',
      ),
      ..._middle(id),
      AdhkarContent(
        id: 'kalimatillah',
        arabic: 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
        transliteration:
            "A'uudzu bikalimaatillaahit taammaati min syarri maa khalaq.",
        translation: id
            ? 'Aku berlindung dengan kalimat-kalimat Allah yang sempurna dari keburukan makhluk yang Dia ciptakan.'
            : 'I seek refuge in the perfect words of Allah from the evil of what He has created.',
        count: 3,
        source: id ? 'HR. Muslim' : 'Muslim',
      ),
      ..._closing(id),
    ];
  }

  static bool _isId(AppLocalizations l10n) => l10n.localeName.startsWith('id');

  /// Ayat al-Kursi and the three Quls — identical morning and evening.
  static List<AdhkarContent> _opening(bool id) => [
        AdhkarContent(
          id: 'ayat-kursi',
          arabic:
              'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ ۝٢٥٥',
          transliteration:
              "Allaahu laa ilaaha illaa huwal hayyul qayyuum, laa ta'khudzuhuu sinatuw wa laa naum, lahuu maa fis samaawaati wa maa fil ardh, man dzalladzii yasyfa'u 'indahuu illaa bi-idznih, ya'lamu maa baina aidiihim wa maa khalfahum, wa laa yuhiithuuna bisyai-im min 'ilmihii illaa bimaa syaa', wasi'a kursiyyuhus samaawaati wal ardh, wa laa ya-uuduhuu hifzhuhumaa, wa huwal 'aliyyul 'azhiim.",
          translation: id
              ? 'Allah, tidak ada tuhan selain Dia. Yang Maha Hidup, Yang terus menerus mengurus (makhluk-Nya), tidak mengantuk dan tidak tidur. Milik-Nya apa yang ada di langit dan apa yang ada di bumi. Tidak ada yang dapat memberi syafaat di sisi-Nya tanpa izin-Nya. Dia mengetahui apa yang di hadapan mereka dan apa yang di belakang mereka, dan mereka tidak mengetahui sesuatu apa pun dari ilmu-Nya melainkan apa yang Dia kehendaki. Kursi-Nya meliputi langit dan bumi. Dan Dia tidak merasa berat memelihara keduanya, dan Dia Mahatinggi, Mahabesar.'
              : 'Allah - there is no deity except Him, the Ever-Living, the Sustainer of existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.',
          count: 1,
          source: id ? 'QS. Al-Baqarah: 255 · HR. al-Hakim' : 'Al-Baqarah 2:255 · al-Hakim',
        ),
        AdhkarContent(
          id: 'al-ikhlas',
          arabic:
              'قُلْ هُوَ اللَّهُ أَحَدٌ ۝١ اللَّهُ الصَّمَدُ ۝٢ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝٣ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ ۝٤',
          transliteration:
              'Qul huwallaahu ahad. Allaahush shamad. Lam yalid wa lam yuulad. Wa lam yakul lahuu kufuwan ahad.',
          translation: id
              ? 'Katakanlah (Muhammad), "Dialah Allah, Yang Maha Esa. Allah tempat meminta segala sesuatu. (Dia) tidak beranak dan tidak pula diperanakkan. Dan tidak ada sesuatu yang setara dengan Dia."'
              : 'Say, "He is Allah, [who is] One, Allah, the Eternal Refuge. He neither begets nor is born, nor is there to Him any equivalent."',
          count: 3,
          source: id ? 'QS. Al-Ikhlas · HR. Abu Dawud, at-Tirmidzi' : 'Al-Ikhlas · Abu Dawud, at-Tirmidhi',
        ),
        AdhkarContent(
          id: 'al-falaq',
          arabic:
              'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝١ مِن شَرِّ مَا خَلَقَ ۝٢ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝٣ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝٤ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ ۝٥',
          transliteration:
              "Qul a'uudzu birabbil falaq. Min syarri maa khalaq. Wa min syarri ghaasiqin idzaa waqab. Wa min syarrin naffaatsaati fil 'uqad. Wa min syarri haasidin idzaa hasad.",
          translation: id
              ? 'Katakanlah, "Aku berlindung kepada Tuhan Yang Menguasai subuh, dari kejahatan makhluk-Nya, dan dari kejahatan malam apabila telah gelap gulita, dan dari kejahatan (perempuan) tukang sihir yang meniup pada buhul-buhul, dan dari kejahatan pendengki apabila dia dengki."'
              : 'Say, "I seek refuge in the Lord of daybreak from the evil of that which He created and from the evil of darkness when it settles and from the evil of the blowers in knots and from the evil of an envier when he envies."',
          count: 3,
          source: id ? 'QS. Al-Falaq · HR. Abu Dawud, at-Tirmidzi' : 'Al-Falaq · Abu Dawud, at-Tirmidhi',
        ),
        AdhkarContent(
          id: 'an-nas',
          arabic:
              'قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝١ مَلِكِ النَّاسِ ۝٢ إِلَٰهِ النَّاسِ ۝٣ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝٤ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝٥ مِنَ الْجِنَّةِ وَالنَّاسِ ۝٦',
          transliteration:
              "Qul a'uudzu birabbin naas. Malikin naas. Ilaahin naas. Min syarril waswaasil khannaas. Alladzii yuwaswisu fii shuduurin naas. Minal jinnati wan naas.",
          translation: id
              ? 'Katakanlah, "Aku berlindung kepada Tuhan manusia, Raja manusia, Sembahan manusia, dari kejahatan (bisikan) setan yang biasa bersembunyi, yang membisikkan (kejahatan) ke dalam dada manusia, dari (golongan) jin dan manusia."'
              : 'Say, "I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer - who whispers [evil] into the breasts of mankind - from among the jinn and mankind."',
          count: 3,
          source: id ? 'QS. An-Nas · HR. Abu Dawud, at-Tirmidzi' : 'An-Nas · Abu Dawud, at-Tirmidhi',
        ),
      ];

  /// Shared supplications read the same way morning and evening.
  static List<AdhkarContent> _middle(bool id) => [
        AdhkarContent(
          id: 'sayyidul-istighfar',
          arabic:
              'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَىٰ عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
          transliteration:
              "Allaahumma anta rabbii laa ilaaha illaa anta, khalaqtanii wa ana 'abduk, wa ana 'alaa 'ahdika wa wa'dika mastatha'tu, a'uudzu bika min syarri maa shana'tu, abuu-u laka bini'matika 'alayya, wa abuu-u bidzanbii faghfir lii, fa innahuu laa yaghfirudz dzunuuba illaa anta.",
          translation: id
              ? 'Ya Allah, Engkau Rabbku, tiada tuhan selain Engkau. Engkau menciptakanku dan aku hamba-Mu. Aku berada di atas perjanjian dan janji-Mu semampuku. Aku berlindung kepada-Mu dari keburukan perbuatanku. Aku mengakui nikmat-Mu kepadaku dan aku mengakui dosaku, maka ampunilah aku, karena tidak ada yang mengampuni dosa selain Engkau.'
              : 'O Allah, You are my Lord; there is no god but You. You created me and I am Your servant, and I hold to Your covenant and promise as best I can. I seek refuge in You from the evil of what I have done. I acknowledge Your favour upon me and I acknowledge my sin, so forgive me, for none forgives sins but You.',
          count: 1,
          source: id ? 'HR. al-Bukhari' : 'al-Bukhari',
        ),
        AdhkarContent(
          id: 'radhitu',
          arabic:
              'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا',
          transliteration:
              "Radhiitu billaahi rabbaa, wa bil islaami diinaa, wa bi muhammadin shallallaahu 'alaihi wa sallama nabiyyaa.",
          translation: id
              ? 'Aku ridha Allah sebagai Rabb, Islam sebagai agama, dan Muhammad ﷺ sebagai nabi.'
              : 'I am pleased with Allah as Lord, with Islam as religion, and with Muhammad ﷺ as prophet.',
          count: 3,
          source: id ? 'HR. Abu Dawud' : 'Abu Dawud',
        ),
        AdhkarContent(
          id: 'bismillah-la-yadhurru',
          arabic:
              'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ، وَهُوَ السَّمِيعُ الْعَلِيمُ',
          transliteration:
              "Bismillaahilladzii laa yadhurru ma'asmihii syai-un fil ardhi wa laa fis samaa-i, wa huwas samii'ul 'aliim.",
          translation: id
              ? 'Dengan nama Allah, yang bersama nama-Nya tidak ada sesuatu pun di bumi maupun di langit yang dapat membahayakan, dan Dia Maha Mendengar lagi Maha Mengetahui.'
              : 'In the name of Allah, with whose name nothing on earth or in the heavens can cause harm, and He is the All-Hearing, the All-Knowing.',
          count: 3,
          source: id ? 'HR. Abu Dawud, at-Tirmidzi' : 'Abu Dawud, at-Tirmidhi',
        ),
        AdhkarContent(
          id: 'hasbiyallah',
          arabic:
              'حَسْبِيَ اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
          transliteration:
              "Hasbiyallaahu laa ilaaha illaa huw, 'alaihi tawakkaltu, wa huwa rabbul 'arsyil 'azhiim.",
          translation: id
              ? 'Cukuplah Allah bagiku, tiada tuhan selain Dia. Kepada-Nya aku bertawakal, dan Dia Rabb pemilik Arsy yang agung.'
              : 'Allah is sufficient for me; there is no god but Him. In Him I put my trust, and He is the Lord of the Mighty Throne.',
          count: 7,
          source: id ? 'HR. Abu Dawud' : 'Abu Dawud',
        ),
        AdhkarContent(
          id: 'ya-hayyu',
          arabic:
              'يَا حَيُّ يَا قَيُّومُ، بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَىٰ نَفْسِي طَرْفَةَ عَيْنٍ',
          transliteration:
              "Yaa hayyu yaa qayyuum, birahmatika astaghiits, ashlih lii sya'nii kullah, wa laa takilnii ilaa nafsii tharfata 'ain.",
          translation: id
              ? 'Wahai Yang Maha Hidup, wahai Yang terus menerus mengurus makhluk-Nya, dengan rahmat-Mu aku memohon pertolongan. Perbaikilah seluruh urusanku dan jangan Engkau serahkan aku kepada diriku sendiri walau sekejap mata.'
              : 'O Ever-Living, O Sustainer, by Your mercy I seek help. Set right all my affairs, and do not leave me to myself even for the blink of an eye.',
          count: 1,
          source: id ? 'HR. al-Hakim' : 'al-Hakim',
        ),
      ];

  /// The counted tasbih and tahlil that close both sets.
  static List<AdhkarContent> _closing(bool id) => [
        AdhkarContent(
          id: 'subhanallah-wabihamdihi',
          arabic: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
          transliteration: 'Subhaanallaahi wa bihamdih.',
          translation: id
              ? 'Maha Suci Allah dengan segala pujian-Nya.'
              : 'Glory be to Allah and praise be to Him.',
          count: 100,
          source: id ? 'HR. Muslim' : 'Muslim',
        ),
        AdhkarContent(
          id: 'tahlil',
          arabic:
              'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
          transliteration:
              "Laa ilaaha illallaahu wahdahuu laa syariika lah, lahul mulku wa lahul hamdu, wa huwa 'alaa kulli syai-in qadiir.",
          translation: id
              ? 'Tiada tuhan selain Allah Yang Maha Esa, tidak ada sekutu bagi-Nya, bagi-Nya kerajaan dan bagi-Nya segala pujian, dan Dia Mahakuasa atas segala sesuatu.'
              : 'There is no god but Allah alone, with no partner or associate. His is the dominion and to Him be all praise, and He has power over all things.',
          count: 10,
          source: id ? "HR. an-Nasa'i" : "an-Nasa'i",
        ),
      ];
}
