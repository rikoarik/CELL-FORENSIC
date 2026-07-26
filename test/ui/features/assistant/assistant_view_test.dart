import 'package:cell_forensic/domain/intent_matcher.dart';
import 'package:cell_forensic/ui/features/assistant/assistant_view.dart';
import 'package:cell_forensic/ui/features/assistant/assistant_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sendButtonKey = Key('assistant-send-button');
const _inputKey = Key('assistant-input');

IntentMatcher _buildMatcher() => IntentMatcher(const [
  IntentRule(
    code: 'inspect_sample_a_organel',
    keywords: {'sampel a', 'organel'},
    response: 'Kloroplas dan vakuola merupakan organel pada sel tumbuhan.',
    sequenceCode: 'SEQ-MISI-1',
  ),
  IntentRule(
    code: 'request_hint',
    keywords: {'petunjuk'},
    response: 'Coba tanyakan organel pada Sampel A.',
  ),
]);

Future<void> _pumpView(
  WidgetTester tester,
  AssistantViewModel viewModel,
) async {
  await tester.pumpWidget(
    MaterialApp(home: AssistantView(viewModel: viewModel)),
  );
}

void main() {
  testWidgets(
    'menampilkan balasan asisten dari IntentMatcher setelah mengirim',
    (tester) async {
      final viewModel = AssistantViewModel(matcher: _buildMatcher());
      await _pumpView(tester, viewModel);

      await tester.enterText(
        find.byKey(_inputKey),
        'lihat organel pada sampel a',
      );
      await tester.tap(find.byKey(_sendButtonKey));
      await tester.pump();

      expect(find.text('lihat organel pada sampel a'), findsOneWidget);
      expect(
        find.text('Kloroplas dan vakuola merupakan organel pada sel tumbuhan.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('menampilkan respons unknown untuk pertanyaan tak dikenal', (
    tester,
  ) async {
    final viewModel = AssistantViewModel(matcher: _buildMatcher());
    await _pumpView(tester, viewModel);

    await tester.enterText(find.byKey(_inputKey), 'apa warna langit?');
    await tester.tap(find.byKey(_sendButtonKey));
    await tester.pump();

    expect(find.text(IntentMatcher.unknownResponse), findsOneWidget);
  });

  testWidgets('riwayat bertambah dan input dikosongkan setelah kirim', (
    tester,
  ) async {
    final viewModel = AssistantViewModel(matcher: _buildMatcher());
    await _pumpView(tester, viewModel);

    expect(viewModel.messages, isEmpty);

    await tester.enterText(find.byKey(_inputKey), 'minta petunjuk dong');
    await tester.tap(find.byKey(_sendButtonKey));
    await tester.pump();

    // Satu pesan pengguna + satu balasan asisten.
    expect(viewModel.messages.length, 2);
    expect(viewModel.messages.first.author, ChatAuthor.user);
    expect(viewModel.messages.last.author, ChatAuthor.assistant);

    final field = tester.widget<TextField>(find.byKey(_inputKey));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('input kosong tidak menambah pesan', (tester) async {
    final viewModel = AssistantViewModel(matcher: _buildMatcher());
    await _pumpView(tester, viewModel);

    await tester.enterText(find.byKey(_inputKey), '    ');
    await tester.tap(find.byKey(_sendButtonKey));
    await tester.pump();

    expect(viewModel.messages, isEmpty);
  });

  testWidgets('memenuhi kebutuhan aksesibilitas dasar', (tester) async {
    final viewModel = AssistantViewModel(matcher: _buildMatcher());
    await _pumpView(tester, viewModel);

    final field = tester.widget<TextField>(find.byKey(_inputKey));
    expect(field.decoration?.labelText, isNotNull);
    expect(field.decoration!.labelText!.trim(), isNotEmpty);

    expect(find.bySemanticsLabel('Kirim pertanyaan'), findsOneWidget);

    final sendSize = tester.getSize(find.byKey(_sendButtonKey));
    expect(sendSize.width, greaterThanOrEqualTo(48));
    expect(sendSize.height, greaterThanOrEqualTo(48));
  });
}
