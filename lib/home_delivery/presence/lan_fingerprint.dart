import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../common/logger.dart';
import 'fingerprint_store.dart';
import 'mdns_browser.dart';

/// LAN mDNS fingerprint for Signal B (spec §3.3).
///
/// WHY: Answers "is this the home LAN?" without location permission. Browse
/// the six household service types, salt-hash stable instance ids, and compare
/// with Jaccard similarity against the set saved during onboarding.
final class LanFingerprint {
  LanFingerprint({
    required MdnsBrowser browser,
    required FingerprintStore store,
    HomeDeliveryLogger logger = const SilentLogger(),
    SaltGenerator saltGenerator = const SecureSaltGenerator(),
  })  : _browser = browser,
        _store = store,
        _logger = logger,
        _saltGenerator = saltGenerator;

  /// Service types browsed during capture and evaluation (§3.3).
  static const List<String> serviceTypes = [
    '_googlecast._tcp',
    '_airplay._tcp',
    '_raop._tcp',
    '_hap._tcp',
    '_spotify-connect._tcp',
    '_printer._tcp',
  ];

  /// Browse budget for onboarding capture and evaluation scans (§3.3 / §3.6).
  static const Duration browseBudget = Duration(seconds: 8);

  /// Jaccard threshold for Signal B (§3.3).
  static const double minJaccard = 0.4;

  /// Minimum overlapping hashed entries for Signal B (§3.3).
  static const int minOverlap = 2;

  final MdnsBrowser _browser;
  final FingerprintStore _store;
  final HomeDeliveryLogger _logger;
  final SaltGenerator _saltGenerator;

  /// Onboarding: browse for [browseBudget], persist salt + hashed set.
  Future<CapturedFingerprint> captureHome() async {
    final services = await _browser.browse(
      serviceTypes: serviceTypes,
      budget: browseBudget,
    );
    final salt = await _ensureSalt();
    final hashes = <String>{
      for (final service in services)
        hashInstanceId(salt, service.stableInstanceId),
    };
    await _store.writeHashes(hashes);
    await _ensureElectionSecret();
    _logger.info(
      'Captured home fingerprint (${hashes.length} entries)',
      tag: 'LanFingerprint',
    );
    return CapturedFingerprint(salt: salt, hashes: hashes);
  }

  /// Evaluate current LAN against the saved fingerprint (Signal B).
  Future<FingerprintEvaluation> evaluate({
    Duration budget = browseBudget,
    bool Function(List<DiscoveredService> soFar)? shouldStop,
  }) async {
    final saved = await _store.readHashes();
    if (saved.isEmpty) {
      return const FingerprintEvaluation(
        matched: false,
        jaccard: 0,
        overlap: 0,
        observedHashes: {},
      );
    }
    final salt = await _ensureSalt();
    final services = await _browser.browse(
      serviceTypes: serviceTypes,
      budget: budget,
      shouldStop: shouldStop,
    );
    final observed = <String>{
      for (final service in services)
        hashInstanceId(salt, service.stableInstanceId),
    };
    return evaluateSets(saved: saved, observed: observed);
  }

  /// Pure Jaccard evaluation — used by [evaluate] and unit tests.
  static FingerprintEvaluation evaluateSets({
    required Set<String> saved,
    required Set<String> observed,
  }) {
    if (saved.isEmpty && observed.isEmpty) {
      return const FingerprintEvaluation(
        matched: false,
        jaccard: 0,
        overlap: 0,
        observedHashes: {},
      );
    }
    final overlapSet = saved.intersection(observed);
    final union = saved.union(observed);
    final jaccard = union.isEmpty ? 0.0 : overlapSet.length / union.length;
    final matched = jaccard >= minJaccard && overlapSet.length >= minOverlap;
    return FingerprintEvaluation(
      matched: matched,
      jaccard: jaccard,
      overlap: overlapSet.length,
      observedHashes: Set<String>.from(observed),
    );
  }

  /// `sha256(salt || instanceId)` hex digest (§3.3).
  static String hashInstanceId(String salt, String instanceId) {
    final digest = sha256.convert(utf8.encode('$salt$instanceId'));
    return digest.toString();
  }

  /// 8-hex short hash for peer TXT `fp` (§4.3) / sessionId (§4.5).
  static String shortHash(Set<String> hashes) {
    final material = (hashes.toList()..sort()).join(',');
    final digest = sha256.convert(utf8.encode(material));
    return digest.toString().substring(0, 8);
  }

  /// Household `fp` / session material from the saved Cast id.
  ///
  /// Per-install LAN salts make [shortHash] of hashes differ on every phone,
  /// so PeerRegistry filtered everyone out and SessionId diverged. The Cast
  /// device id is the same on every phone that picked the same speaker.
  static String householdFingerprintShort(String homeCastId) {
    final digest = sha256.convert(utf8.encode('prayer-cast-home|$homeCastId'));
    return digest.toString().substring(0, 8);
  }

  /// Household election HMAC derived from the same Cast id.
  ///
  /// A per-install random secret has no QR/pair path, so CLAIMs failed MAC
  /// on the other phone. Phones that saved the same speaker converge here.
  static String householdElectionSecret(String homeCastId) {
    return sha256
        .convert(utf8.encode('prayer-cast-election|$homeCastId'))
        .toString();
  }

  Future<String> shortHashForHome() async {
    final castId = await _store.readHomeCastId();
    if (castId != null && castId.isNotEmpty) {
      return householdFingerprintShort(castId);
    }
    final hashes = await _store.readHashes();
    if (hashes.isEmpty) return '00000000';
    return shortHash(hashes);
  }

  /// Household-shared election HMAC secret.
  Future<String> electionSecret() => _ensureElectionSecret();

  Future<String> _ensureSalt() async {
    final existing = await _store.readSalt();
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _saltGenerator.generate();
    await _store.writeSalt(created);
    return created;
  }

  Future<String> _ensureElectionSecret() async {
    final castId = await _store.readHomeCastId();
    if (castId != null && castId.isNotEmpty) {
      final derived = householdElectionSecret(castId);
      final existing = await _store.readElectionSecret();
      if (existing != derived) {
        await _store.writeElectionSecret(derived);
      }
      return derived;
    }
    final existing = await _store.readElectionSecret();
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _saltGenerator.generate();
    await _store.writeElectionSecret(created);
    return created;
  }
}

/// Result of an onboarding capture.
final class CapturedFingerprint {
  const CapturedFingerprint({required this.salt, required this.hashes});

  final String salt;
  final Set<String> hashes;
}

/// Result of comparing observed LAN services to the saved fingerprint.
final class FingerprintEvaluation {
  const FingerprintEvaluation({
    required this.matched,
    required this.jaccard,
    required this.overlap,
    required this.observedHashes,
  });

  /// True when J >= 0.4 and overlap >= 2 (§3.3).
  final bool matched;
  final double jaccard;
  final int overlap;
  final Set<String> observedHashes;
}

/// Generates the per-install fingerprint salt.
abstract interface class SaltGenerator {
  String generate();
}

final class SecureSaltGenerator implements SaltGenerator {
  const SecureSaltGenerator();

  @override
  String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
