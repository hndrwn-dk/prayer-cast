/// State for a single dhikr counter.
final class DhikrCounterState {
  DhikrCounterState({
    required this.dhikrId,
    required this.count,
    required this.target,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory DhikrCounterState.fromJson(Map<String, dynamic> json) {
    return DhikrCounterState(
      dhikrId: json['dhikrId'] as String,
      count: json['count'] as int,
      target: json['target'] as int,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  final String dhikrId;
  final int count;
  final int target;
  final DateTime lastUpdated;

  DhikrCounterState increment() => copyWith(
        count: count + 1,
        lastUpdated: DateTime.now(),
      );

  /// Undo one tap. Never goes below zero.
  DhikrCounterState decrement() => copyWith(
        count: count > 0 ? count - 1 : 0,
        lastUpdated: DateTime.now(),
      );

  bool get isComplete => target > 0 && count >= target;

  DhikrCounterState reset() => copyWith(
        count: 0,
        lastUpdated: DateTime.now(),
      );

  DhikrCounterState copyWith({
    int? count,
    int? target,
    DateTime? lastUpdated,
  }) {
    return DhikrCounterState(
      dhikrId: dhikrId,
      count: count ?? this.count,
      target: target ?? this.target,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  double get progress {
    if (target == 0) return 0.0;
    final p = count / target;
    return p > 1.0 ? 1.0 : p;
  }

  Map<String, dynamic> toJson() => {
        'dhikrId': dhikrId,
        'count': count,
        'target': target,
        'lastUpdated': lastUpdated.toIso8601String(),
      };
}
