import 'package:prayer_cast/l10n/app_localizations.dart';

/// Consumable Play Billing product ids. Prices come from [ProductDetails].
abstract final class SupportProducts {
  static const coffee = 'support_10k';
  static const lunch = 'support_25k';
  static const full = 'support_50k';

  static const ordered = <String>[coffee, lunch, full];
  static const ids = <String>{coffee, lunch, full};
  static const defaultSelection = lunch;
}

String supportTierLabel(AppLocalizations l10n, String productId) {
  return switch (productId) {
    SupportProducts.coffee => l10n.supportTierCoffee,
    SupportProducts.lunch => l10n.supportTierLunch,
    SupportProducts.full => l10n.supportTierFull,
    _ => productId,
  };
}
