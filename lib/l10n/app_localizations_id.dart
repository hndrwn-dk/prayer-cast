// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Prayer Cast';

  @override
  String get homeEyebrow => 'Beranda';

  @override
  String get homeHeadline => 'Adzan di rumah,\ntepat sekali.';

  @override
  String get homeSubhead =>
      'Diputar ke speaker rumah hanya saat Anda benar-benar di rumah — tanpa akun, tanpa GPS.';

  @override
  String get nextAdhanEyebrow => 'Adzan berikutnya';

  @override
  String nextAdhanHero(String name, String time) {
    return '$name · $time';
  }

  @override
  String get adhanCountdownNow => 'sekarang';

  @override
  String adhanCountdownIn(String clock) {
    return 'dalam $clock';
  }

  @override
  String get homeDetected => 'di rumah';

  @override
  String get notHome => 'tidak di rumah';

  @override
  String get checkingHome => 'memeriksa rumah';

  @override
  String get speakerNotSelected => 'Speaker belum dipilih';

  @override
  String get speakerCardEmpty => 'Belum ada speaker';

  @override
  String speakerNamed(String name) {
    return 'Speaker: $name';
  }

  @override
  String get speakerLoading => 'Speaker…';

  @override
  String get prayerNotConfigured => 'Waktu sholat belum diatur';

  @override
  String get prayerLoading => 'Waktu sholat…';

  @override
  String nextPrayer(String name, String time) {
    return 'Berikutnya: $name $time';
  }

  @override
  String get speakerHome => 'Speaker rumah';

  @override
  String get speakerHomeScanHint => 'Pindai dan pilih speaker Cast';

  @override
  String get speakerHomeChangeHint => 'Ganti speaker rumah';

  @override
  String get changeHomeSpeaker => 'Speaker';

  @override
  String get prayerTimes => 'Waktu sholat';

  @override
  String get prayerTimesHint => 'Kota, metode, dan jadwal hari ini';

  @override
  String get deviceEyebrow => 'Perangkat';

  @override
  String get scheduleEyebrow => 'Jadwal';

  @override
  String get dataOnDeviceOnly => 'Data hanya tersimpan di ponsel Anda.';

  @override
  String get exactAlarmTitle => 'Izin alarm tepat waktu diperlukan';

  @override
  String get exactAlarmBody =>
      'Tanpa izin ini, adzan tidak bisa dijadwalkan saat ponsel tidur.';

  @override
  String get exactAlarmOpenSettings => 'Buka pengaturan alarm';

  @override
  String get language => 'Bahasa';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get languageEnglish => 'English';

  @override
  String get back => 'Kembali';

  @override
  String get save => 'Simpan';

  @override
  String get saving => 'Menyimpan…';

  @override
  String get city => 'Kota';

  @override
  String get country => 'Negara';

  @override
  String get prayerFajr => 'Subuh';

  @override
  String get prayerDhuhr => 'Dzuhur';

  @override
  String get prayerAsr => 'Asar';

  @override
  String get prayerMaghrib => 'Maghrib';

  @override
  String get prayerIsha => 'Isya';

  @override
  String get madhabShafi => 'Madzhab Asar · Syafi’i';

  @override
  String get madhabHanafi => 'Madzhab Asar · Hanafi';

  @override
  String get madhabAsrOnlyHint =>
      'Hanya Asar yang berubah. Asar Hanafi lebih lambat.';

  @override
  String get voiceFajr => 'Adzan Subuh';

  @override
  String get voiceStandard => 'Adzan standar';

  @override
  String get voiceTestTone => 'Nada uji';

  @override
  String get pillGps => 'GPS';

  @override
  String get pillManual => 'manual';

  @override
  String get pillAuto => 'otomatis';

  @override
  String get pillFajrOnly => 'khusus subuh';

  @override
  String get useCurrentLocation => 'Gunakan lokasi saat ini';

  @override
  String get detectingLocation => 'Mendeteksi lokasi…';

  @override
  String get noLocationYet => 'Belum ada lokasi';

  @override
  String get changeCityCountry => 'Ubah kota / negara';

  @override
  String get hideCityForm => 'Sembunyikan form kota';

  @override
  String get calculationMethod => 'Metode perhitungan';

  @override
  String get fetchSchedule => 'Ambil jadwal';

  @override
  String get fetchingSchedule => 'Mengambil jadwal…';

  @override
  String get todaysSchedule => 'Jadwal hari ini';

  @override
  String get scheduleVoiceHint => 'Pilih cara penyampaian tiap waktu, lalu uji';

  @override
  String get scheduleEmptyHint =>
      'Tekan Ambil jadwal atau Gunakan lokasi saat ini.';

  @override
  String morePrayers(int count) {
    return '+ $count waktu lainnya';
  }

  @override
  String get hide => 'Sembunyikan';

  @override
  String locationResolved(String place) {
    return 'Lokasi: $place';
  }

  @override
  String loadFailed(String error) {
    return 'Gagal memuat: $error';
  }

  @override
  String get prayerSaved => 'Waktu sholat disimpan';

  @override
  String saveFailed(String error) {
    return 'Gagal menyimpan: $error';
  }

  @override
  String get needLocationOrCity =>
      'Gunakan lokasi saat ini, atau isi kota dan negara terlebih dahulu';

  @override
  String castSent(String prayer, String voice) {
    return 'Adzan $prayer dikirim ke speaker rumah ($voice).';
  }

  @override
  String get deliveryBeep => 'Beep di HP';

  @override
  String get deliveryAdhanPhone => 'Adzan di HP';

  @override
  String get deliveryCast => 'Cast';

  @override
  String get beepPlayed => 'Beep diputar di HP ini.';

  @override
  String adhanPhonePlayed(String prayer, String voice) {
    return 'Adzan $prayer diputar di HP ini ($voice).';
  }

  @override
  String phonePlayFailed(String error) {
    return 'Gagal memutar di HP ini: $error';
  }

  @override
  String get locationServiceOff =>
      'Layanan lokasi mati. Nyalakan GPS lalu coba lagi.';

  @override
  String get locationDenied =>
      'Izin lokasi ditolak. Izinkan akses lokasi untuk deteksi otomatis.';

  @override
  String get locationDeniedForever =>
      'Izin lokasi diblokir. Buka pengaturan aplikasi dan aktifkan lokasi.';

  @override
  String get castBusy => 'Masih mengirim uji putar sebelumnya…';

  @override
  String get castNoSpeaker => 'Pilih speaker rumah dulu di menu Speaker rumah.';

  @override
  String get castEmptyAudio => 'Audio adzan kosong.';

  @override
  String castMediaRejected(int hits) {
    return 'Speaker menolak media (hits=$hits). Pastikan HP dan speaker satu Wi‑Fi, bukan guest/VPN.';
  }

  @override
  String get castNoFetch =>
      'Speaker tidak mengambil audio dari HP (0 request). Cek Wi‑Fi yang sama, matikan VPN, dan pilih ulang speaker rumah.';

  @override
  String castFailed(String error) {
    return 'Gagal cast ke speaker: $error';
  }

  @override
  String get speakerSetupTitle => 'Speaker rumah';

  @override
  String get speakerSetupIntro =>
      'Kelompokkan speaker di Google Home dulu, lalu pilih grupnya di sini.';

  @override
  String speakersFound(int count) {
    return '$count speaker ditemukan';
  }

  @override
  String get reachableNow => 'dapat dijangkau sekarang';

  @override
  String get scanAgain => 'Pindai ulang';

  @override
  String get scanning => 'Memindai…';

  @override
  String get searchingForSpeakers => 'Mencari speaker…';

  @override
  String get noSpeakersFoundTitle => 'Tidak ada speaker ditemukan';

  @override
  String get noSpeakersFoundGuidance =>
      'Pastikan ponsel dan speaker terhubung ke jaringan Wi‑Fi yang sama';

  @override
  String get speakerScanRetry => 'Coba lagi';

  @override
  String get openLocalNetworkSettings => 'Buka pengaturan';

  @override
  String speakerSaved(String name) {
    return '$name disimpan sebagai speaker rumah';
  }

  @override
  String speakerSaveFailed(String error) {
    return 'Gagal menyimpan speaker: $error';
  }

  @override
  String get speakerNoneFound =>
      'Tidak ada speaker Cast di Wi‑Fi ini. Pastikan speaker Xiaomi / Google Home menyala, terhubung Wi‑Fi yang sama, dan muncul di aplikasi Google Home.';

  @override
  String get speakerOnlyTvsFound =>
      'Hanya TV yang ditemukan — disembunyikan di sini. Kelompokkan speaker di Google Home, atau nyalakan speaker di Wi‑Fi ini.';

  @override
  String speakerScanFailed(String error) {
    return 'Gagal memindai speaker. Pastikan Wi‑Fi aktif dan izin jaringan lokal diizinkan.\n$error';
  }

  @override
  String speakerIpDebug(String address) {
    return 'IP: $address';
  }

  @override
  String get supportOnKofi => 'Dukung di Ko-fi';

  @override
  String get dryRunTitle => 'Uji adzan terjadwal';

  @override
  String get dryRunHint =>
      'Menjalankan jalur alarm yang sama dengan sholat sungguhan (bangun, kehadiran, lalu Cast, beep, atau HP) — bukan tombol uji speaker. Mengganti alarm berikutnya sampai tes berjalan.';

  @override
  String get dryRunIn10Minutes => 'Dalam 10 menit';

  @override
  String get dryRunIn1Hour => 'Dalam 1 jam';

  @override
  String dryRunScheduled(String time) {
    return 'Uji adzan pukul $time';
  }

  @override
  String dryRunFailed(String error) {
    return 'Tidak bisa menjadwalkan uji adzan: $error';
  }
}
