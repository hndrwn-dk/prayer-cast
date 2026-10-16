import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:prayer_cast/l10n/app_localizations.dart';
import 'package:prayer_cast/support/support_billing.dart';
import 'package:prayer_cast/support/support_icon_button.dart';
import 'package:prayer_cast/support/support_products.dart';
import 'package:prayer_cast/support/support_providers.dart';
import 'package:prayer_cast/support/support_purchase_service.dart';
import 'package:prayer_cast/support/support_sheet.dart';

void main() {
  testWidgets('support sheet shows three price placeholders while loading', (
    tester,
  ) async {
    final gate = Completer<ProductDetailsResponse>();
    final billing = _FakeBilling()..onQuery = (_) => gate.future;
    final service = SupportPurchaseService(billing: billing);
    addTearDown(service.dispose);
    addTearDown(() {
      if (!gate.isCompleted) {
        gate.complete(
          ProductDetailsResponse(
            productDetails: const [],
            notFoundIDs: SupportProducts.ordered,
          ),
        );
      }
    });

    await tester.pumpWidget(_app(service, const Locale('id')));
    await tester.pump();

    expect(find.byType(SupportPricePlaceholder), findsNWidgets(3));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Segelas kopi'), findsOneWidget);
    expect(find.text('Makan siang'), findsOneWidget);
    expect(find.text('Dukung penuh'), findsOneWidget);
  });

  testWidgets('quantity line appears only when the purchase quantity is above 1', (
    tester,
  ) async {
    final billing = _FakeBilling();
    final service = SupportPurchaseService(billing: billing);
    addTearDown(service.dispose);
    await service.start();

    await tester.pumpWidget(_app(service, const Locale('id')));
    await tester.pump();

    billing.emit([_googlePurchase('{"quantity":1}')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Jazakallahu khairan'), findsOneWidget);
    expect(find.byKey(const ValueKey('support_thanks_quantity')), findsNothing);

    service.onSheetOpened();
    await tester.pump();
    billing.emit([_googlePurchase('{"quantity":3}')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Makan siang ×3'), findsOneWidget);
  });

  testWidgets('home support icon keeps the hand mark and opens the sheet', (
    tester,
  ) async {
    final billing = _FakeBilling();
    final service = SupportPurchaseService(billing: billing);
    addTearDown(service.dispose);
    await service.start();

    await tester.pumpWidget(
      _app(service, const Locale('id'), home: const Scaffold(body: SupportIconButton())),
    );

    expect(find.byIcon(Icons.volunteer_activism), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).tooltip,
      'Dukung aplikasi',
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('Dukung Prayer Cast'), findsOneWidget);
  });

  testWidgets('english tooltip is Support the app', (tester) async {
    final service = SupportPurchaseService(billing: _FakeBilling());
    addTearDown(service.dispose);

    await tester.pumpWidget(
      _app(
        service,
        const Locale('en'),
        home: const Scaffold(body: SupportIconButton()),
      ),
    );

    expect(
      tester.widget<IconButton>(find.byType(IconButton)).tooltip,
      'Support the app',
    );
  });
}

Widget _app(
  SupportPurchaseService service,
  Locale locale, {
  Widget home = const SupportSheet(),
}) {
  return ProviderScope(
    overrides: [supportPurchaseProvider.overrideWith((ref) => service)],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}

final class _FakeBilling implements SupportBilling {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  Future<ProductDetailsResponse> Function(Set<String> ids)? onQuery;

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) {
    final query = onQuery;
    if (query != null) return query(ids);
    return Future.value(
      ProductDetailsResponse(
        productDetails: [
          for (final id in SupportProducts.ordered)
            ProductDetails(
              id: id,
              title: id,
              description: id,
              price: 'Rp25.000',
              rawPrice: 25000,
              currencyCode: 'IDR',
            ),
        ],
        notFoundIDs: const [],
      ),
    );
  }

  @override
  Future<bool> buyConsumable({required ProductDetails product}) async => true;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}

GooglePlayPurchaseDetails _googlePurchase(String originalJson) {
  return GooglePlayPurchaseDetails(
    productID: SupportProducts.lunch,
    verificationData: PurchaseVerificationData(
      localVerificationData: originalJson,
      serverVerificationData: 'token',
      source: 'google_play',
    ),
    transactionDate: '1700000000000',
    status: PurchaseStatus.purchased,
    billingClientPurchase: PurchaseWrapper(
      orderId: 'order',
      packageName: 'com.tursinalabs.prayer_cast',
      purchaseTime: 1700000000000,
      purchaseToken: 'token',
      signature: 'sig',
      products: const [SupportProducts.lunch],
      isAutoRenewing: false,
      originalJson: originalJson,
      isAcknowledged: true,
      purchaseState: PurchaseStateWrapper.purchased,
    ),
  );
}
