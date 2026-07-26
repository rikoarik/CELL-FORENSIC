import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/investigation/investigation_sync.dart';
import 'package:cell_forensic/features/journey/screens/investigation/conclusion_screen.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sampleAIdentityKey = Key('conclusion-sample-a-identity');
const _sampleAReasoningKey = Key('conclusion-sample-a-reasoning');
const _sampleBIdentityKey = Key('conclusion-sample-b-identity');
const _sampleBReasoningKey = Key('conclusion-sample-b-reasoning');
const _hypothesisKey = Key('conclusion-hypothesis');
const _submitKey = Key('conclusion-submit');

StudentJourney _atConclusion() {
  return StudentJourney(content: buildLocalContentPack())
    ..completeDeviceCheck(arSupported: false)
    ..joinWithGroup(groupName: 'Tim A', leaderName: 'Budi')
    ..debugCompleteAllMissionsToConclusion();
}

Widget _wrap(Widget child) => MaterialApp(home: child);

Future<void> _fillAll(WidgetTester tester) async {
  await tester.enterText(find.byKey(_sampleAIdentityKey), 'Sel tumbuhan');
  await tester.enterText(find.byKey(_sampleAReasoningKey), 'Punya dinding sel');
  await tester.enterText(find.byKey(_sampleBIdentityKey), 'Sel hewan');
  await tester.enterText(find.byKey(_sampleBReasoningKey), 'Membran robek');
  await tester.enterText(find.byKey(_hypothesisKey), 'Sampel A lebih tahan.');
}

void main() {
  testWidgets('menampilkan lima field kesimpulan', (tester) async {
    final journey = _atConclusion();
    await tester.pumpWidget(_wrap(ConclusionScreen(journey: journey)));

    expect(find.byKey(_sampleAIdentityKey), findsOneWidget);
    expect(find.byKey(_sampleAReasoningKey), findsOneWidget);
    expect(find.byKey(_sampleBIdentityKey), findsOneWidget);
    expect(find.byKey(_sampleBReasoningKey), findsOneWidget);
    expect(find.byKey(_hypothesisKey), findsOneWidget);
    expect(find.byKey(_submitKey), findsOneWidget);
  });

  testWidgets('submit tanpa mengisi menampilkan lastError', (tester) async {
    final journey = _atConclusion();
    await tester.pumpWidget(_wrap(ConclusionScreen(journey: journey)));

    await tester.tap(find.byKey(_submitKey));
    await tester.pump();

    expect(journey.stage, JourneyStage.conclusion);
    expect(journey.lastError, isNotNull);
    expect(find.textContaining('Lengkapi semua field'), findsOneWidget);
  });

  testWidgets('submit lengkap memajukan ke tahap stations', (tester) async {
    final journey = _atConclusion();
    await tester.pumpWidget(_wrap(ConclusionScreen(journey: journey)));

    await _fillAll(tester);
    await tester.tap(find.byKey(_submitKey));
    await tester.pump();

    expect(journey.lastError, isNull);
    expect(journey.stage, JourneyStage.stations);
  });

  testWidgets('mengetik field mengisi conclusionDraft (autosave)', (
    tester,
  ) async {
    final journey = _atConclusion();
    await tester.pumpWidget(_wrap(ConclusionScreen(journey: journey)));

    await tester.enterText(find.byKey(_sampleAIdentityKey), 'Sel tumbuhan');
    await tester.pump();

    expect(journey.conclusionDraft, isNotNull);
    expect(journey.conclusionDraft!.sampleAIdentity, 'Sel tumbuhan');
  });

  testWidgets('memulihkan draft kesimpulan dari journey', (tester) async {
    final journey = _atConclusion()
      ..saveConclusionDraft(
        const ConclusionDraft(
          sampleAIdentity: 'Draft A',
          sampleAReasoning: 'Alasan A',
          sampleBIdentity: 'Draft B',
          sampleBReasoning: 'Alasan B',
          hypothesis: 'Hipotesis draft',
        ),
      );

    await tester.pumpWidget(_wrap(ConclusionScreen(journey: journey)));

    expect(find.text('Draft A'), findsOneWidget);
    expect(find.text('Hipotesis draft'), findsOneWidget);
  });
}
