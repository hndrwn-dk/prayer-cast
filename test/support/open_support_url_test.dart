import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/support/app_links.dart';
import 'package:prayer_cast/support/open_support_url.dart';

void main() {
  final launched = <Uri>[];

  setUp(() {
    launched.clear();
    debugLaunchExternalUrl = (uri) async {
      launched.add(uri);
      return true;
    };
  });

  tearDown(() {
    debugLaunchExternalUrl = null;
  });

  Future<void> pumpAndTap(
    WidgetTester tester,
    Future<void> Function(BuildContext context) onPressed,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => onPressed(context),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
  }

  testWidgets('openSupportUrl launches the Ko-fi donate URL', (tester) async {
    await pumpAndTap(tester, openSupportUrl);
    expect(launched, [Uri.parse(AppLinks.donateUrl)]);
  });

  testWidgets('openPlayStoreUrl launches the Prayer Cast listing', (
    tester,
  ) async {
    await pumpAndTap(tester, openPlayStoreUrl);
    expect(launched, [Uri.parse(AppLinks.playStoreUrl)]);
  });

  testWidgets('openExternalUrl shows a snackbar when launch fails', (
    tester,
  ) async {
    debugLaunchExternalUrl = (uri) async => false;
    await pumpAndTap(
      tester,
      (context) => openExternalUrl(context, AppLinks.privacyPolicyUrl),
    );
    expect(find.text('Could not open link'), findsOneWidget);
  });
}
