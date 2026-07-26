import ARKit
import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "cell_forensic/ar_capability"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "unavailable",
            message: "AppDelegate deallocated",
            details: nil
          )
        )
        return
      }
      switch call.method {
      case "probe":
        let args = call.arguments as? [String: Any]
        let requestCamera = args?["requestCameraPermission"] as? Bool ?? true
        self.probeArCapability(requestCamera: requestCamera, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Mirrors Android [MainActivity] probe for Dart [ArCapabilityProbe] (FR-010).
  private func probeArCapability(
    requestCamera: Bool,
    result: @escaping FlutterResult
  ) {
    let arkitSupported = ARWorldTrackingConfiguration.isSupported
    let status = AVCaptureDevice.authorizationStatus(for: .video)

    switch status {
    case .authorized:
      result(buildProbeMap(arkitSupported: arkitSupported, cameraGranted: true))
    case .notDetermined:
      guard requestCamera else {
        result(buildProbeMap(arkitSupported: arkitSupported, cameraGranted: false))
        return
      }
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          result(
            self.buildProbeMap(
              arkitSupported: arkitSupported,
              cameraGranted: granted
            )
          )
        }
      }
    case .denied, .restricted:
      result(buildProbeMap(arkitSupported: arkitSupported, cameraGranted: false))
    @unknown default:
      result(buildProbeMap(arkitSupported: arkitSupported, cameraGranted: false))
    }
  }

  private func buildProbeMap(
    arkitSupported: Bool,
    cameraGranted: Bool
  ) -> [String: Any] {
    let availability =
      arkitSupported
      ? "ARKIT_WORLD_TRACKING_SUPPORTED"
      : "ARKIT_UNSUPPORTED"
    let supported = arkitSupported && cameraGranted
    let reason: String
    if !cameraGranted {
      reason = "camera_permission_denied"
    } else if !arkitSupported {
      reason = "arkit_unsupported_device"
    } else {
      reason = "arkit_supported"
    }

    NSLog(
      "CellForensicArProbe: supported=%@ reason=%@ availability=%@ camera=%@",
      String(supported),
      reason,
      availability,
      String(cameraGranted)
    )

    return [
      "supported": supported,
      "reason": reason,
      "arcoreAvailability": availability,
      "cameraGranted": cameraGranted,
      "hasCameraArFeature": arkitSupported,
    ]
  }
}
