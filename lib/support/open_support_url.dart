import 'package:flutter/material.dart';
import 'package:prayer_cast/support/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the developer Ko-fi page in an external browser.
Future<void> openSupportUrl(BuildContext context) async {
  final uri = Uri.parse(AppLinks.donateUrl);
  try {
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
