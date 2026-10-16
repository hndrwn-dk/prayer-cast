import 'package:flutter/material.dart';
import 'package:prayer_cast/dhikr/models/adhkar_type.dart';
import 'package:prayer_cast/dhikr/ui/adhkar_page_body.dart';

/// Morning adhkar page with settings and reading guide.
class MorningAdhkarPage extends StatelessWidget {
  const MorningAdhkarPage({super.key});

  static const ValueKey<String> keyName =
      ValueKey<String>('morning_adhkar_page');

  @override
  Widget build(BuildContext context) {
    return const AdhkarPageBody(type: AdhkarType.morning, listKey: keyName);
  }
}
