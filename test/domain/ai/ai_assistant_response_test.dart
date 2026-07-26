import 'package:cell_forensic/domain/ai/ai_assistant_response.dart';
import 'package:cell_forensic/domain/ai/ar_action_whitelist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses structured JSON and sanitizes ar_action', () {
    final parsed = AiAssistantResponse.tryParse({
      'message': 'Lihat kloroplas yang menyusut.',
      'intent': 'focus_chloroplast',
      'mission': 1,
      'target': 'chloroplast',
      'ar_action': 'highlight_chloroplast',
      'confidence': 0.95,
    });

    expect(parsed, isNotNull);
    expect(parsed!.message, contains('kloroplas'));
    expect(parsed.arAction, 'highlight_chloroplast');
    expect(
      parsed.resolvedAction(activeMission: 1),
      'highlight_chloroplast',
    );
  });

  test('unknown ar_action becomes none', () {
    final parsed = AiAssistantResponse.tryParse({
      'message': 'ok',
      'intent': 'x',
      'mission': 1,
      'target': '',
      'ar_action': 'invent_organelle',
      'confidence': 0.99,
    });
    expect(parsed!.arAction, ArActionWhitelist.none);
    expect(parsed.resolvedAction(activeMission: 1), ArActionWhitelist.none);
  });

  test('low confidence resolves to none', () {
    final parsed = AiAssistantResponse.tryParse({
      'message': 'ok',
      'intent': 'x',
      'mission': 1,
      'target': 'chloroplast',
      'ar_action': 'highlight_chloroplast',
      'confidence': 0.2,
    });
    expect(parsed!.resolvedAction(activeMission: 1), ArActionWhitelist.none);
  });

  test('rejects empty message', () {
    expect(AiAssistantResponse.tryParse({'message': '  '}), isNull);
  });
}
