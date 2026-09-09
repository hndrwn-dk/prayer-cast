/// Home-hero hold while Cast adhan plays.
///
/// Nest / Chromecast often emit [finished] shortly after load even though
/// audio continues. Ignore those until [minCastHeroHold] has elapsed.
const Duration minCastHeroHold = Duration(minutes: 2, seconds: 30);

/// True when a Cast `finished` event should clear the home hero hold.
bool shouldEndHeroHoldOnFinished({
  required Duration elapsedSinceHoldBegan,
  Duration minHold = minCastHeroHold,
}) {
  return !elapsedSinceHoldBegan.isNegative &&
      elapsedSinceHoldBegan >= minHold;
}
