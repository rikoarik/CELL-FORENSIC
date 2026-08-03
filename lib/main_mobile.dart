import 'package:cell_forensic/core/app_services.dart';
import 'package:cell_forensic/core/routing/url_strategy.dart';
import 'package:flutter/widgets.dart';

import 'app/cell_forensic_app.dart';

/// Explicit student / mobile entry (same experience as [main.dart]).
///
/// ```bash
/// flutter run -t lib/main_mobile.dart
/// flutter run -d chrome -t lib/main_mobile.dart
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configurePathUrlStrategy();
  await AppServices.ensureInitialized();
  runApp(const CellForensicApp());
}
