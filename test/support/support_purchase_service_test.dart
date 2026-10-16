import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:prayer_cast/support/purchase_quantity.dart';
import 'package:prayer_cast/support/support_billing.dart';
import 'package:prayer_cast/support/support_products.dart';
import 'package:prayer_cast/support/support_purchase_service.dart';
import 'package:prayer_cast/support/support_state_store.dart';

void main() {
  test('thanks quantity line is omitted unless quantity is greater than 1', () {
    expect(
      supportThanksQuantityLine(label: 'Makan siang', quantity: 1),
      isNull,
    );
    expect(
      supportThanksQuantityLine(label: 'Makan siang', quantity: 0),
      isNull,
    );
    expect(
      supportThanksQuantityLine(label: 'Makan siang', quantity: 3),
      'Makan siang ×3',
    );
  });

  test('missing purchase quantity counts as 1', () {
    expect(purchaseQuantity(_plainPurchase()), 1);
    expect(purchaseQuantity(_googlePurchase('{}')), 1);
    expect(purchaseQuantity(_googlePurchase('{"quantity":0}')), 1);
    expect(purchaseQuantity(_googlePurchase('{"quantity":4}')), 4);
  });

  test('prefetch failure leaves the cache empty', () async {
    final billing = _FakeBilling()
      ..onQuery = (_) async {
        throw StateError('offline');
      };
    final service = SupportPurchaseService(billing: billing);
    addTearDown(service.dispose);

    await service.start();

    expect(service.state.products, isEmpty);
    expect(service.state.catalog, SupportCatalog.empty);
  });

  test('prepare does not enter loading when products are already cached', () async {
    final billing = _FakeBilling();
    final service = SupportPurchaseService(billing: billing);
    addTearDown(service.dispose);
    await service.start();
    expect(service.state.cacheComplete, isTrue);

    final seen = <SupportCatalog>[];
    final remove = service.addListener((state) {
      seen.add(state.catalog);
    }, fireImmediately: false);

    await service.prepare();
    remove();

    expect(seen, isNot(contains(SupportCatalog.loading)));
    expect(service.state.catalog, SupportCatalog.ready);
  });

  test('pending and thanks do not return to loading', () async {
    final gate = Completer<ProductDetailsResponse>();
    final billing = _FakeBilling()..onQuery = (_) => gate.future;
    final service = SupportPurchaseService(billing: billing);
    addTearDown(service.dispose);

    final started = service.start();
    await Future<void>.delayed(Duration.zero);
    billing.emit([_plainPurchase(status: PurchaseStatus.pending)]);
    await Future<void>.delayed(Duration.zero);
    expect(service.state.activity, SupportActivity.pending);

    final seen = <SupportCatalog>[];
    final remove = service.addListener((state) {
      seen.add(state.catalog);
    }, fireImmediately: false);
    await service.prepare();
    expect(service.state.activity, SupportActivity.pending);
    expect(seen, isNot(contains(SupportCatalog.loading)));

    billing.emit([
      _googlePurchase(
        '{"quantity":2}',
        status: PurchaseStatus.purchased,
        productId: SupportProducts.lunch,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(service.state.activity, SupportActivity.thanks);
    expect(service.state.thanksQuantity, 2);

    await service.prepare();
    expect(service.state.activity, SupportActivity.thanks);
    expect(seen, isNot(contains(SupportCatalog.loading)));
    remove();

    gate.complete(_productsResponse());
    await started;
    expect(service.state.activity, SupportActivity.thanks);
    expect(service.state.catalog, isNot(SupportCatalog.loading));
  });

  test('buyConsumable is called with autoConsume true', () async {
    final fake = _FakePlatform();
    final billing = PlaySupportBilling(platform: fake);
    final ok = await billing.buyConsumable(
      product: _product(SupportProducts.coffee),
    );

    expect(ok, isTrue);
    expect(fake.autoConsume, isTrue);
  });

  test('a purchased consumable is completed and recorded', () async {
    final billing = _FakeBilling();
    final store = MemorySupportStateStore();
    final service = SupportPurchaseService(billing: billing, store: store);
    addTearDown(service.dispose);
    await service.start();

    final purchase = _googlePurchase(
      '{"quantity":1}',
      status: PurchaseStatus.purchased,
      acknowledged: false,
    );
    billing.emit([purchase]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(billing.completed, [purchase]);
    expect(service.state.activity, SupportActivity.thanks);
    expect(service.state.thanksQuantity, 1);
    expect((await store.read()).lastPurchaseAt, isNotNull);
  });
}

class _FakeBilling implements SupportBilling {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  Future<ProductDetailsResponse> Function(Set<String> ids)? onQuery;
  final completed = <PurchaseDetails>[];

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) {
    final query = onQuery;
    if (query != null) return query(ids);
    return Future.value(_productsResponse());
  }

  @override
  Future<bool> buyConsumable({required ProductDetails product}) async => true;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }
}

class _FakePlatform extends InAppPurchasePlatform {
  bool? autoConsume;

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    this.autoConsume = autoConsume;
    return true;
  }
}

ProductDetailsResponse _productsResponse() {
  return ProductDetailsResponse(
    productDetails: [
      for (final id in SupportProducts.ordered) _product(id),
    ],
    notFoundIDs: const [],
  );
}

ProductDetails _product(String id) {
  return ProductDetails(
    id: id,
    title: id,
    description: id,
    price: 'Rp25.000',
    rawPrice: 25000,
    currencyCode: 'IDR',
  );
}

PurchaseDetails _plainPurchase({
  PurchaseStatus status = PurchaseStatus.purchased,
}) {
  return PurchaseDetails(
    productID: SupportProducts.coffee,
    verificationData: PurchaseVerificationData(
      localVerificationData: '{}',
      serverVerificationData: 'token',
      source: 'google_play',
    ),
    transactionDate: null,
    status: status,
  );
}

GooglePlayPurchaseDetails _googlePurchase(
  String originalJson, {
  PurchaseStatus status = PurchaseStatus.purchased,
  String productId = SupportProducts.lunch,
  bool acknowledged = true,
}) {
  return GooglePlayPurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: originalJson,
      serverVerificationData: 'token',
      source: 'google_play',
    ),
    transactionDate: '1700000000000',
    status: status,
    billingClientPurchase: PurchaseWrapper(
      orderId: 'order',
      packageName: 'com.tursinalabs.prayer_cast',
      purchaseTime: 1700000000000,
      purchaseToken: 'token',
      signature: 'sig',
      products: [productId],
      isAutoRenewing: false,
      originalJson: originalJson,
      isAcknowledged: acknowledged,
      purchaseState: PurchaseStateWrapper.purchased,
    ),
  );
}
