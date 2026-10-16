import 'package:flutter/material.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/ui/adhkar_page_body.dart';

/// Evening adhkar page with settings and reading guide.
class EveningAdhkarPage extends StatelessWidget {
  const EveningAdhkarPage({super.key});

  static const ValueKey<String> keyName =
      ValueKey<String>('evening_adhkar_page');

  @override
  Widget build(BuildContext context) {
    return const AdhkarPageBody(type: AdhkarType.evening, listKey: keyName);
  }
}
