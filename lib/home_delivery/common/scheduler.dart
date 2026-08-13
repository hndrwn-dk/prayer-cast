import 'dart:async';

import 'clock.dart';

/// Await helpers anchored to a [Clock] (spec hard requirement #4).
///
/// WHY: Elections must sleep until absolute deadlines derived from the
/// scheduled azan epoch. Tests inject [ControllableScheduler] so multi-device
/// timelines complete without wall-clock waits.
abstract interface class Scheduler implements Clock {
  /// Completes when [now] >= [deadline].
  Future<void> waitUntil(DateTime deadline);

  /// Completes when [now] has advanced by [duration] from the call instant.
  Future<void> delay(Duration duration);
}

/// Production scheduler using real wall time.
final class WallScheduler implements Scheduler {
  const WallScheduler();

  @override
  DateTime now() => DateTime.now();

  @override
  Future<void> waitUntil(DateTime deadline) async {
    while (true) {
      final remaining = deadline.difference(now());
      if (remaining <= Duration.zero) return;
      final slice = remaining > const Duration(milliseconds: 50)
          ? const Duration(milliseconds: 50)
          : remaining;
      await Future<void>.delayed(slice);
    }
  }

  @override
  Future<void> delay(Duration duration) => waitUntil(now().add(duration));
}

/// Test scheduler: time advances only when the test calls [advance]/advanceTo].
final class ControllableScheduler implements Scheduler {
  ControllableScheduler(DateTime initial) : _now = initial;

  DateTime _now;
  final List<_Waiter> _waiters = [];

  @override
  DateTime now() => _now;

  @override
  Future<void> waitUntil(DateTime deadline) {
    if (!_now.isBefore(deadline)) {
      return Future<void>.value();
    }
    final waiter = _Waiter(deadline);
    _waiters.add(waiter);
    return waiter.completer.future;
  }

  @override
  Future<void> delay(Duration duration) => waitUntil(_now.add(duration));

  void advance(Duration delta) {
    advanceTo(_now.add(delta));
  }

  void advanceTo(DateTime instant) {
    if (instant.isBefore(_now)) return;
    _now = instant;
    final due = _waiters.where((w) => !_now.isBefore(w.deadline)).toList();
    for (final w in due) {
      _waiters.remove(w);
      if (!w.completer.isCompleted) {
        w.completer.complete();
      }
    }
  }

  /// Advance in steps, flushing microtasks so election loops can run.
  Future<void> pumpUntil(
    DateTime target, {
    Duration step = const Duration(seconds: 1),
  }) async {
    while (_now.isBefore(target)) {
      final next = _now.add(step);
      advanceTo(next.isAfter(target) ? target : next);
      // Several yields so nested async election work can settle.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

final class _Waiter {
  _Waiter(this.deadline);

  final DateTime deadline;
  final Completer<void> completer = Completer<void>();
}
