import 'package:cell_forensic/app/mobile_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('student home memakai layout ringkas pada layar sempit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MobileHome()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('student-compact-layout')), findsOneWidget);
    expect(find.byKey(const Key('student-enter-session')), findsOneWidget);
    expect(find.text('Masuk Sesi'), findsOneWidget);
  });

  testWidgets('student home membatasi lebar pada layar lebar', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MobileHome()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('student-wide-layout')), findsOneWidget);
  });
}
