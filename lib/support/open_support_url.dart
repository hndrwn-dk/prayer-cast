import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:prayer_cast/support/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

/// Test hook that replaces the platform URL launch path when non-null.
@visibleForTesting
Future<bool> Function(Uri uri)? debugLaunchExternalUrl;

/// Opens [url] in an external browser. Shared by Ko-fi and the privacy policy.
Future<void> openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  try {
    final override = debugLaunchExternalUrl;
    if (override != null) {
      final launched = await override(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

/// Opens the developer Ko-fi page in an external browser.
Future<void> openSupportUrl(BuildContext context) {
  return openExternalUrl(context, AppLinks.donateUrl);
}

/// Opens the public Prayer Cast privacy policy in an external browser.
Future<void> openPrivacyPolicyUrl(BuildContext context) {
  return openExternalUrl(context, AppLinks.privacyPolicyUrl);
}
