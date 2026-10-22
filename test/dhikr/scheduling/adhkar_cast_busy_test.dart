import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/dhikr/scheduling/adhkar_cast_busy.dart';
import 'package:prayer_cast/home_delivery/delivery/cast_client.dart';

void main() {
  final now = DateTime.utc(2026, 10, 22, 6, 10);

  CastMediaSnapshot playing(String title) => CastMediaSnapshot(
    contentId: 'http://192.168.1.20:8080/x.mp3',
    title: title,
    isPlaying: true,
  );

  test('nothing loaded or paused is not busy', () {
    expect(
      AdhkarCastBusy.isBusy(media: null, lastOwnLoadAt: null, now: now),
      isFalse,
    );
    expect(
      AdhkarCastBusy.isBusy(
        media: const CastMediaSnapshot(
          contentId: 'x',
          title: 'adzan:s:makkah',
          isPlaying: false,
        ),
        lastOwnLoadAt: now,
        now: now,
      ),
      isFalse,
    );
  });

  test('our adhan still inside its serving window is busy', () {
    expect(
      AdhkarCastBusy.isBusy(
        media: playing('adzan:sess:makkah'),
        lastOwnLoadAt: now.subtract(const Duration(minutes: 4)),
        now: now,
      ),
      isTrue,
    );
  });

  test('stale PLAYING of our adhan from a frozen process is not busy', () {
    expect(
      AdhkarCastBusy.isBusy(
        media: playing('adzan:sess:makkah'),
        lastOwnLoadAt: now.subtract(const Duration(minutes: 10)),
        now: now,
      ),
      isFalse,
      reason: 'the adhan media server is gone after 6 minutes',
    );
  });

  test('our adhan with no load recorded in this process stays busy', () {
    expect(
      AdhkarCastBusy.isBusy(
        media: playing('adzan:sess:makkah'),
        lastOwnLoadAt: null,
        now: now,
      ),
      isTrue,
    );
  });

  test('someone else playing music is always busy', () {
    expect(
      AdhkarCastBusy.isBusy(
        media: playing('Some Song'),
        lastOwnLoadAt: now.subtract(const Duration(hours: 3)),
        now: now,
      ),
      isTrue,
    );
  });

  test('stale adhkar status older than the longest hold is not busy', () {
    expect(
      AdhkarCastBusy.isBusy(
        media: playing('adhkar_morning'),
        lastOwnLoadAt: now.subtract(const Duration(hours: 9)),
        now: now,
      ),
      isFalse,
    );
  });
}
