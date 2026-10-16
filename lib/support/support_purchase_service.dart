import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:prayer_cast/home_delivery/common/clock.dart';
import 'package:prayer_cast/support/purchase_quantity.dart';
import 'package:prayer_cast/support/support_billing.dart';
import 'package:prayer_cast/support/support_products.dart';
import 'package:prayer_cast/support/support_state_store.dart';

enum SupportCatalog { empty, loading, ready, unavailable }

enum SupportActivity { idle, pending, thanks }

enum SupportDismiss { none, quiet, error }

final class SupportPurchaseState {
  const SupportPurchaseState({
    this.catalog = SupportCatalog.empty,
    this.products = const {},
    this.activity = SupportActivity.idle,
    this.thanksProductId,
    this.thanksQuantity = 1,
    this.dismiss = SupportDismiss.none,
    this.dismissNonce = 0,
    this.submitting = false,
  });

  final SupportCatalog catalog;
  final Map<String, ProductDetails> products;
  final SupportActivity activity;
  final String? thanksProductId;
  final int thanksQuantity;
  final SupportDismiss dismiss;
  final int dismissNonce;
  final bool submitting;

  bool get cacheComplete =>
      SupportProducts.ordered.every(products.containsKey);

  SupportPurchaseState copyWith({
    SupportCatalog? catalog,
    Map<String, ProductDetails>? products,
    SupportActivity? activity,
    Object? thanksProductId = _keep,
    int? thanksQuantity,
    SupportDismiss? dismiss,
    int? dismissNonce,
    bool? submitting,
  }) {
    return SupportPurchaseState(
      catalog: catalog ?? this.catalog,
      products: products ?? this.products,
      activity: activity ?? this.activity,
      thanksProductId: identical(thanksProductId, _keep)
          ? this.thanksProductId
          : thanksProductId as String?,
      thanksQuantity: thanksQuantity ?? this.thanksQuantity,
      dismiss: dismiss ?? this.dismiss,
      dismissNonce: dismissNonce ?? this.dismissNonce,
      submitting: submitting ?? this.submitting,
    );
  }
}

const Object _keep = Object();

/// Listens to Play Billing for the life of the process and caches product
/// details. [prepare] is cache-first: a full cache never passes through
/// [SupportCatalog.loading], and pending or thanks never return to loading.
final class SupportPurchaseService extends StateNotifier<SupportPurchaseState> {
  SupportPurchaseService({
    required SupportBilling billing,
    SupportStateStore? store,
    Clock clock = const SystemClock(),
  }) : _billing = billing,
       _store = store,
       _clock = clock,
       super(const SupportPurchaseState());

  final SupportBilling _billing;
  final Clock _clock;
  SupportStateStore? _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _started = false;
  DateTime? _pendingPurchaseAt;

  void attachStore(SupportStateStore store) {
    _store = store;
    final pending = _pendingPurchaseAt;
    if (pending == null) return;
    _pendingPurchaseAt = null;
    unawaited(store.recordPurchase(pending));
  }

