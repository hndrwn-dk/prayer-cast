import 'package:flutter/widgets.dart';

import 'outcome.dart';

/// Plain-language explanations for [Outcome] codes (spec §6.3).
///
/// Primary copy is Bahasa Indonesia (BI). English is the fallback when the
/// active locale is not `id`.
abstract final class OutcomeExplanation {
  /// One-line explanation for [outcome] in [locale] (BI preferred, EN else).
  static String forOutcome(Outcome outcome, Locale locale) {
    if (locale.languageCode == 'id') {
      return _bi[outcome]!;
    }
    return _en[outcome]!;
  }

  /// Bahasa Indonesia copy (always available for tests / explicit BI UI).
  static String bi(Outcome outcome) => _bi[outcome]!;

  /// English copy (always available for tests / explicit EN UI).
  static String en(Outcome outcome) => _en[outcome]!;

  static const Map<Outcome, String> _bi = {
    Outcome.played: 'Adhan berhasil diputar di speaker rumah.',
    Outcome.playedOnPhone: 'Adhan diputar di ponsel.',
    Outcome.playedBeep: 'Bunyi bip diputar di ponsel.',
    Outcome.playedTakbir: 'Takbir diputar di ponsel.',
    Outcome.playedPhoneFallback:
        'Speaker gagal — Adhan/nada diputar di ponsel sebagai cadangan.',
    Outcome.iqamahChime: 'Nada iqamah diputar di ponsel.',
    Outcome.suppressedAway:
        'Perangkat tidak di rumah — adhan tidak diputar.',
    Outcome.suppressedNotLeader:
        'Perangkat lain di keluarga yang memutar adhan.',
    Outcome.suppressedAlreadyPlaying:
        'Speaker sudah memutar adhan — duplikat dicegah.',
    Outcome.suppressedUserDnd:
        'Mode tenang / tamu aktif — adhan ditunda.',
    Outcome.failedNoTarget:
        'Speaker tersimpan tidak ditemukan di jaringan rumah.',
    Outcome.failedNoRoute:
        'Tidak ada jalur jaringan ke speaker (VPN atau subnet salah).',
    Outcome.failedCastConnect:
        'Gagal terhubung ke speaker (waktu habis).',
    Outcome.failedLoadMedia:
        'Speaker menolak memuat audio adhan.',
    Outcome.failedAlarmMissed:
        'Alarm terlambat >60 detik — penghemat baterai OEM mungkin memblokir.',
    Outcome.clockSkew:
        'Jam perangkat melenceng — tidak memimpin pemutaran.',
    Outcome.failedReschedule:
        'Gagal menjadwalkan adhan berikutnya — mungkin perlu ulang.',
    Outcome.rescheduleRetryArmed:
        'Waktu 15 detik dijadwalkan untuk mencoba lagi.',
  };

  static const Map<Outcome, String> _en = {
    Outcome.played: 'Adhan played successfully on the home speaker.',
    Outcome.playedOnPhone: 'Adhan played on this phone.',
    Outcome.playedBeep: 'Beep played on this phone.',
    Outcome.playedTakbir: 'Takbir played on this phone.',
    Outcome.playedPhoneFallback:
        'Speaker unavailable — played on this phone instead.',
    Outcome.iqamahChime: 'Iqamah chime played on this phone.',
    Outcome.suppressedAway:
        'Device was away from home — Adhan was not cast.',
    Outcome.suppressedNotLeader:
        'Another family device led and cast the Adhan.',
    Outcome.suppressedAlreadyPlaying:
        'Speaker was already playing Adhan — duplicate blocked.',
    Outcome.suppressedUserDnd:
        'Quiet hours / guest mode active — Adhan suppressed.',
    Outcome.failedNoTarget:
        'Saved speaker was not found on the home network.',
    Outcome.failedNoRoute:
        'No network route to the speaker (VPN or wrong subnet).',
    Outcome.failedCastConnect:
        'Could not connect to the speaker (timed out).',
    Outcome.failedLoadMedia:
        'Speaker rejected loading the Adhan audio.',
    Outcome.failedAlarmMissed:
        'Alarm fired >60s late — OEM battery saver may be blocking.',
    Outcome.clockSkew:
        'Device clock skew detected — did not lead playback.',
    Outcome.failedReschedule:
        'Failed to schedule next Adhan — may need retry.',
    Outcome.rescheduleRetryArmed:
        '15-second retry wake scheduled.',
  };
}
