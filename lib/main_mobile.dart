import 'package:cell_forensic/core/app_services.dart';
import 'package:flutter/widgets.dart';

import 'app/cell_forensic_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.ensureInitialized();
  runApp(const CellForensicApp());
}
