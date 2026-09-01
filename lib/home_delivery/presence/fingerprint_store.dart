/// Persisted home LAN fingerprint and per-install salt (§3.3).
///
/// WHY: Hashing is not for security — it keeps a readable inventory of the
/// user's home devices out of storage and backups. The salt is per-install so
/// two phones in the same house do not produce identical stored hashes (each
/// still evaluates Jaccard against its own saved set).
///
/// [electionSecret] is the household HMAC key for election UDP. When a home
/// Cast id is saved, it is derived from that id so every phone that picked
/// the same speaker holds the same value — unlike the per-install salt.
abstract interface class FingerprintStore {
  Future<String?> readSalt();

  Future<void> writeSalt(String salt);

  /// Salted-hashed instance ids saved during "Set this as my home".
  Future<Set<String>> readHashes();

  Future<void> writeHashes(Set<String> hashes);

  /// Saved home Cast device id for Signal A (Cast `id` TXT, not friendly name).
  Future<String?> readHomeCastId();

  /// Cast id with backup-file / scan-cache recovery (alarm + UI safe).
  Future<String?> readHomeCastIdResilient();

  Future<void> writeHomeCastId(String castId);

  /// Friendly name for UI only — matching always uses [readHomeCastId].
  Future<String?> readHomeCastFriendlyName();

  Future<void> writeHomeCastFriendlyName(String name);

  /// Household-shared election HMAC secret (never broadcast in TXT).
  Future<String?> readElectionSecret();

  Future<void> writeElectionSecret(String secret);

  /// Compact JSON of the last Speaker Setup scan, or null if never scanned.
  ///
  /// Empty JSON (`{"devices":[]}`) is a real result and must not be treated
  /// as a cache miss — that would rescan on every launch after a genuine empty.
  Future<String?> readLastSpeakerScanJson();

  Future<void> writeLastSpeakerScanJson(String json);
}

/// In-memory store for unit tests.
final class MemoryFingerprintStore implements FingerprintStore {
  MemoryFingerprintStore({
    String? salt,
    Set<String>? hashes,
    String? homeCastId,
    String? homeCastFriendlyName,
    String? electionSecret,
    String? lastSpeakerScanJson,
  }) : _salt = salt,
       _hashes = hashes == null ? {} : Set<String>.from(hashes),
       _homeCastId = homeCastId,
       _homeCastFriendlyName = homeCastFriendlyName,
       _electionSecret = electionSecret,
       _lastSpeakerScanJson = lastSpeakerScanJson;

  String? _salt;
  Set<String> _hashes;
  String? _homeCastId;
  String? _homeCastFriendlyName;
  String? _electionSecret;
  String? _lastSpeakerScanJson;

  @override
  Future<String?> readSalt() async => _salt;

  @override
  Future<void> writeSalt(String salt) async => _salt = salt;

  @override
  Future<Set<String>> readHashes() async => Set<String>.from(_hashes);

  @override
  Future<void> writeHashes(Set<String> hashes) async {
    _hashes = Set<String>.from(hashes);
  }

  @override
  Future<String?> readHomeCastId() async => _homeCastId;

  @override
  Future<String?> readHomeCastIdResilient() async => _homeCastId;

  @override
  Future<void> writeHomeCastId(String castId) async => _homeCastId = castId;

  @override
  Future<String?> readHomeCastFriendlyName() async => _homeCastFriendlyName;

  @override
  Future<void> writeHomeCastFriendlyName(String name) async =>
      _homeCastFriendlyName = name;

  @override
  Future<String?> readElectionSecret() async => _electionSecret;

  @override
  Future<void> writeElectionSecret(String secret) async =>
      _electionSecret = secret;

  @override
  Future<String?> readLastSpeakerScanJson() async => _lastSpeakerScanJson;

  @override
  Future<void> writeLastSpeakerScanJson(String json) async =>
      _lastSpeakerScanJson = json;
}
