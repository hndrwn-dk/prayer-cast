import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/home_delivery/ui/home_setup_providers.dart';
import 'package:prayer_cast/home_delivery/ui/icons/premium_icons.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_colors.dart';
import 'package:prayer_cast/home_delivery/ui/theme/prayer_cast_theme.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/prayer_times/prayer_prefs.dart';
import 'package:prayer_cast/prayer_times/prayer_times_providers.dart';
import 'package:prayer_cast/setup/setup_card_store.dart';

/// Latest setup-card flags, including the one-shot existing-user migration.
final setupCardFlagsProvider = FutureProvider<SetupCardFlags>((ref) async {
  final store = ref.watch(setupCardStoreProvider);
  final prefs = await ref.watch(prayerPrefsProvider.future);
  final flags = await store.read();
  if (flags.existingUserMigrated) return flags;
  final next = flags.copyWith(
    dismissed: prefs.configured ? true : flags.dismissed,
    existingUserMigrated: true,
  );
  await store.write(next);
  return next;
});

/// Pure visibility for dismiss and the existing-user migration.
///
/// Speaker / phone completion is applied by [SetupChecklistCard]: the card
/// hides once prayer times are configured and a speaker is saved or the
/// user chose this phone. An unticked reminders row does not keep it visible.
bool shouldShowSetupCard({
  required SetupCardFlags flags,
  required bool prayerConfigured,
}) {
  if (flags.dismissed) return false;
  if (!flags.existingUserMigrated && prayerConfigured) return false;
  return true;
}

bool _setupCardPhoneDeliveryMode(PrayerDeliveryMode mode) {
  return switch (mode) {
    PrayerDeliveryMode.adhanPhone ||
    PrayerDeliveryMode.beep ||
    PrayerDeliveryMode.takbir => true,
    PrayerDeliveryMode.cast => false,
  };
}

/// Saved phone delivery: adhan on this phone, beep, or takbir.
///
/// Cast stays unticked. Matches persisted [PrayerPrefs.defaultDeliveryMode]
/// or any per-prayer entry in [PrayerPrefs.deliveryByPrayer].
bool setupCardDeliveryDone(PrayerPrefs prefs) {
  if (_setupCardPhoneDeliveryMode(prefs.defaultDeliveryMode)) return true;
  for (final raw in prefs.deliveryByPrayer.values) {
    if (_setupCardPhoneDeliveryMode(PrayerDeliveryModeX.parse(raw))) {
      return true;
    }
  }
  return false;
}

class SetupChecklistCard extends ConsumerWidget {
  const SetupChecklistCard({
    super.key,
    required this.onOpenSpeaker,
    required this.onOpenPrayerTimes,
    required this.onOpenDelivery,
    required this.onOpenReminders,
  });

  static const Key keyName = ValueKey<String>('setup_checklist_card');
  static const Key dismissKey = ValueKey<String>('setup_card_dismiss');
  static const Key speakerKey = ValueKey<String>('setup_card_speaker');
  static const Key noSpeakerKey = ValueKey<String>('setup_card_no_speaker');
  static const Key prayerKey = ValueKey<String>('setup_card_prayer');
  static const Key deliveryKey = ValueKey<String>('setup_card_delivery');
  static const Key remindersKey = ValueKey<String>('setup_card_reminders');

  final VoidCallback onOpenSpeaker;
  final VoidCallback onOpenPrayerTimes;
  final VoidCallback onOpenDelivery;
  final VoidCallback onOpenReminders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagsAsync = ref.watch(setupCardFlagsProvider);
    final prefsAsync = ref.watch(prayerPrefsProvider);
    final speakerAsync = ref.watch(savedHomeSpeakerProvider);

    final flags = flagsAsync.asData?.value;
    final prefs = prefsAsync.asData?.value;
    final speakerPending = speakerAsync.isLoading && !speakerAsync.hasValue;
    if (flags == null || prefs == null || speakerPending) {
      return const SizedBox.shrink();
    }
    if (flagsAsync.hasError || prefsAsync.hasError) {
      return const SizedBox.shrink();
    }

    final speaker = speakerAsync.asData?.value;
    if (!shouldShowSetupCard(
      flags: flags,
      prayerConfigured: prefs.configured,
    )) {
      return const SizedBox.shrink();
    }
    if (prefs.configured && (speaker != null || flags.noSpeaker)) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final showDelivery = speaker == null && flags.noSpeaker;

    return ColoredBox(
      color: PrayerCastColors.canopyDeep,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 16, 16),
        child: Material(
          key: SetupChecklistCard.keyName,
          color: PrayerCastColors.dawnSoft,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.setupCardTitle,
                        style: const TextStyle(
                          fontFamily: PrayerCastTheme.bodyFont,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: PrayerCastColors.ink,
                        ),
                      ),
                    ),
                    TextButton(
                      key: SetupChecklistCard.dismissKey,
                      onPressed: () => unawaited(_dismiss(ref)),
                      child: Text(l10n.setupCardDismiss),
                    ),
                  ],
                ),
                _SetupRow(
                  rowKey: SetupChecklistCard.speakerKey,
                  label: l10n.setupCardSpeaker,
                  done: speaker != null,
                  onTap: onOpenSpeaker,
                ),
                _SetupRow(
                  rowKey: SetupChecklistCard.noSpeakerKey,
                  label: l10n.setupCardNoSpeaker,
                  done: flags.noSpeaker,
                  onTap: () => unawaited(_chooseThisPhone(ref)),
                ),
                _SetupRow(
                  rowKey: SetupChecklistCard.prayerKey,
                  label: l10n.setupCardPrayer,
                  done: prefs.configured,
                  onTap: onOpenPrayerTimes,
                ),
                if (showDelivery)
                  _SetupRow(
                    rowKey: SetupChecklistCard.deliveryKey,
                    label: l10n.setupCardDelivery,
                    done: setupCardDeliveryDone(prefs),
                    onTap: onOpenDelivery,
                  ),
                _SetupRow(
                  rowKey: SetupChecklistCard.remindersKey,
                  label: l10n.setupCardReminders,
                  done: flags.remindersSeen,
                  onTap: onOpenReminders,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _dismiss(WidgetRef ref) async {
    final store = ref.read(setupCardStoreProvider);
    final latest = await store.read();
    await store.write(latest.copyWith(dismissed: true));
    ref.invalidate(setupCardFlagsProvider);
  }

  Future<void> _chooseThisPhone(WidgetRef ref) async {
    final store = ref.read(setupCardStoreProvider);
    final latest = await store.read();
    await store.write(latest.copyWith(noSpeaker: true));
    ref.invalidate(setupCardFlagsProvider);
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.rowKey,
    required this.label,
    required this.done,
    required this.onTap,
  });

  final Key rowKey;
  final String label;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: PrayerCastTheme.minTap),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: PrayerCastTheme.bodyFont,
                  fontSize: 16,
                  height: 1.4,
                  color: PrayerCastColors.ink,
                ),
              ),
            ),
            if (done) PremiumIcons.check(size: 18, color: PrayerCastColors.ink),
          ],
        ),
      ),
    );
  }
}
