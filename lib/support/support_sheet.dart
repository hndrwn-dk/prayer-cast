import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/support/purchase_quantity.dart';
import 'package:prayer_cast/support/support_products.dart';
import 'package:prayer_cast/support/support_providers.dart';
import 'package:prayer_cast/support/support_purchase_service.dart';

/// Opens the Play Billing support sheet.
Future<void> showSupportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => const SupportSheet(),
  );
}

class SupportSheet extends ConsumerStatefulWidget {
  const SupportSheet({super.key});

  @override
  ConsumerState<SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends ConsumerState<SupportSheet> {
  String _selected = SupportProducts.defaultSelection;

  @override
  void initState() {
    super.initState();
    // prepare() updates the provider. Riverpod rejects that during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(supportPurchaseProvider.notifier).onSheetOpened();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(supportPurchaseProvider, (previous, next) {
      if (previous?.dismissNonce == next.dismissNonce) return;
      if (next.dismiss == SupportDismiss.none) return;
      final messenger = ScaffoldMessenger.of(context);
      final message = l10n.supportPurchaseError;
      Navigator.of(context).maybePop();
      if (next.dismiss == SupportDismiss.error) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final purchase = ref.watch(supportPurchaseProvider);
    final thanks = purchase.activity == SupportActivity.thanks;
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return SafeArea(
      child: AnimatedSize(
        duration: motion,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: motion,
          child: thanks
              ? _ThanksView(
                  key: const ValueKey('support_thanks'),
                  productId: purchase.thanksProductId,
                  quantity: purchase.thanksQuantity,
                )
              : _CatalogView(
                  key: const ValueKey('support_catalog'),
                  purchase: purchase,
                  selected: _selected,
                  onSelected: (id) => setState(() => _selected = id),
                ),
        ),
      ),
    );
  }
}

class _CatalogView extends ConsumerWidget {
  const _CatalogView({
    super.key,
    required this.purchase,
    required this.selected,
    required this.onSelected,
  });

  final SupportPurchaseState purchase;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final unavailable = purchase.catalog == SupportCatalog.unavailable;
    final pending = purchase.activity == SupportActivity.pending;
    final selectedProduct = purchase.products[selected];
    final canBuy =
        !unavailable &&
        !pending &&
        !purchase.submitting &&
        selectedProduct != null &&
        purchase.catalog == SupportCatalog.ready;
    final product = selectedProduct;
    final VoidCallback? onBuy = product == null || !canBuy
        ? null
        : () => ref.read(supportPurchaseProvider.notifier).buy(product);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.supportSheetTitle,
            style: TextStyle(
              fontFamily: PrayerCastTheme.displayFont,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              height: 1.25,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.supportSheetBody,
            style: TextStyle(
              fontFamily: PrayerCastTheme.bodyFont,
              fontSize: 15,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          if (unavailable)
            Text(
              l10n.supportUnavailable,
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 15,
                height: 1.4,
                color: scheme.onSurface,
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < SupportProducts.ordered.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _TierBox(
                      label: supportTierLabel(
                        l10n,
                        SupportProducts.ordered[i],
                      ),
                      price: purchase.products[SupportProducts.ordered[i]]?.price,
                      loading: purchase.catalog != SupportCatalog.ready,
                      selected: selected == SupportProducts.ordered[i],
                      onTap: () => onSelected(SupportProducts.ordered[i]),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.supportQuantityHint,
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 13,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (pending)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.supportPending,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: PrayerCastTheme.bodyFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              )
            else
              FilledButton(
                onPressed: onBuy,
                child: Text(l10n.supportContinue),
              ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.supportPaymentNote,
            style: TextStyle(
              fontFamily: PrayerCastTheme.bodyFont,
              fontSize: 12,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierBox extends StatelessWidget {
  const _TierBox({
    required this.label,
    required this.price,
    required this.loading,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? price;
  final bool loading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 108,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 22,
                    child: Center(
                      child: loading || price == null
                          ? const SupportPricePlaceholder()
                          : Text(
                              price!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: PrayerCastTheme.bodyFont,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: PrayerCastTheme.bodyFont,
                      fontSize: 13,
                      height: 1.25,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed-size stand-in for a Play price so the tier row does not jump.
class SupportPricePlaceholder extends StatelessWidget {
  const SupportPricePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 14,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _ThanksView extends StatefulWidget {
  const _ThanksView({super.key, required this.productId, required this.quantity});

  final String? productId;
  final int quantity;

  @override
  State<_ThanksView> createState() => _ThanksViewState();
}

class _ThanksViewState extends State<_ThanksView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _played = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_played) return;
    _played = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final label = widget.productId == null
        ? null
        : supportTierLabel(l10n, widget.productId!);
    final quantityLine = label == null
        ? null
        : supportThanksQuantityLine(label: label, quantity: widget.quantity);
    final scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.6,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _controller,
            child: ScaleTransition(
              scale: scale,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 36,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.supportThanksTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: PrayerCastTheme.displayFont,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.supportThanksBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: PrayerCastTheme.bodyFont,
              fontSize: 15,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (quantityLine != null) ...[
            const SizedBox(height: 8),
            Text(
              quantityLine,
              key: const ValueKey('support_thanks_quantity'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: PrayerCastTheme.bodyFont,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.supportClose),
          ),
        ],
      ),
    );
  }
}
