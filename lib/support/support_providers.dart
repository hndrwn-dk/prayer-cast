import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/common/clock.dart';
import 'package:prayer_cast/home_delivery/logging/delivery_log_dao.dart';
import 'package:prayer_cast/home_delivery/ui/delivery_log_providers.dart';
import 'package:prayer_cast/support/support_prompt_policy.dart';
import 'package:prayer_cast/support/support_purchase_service.dart';
import 'package:prayer_cast/support/support_state_store.dart';

final supportStateStoreProvider = Provider<SupportStateStore>((ref) {
  throw UnimplementedError('supportStateStoreProvider must be overridden');
});

final supportPurchaseProvider =
    StateNotifierProvider<SupportPurchaseService, SupportPurchaseState>((ref) {
      throw UnimplementedError('supportPurchaseProvider must be overridden');
    });

/// Home card contents. [milestone] is null when the card is hidden.
final class SupportPromptView {
  const SupportPromptView([this.milestone]);

  final int? milestone;
}

final supportPromptProvider =
    StateNotifierProvider<SupportPromptController, SupportPromptView>((ref) {
      final db = ref.watch(deliveryDatabaseProvider);
      final controller = SupportPromptController(
        store: ref.watch(supportStateStoreProvider),
        playedCounts: DeliveryLogDao(db).watchPlayedCount(),
      );
      return controller;
    });

final class SupportPromptController extends StateNotifier<SupportPromptView> {
  SupportPromptController({
    required SupportStateStore store,
    required Stream<int> playedCounts,
    Clock clock = const SystemClock(),
  }) : _store = store,
       _clock = clock,
       super(const SupportPromptView()) {
    _boot = _store.read().then((state) {
      _persisted = state;
      _ready = true;
    });
    _countsSub = playedCounts.listen(
      (count) {
        _seenCount = true;
        _count = count;
        _schedule();
      },
      onError: (Object _, StackTrace __) {},
    );
    _storeSub = _store.changes.listen((stored) {
      if (stored == _persisted) return;
      _persisted = stored;
      _schedule();
    });
  }

  final SupportStateStore _store;
  final Clock _clock;
  late final Future<void> _boot;
  StreamSubscription<int>? _countsSub;
  StreamSubscription<SupportPromptState>? _storeSub;
  SupportPromptState _persisted = const SupportPromptState();
  int _count = 0;
  bool _seenCount = false;
  bool _ready = false;
  Future<void> _queue = Future<void>.value();

  void _schedule() {
    _queue = _queue.then((_) => _apply());
  }

  Future<void> _apply() async {
    if (!_ready) await _boot;
    if (!mounted || !_seenCount) return;
    final decision = SupportPromptPolicy.evaluate(
      playedCount: _count,
      state: _persisted,
      clock: _clock,
    );
    final changed = decision.state != _persisted;
    _persisted = decision.state;
    final view = SupportPromptView(decision.showMilestone);
    if (state.milestone != view.milestone) state = view;
    if (changed && mounted) await _store.write(_persisted);
  }

  Future<void> dismiss() async {
    if (!_ready) await _boot;
    final next = SupportPromptPolicy.dismiss(_persisted);
    if (next == _persisted) return;
    _persisted = next;
    state = const SupportPromptView();
    await _store.write(next);
  }

  var _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_countsSub?.cancel());
    unawaited(_storeSub?.cancel());
    super.dispose();
  }
}
