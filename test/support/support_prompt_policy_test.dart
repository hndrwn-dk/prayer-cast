import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/common/clock.dart';
import 'package:prayer_cast/support/support_prompt_policy.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1);

  SupportPromptDecision evaluate({
    required int playedCount,
    required SupportPromptState state,
    required Clock clock,
  }) {
    return SupportPromptPolicy.evaluate(
      playedCount: playedCount,
      state: state,
      clock: clock,
    );
  }

  test('first run marks milestones already passed and shows nothing', () {
    final clock = FakeClock(start);
    final decision = evaluate(
      playedCount: 40,
      state: const SupportPromptState(),
      clock: clock,
    );

    expect(decision.showMilestone, isNull);
    expect(decision.state.baselineCount, 40);
    expect(decision.state.completedMilestones, {30});
    expect(decision.state.lastPromptAt, isNull);
  });

  test('first run at 160 silences 30 and 150', () {
    final decision = evaluate(
      playedCount: 160,
      state: const SupportPromptState(),
      clock: FakeClock(start),
    );

    expect(decision.showMilestone, isNull);
    expect(decision.state.completedMilestones, {30, 150});
  });

  test('first run at zero stores the baseline without a card', () {
    final decision = evaluate(
      playedCount: 0,
      state: const SupportPromptState(),
      clock: FakeClock(start),
    );

    expect(decision.showMilestone, isNull);
    expect(decision.state.baselineCount, 0);
    expect(decision.state.completedMilestones, isEmpty);
  });

  test('a milestone reached after the baseline is shown', () {
    final clock = FakeClock(start);
    final baseline = evaluate(
      playedCount: 29,
      state: const SupportPromptState(),
      clock: clock,
    ).state;

    final decision = evaluate(
      playedCount: 30,
      state: baseline,
      clock: clock,
    );

    expect(decision.showMilestone, 30);
    expect(decision.state.visibleSince, clock.now());
    expect(decision.state.lastPromptAt, clock.now());
  });

  test('an exact baseline of 30 does not show, and 150 can show immediately', () {
    final clock = FakeClock(start);
    final baseline = evaluate(
      playedCount: 30,
      state: const SupportPromptState(),
      clock: clock,
    ).state;

    expect(
      evaluate(playedCount: 30, state: baseline, clock: clock).showMilestone,
      isNull,
    );
    expect(
      evaluate(playedCount: 150, state: baseline, clock: clock).showMilestone,
      150,
    );
  });

  test('the next milestone waits 30 days after a card was shown', () {
    final clock = FakeClock(start);
    var state = evaluate(
      playedCount: 30,
      state: const SupportPromptState(baselineCount: 0),
      clock: clock,
    ).state;
    state = SupportPromptPolicy.dismiss(state);

    clock.advance(const Duration(days: 29));
    expect(
      evaluate(playedCount: 150, state: state, clock: clock).showMilestone,
      isNull,
    );

    clock.advance(const Duration(days: 1));
    final next = evaluate(playedCount: 150, state: state, clock: clock);
    expect(next.showMilestone, 150);
  });

  test('a dismissed milestone is not shown again', () {
    final clock = FakeClock(start);
    var state = evaluate(
      playedCount: 30,
      state: const SupportPromptState(baselineCount: 0),
      clock: clock,
    ).state;
    state = SupportPromptPolicy.dismiss(state);
    clock.advance(const Duration(days: 31));

    final again = evaluate(playedCount: 30, state: state, clock: clock);
    expect(again.showMilestone, isNull);
    expect(again.state.completedMilestones, contains(30));
  });

  test('a purchase inside 90 days hides the card, and day 90 allows it', () {
    final clock = FakeClock(start);
    final recent = evaluate(
      playedCount: 30,
      state: SupportPromptState(
        baselineCount: 0,
        lastPurchaseAt: clock.now().subtract(const Duration(days: 89)),
      ),
      clock: clock,
    );
    expect(recent.showMilestone, isNull);

    final allowed = evaluate(
      playedCount: 30,
      state: SupportPromptState(
        baselineCount: 0,
        lastPurchaseAt: clock.now().subtract(const Duration(days: 90)),
      ),
      clock: clock,
    );
    expect(allowed.showMilestone, 30);
  });

  test('a purchase while the card is visible hides it for good', () {
    final clock = FakeClock(start);
    final shown = evaluate(
      playedCount: 30,
      state: const SupportPromptState(baselineCount: 0),
      clock: clock,
    );
    clock.advance(const Duration(days: 2));

    final hidden = evaluate(
      playedCount: 30,
      state: shown.state.copyWith(lastPurchaseAt: clock.now()),
      clock: clock,
    );

    expect(hidden.showMilestone, isNull);
    expect(hidden.state.completedMilestones, contains(30));
    clock.advance(const Duration(days: 91));
    expect(
      evaluate(
        playedCount: 30,
        state: hidden.state,
        clock: clock,
      ).showMilestone,
      isNull,
    );
  });

  test('the card stays up until it has been visible for 3 days', () {
    final clock = FakeClock(start);
    final shown = evaluate(
      playedCount: 30,
      state: const SupportPromptState(baselineCount: 0),
      clock: clock,
    );
    clock.advance(const Duration(days: 3) - const Duration(minutes: 1));
    expect(
      evaluate(
        playedCount: 30,
        state: shown.state,
        clock: clock,
      ).showMilestone,
      30,
    );

    clock.advance(const Duration(minutes: 1));
    final expired = evaluate(
      playedCount: 30,
      state: shown.state,
      clock: clock,
    );
    expect(expired.showMilestone, isNull);
    expect(expired.state.completedMilestones, contains(30));
  });

  test('a visible card does not jump to a later milestone', () {
    final clock = FakeClock(start);
    final shown = evaluate(
      playedCount: 30,
      state: const SupportPromptState(baselineCount: 0),
      clock: clock,
    );

    final still = evaluate(
      playedCount: 500,
      state: shown.state,
      clock: clock,
    );
    expect(still.showMilestone, 30);
  });
}
