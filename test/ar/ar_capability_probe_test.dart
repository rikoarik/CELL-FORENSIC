import 'package:cell_forensic/ar/ar_capability_probe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('cell_forensic/ar_capability');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    ArCapabilityProbe.debugProbeOverride = null;
  });

  group('isFatalLiveArInitFailure', () {
    test('treats permanent unsupported / create failures as fatal', () {
      expect(isFatalLiveArInitFailure('AR not supported on this device'), isTrue);
      expect(isFatalLiveArInitFailure('Failed to create session'), isTrue);
      expect(isFatalLiveArInitFailure('Device is not compatible'), isTrue);
      expect(
        isFatalLiveArInitFailure('ARCore failed to initialize'),
        isTrue,
      );
      expect(isFatalLiveArInitFailure('ARCore unavailable'), isTrue);
      expect(isFatalLiveArInitFailure('ARCore not installed'), isTrue);
    });

    test('does not soft-fallback on tracking or transient session messages', () {
      expect(isFatalLiveArInitFailure('Tracking lost'), isFalse);
      expect(isFatalLiveArInitFailure('Relocalization required'), isFalse);
      expect(isFatalLiveArInitFailure('Tracking limited'), isFalse);
      // Plugin mid-op noise — must stay on live ARView before/after place.
      expect(isFatalLiveArInitFailure('AR Session is not available'), isFalse);
      expect(
        isFatalLiveArInitFailure('Cloud Anchor Service unavailable'),
        isFalse,
      );
      expect(isFatalLiveArInitFailure('something went wrong'), isFalse);
    });
  });

  test('maps Android probe payload to supported result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'probe');
          expect(call.arguments['requestCameraPermission'], isTrue);
          return <String, Object?>{
            'supported': true,
            'reason': 'arcore_supported',
            'arcoreAvailability': 'SUPPORTED_INSTALLED',
            'cameraGranted': true,
            'hasCameraArFeature': false,
          };
        });

    final result = await ArCapabilityProbe().probe();
    expect(result.supported, isTrue);
    expect(result.reason, 'arcore_supported');
    expect(result.arcoreAvailability, 'SUPPORTED_INSTALLED');
    expect(result.hasCameraArFeature, isFalse);
  });

  test('debugOverride bypasses MethodChannel', () async {
    final probe = ArCapabilityProbe(
      debugOverride: () async =>
          const ArCapabilityResult(supported: false, reason: 'forced'),
    );
    final result = await probe.probe();
    expect(result.supported, isFalse);
    expect(result.reason, 'forced');
  });

  test('unsupportedDesktop constant gates browser/desktop AR', () {
    expect(ArCapabilityProbe.unsupportedDesktop.supported, isFalse);
    expect(ArCapabilityProbe.unsupportedDesktop.reason, 'platform_unsupported');
    expect(ArCapabilityProbe.unsupportedDesktop.platform, 'desktop_or_web');
    expect(ArCapabilityProbe.unsupportedDesktop.probed, isTrue);
  });

  test('maps iOS ARKit probe payload to supported result', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'probe');
          expect(call.arguments['requestCameraPermission'], isTrue);
          return <String, Object?>{
            'supported': true,
            'reason': 'arkit_supported',
            'arcoreAvailability': 'ARKIT_WORLD_TRACKING_SUPPORTED',
            'cameraGranted': true,
            'hasCameraArFeature': true,
          };
        });

    final result = await ArCapabilityProbe().probe();
    expect(result.supported, isTrue);
    expect(result.reason, 'arkit_supported');
    expect(result.platform, 'iOS');
    expect(result.arcoreAvailability, 'ARKIT_WORLD_TRACKING_SUPPORTED');
    expect(result.hasCameraArFeature, isTrue);
  });
}
