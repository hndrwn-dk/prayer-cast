import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

/// Play Billing surface used by [SupportPurchaseService].
abstract interface class SupportBilling {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids);

  /// Buys a consumable. Implementations pass `autoConsume: true`.
  Future<bool> buyConsumable({required ProductDetails product});

  Future<void> completePurchase(PurchaseDetails purchase);
}

final class PlaySupportBilling implements SupportBilling {
  PlaySupportBilling({InAppPurchasePlatform? platform}) : _platform = platform;

  final InAppPurchasePlatform? _platform;

  InAppPurchasePlatform get _billing {
    final injected = _platform;
    if (injected != null) return injected;
    // The facade registers the store implementation on first access.
    InAppPurchase.instance;
    return InAppPurchasePlatform.instance;
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _billing.purchaseStream;

  @override
  Future<bool> isAvailable() => _billing.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) {
    return _billing.queryProductDetails(ids);
  }

  @override
  Future<bool> buyConsumable({required ProductDetails product}) {
    return _billing.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
      autoConsume: true,
    );
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _billing.completePurchase(purchase);
  }
}
