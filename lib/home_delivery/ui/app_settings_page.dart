import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_cast/l10n/l10n_ext.dart';
import 'package:prayer_cast/l10n/locale_controller.dart';
import 'package:prayer_cast/support/app_links.dart';
import 'package:prayer_cast/support/open_support_url.dart';
import 'package:prayer_cast/support/share_plain_text.dart';

import 'delivery_log_page.dart';
import 'icons/premium_icons.dart';
import 'theme/prayer_cast_colors.dart';
import 'theme/prayer_cast_theme.dart';
import 'widgets/editorial_chrome.dart';

/// Language, adhan history, about, and legal — off the home screen.
class AppSettingsPage extends ConsumerWidget {
  const AppSettingsPage({super.key, required this.version});

  final String version;

  static const ValueKey<String> keyName = ValueKey<String>('app_settings_page');
  static const ValueKey<String> languageIdKey = ValueKey<String>(
    'settings_language_id',
  );
  static const ValueKey<String> languageEnKey = ValueKey<String>(
    'settings_language_en',
  );
  static const ValueKey<String> deliveryLogKey = ValueKey<String>(
    'settings_delivery_log',
  );
  static const ValueKey<String> rateKey = ValueKey<String>('settings_rate');
  static const ValueKey<String> shareKey = ValueKey<String>('settings_share');
  static const ValueKey<String> privacyKey = ValueKey<String>(
    'settings_privacy',
  );
  static const ValueKey<String> versionKey = ValueKey<String>(
    'settings_version',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final localeOverride = ref.watch(appLocaleProvider);
    final activeLang =
        localeOverride?.languageCode ??
        Localizations.localeOf(context).languageCode;

    return Theme(
      data: PrayerCastTheme.forest(),
      child: ForestScaffold(
        header: EditorialPageHeader(
          title: l10n.settings,
          backTooltip: l10n.back,
          onBack: () => Navigator.of(context).maybePop(),
        ),
        body: SingleChildScrollView(
          key: keyName,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EditorialEyebrow(l10n.language, color: PrayerCastColors.dawn),
              const SizedBox(height: 6),
              Text(
                l10n.languageHint,
                style: const TextStyle(
                  fontFamily: PrayerCastTheme.bodyFont,
                  fontSize: 13,
                  height: 1.35,
                  color: PrayerCastColors.mistDeep,
                ),
              ),
              const SizedBox(height: 8),
              _LanguageChoice(
                rowKey: languageIdKey,
                label: l10n.languageIndonesian,
                selected: activeLang == 'id',
                onTap: () => ref
                    .read(appLocaleProvider.notifier)
                    .setLocale(const Locale('id')),
              ),
              _LanguageChoice(
                rowKey: languageEnKey,
                label: l10n.languageEnglish,
                selected: activeLang == 'en',
                onTap: () => ref
                    .read(appLocaleProvider.notifier)
                    .setLocale(const Locale('en')),
              ),
              const SizedBox(height: 28),
              _SettingsLink(
                rowKey: deliveryLogKey,
                title: l10n.deliveryLog,
                subtitle: l10n.deliveryLogHint,
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (_, __, ___) => const DeliveryLogPage(),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 280),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              EditorialEyebrow(l10n.aboutEyebrow, color: PrayerCastColors.dawn),
              const SizedBox(height: 8),
              _SettingsFact(
                rowKey: versionKey,
                title: l10n.appVersion,
                subtitle: version,
              ),
              _SettingsLink(
                rowKey: rateKey,
                title: l10n.rateApp,
                subtitle: l10n.rateAppHint,
                onTap: () => openPlayStoreUrl(context),
              ),
              _SettingsLink(
                rowKey: shareKey,
                title: l10n.shareApp,
                subtitle: l10n.shareAppHint,
                onTap: () =>
                    sharePlainText(l10n.shareAppMessage(AppLinks.playStoreUrl)),
              ),
              const SizedBox(height: 28),
              EditorialEyebrow(l10n.legalEyebrow, color: PrayerCastColors.dawn),
              const SizedBox(height: 8),
              _SettingsLink(
                rowKey: privacyKey,
                title: l10n.privacyPolicy,
                subtitle: l10n.privacyPolicyHint,
                onTap: () => openPrivacyPolicyUrl(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.rowKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key rowKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: rowKey,
          onTap: onTap,
          child: SizedBox(
            height: PrayerCastTheme.minTap,
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: PrayerCastTheme.forestDropdown),
                ),
                if (selected)
                  PremiumIcons.check(size: 18, color: PrayerCastColors.dawn),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsFact extends StatelessWidget {
  const _SettingsFact({
    required this.rowKey,
    required this.title,
    required this.subtitle,
  });

  final Key rowKey;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: PrayerCastTheme.displayFont,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
              color: PrayerCastColors.surfaceRaised,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: PrayerCastTheme.bodyFont,
              fontSize: 13,
              height: 1.35,
              color: PrayerCastColors.mistDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.rowKey,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final Key rowKey;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: rowKey,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: PrayerCastTheme.displayFont,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          color: PrayerCastColors.surfaceRaised,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontFamily: PrayerCastTheme.bodyFont,
                            fontSize: 13,
                            height: 1.35,
                            color: PrayerCastColors.mistDeep,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PremiumIcons.caretRight(size: 18, color: PrayerCastColors.mist),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
