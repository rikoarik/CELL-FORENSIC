import 'package:cell_forensic/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mobile menampilkan brand dan CTA aksesibel', (tester) async {
    await tester.pumpWidget(const CellForensicApp());

    expect(find.text('Cell Forensic'), findsOneWidget);
    expect(find.text('Masuk Sesi'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.bySemanticsLabel('Masuk ke sesi praktikum'), findsOneWidget);
  });
}
