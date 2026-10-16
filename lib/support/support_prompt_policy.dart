import 'package:prayer_cast/home_delivery/common/clock.dart';

/// Persisted prompt bookkeeping. [baselineCount] is null until the first
/// observation after this feature is installed.
final class SupportPromptState {
  const SupportPromptState({
    this.baselineCount,
    this.completedMilestones = const {},
    this.lastPromptAt,
    this.visibleMilestone,
    this.visibleSince,
    this.lastPurchaseAt,
  });

  final int? baselineCount;
  final Set<int> completedMilestones;
  final DateTime? lastPromptAt;
  final int? visibleMilestone;
  final DateTime? visibleSince;
  final DateTime? lastPurchaseAt;

  SupportPromptState copyWith({
    Object? baselineCount = _keep,
    Set<int>? completedMilestones,
    Object? lastPromptAt = _keep,
    Object? visibleMilestone = _keep,
    Object? visibleSince = _keep,
    Object? lastPurchaseAt = _keep,
  }) {
    return SupportPromptState(
      baselineCount: baselineCount == _keep
          ? this.baselineCount
          : baselineCount as int?,
      completedMilestones: completedMilestones ?? this.completedMilestones,
      lastPromptAt: lastPromptAt == _keep
          ? this.lastPromptAt
          : lastPromptAt as DateTime?,
      visibleMilestone: visibleMilestone == _keep
          ? this.visibleMilestone
          : visibleMilestone as int?,
      visibleSince: visibleSince == _keep
          ? this.visibleSince
          : visibleSince as DateTime?,
      lastPurchaseAt: lastPurchaseAt == _keep
          ? this.lastPurchaseAt
          : lastPurchaseAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() => {
    'baselineCount': baselineCount,
    'completedMilestones': (completedMilestones.toList()..sort()),
    'lastPromptAt': lastPromptAt?.toUtc().toIso8601String(),
    'visibleMilestone': visibleMilestone,
    'visibleSince': visibleSince?.toUtc().toIso8601String(),
    'lastPurchaseAt': lastPurchaseAt?.toUtc().toIso8601String(),
  };

  factory SupportPromptState.fromJson(Map<String, Object?> json) {
    return SupportPromptState(
      baselineCount: _asInt(json['baselineCount']),
      completedMilestones: _milestones(json['completedMilestones']),
      lastPromptAt: _asTime(json['lastPromptAt']),
      visibleMilestone: _asInt(json['visibleMilestone']),
      visibleSince: _asTime(json['visibleSince']),
      lastPurchaseAt: _asTime(json['lastPurchaseAt']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SupportPromptState &&
        other.baselineCount == baselineCount &&
        other.lastPromptAt == lastPromptAt &&
        other.visibleMilestone == visibleMilestone &&
        other.visibleSince == visibleSince &&
        other.lastPurchaseAt == lastPurchaseAt &&
        other.completedMilestones.length == completedMilestones.length &&
        other.completedMilestones.containsAll(completedMilestones);
  }

  @override
  int get hashCode => Object.hash(
    baselineCount,
    lastPromptAt,
    visibleMilestone,
    visibleSince,
    lastPurchaseAt,
    Object.hashAll(completedMilestones.toList()..sort()),
  );
}

final class SupportPromptDecision {
  const SupportPromptDecision({required this.state, required this.showMilestone});

  final SupportPromptState state;

  /// Milestone to show on the home card, or null when the card stays hidden.
  final int? showMilestone;
}

/// When a home-speaker adhan count may surface a support card.
///
/// The clock is injected so tests can move the 30-day, 90-day, and 3-day
/// windows without waiting.
abstract final class SupportPromptPolicy {
  static const milestones = <int>[30, 150, 500];
  static const promptGap = Duration(days: 30);
  static const purchaseQuietPeriod = Duration(days: 90);
  static const cardLifetime = Duration(days: 3);

  static SupportPromptDecision evaluate({
    required int playedCount,
    required SupportPromptState state,
    required Clock clock,
  }) {
    final now = clock.now();
    if (state.baselineCount == null) {
      final completed = {...state.completedMilestones};
      for (final milestone in milestones) {
        if (playedCount >= milestone) completed.add(milestone);
      }
      return SupportPromptDecision(
        state: state.copyWith(
          baselineCount: playedCount,
          completedMilestones: completed,
          visibleMilestone: null,
          visibleSince: null,
        ),
        showMilestone: null,
      );
    }

    var next = state;
    final visible = next.visibleMilestone;
    final since = next.visibleSince;
    if (visible != null && since != null) {
      final expired = !now.isBefore(since.add(cardLifetime));
      final quiet = _within(now, next.lastPurchaseAt, purchaseQuietPeriod);
      if (expired || quiet) {
        next = next.copyWith(
          completedMilestones: {...next.completedMilestones, visible},
          visibleMilestone: null,
          visibleSince: null,
        );
      } else {
        return SupportPromptDecision(state: next, showMilestone: visible);
      }
    }

    if (_within(now, next.lastPurchaseAt, purchaseQuietPeriod)) {
      return SupportPromptDecision(state: next, showMilestone: null);
    }
    if (_within(now, next.lastPromptAt, promptGap)) {
      return SupportPromptDecision(state: next, showMilestone: null);
    }

    int? reached;
    for (final milestone in milestones) {
      if (playedCount >= milestone &&
          !next.completedMilestones.contains(milestone)) {
        reached = milestone;
        break;
      }
    }
    if (reached == null) {
      return SupportPromptDecision(state: next, showMilestone: null);
    }

    next = next.copyWith(
      visibleMilestone: reached,
      visibleSince: now,
      lastPromptAt: now,
    );
    return SupportPromptDecision(state: next, showMilestone: reached);
  }

  static SupportPromptState dismiss(SupportPromptState state) {
    final visible = state.visibleMilestone;
    if (visible == null) return state;
    return state.copyWith(
      completedMilestones: {...state.completedMilestones, visible},
      visibleMilestone: null,
      visibleSince: null,
    );
  }
}

const Object _keep = Object();

bool _within(DateTime now, DateTime? at, Duration window) {
  if (at == null) return false;
  return now.difference(at) < window;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

DateTime? _asTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

Set<int> _milestones(Object? value) {
  if (value is! List) return const {};
  return {
    for (final item in value)
      if (item is int) item,
  };
}
