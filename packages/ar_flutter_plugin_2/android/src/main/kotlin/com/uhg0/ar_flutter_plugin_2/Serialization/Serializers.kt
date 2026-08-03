package com.uhg0.ar_flutter_plugin_2.Serialization

import com.google.ar.core.HitResult
import com.google.ar.core.Pose

fun serializeHitResult(hit: HitResult): HashMap<String, Any> =
    hashMapOf(
        "type" to 1,
        "distance" to hit.distance.toDouble(),
        // Preserve the complete ARCore hit pose. The public package rebuilt a
        // translation-only pose here and silently discarded plane rotation.
        "worldTransform" to serializePose(hit.hitPose),
    )

fun serializePose(pose: Pose): DoubleArray {
    val serializedPose = FloatArray(16)
    pose.toMatrix(serializedPose, 0)
    return DoubleArray(16) { serializedPose[it].toDouble() }
} 
