import 'package:cell_forensic/ar/ar_capability_probe.dart';
import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/screens/intro/device_check_screen.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StudentJourney _journey() => StudentJourney(content: buildLocalContentPack());

Widget _wrap(Widget child) => MaterialApp(home: child);

ArCapabilityProbe _probe(ArCapabilityResult result) =>
    ArCapabilityProbe(debugOverride: () async => result);

void main() {
  tearDown(() {
    ArCapabilityProbe.debugProbeOverride = null;
  });

  testWidgets('shows loading then AR continue when probe supports AR', (
    tester,
  ) async {
    final journey = _journey();
    await tester.pumpWidget(
      _wrap(
        DeviceCheckScreen(
          journey: journey,
          probe: _probe(
            const ArCapabilityResult(
              supported: true,
              reason: 'arcore_supported',
              platform: 'android',
              arcoreAvailability: 'SUPPORTED_INSTALLED',
              cameraGranted: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('device-check-loading')), findsOneWidget);
    await tester.pump(); // post-frame probe start
    await tester.pump(); // probe completes

    expect(find.byKey(const Key('device-check-continue-ar')), findsOneWidget);
    expect(find.text('Gunakan Mode 3D'), findsNothing);
    expect(find.textContaining('AR siap'), findsOneWidget);

    await tester.tap(find.byKey(const Key('device-check-continue-ar')));
    await tester.pump();

    expect(journey.stage, JourneyStage.joinSession);
    expect(journey.arSupported, isTrue);
  });

  testWidgets('offers Mode 3D only when probe reports unsupported', (
    tester,
  ) async {
    final journey = _journey();
    await tester.pumpWidget(
      _wrap(
        DeviceCheckScreen(
          journey: journey,
          probe: _probe(
            const ArCapabilityResult(
              supported: false,
              reason: 'arcore_unsupported_device',
              platform: 'android',
              arcoreAvailability: 'UNSUPPORTED_DEVICE_NOT_CAPABLE',
              cameraGranted: true,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('device-check-continue-3d')), findsOneWidget);
    expect(find.byKey(const Key('device-check-continue-ar')), findsNothing);

    await tester.tap(find.byKey(const Key('device-check-continue-3d')));
    await tester.pump();

    expect(journey.stage, JourneyStage.joinSession);
    expect(journey.arSupported, isFalse);
  });

  testWidgets('ARCore runtime unavailable routes mobile to Mode 3D', (
    tester,
  ) async {
    for (final result in [
      const ArCapabilityResult(
        supported: false,
        reason: 'arcore_not_installed',
        platform: 'android',
        arcoreAvailability: 'SUPPORTED_NOT_INSTALLED',
        cameraGranted: true,
        hasCameraArFeature: true,
      ),
      const ArCapabilityResult(
        supported: false,
        reason: 'arcore_apk_too_old',
        platform: 'android',
        arcoreAvailability: 'SUPPORTED_APK_TOO_OLD',
        cameraGranted: true,
        hasCameraArFeature: true,
      ),
    ]) {
      final journey = _journey();
      await tester.pumpWidget(
        _wrap(DeviceCheckScreen(journey: journey, probe: _probe(result))),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('device-check-continue-3d')), findsOneWidget);
      expect(find.byKey(const Key('device-check-continue-ar')), findsNothing);
      expect(find.textContaining('menggunakan Mode 3D'), findsOneWidget);

      await tester.tap(find.byKey(const Key('device-check-continue-3d')));
      await tester.pump();
      expect(journey.arSupported, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('retry re-runs probe after camera denial', (tester) async {
    var calls = 0;
    final journey = _journey();
    final probe = ArCapabilityProbe(
      debugOverride: () async {
        calls++;
        if (calls == 1) {
          return const ArCapabilityResult(
            supported: false,
            reason: 'camera_permission_denied',
            platform: 'android',
            cameraGranted: false,
          );
        }
        return const ArCapabilityResult(
          supported: true,
          reason: 'arcore_supported',
          platform: 'android',
          arcoreAvailability: 'SUPPORTED_INSTALLED',
          cameraGranted: true,
        );
      },
    );

    await tester.pumpWidget(
      _wrap(DeviceCheckScreen(journey: journey, probe: probe)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('izin kamera'), findsOneWidget);
    await tester.tap(find.byKey(const Key('device-check-retry')));
    await tester.pump();
    await tester.pump();

    expect(calls, 2);
    expect(find.byKey(const Key('device-check-continue-ar')), findsOneWidget);
  });

  testWidgets('platform unsupported menawarkan Mode 3D dengan copy browser', (
    tester,
  ) async {
    final journey = _journey();
    await tester.pumpWidget(
      _wrap(
        DeviceCheckScreen(
          journey: journey,
          probe: _probe(ArCapabilityProbe.unsupportedDesktop),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('device-check-continue-3d')), findsOneWidget);
    expect(
      find.textContaining('Browser / desktop tidak menjalankan AR'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('device-check-continue-3d')));
    await tester.pump();

    expect(journey.arSupported, isFalse);
    expect(journey.stage, JourneyStage.joinSession);
  });

  testWidgets('arkit_supported offers Lanjut Mode AR', (tester) async {
    final journey = _journey();
    await tester.pumpWidget(
      _wrap(
        DeviceCheckScreen(
          journey: journey,
          probe: _probe(
            const ArCapabilityResult(
              supported: true,
              reason: 'arkit_supported',
              platform: 'iOS',
              arcoreAvailability: 'ARKIT_WORLD_TRACKING_SUPPORTED',
              cameraGranted: true,
              hasCameraArFeature: true,
              probed: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Lanjut Mode AR'), findsOneWidget);
    expect(find.byKey(const Key('device-check-continue-ar')), findsOneWidget);
    expect(find.text('Gunakan Mode 3D'), findsNothing);

    await tester.tap(find.byKey(const Key('device-check-continue-ar')));
    await tester.pump();

    expect(journey.arSupported, isTrue);
    expect(journey.stage, JourneyStage.joinSession);
  });

  testWidgets('arkit_unsupported_device offers Mode 3D', (tester) async {
    final journey = _journey();
    await tester.pumpWidget(
      _wrap(
        DeviceCheckScreen(
          journey: journey,
          probe: _probe(
            const ArCapabilityResult(
              supported: false,
              reason: 'arkit_unsupported_device',
              platform: 'iOS',
              probed: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Gunakan Mode 3D'), findsOneWidget);
    expect(find.text('Lanjut Mode AR'), findsNothing);
    expect(find.textContaining('tidak mendukung ARKit'), findsOneWidget);
  });
}
