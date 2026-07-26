import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/screens/intro/device_check_screen.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StudentJourney _journey() => StudentJourney(content: buildLocalContentPack());

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('shows AR support explanation and both mode buttons', (
    tester,
  ) async {
    final journey = _journey();
    await tester.pumpWidget(_wrap(DeviceCheckScreen(journey: journey)));

    expect(find.text('AR Didukung'), findsOneWidget);
    expect(find.text('Gunakan Mode 3D'), findsOneWidget);
    // Some explanation about AR support is present.
    expect(find.textContaining('AR'), findsWidgets);
  });

  testWidgets('AR Didukung completes device check as AR supported', (
    tester,
  ) async {
    final journey = _journey();
    await tester.pumpWidget(_wrap(DeviceCheckScreen(journey: journey)));

    await tester.tap(find.text('AR Didukung'));
    await tester.pump();

    expect(journey.stage, JourneyStage.joinSession);
    expect(journey.arSupported, isTrue);
  });

  testWidgets('Gunakan Mode 3D completes device check without AR', (
    tester,
  ) async {
    final journey = _journey();
    await tester.pumpWidget(_wrap(DeviceCheckScreen(journey: journey)));

    await tester.tap(find.text('Gunakan Mode 3D'));
    await tester.pump();

    expect(journey.stage, JourneyStage.joinSession);
    expect(journey.arSupported, isFalse);
  });
}
