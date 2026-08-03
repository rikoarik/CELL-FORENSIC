package com.example.cell_forensic

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.ar.core.ArCoreApk
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the AR capability probe used by Dart [ArCapabilityProbe] (FR-010).
 *
 * Pixel / ARCore devices do not always declare FEATURE_CAMERA_AR, so we rely
 * on [ArCoreApk.checkAvailability] rather than the feature flag alone.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "cell_forensic/ar_capability"
    private val cameraPermissionRequestCode = 4821
    private var pendingCameraResult: MethodChannel.Result? = null
    private var pendingProbeArgs: Map<*, *>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "probe" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<*, *>
                        probeArCapability(args, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun probeArCapability(args: Map<*, *>?, result: MethodChannel.Result) {
        val requestCamera = args?.get("requestCameraPermission") as? Boolean ?: true
        val hasFeature =
            packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_AR)
        val cameraGranted =
            ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED

        if (requestCamera && !cameraGranted) {
            pendingCameraResult = result
            pendingProbeArgs = args
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                cameraPermissionRequestCode,
            )
            return
        }

        result.success(buildProbeMap(hasFeature, cameraGranted))
    }

    private fun buildProbeMap(
        hasFeature: Boolean,
        cameraGranted: Boolean,
    ): Map<String, Any?> {
        val availability =
            try {
                ArCoreApk.getInstance().checkAvailability(this)
            } catch (error: Throwable) {
                android.util.Log.w(TAG, "ArCoreApk.checkAvailability failed", error)
                null
            }

        // Live AR is usable only when the runtime is already installed and
        // current. Hardware capability alone is not readiness: routing
        // NOT_INSTALLED / APK_TOO_OLD / UNKNOWN into AR leaves the mission
        // stuck on "tracking lost" instead of opening the 3D viewer.
        val arcoreReady = availability == ArCoreApk.Availability.SUPPORTED_INSTALLED

        val availabilityName = availability?.name ?: "CHECK_FAILED"
        val supported = arcoreReady && cameraGranted
        val reason =
            when {
                !cameraGranted -> "camera_permission_denied"
                availability == ArCoreApk.Availability.UNSUPPORTED_DEVICE_NOT_CAPABLE ->
                    "arcore_unsupported_device"
                availability == ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED ->
                    "arcore_not_installed"
                availability == ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD ->
                    "arcore_apk_too_old"
                availability == ArCoreApk.Availability.UNKNOWN_CHECKING ->
                    "arcore_checking"
                availability == ArCoreApk.Availability.UNKNOWN_TIMED_OUT ->
                    "arcore_check_timed_out"
                availability == ArCoreApk.Availability.UNKNOWN_ERROR ->
                    "arcore_check_error"
                availability == null -> "arcore_check_failed"
                supported -> "arcore_supported"
                else -> "arcore_$availabilityName".lowercase()
            }

        android.util.Log.i(
            TAG,
            "AR probe: supported=$supported reason=$reason " +
                "availability=$availabilityName camera=$cameraGranted feature=$hasFeature " +
                "sdk=${Build.VERSION.SDK_INT}",
        )

        return mapOf(
            "supported" to supported,
            "reason" to reason,
            "arcoreAvailability" to availabilityName,
            "cameraGranted" to cameraGranted,
            "hasCameraArFeature" to hasFeature,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != cameraPermissionRequestCode) return
        val result = pendingCameraResult ?: return
        pendingCameraResult = null
        pendingProbeArgs = null
        val cameraGranted =
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
        val hasFeature =
            packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_AR)
        result.success(buildProbeMap(hasFeature, cameraGranted))
    }

    companion object {
        private const val TAG = "CellForensicArProbe"
    }
}
