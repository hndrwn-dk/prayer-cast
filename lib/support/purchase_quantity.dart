import 'dart:convert';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Play Billing quantity for a consumable purchase. Missing or empty values
/// count as one.
///
/// `in_app_purchase_android` 0.5.x receives `quantity` on the Pigeon purchase
/// but does not copy it onto [PurchaseWrapper]. The Play purchase JSON in
/// [PurchaseWrapper.originalJson] still carries it. A future wrapper field
/// named `quantity` is preferred when it exists.
int purchaseQuantity(PurchaseDetails details) {
  if (details is! GooglePlayPurchaseDetails) return 1;
  final wrapper = details.billingClientPurchase;
  return normalizePurchaseQuantity(
    _declaredQuantity(wrapper) ?? _quantityFromOriginalJson(wrapper.originalJson),
  );
}

int normalizePurchaseQuantity(int? quantity) {
  if (quantity == null || quantity < 1) return 1;
  return quantity;
}

/// Tier line on the thanks state. Hidden when the buyer chose a single unit.
String? supportThanksQuantityLine({
  required String label,
  required int quantity,
}) {
  if (quantity <= 1) return null;
  return '$label ×$quantity';
}

int? _declaredQuantity(Object purchase) {
  try {
    final value = (purchase as dynamic).quantity;
    if (value is int) return value;
  } on NoSuchMethodError {
    return null;
  }
  return null;
}

int? _quantityFromOriginalJson(String raw) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final value = decoded['quantity'];
    if (value is int) return value;
    if (value is num) return value.toInt();
  } catch (_) {}
  return null;
}
