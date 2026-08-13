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
    Outcome.played: 'Adzan berhasil diputar di speaker rumah.',
    Outcome.suppressedAway:
        'Perangkat tidak di rumah — adzan tidak diputar.',
    Outcome.suppressedNotLeader:
        'Perangkat lain di keluarga yang memutar adzan.',
    Outcome.suppressedAlreadyPlaying:
        'Speaker sudah memutar adzan — duplikat dicegah.',
    Outcome.suppressedUserDnd:
        'Mode tenang / tamu aktif — adzan ditunda.',
    Outcome.failedNoTarget:
        'Speaker tersimpan tidak ditemukan di jaringan rumah.',
    Outcome.failedNoRoute:
        'Tidak ada jalur jaringan ke speaker (VPN atau subnet salah).',
    Outcome.failedCastConnect:
        'Gagal terhubung ke speaker (waktu habis).',
    Outcome.failedLoadMedia:
        'Speaker menolak memuat audio adzan.',
    Outcome.failedAlarmMissed:
        'Alarm terlambat >60 detik — penghemat baterai OEM mungkin memblokir.',
    Outcome.clockSkew:
        'Jam perangkat melenceng — tidak memimpin pemutaran.',
  };

  static const Map<Outcome, String> _en = {
    Outcome.played: 'Adzan played successfully on the home speaker.',
    Outcome.suppressedAway:
        'Device was away from home — adzan was not cast.',
    Outcome.suppressedNotLeader:
        'Another family device led and cast the adzan.',
    Outcome.suppressedAlreadyPlaying:
        'Speaker was already playing adzan — duplicate blocked.',
    Outcome.suppressedUserDnd:
        'Quiet hours / guest mode active — adzan suppressed.',
    Outcome.failedNoTarget:
        'Saved speaker was not found on the home network.',
    Outcome.failedNoRoute:
        'No network route to the speaker (VPN or wrong subnet).',
    Outcome.failedCastConnect:
        'Could not connect to the speaker (timed out).',
    Outcome.failedLoadMedia:
        'Speaker rejected loading the adzan audio.',
    Outcome.failedAlarmMissed:
        'Alarm fired >60s late — OEM battery saver may be blocking.',
    Outcome.clockSkew:
        'Device clock skew detected — did not lead playback.',
  };
}
