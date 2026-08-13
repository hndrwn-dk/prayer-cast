import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Derives the election `sessionId` independently on every peer (§4.5).
///
/// WHY: All devices must agree on *which* adzan they are electing for without
/// negotiating. Anchoring to prayer name + scheduled minute + home fingerprint
/// means two houses never collide, and a one-minute prayer-calc disagreement
/// produces a different sessionId (treated as a bug and logged — §6).
///
/// Formula (spec §4.5):
/// `sha256( prayerName || floor(scheduledEpoch / 60) || homeFingerprintShort )[0:16]`
///
/// Interpretation used here: [scheduledEpochMs] is Unix epoch milliseconds
/// (consistent with `delivery_log.scheduled_at` in §6.1). The minute bucket is
/// therefore `scheduledEpochMs ~/ 60000`, which equals `floor(epochSeconds / 60)`.
/// If the literal `/ 60` against milliseconds was intended, that would not
/// produce minute buckets — raise before changing.
final class SessionId {
  const SessionId._();

  /// Length of the hex prefix kept as the session id (§4.5 `[0:16]`).
  static const int hexLength = 16;

  /// Length of the short home fingerprint embedded in peer TXT `fp` (§4.3).
  static const int fingerprintShortLength = 8;

  /// Derive a 16-char hex session id.
  ///
  /// [prayerName] should be a stable canonical name (e.g. `fajr`, `maghrib`).
  /// [homeFingerprintShort] is the 8-hex-char home fingerprint hash (§4.3 `fp`).
  static String derive({
    required String prayerName,
    required int scheduledEpochMs,
    required String homeFingerprintShort,
  }) {
    if (homeFingerprintShort.length != fingerprintShortLength) {
      throw ArgumentError.value(
        homeFingerprintShort,
        'homeFingerprintShort',
        'Must be $fingerprintShortLength hex characters (spec §4.3 fp)',
      );
    }

    final minuteBucket = scheduledEpochMs ~/ 60000;
    final material = '$prayerName$minuteBucket$homeFingerprintShort';
    final digest = sha256.convert(utf8.encode(material));
    return digest.toString().substring(0, hexLength);
  }
}
