import 'package:cell_forensic/domain/ai/ai_assistant_client.dart';
import 'package:cell_forensic/domain/ai/ai_assistant_response.dart';
import 'package:cell_forensic/domain/ai/ar_action_whitelist.dart';
import 'package:cell_forensic/domain/intent_matcher.dart';
import 'package:cell_forensic/ui/features/assistant/assistant_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntentMatcher matcher() => IntentMatcher(const [
    IntentRule(
      code: 'inspect_sample_a_organel',
      keywords: {'sampel a', 'organel'},
      response: 'Balasan lokal IntentMatcher.',
      sequenceCode: 'SEQ-MISI-1',
    ),
  ]);

  test('API failure falls back to IntentMatcher without clearing state',
      () async {
    final fake = FakeAiAssistantClient(error: Exception('network down'));
    final actions = <String>[];
    final sequences = <String>[];
    final vm = AssistantViewModel(
      matcher: matcher(),
      aiClient: fake,
      missionNumber: 1,
      onArAction: actions.add,
      onSequenceCode: sequences.add,
    );

    await vm.send('amati organel pada sampel a');

    expect(fake.callCount, 1);
    expect(vm.messages.length, 2);
    expect(vm.messages.last.text, 'Balasan lokal IntentMatcher.');
    expect(vm.lastArAction, ArActionWhitelist.none);
    expect(actions, isEmpty);
    // Offline-equivalent fallback must still drive SequenceEngine.
    expect(vm.lastSequenceCode, 'SEQ-MISI-1');
    expect(sequences, ['SEQ-MISI-1']);
  });

  test('offline path (null aiClient) emits sequenceCode for AR', () async {
    final sequences = <String>[];
    final vm = AssistantViewModel(
      matcher: matcher(),
      missionNumber: 1,
      onSequenceCode: sequences.add,
    );

    await vm.send('amati organel pada sampel a');

    expect(vm.messages.last.sequenceCode, 'SEQ-MISI-1');
    expect(vm.lastSequenceCode, 'SEQ-MISI-1');
    expect(vm.lastArAction, ArActionWhitelist.none);
    expect(sequences, ['SEQ-MISI-1']);
  });

  test('valid AI action is emitted; mission mismatch strips action', () async {
    final response = AiAssistantResponse(
      message: 'Fokus ke kloroplas.',
      intent: 'highlight',
      mission: 1,
      target: 'chloroplast',
      arAction: 'highlight_chloroplast',
      confidence: 0.95,
    );
    final fake = FakeAiAssistantClient(response: response);
    // Sanity: fake client itself returns structured JSON fields.
    final direct = await fake.ask(message: 'ping', mission: 1);
    expect(direct.message, 'Fokus ke kloroplas.');
    fake.callCount = 0;

    final actions = <String>[];
    final vm = AssistantViewModel(
      matcher: matcher(),
      aiClient: fake,
      missionNumber: 1,
      onArAction: (action) => actions.add(action),
    );

    await vm.send('tunjukkan kloroplas');
    expect(fake.callCount, 1);
    expect(
      vm.messages.map((m) => m.text).toList(),
      [
        'tunjukkan kloroplas',
        'Fokus ke kloroplas.',
      ],
    );
    expect(actions, ['highlight_chloroplast']);

    fake.response = const AiAssistantResponse(
      message: 'Bandingkan sampel.',
      intent: 'compare',
      mission: 3,
      target: '',
      arAction: 'compare_samples',
      confidence: 0.99,
    );
    actions.clear();
    await vm.send('bandingkan');
    expect(vm.messages.last.text, 'Bandingkan sampel.');
    expect(vm.lastArAction, ArActionWhitelist.none);
    expect(actions, isEmpty);
  });

  test('provisional labels never call AI client', () async {
    final fake = FakeAiAssistantClient(
      response: const AiAssistantResponse(
        message: 'should not appear',
        intent: 'x',
        mission: 1,
        target: '',
        arAction: 'none',
        confidence: 1,
      ),
    );
    final vm = AssistantViewModel(
      matcher: matcher(),
      aiClient: fake,
      missionNumber: 1,
    );

    await vm.send('apa itu organel x');
    expect(fake.callCount, 0);
    expect(vm.messages.last.text, IntentMatcher.provisionalResponse);
  });
}
