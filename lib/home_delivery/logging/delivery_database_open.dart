import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'delivery_database.dart';

/// Opens the on-device delivery log database (app shell only).
///
/// WHY: The home_delivery layer itself stays free of `path_provider`; the
/// shell picks the documents directory and injects [DeliveryDatabase].
Future<DeliveryDatabase> openDeliveryDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'delivery_log.sqlite'));
  return DeliveryDatabase(NativeDatabase.createInBackground(file));
}
