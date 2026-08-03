package com.uhg0.ar_flutter_plugin_2.Serialization

import com.google.ar.core.Pose

/** Reconstructs the complete rigid ARCore pose from a column-major Matrix4. */
fun deserializePose(transform: List<Double>): Pose {
    require(transform.size == 16) { "Transformation must contain 16 values" }

    val m00 = transform[0]
    val m01 = transform[4]
    val m02 = transform[8]
    val m10 = transform[1]
    val m11 = transform[5]
    val m12 = transform[9]
    val m20 = transform[2]
    val m21 = transform[6]
    val m22 = transform[10]
    val trace = m00 + m11 + m22

    val quaternion = DoubleArray(4)
    if (trace > 0.0) {
        val s = kotlin.math.sqrt(trace + 1.0) * 2.0
        quaternion[3] = 0.25 * s
        quaternion[0] = (m21 - m12) / s
        quaternion[1] = (m02 - m20) / s
        quaternion[2] = (m10 - m01) / s
    } else if (m00 > m11 && m00 > m22) {
        val s = kotlin.math.sqrt(1.0 + m00 - m11 - m22) * 2.0
        quaternion[3] = (m21 - m12) / s
        quaternion[0] = 0.25 * s
        quaternion[1] = (m01 + m10) / s
        quaternion[2] = (m02 + m20) / s
    } else if (m11 > m22) {
        val s = kotlin.math.sqrt(1.0 + m11 - m00 - m22) * 2.0
        quaternion[3] = (m02 - m20) / s
        quaternion[0] = (m01 + m10) / s
        quaternion[1] = 0.25 * s
        quaternion[2] = (m12 + m21) / s
    } else {
        val s = kotlin.math.sqrt(1.0 + m22 - m00 - m11) * 2.0
        quaternion[3] = (m10 - m01) / s
        quaternion[0] = (m02 + m20) / s
        quaternion[1] = (m12 + m21) / s
        quaternion[2] = 0.25 * s
    }

    return Pose(
        floatArrayOf(
            transform[12].toFloat(),
            transform[13].toFloat(),
            transform[14].toFloat(),
        ),
        quaternion.map { it.toFloat() }.toFloatArray(),
    )
}
