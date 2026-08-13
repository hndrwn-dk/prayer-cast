import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces spec §7: `presence` and `coordination` must not import `delivery`.
void main() {
  test('presence and coordination do not import delivery', () {
    final roots = [
      Directory('lib/home_delivery/presence'),
      Directory('lib/home_delivery/coordination'),
    ];

    final violations = <String>[];
    final importDelivery = RegExp(
      r'''import\s+['"]([^'"]*delivery[^'"]*)['"]''',
    );

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final match in importDelivery.allMatches(source)) {
          final uri = match.group(1)!;
          // Allow nothing under home_delivery/delivery/.
          if (uri.contains('home_delivery/delivery') ||
              uri.contains('/delivery/') ||
              uri.startsWith('delivery/') ||
              uri.contains('package:prayer_cast/home_delivery/delivery')) {
            violations.add('${entity.path} imports $uri');
          }
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