  /// Subscribes first, then prefetches once. Failures leave the cache empty.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _subscription = _billing.purchaseStream.listen(
        (purchases) {
          unawaited(_onPurchases(purchases));
        },
        onError: (Object _, StackTrace __) {},
      );
    } catch (_) {}
    await _prefetch();
  }

  /// Called when the support sheet opens.
  void onSheetOpened() {
    if (state.activity == SupportActivity.thanks) {
      state = state.copyWith(
        activity: SupportActivity.idle,
        thanksProductId: null,
        thanksQuantity: 1,
      );
    }
    if (state.dismiss != SupportDismiss.none) {
      state = state.copyWith(dismiss: SupportDismiss.none);
    }
    unawaited(prepare());
  }

  Future<void> prepare() async {
    if (state.cacheComplete || !_catalogMayLoad) {
      if (_catalogMayLoad && state.catalog != SupportCatalog.ready) {
        state = state.copyWith(catalog: SupportCatalog.ready);
      }
      unawaited(_refresh(surfaceFailure: false));
      return;
    }
    state = state.copyWith(catalog: SupportCatalog.loading);
    await _refresh(surfaceFailure: true);
  }

  Future<void> buy(ProductDetails product) async {
    if (state.submitting) return;
    state = state.copyWith(submitting: true);
    try {
      final started = await _billing.buyConsumable(product: product);
      if (!mounted) return;
      if (!started) {
        _dismiss(SupportDismiss.error);
      }
    } catch (_) {
      _dismiss(SupportDismiss.error);
    }
  }

  bool get _catalogMayLoad =>
      state.activity != SupportActivity.pending &&
      state.activity != SupportActivity.thanks;

  Future<void> _prefetch() async {
    try {
      await _refresh(surfaceFailure: false);
    } catch (_) {}
  }

  Future<void> _refresh({required bool surfaceFailure}) async {
    try {
      final available = await _billing.isAvailable();
      if (!mounted) return;
      if (!available) {
        _fail(surfaceFailure: surfaceFailure);
        return;
      }
      final response = await _billing.queryProductDetails(SupportProducts.ids);
      if (!mounted) return;
      if (response.error != null) {
        _fail(surfaceFailure: surfaceFailure);
        return;
      }
      final next = Map<String, ProductDetails>.of(state.products);
      for (final product in response.productDetails) {
        if (SupportProducts.ids.contains(product.id)) {
          next[product.id] = product;
        }
      }
      final complete = SupportProducts.ordered.every(next.containsKey);
      if (!complete) {
        state = state.copyWith(products: next);
        _fail(surfaceFailure: surfaceFailure);
        return;
      }
      state = state.copyWith(
        products: next,
        catalog: _catalogMayLoad ? SupportCatalog.ready : state.catalog,
      );
    } catch (_) {
      if (!mounted) return;
      _fail(surfaceFailure: surfaceFailure);
    }
  }

  void _fail({required bool surfaceFailure}) {
    if (!mounted) return;
    if (state.cacheComplete) return;
    if (!_catalogMayLoad) return;
    if (!surfaceFailure) return;
    if (state.catalog == SupportCatalog.loading ||
        state.catalog == SupportCatalog.empty) {
      state = state.copyWith(catalog: SupportCatalog.unavailable);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!mounted) return;
      if (purchase.pendingCompletePurchase) {
        try {
          await _billing.completePurchase(purchase);
        } catch (_) {}
      }
      if (!mounted) return;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(
            activity: SupportActivity.pending,
            submitting: false,
          );
        case PurchaseStatus.purchased:
          final quantity = purchaseQuantity(purchase);
          state = state.copyWith(
            activity: SupportActivity.thanks,
            thanksProductId: purchase.productID,
            thanksQuantity: quantity,
            submitting: false,
          );
          await _rememberPurchase(purchase);
          if (!mounted) return;
        case PurchaseStatus.error:
          _dismiss(SupportDismiss.error);
        case PurchaseStatus.canceled:
          _dismiss(SupportDismiss.quiet);
        case PurchaseStatus.restored:
          state = state.copyWith(submitting: false);
      }
    }
  }

  Future<void> _rememberPurchase(PurchaseDetails purchase) async {
    final at = _purchaseTime(purchase);
    final store = _store;
    if (store == null) {
      final pending = _pendingPurchaseAt;
      if (pending == null || at.isAfter(pending)) _pendingPurchaseAt = at;
      return;
    }
    await store.recordPurchase(at);
  }

  DateTime _purchaseTime(PurchaseDetails purchase) {
    final raw = purchase.transactionDate;
    if (raw != null) {
      final ms = int.tryParse(raw);
      if (ms != null && ms > 0) {
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
    return _clock.now();
  }

  void _dismiss(SupportDismiss dismiss) {
    if (!mounted) return;
    state = state.copyWith(
      activity: SupportActivity.idle,
      submitting: false,
      dismiss: dismiss,
      dismissNonce: state.dismissNonce + 1,
    );
  }

  var _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
