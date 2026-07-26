import 'package:cell_forensic/core/app_services.dart';
import 'package:flutter/widgets.dart';

import 'app/cell_forensic_app.dart';
export 'app/cell_forensic_app.dart';

/// Default entry — student journey (Android **or** Chrome web).
///
/// ```bash
/// flutter run -t lib/main.dart
/// flutter run -d chrome -t lib/main.dart
/// ```
///
/// Teacher dashboard: `flutter run -d chrome -t lib/main_dashboard.dart`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.ensureInitialized();
  runApp(const CellForensicApp());
}
