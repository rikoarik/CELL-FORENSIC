import 'package:cell_forensic/core/app_services.dart';
import 'package:cell_forensic/core/routing/url_strategy.dart';
import 'package:flutter/widgets.dart';

import 'app/cell_forensic_app.dart';
export 'app/cell_forensic_app.dart';

/// Default entry — student journey and teacher dashboard in one web build.
///
/// ```bash
/// flutter run -t lib/main.dart
/// flutter run -d chrome -t lib/main.dart
/// ```
///
/// Web routes: `/` for students, `/guru` (or `/dashboard`) for teachers.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configurePathUrlStrategy();
  await AppServices.ensureInitialized();
  runApp(const CellForensicApp());
}
