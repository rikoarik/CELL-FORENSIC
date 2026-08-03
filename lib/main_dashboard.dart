import 'package:cell_forensic/core/app_services.dart';
import 'package:cell_forensic/core/routing/url_strategy.dart';
import 'package:flutter/widgets.dart';

import 'app/cell_forensic_app.dart';

/// Flutter Web teacher dashboard entry (E1-02).
///
/// Not the default `flutter run -d chrome` target — that loads student
/// [main.dart]. Use this file explicitly:
///
/// ```bash
/// flutter run -d chrome -t lib/main_dashboard.dart
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configurePathUrlStrategy();
  await AppServices.ensureInitialized();
  runApp(const CellForensicApp.dashboard());
}
