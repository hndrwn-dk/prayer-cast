import '../common/clock.dart';
import '../common/logger.dart';
import 'fingerprint_store.dart';
import 'lan_fingerprint.dart';
import 'mdns_browser.dart';
import 'presence_schedule.dart';
import 'presence_state.dart';

/// Presence state machine with mandatory hysteresis (spec §3.4, §3.6).
///
/// WHY: The adzan must not fire when nobody is home, but Cast speakers
/// disappear from mDNS briefly during TV power-off, AP reassociation, and
/// Android Doze Wi-Fi throttling. Two consecutive false scans spanning
/// >= 90s are required before flipping to [PresenceState.away] — a single
/// failed scan must never flip to away.
///
/// Default install uses signals A + B only. Signals C/D are opt-in (§3.5) and
/// are not consulted here (no location permission on the default path).
final class PresenceService {
  PresenceService({
    required MdnsBrowser browser,
    required FingerprintStore store,
    LanFingerprint? lanFingerprint,
    Clock clock = const SystemClock(),
    HomeDeliveryLogger logger = const SilentLogger(),
    this.awayHysteresis = const Duration(seconds: 90),
  })  : _browser = browser,
        _store = store,
        _lanFingerprint = lanFingerprint ??
            LanFingerprint(browser: browser, store: store, logger: logger),
        _clock = clock,
        _logger = logger;

  /// Minimum span between the first and latest consecutive false scans
  /// before transitioning to [PresenceState.away] (§3.4).
  final Duration awayHysteresis;

  final MdnsBrowser _browser;
  final FingerprintStore _store;
  final LanFingerprint _lanFingerprint;
  final Clock _clock;
  final HomeDeliveryLogger _logger;

  PresenceState _state = PresenceState.unknown;
  PresenceSignal _lastSignal = PresenceSignal.none;
  DateTime? _lastResultAt;

  /// Timestamp of the first false scan in the current consecutive streak.
  DateTime? _falseStreakStartedAt;
  int _consecutiveFalseScans = 0;

  PresenceState get state => _state;

  PresenceSignal get lastSignal => _lastSignal;

  DateTime? get lastResultAt => _lastResultAt;

  /// True when there is no cached result, or it is older than 10 minutes.
  bool isCacheStale([DateTime? now]) {
    final resultAt = _lastResultAt;
    if (resultAt == null) return true;
    return !PresenceSchedule.isCacheFresh(resultAt, now ?? _clock.now());
  }

  /// Run one presence scan (Signal A then B) and update the state machine.
  ///
  /// Browse budget is 8 s with early-exit when Signal A matches (§3.6).
  Future<PresenceSnapshot> scan() async {
    final now = _clock.now();
    try {
      final result = await _detect(now: now);
      return _apply(result, now: now);
    } on PresenceBrowseFailure catch (e, st) {
      _logger.warn(
        'Presence browse failed; counting as false scan',
        tag: 'PresenceService',
        error: e,
        stackTrace: st,
      );
      return _apply(
        PresenceScanResult.notDetected(detail: e.message),
        now: now,
      );
    }
  }

  /// Apply an already-computed scan result (unit tests / injected detectors).
  PresenceSnapshot applyScanResult(PresenceScanResult result, {DateTime? now}) {
    return _apply(result, now: now ?? _clock.now());
  }

  Future<PresenceScanResult> _detect({required DateTime now}) async {
    final homeCastId = await _store.readHomeCastIdResilient();

    // Signal A: saved Cast target discoverable. Browse Cast only first so we
    // can early-exit without waiting on the full fingerprint set (§3.6).
    if (homeCastId != null && homeCastId.isNotEmpty) {
      final castServices = await _browser.browse(
        serviceTypes: const ['_googlecast._tcp'],
        budget: LanFingerprint.browseBudget,
        shouldStop: (soFar) => soFar.any((s) => s.txt['id'] == homeCastId),
      );
      final hit = castServices.any((s) => s.txt['id'] == homeCastId);
      if (hit) {
        return PresenceScanResult.detected(signal: PresenceSignal.a);
      }
    }

    // Signal B: LAN fingerprint Jaccard match.
    final evaluation = await _lanFingerprint.evaluate(
      budget: LanFingerprint.browseBudget,
    );
    if (evaluation.matched) {
      return PresenceScanResult.detected(
        signal: PresenceSignal.b,
        detail:
            'jaccard=${evaluation.jaccard.toStringAsFixed(2)} overlap=${evaluation.overlap}',
      );
    }

    return PresenceScanResult.notDetected(
      detail:
          'jaccard=${evaluation.jaccard.toStringAsFixed(2)} overlap=${evaluation.overlap}',
    );
  }

  PresenceSnapshot _apply(PresenceScanResult result, {required DateTime now}) {
    _lastResultAt = now;

    if (result.detected) {
      _consecutiveFalseScans = 0;
      _falseStreakStartedAt = null;
      _state = PresenceState.home;
      _lastSignal = result.signal ?? PresenceSignal.none;
      _logger.info(
        'Presence HOME via signal ${_lastSignal.name}',
        tag: 'PresenceService',
      );
      return PresenceSnapshot(
        state: _state,
        signal: _lastSignal,
        resultAt: now,
        scan: result,
      );
    }

    // False scan — advance hysteresis streak (§3.4).
    _lastSignal = PresenceSignal.none;
    _consecutiveFalseScans += 1;
    _falseStreakStartedAt ??= now;

    final span = now.difference(_falseStreakStartedAt!);
    final canGoAway =
        _consecutiveFalseScans >= 2 && span >= awayHysteresis;

    if (canGoAway) {
      _state = PresenceState.away;
      _logger.info(
        'Presence AWAY after $_consecutiveFalseScans false scans spanning ${span.inSeconds}s',
        tag: 'PresenceService',
      );
    } else {
      // Stay in current state (UNKNOWN or HOME). Never flip on a single miss.
      _logger.debug(
        'False scan #$_consecutiveFalseScans span=${span.inSeconds}s; state=$_state',
        tag: 'PresenceService',
      );
    }

    return PresenceSnapshot(
      state: _state,
      signal: _lastSignal,
      resultAt: now,
      scan: result,
    );
  }
}

/// Outcome of a single scan attempt before state-machine application.
sealed class PresenceScanResult {
  const PresenceScanResult();

  bool get detected;

  PresenceSignal? get signal;

  String? get detail;

  factory PresenceScanResult.detected({
    required PresenceSignal signal,
    String? detail,
  }) = PresenceDetected;

  factory PresenceScanResult.notDetected({String? detail}) =
      PresenceNotDetected;
}

final class PresenceDetected extends PresenceScanResult {
  const PresenceDetected({required this.signal, this.detail});

  @override
  final PresenceSignal signal;

  @override
  final String? detail;

  @override
  bool get detected => true;
}

final class PresenceNotDetected extends PresenceScanResult {
  const PresenceNotDetected({this.detail});

  @override
  final String? detail;

  @override
  bool get detected => false;

  @override
  PresenceSignal? get signal => null;
}

/// Point-in-time view after applying a scan to the state machine.
final class PresenceSnapshot {
  const PresenceSnapshot({
    required this.state,
    required this.signal,
    required this.resultAt,
    required this.scan,
  });

  final PresenceState state;
  final PresenceSignal signal;
  final DateTime resultAt;
  final PresenceScanResult scan;
}
