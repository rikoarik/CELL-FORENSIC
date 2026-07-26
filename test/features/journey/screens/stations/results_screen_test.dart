import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/screens/stations/results_screen.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StudentJourney _completedJourney() {
  final journey = StudentJourney(content: buildLocalContentPack())
    ..completeDeviceCheck(arSupported: false)
    ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
    ..debugCompleteAllMissionsToConclusion();
  journey.submitInvestigation(
    sampleAIdentity: 'Sel tumbuhan',
    sampleAReasoning: 'Dinding sel',
    sampleBIdentity: 'Sel hewan',
    sampleBReasoning: 'Membran robek',
    hypothesis: 'Bukti mendukung.',
  );
  journey
    ..unlockStation('1111')
    ..answerQuestion('POS1-Q1', 'Sampel A')
    ..answerQuestion('POS1-Q2', 'Melindungi sel')
    ..submitActiveStation()
    ..unlockStation('2222')
    ..answerQuestion('POS2-Q1', 'Membran')
    ..answerQuestion('POS2-Q2', 'Isi sel bocor')
    ..submitActiveStation()
    ..unlockStation('3333')
    ..answerQuestion('POS3-Q1', 'Tumbuhan')
    ..answerQuestion('POS3-Q2', 'Hipotesis akhir')
    ..submitActiveStation();
  return journey;
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('shows the objective auto-score total', (tester) async {
    final journey = _completedJourney();
    await tester.pumpWidget(_wrap(ResultsScreen(journey: journey)));

    expect(find.textContaining('30'), findsWidgets);
  });

  testWidgets('notes that essays await teacher review when pending', (
    tester,
  ) async {
    final journey = _completedJourney();
    expect(journey.pendingTeacherReview, isTrue);
    await tester.pumpWidget(_wrap(ResultsScreen(journey: journey)));

    expect(find.textContaining('guru'), findsWidgets);
  });

  testWidgets('shows a completion message', (tester) async {
    final journey = _completedJourney();
    await tester.pumpWidget(_wrap(ResultsScreen(journey: journey)));

    expect(find.textContaining('selesai'), findsWidgets);
  });
}
