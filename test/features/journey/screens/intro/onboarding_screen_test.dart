import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/screens/intro/onboarding_screen.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StudentJourney _journey() => StudentJourney(content: buildLocalContentPack())
  ..completeDeviceCheck(arSupported: true)
  ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi');

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('shows the tutorial steps and start button', (tester) async {
    final journey = _journey();
    await tester.pumpWidget(_wrap(OnboardingScreen(journey: journey)));

    expect(find.textContaining('Pindai'), findsWidgets);
    expect(find.text('Mulai Investigasi'), findsOneWidget);

    // Logbook step sits lower in the lazily-built list; scroll it into view.
    await tester.scrollUntilVisible(
      find.textContaining('Logbook'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Logbook'), findsWidgets);
  });

  testWidgets('Mulai Investigasi finishes onboarding', (tester) async {
    final journey = _journey();
    await tester.pumpWidget(_wrap(OnboardingScreen(journey: journey)));

    await tester.tap(find.text('Mulai Investigasi'));
    await tester.pump();

    expect(journey.stage, JourneyStage.investigating);
  });
}
