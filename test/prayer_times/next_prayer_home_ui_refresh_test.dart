import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';

void main() {
  testWidgets('refreshNextPrayerHomeUi re-resolves snapshot only', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nextPrayerSnapshotProvider.overrideWith((ref) async {
            builds++;
            return NextPrayer(
              name: builds == 1 ? 'dhuhr' : 'asr',
              scheduledAt: DateTime(2026, 9, 7, 12 + builds),
              voiceId: 'standard_adhan',
            );
          }),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final snap = ref.watch(nextPrayerSnapshotProvider);
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Text(snap.asData?.value?.name ?? 'loading'),
                    TextButton(
                      onPressed: () => refreshNextPrayerHomeUi(ref),
                      child: const Text('refresh'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(builds, 1);
    expect(find.text('dhuhr'), findsOneWidget);

    await tester.tap(find.text('refresh'));
    await tester.pumpAndSettle();

    expect(builds, 2);
    expect(find.text('asr'), findsOneWidget);
  });
}
