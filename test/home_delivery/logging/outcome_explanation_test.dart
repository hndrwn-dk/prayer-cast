import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_cast/home_delivery/logging/outcome.dart';
import 'package:prayer_cast/home_delivery/logging/outcome_explanation.dart';

void main() {
  test('every Outcome has BI and EN one-liners', () {
    for (final outcome in Outcome.values) {
      expect(OutcomeExplanation.bi(outcome), isNotEmpty);
      expect(OutcomeExplanation.en(outcome), isNotEmpty);
      expect(OutcomeExplanation.bi(outcome), isNot(equals(OutcomeExplanation.en(outcome))));
    }
  });

  test('id locale prefers BI; other locales fall back to EN', () {
    expect(
      OutcomeExplanation.forOutcome(Outcome.played, const Locale('id')),
      OutcomeExplanation.bi(Outcome.played),
    );
    expect(
      OutcomeExplanation.forOutcome(Outcome.played, const Locale('en')),
      OutcomeExplanation.en(Outcome.played),
    );
    expect(
      OutcomeExplanation.forOutcome(Outcome.played, const Locale('fr')),
      OutcomeExplanation.en(Outcome.played),
    );
  });
}
