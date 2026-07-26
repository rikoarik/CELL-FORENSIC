import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of an on-device AR readiness probe (FR-010 / FR-011).
@immutable
class ArCapabilityResult {
  const ArCapabilityResult({
    required this.supported,
    required this.reason,
    this.platform = '',
    this.arcoreAvailability = '',
    this.cameraGranted = false,
    this.hasCameraArFeature = false,
    this.probed = true,
  });

  /// Probe failed or is unavailable (tests / desktop) — do not claim support.
  static const unknown = ArCapabilityResult(
    supported: false,
    reason: 'unknown',
    probed: false,
  );

  /// True when live tabletop AR should be preferred over model_viewer_plus.
  final bool supported;

  /// Short machine/debug reason (also safe for Indonesian UI copy).
  final String reason;

  final String platform;
  final String arcoreAvailability;
  final bool cameraGranted;
  final bool hasCameraArFeature;

  /// False when the native channel could not be reached.
  final bool probed;

  @override
  String toString() =>
      'ArCapabilityResult(supported=$supported, reason=$reason, '
      'platform=$platform, arcore=$arcoreAvailability, '
      'camera=$cameraGranted, feature=$hasCameraArFeature, probed=$probed)';
}

/// Probes whether this device can run live tabletop AR.
///
/// Android uses ARCore (`MainActivity`); iOS uses ARKit (`AppDelegate`).
/// Desktop/web report `platform_unsupported`. [debugOverride] /
/// [debugProbeOverride] keep tests deterministic.
class ArCapabilityProbe {
  const ArCapabilityProbe({
    MethodChannel? channel,
    Future<ArCapabilityResult> Function()? debugOverride,
  }) : _channel = channel,
       _instanceOverride = debugOverride;

  static const unsupportedDesktop = ArCapabilityResult(
    supported: false,
    reason: 'platform_unsupported',
    platform: 'desktop_or_web',
    probed: true,
  );

  static const _defaultChannel = MethodChannel('cell_forensic/ar_capability');

  final MethodChannel? _channel;
  final Future<ArCapabilityResult> Function()? _instanceOverride;

  /// Global test hook (also used when instance override is null).
  @visibleForTesting
  static Future<ArCapabilityResult> Function()? debugProbeOverride;

  /// Alias kept for earlier tests / call sites.
  @visibleForTesting
  static Future<ArCapabilityResult> Function()? get debugOverride =>
      debugProbeOverride;

  @visibleForTesting
  static set debugOverride(Future<ArCapabilityResult> Function()? value) {
    debugProbeOverride = value;
  }

  Future<ArCapabilityResult> probe({bool requestCameraPermission = true}) async {
    final override = _instanceOverride ?? debugProbeOverride;
    if (override != null) return override();

    // Browser / desktop never get ARCore/ARKit; skip the channel round-trip.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return unsupportedDesktop;
    }

    // Always hit the MethodChannel (mocked in tests). MissingPluginException
    // on mobile builds → unsupported, not a false AR claim.
    final channel = _channel ?? _defaultChannel;
    try {
      final raw = await channel.invokeMethod<Map<Object?, Object?>>(
        'probe',
        <String, Object?>{'requestCameraPermission': requestCameraPermission},
      );
      if (raw == null) {
        return const ArCapabilityResult(
          supported: false,
          reason: 'probe_null',
          probed: false,
        );
      }
      final map = Map<String, Object?>.from(raw);
      final supported = map['supported'] == true;
      return ArCapabilityResult(
        supported: supported,
        reason: (map['reason'] as String?) ??
            (supported ? 'arcore_supported' : 'arcore_unsupported'),
        platform: defaultTargetPlatform.name,
        arcoreAvailability: (map['arcoreAvailability'] as String?) ?? '',
        cameraGranted: map['cameraGranted'] == true,
        hasCameraArFeature: map['hasCameraArFeature'] == true,
      );
    } on MissingPluginException {
      if (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux) {
        return unsupportedDesktop;
      }
      return ArCapabilityResult(
        supported: false,
        reason: 'missing_plugin',
        platform: defaultTargetPlatform.name,
        probed: false,
      );
    } on PlatformException catch (error) {
      debugPrint('ArCapabilityProbe failed: ${error.code} ${error.message}');
      return ArCapabilityResult(
        supported: false,
        reason: 'probe_error:${error.code}',
        platform: defaultTargetPlatform.name,
        probed: false,
      );
    }
  }
}

/// Soft ModelViewer fallback may activate **only** for permanent live-AR init
/// failures before a successful plane place (E11-A). Transient tracking /
/// session-not-ready messages must **not** flip the mission to 3D.
bool isFatalLiveArInitFailure(String message) {
  final lower = message.toLowerCase();

  // Tracking / relocalization — pause sequence, never soft-fallback.
  if (lower.contains('track') ||
      lower.contains('relocal') ||
      lower.contains('limited')) {
    return false;
  }

  if (lower.contains('not supported')) return true;
  if (lower.contains('failed to create')) return true;
  if (lower.contains('device is not compatible')) return true;
  if (lower.contains('this device does not support')) return true;

  // ARCore install / availability — require the ARCore token so we do not
  // match transient "AR Session is not available" or cloud-anchor "unavailable".
  if (lower.contains('arcore') &&
      (lower.contains('fail') ||
          lower.contains('unavailable') ||
          lower.contains('not installed') ||
          lower.contains('not compatible'))) {
    return true;
  }

  return false;
}
