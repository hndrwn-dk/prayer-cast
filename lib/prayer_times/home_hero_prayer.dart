import 'package:prayer_cast/home_delivery/coordinator/next_prayer_provider.dart';

/// Home hero prayer: active delivery on this device wins over upcoming next.
NextPrayer? resolveHomeHeroPrayer({
  required NextPrayer? active,
  required NextPrayer? upcoming,
}) {
  return active ?? upcoming;
}
