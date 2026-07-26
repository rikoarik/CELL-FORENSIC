import 'package:cell_forensic/core/app_services.dart';
import 'package:flutter/widgets.dart';

import 'app/cell_forensic_app.dart';

/// Flutter Web teacher dashboard entry (E1-02).
///
/// ```bash
/// flutter run -d chrome -t lib/main_dashboard.dart
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.ensureInitialized();
  runApp(const CellForensicApp.dashboard());
}
