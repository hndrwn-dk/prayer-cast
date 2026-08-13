/// Persisted home LAN fingerprint and per-install salt (§3.3).
///
/// WHY: Hashing is not for security — it keeps a readable inventory of the
/// user's home devices out of storage and backups. The salt is per-install so
/// two phones in the same house do not produce identical stored hashes (each
/// still evaluates Jaccard against its own saved set).
///
/// [electionSecret] is different: it is the household-shared HMAC key for
/// election UDP (created at onboarding). Every phone in the home must hold
/// the same value — unlike the per-install fingerprint salt.
abstract interface class FingerprintStore {
  Future<String?> readSalt();

  Future<void> writeSalt(String salt);

  /// Salted-hashed instance ids saved during "Set this as my home".
  Future<Set<String>> readHashes();

  Future<void> writeHashes(Set<String> hashes);

  /// Saved home Cast device id for Signal A (Cast `id` TXT, not friendly name).
  Future<String?> readHomeCastId();

  Future<void> writeHomeCastId(String castId);

  /// Household-shared election HMAC secret (never broadcast in TXT).
  Future<String?> readElectionSecret();

  Future<void> writeElectionSecret(String secret);
}

/// In-memory store for unit tests.
final class MemoryFingerprintStore implements FingerprintStore {
  MemoryFingerprintStore({
    String? salt,
    Set<String>? hashes,
    String? homeCastId,
    String? electionSecret,
  })  : _salt = salt,
        _hashes = hashes == null ? {} : Set<String>.from(hashes),
        _homeCastId = homeCastId,
        _electionSecret = electionSecret;

  String? _salt;
  Set<String> _hashes;
  String? _homeCastId;
  String? _electionSecret;

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
  Future<void> writeHomeCastId(String castId) async => _homeCastId = castId;

  @override
  Future<String?> readElectionSecret() async => _electionSecret;

  @override
  Future<void> writeElectionSecret(String secret) async =>
      _electionSecret = secret;
}
