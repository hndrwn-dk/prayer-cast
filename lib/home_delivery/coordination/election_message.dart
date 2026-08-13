import 'dart:convert';

/// JSON election messages over unicast UDP (spec §4.6).
///
/// WHY: Peers must elect exactly one caster without multicast. Messages are
/// small JSON envelopes addressed unicast to each discovered peer.
sealed class ElectionMessage {
  const ElectionMessage();

  String get type;
  String get sessionId;
  String get deviceId;

  Map<String, Object?> toJson();

  List<int> encode() => utf8.encode(jsonEncode(toJson()));

  static ElectionMessage decode(List<int> bytes) {
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
    return fromJson(map);
  }

  static ElectionMessage fromJson(Map<String, Object?> json) {
    final t = json['t'];
    if (t is! String) {
      throw ElectionProtocolFailure('Missing message type t');
    }
    switch (t) {
      case 'CLAIM':
        return ClaimMessage.fromJson(json);
      case 'LEAD':
        return LeadMessage.fromJson(json);
      case 'PLAYING':
        return PlayingMessage.fromJson(json);
      case 'YIELD':
        return YieldMessage.fromJson(json);
      default:
        throw ElectionProtocolFailure('Unknown election message type: $t');
    }
  }
}

final class ClaimMessage extends ElectionMessage {
  const ClaimMessage({
    required this.sessionId,
    required this.deviceId,
    required this.priority,
    required this.nowEpochMs,
  });

  @override
  String get type => 'CLAIM';

  @override
  final String sessionId;
  @override
  final String deviceId;
  final int priority;

  /// Sender's wall clock, Unix epoch milliseconds (§4.7).
  final int nowEpochMs;

  factory ClaimMessage.fromJson(Map<String, Object?> json) {
    final priority = _reqInt(json, 'pri');
    if (priority < ClaimMessage.minPriority ||
        priority > ClaimMessage.maxPriority) {
      throw ElectionProtocolFailure(
        'CLAIM priority out of range: $priority '
        '(allowed ${ClaimMessage.minPriority}–${ClaimMessage.maxPriority})',
      );
    }
    return ClaimMessage(
      sessionId: _reqString(json, 'sid'),
      deviceId: _reqString(json, 'id'),
      priority: priority,
      nowEpochMs: _reqInt(json, 'now'),
    );
  }

  /// Spec §4.4 priority band — forged CLAIMs with pri outside this are dropped.
  static const int minPriority = 0;
  static const int maxPriority = 100;

  @override
  Map<String, Object?> toJson() => {
        't': type,
        'sid': sessionId,
        'id': deviceId,
        'pri': priority,
        'now': nowEpochMs,
      };
}

final class LeadMessage extends ElectionMessage {
  const LeadMessage({required this.sessionId, required this.deviceId});

  @override
  String get type => 'LEAD';
  @override
  final String sessionId;
  @override
  final String deviceId;

  factory LeadMessage.fromJson(Map<String, Object?> json) => LeadMessage(
        sessionId: _reqString(json, 'sid'),
        deviceId: _reqString(json, 'id'),
      );

  @override
  Map<String, Object?> toJson() => {
        't': type,
        'sid': sessionId,
        'id': deviceId,
      };
}

final class PlayingMessage extends ElectionMessage {
  const PlayingMessage({required this.sessionId, required this.deviceId});

  @override
  String get type => 'PLAYING';
  @override
  final String sessionId;
  @override
  final String deviceId;

  factory PlayingMessage.fromJson(Map<String, Object?> json) => PlayingMessage(
        sessionId: _reqString(json, 'sid'),
        deviceId: _reqString(json, 'id'),
      );

  @override
  Map<String, Object?> toJson() => {
        't': type,
        'sid': sessionId,
        'id': deviceId,
      };
}

final class YieldMessage extends ElectionMessage {
  const YieldMessage({
    required this.sessionId,
    required this.deviceId,
    required this.reason,
  });

  @override
  String get type => 'YIELD';
  @override
  final String sessionId;
  @override
  final String deviceId;
  final String reason;

  factory YieldMessage.fromJson(Map<String, Object?> json) => YieldMessage(
        sessionId: _reqString(json, 'sid'),
        deviceId: _reqString(json, 'id'),
        reason: _reqString(json, 'reason'),
      );

  @override
  Map<String, Object?> toJson() => {
        't': type,
        'sid': sessionId,
        'id': deviceId,
        'reason': reason,
      };
}

/// Peer advertisement state for `_adzan._tcp` TXT `st` (§4.3).
enum PeerAdState {
  idle('idle'),
  claiming('claiming'),
  leading('leading'),
  playing('playing');

  const PeerAdState(this.wire);
  final String wire;

  static PeerAdState fromWire(String value) {
    for (final s in PeerAdState.values) {
      if (s.wire == value) return s;
    }
    throw FormatException('Unknown peer state: $value');
  }
}

/// Typed protocol failure (hard requirement #3).
final class ElectionProtocolFailure implements Exception {
  ElectionProtocolFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ElectionProtocolFailure: $message';
}

String _reqString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw ElectionProtocolFailure('Missing or invalid string field $key');
  }
  return value;
}

int _reqInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw ElectionProtocolFailure('Missing or invalid int field $key');
}
