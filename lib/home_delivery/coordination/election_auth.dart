import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'election_message.dart';

/// HMAC-SHA256 authentication for election UDP messages.
///
/// WHY: sessionId and the UDP port are derivable from public mDNS TXT (`fp`).
/// Without a MAC, any LAN host can forge a high-pri CLAIM + PLAYING and force
/// every household phone into SUPPRESSED_NOT_LEADER. The secret is created at
/// onboarding and must be the same on every phone in the household.
final class ElectionAuth {
  ElectionAuth(this.sharedSecret) {
    if (sharedSecret.isEmpty) {
      throw ArgumentError.value(
        sharedSecret,
        'sharedSecret',
        'Election shared secret must be non-empty',
      );
    }
  }

  /// Onboarding-shared household secret (never placed in TXT / sessionId).
  final String sharedSecret;

  static const String macField = 'mac';

  /// Hex length of the truncated HMAC written on the wire.
  static const int macHexLength = 32;

  List<int> encodeSigned(ElectionMessage message) {
    final body = message.toJson();
    body[macField] = _macHex(body);
    return utf8.encode(jsonEncode(body));
  }

  ElectionMessage decodeVerified(List<int> bytes) {
    final Object? raw;
    try {
      raw = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw ElectionProtocolFailure('Invalid JSON election message', cause: e);
    }
    if (raw is! Map) {
      throw ElectionProtocolFailure('Election message must be a JSON object');
    }
    final map = <String, Object?>{
      for (final entry in raw.entries) entry.key.toString(): entry.value,
    };
    final mac = map.remove(macField);
    if (mac is! String || mac.isEmpty) {
      throw ElectionProtocolFailure('Missing election message MAC');
    }
    final expected = _macHex(map);
    if (!_constantTimeEquals(mac, expected)) {
      throw ElectionProtocolFailure('Invalid election message MAC');
    }
    return ElectionMessage.fromJson(map);
  }

  String _macHex(Map<String, Object?> bodyWithoutMac) {
    final canonical = canonicalPayload(bodyWithoutMac);
    final digest = Hmac(sha256, utf8.encode(sharedSecret))
        .convert(utf8.encode(canonical));
    return digest.toString().substring(0, macHexLength);
  }

  /// Stable signing input: sorted keys, `key=value` joined by `|`.
  static String canonicalPayload(Map<String, Object?> bodyWithoutMac) {
    final keys = bodyWithoutMac.keys.toList()..sort();
    return keys.map((k) => '$k=${bodyWithoutMac[k]}').join('|');
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
