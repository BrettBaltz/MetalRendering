import simd

// Convert degrees to radians
func toRad(_ angle: Float) -> Float {
    return angle * (Float.pi / 180)
}

func createIdentityMatrix() -> float4x4 {
    return simd_float4x4(
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0]
    )
}

// Rotate about the x axis
func rotateByX(mat: float4x4 , rad: Float) -> float4x4 {
    let rotMat = simd_float4x4(
        simd_float4(1.0,      0.0,       0.0, 0.0),
        simd_float4(0.0, cos(rad), -sin(rad), 0.0),
        simd_float4(0.0, sin(rad),  cos(rad), 0.0),
        simd_float4(0.0,      0.0,       0.0, 1.0)
    )
    return mat * rotMat
}

// Rotate about the y axis
func rotateByY(mat: float4x4, rad: Float) -> float4x4 {
    let rotMat = simd_float4x4(
        [ cos(rad), 0.0, sin(rad), 0.0],
        [      0.0, 1.0,      0.0, 0.0],
        [-sin(rad), 0.0, cos(rad), 0.0],
        [      0.0, 0.0,      0.0, 1.0]
    )
    return mat * rotMat
}

// Rotate about the z axis
func rotateByZ(mat: float4x4, rad: Float) -> float4x4 {
    let rotMat = simd_float4x4(
        [cos(rad), -sin(rad), 0.0, 0.0],
        [sin(rad),  cos(rad), 0.0, 0.0],
        [     0.0,       0.0, 1.0, 0.0],
        [     0.0,       0.0, 0.0, 1.0]
    )
    return mat * rotMat
}

// Create view matrix
func lookAt(eye: simd_float3, center: simd_float3, up: simd_float3)
-> float4x4 {
    let z = normalize(center - eye)
    let y = normalize(cross(up, z))
    let x = normalize(cross(z, y))
    let view = simd_float4x4(
        [            -y.x,               x.x,                 z.x,    0.0],
        [            -y.y,               x.y,                 z.y,    0.0],
        [            -y.z,               x.z,                 z.z,    0.0],
        [simd.dot(y, eye), -simd.dot(x, eye),   -simd.dot(z, eye),    1.0]
    )
    return view
}

// Create orthographic projection matrix
func ortho(left: Int, right: Int, bottom: Int, top: Int, near: Int, far: Int)
-> float4x4 {
    let lr = 1.0 / Float(left - right)
    let bt = 1.0 / Float(bottom - top)
    let nf = 1.0 / Float(near - far)
    return simd_float4x4(
        [               -2.0 * lr,                      0.0,              0.0, 0.0],
        [                     0.0,                -2.0 * bt,              0.0, 0.0],
        [                     0.0,                      0.0,               nf, 0.0],
        [Float(left + right) * lr, Float(bottom + top) * bt, Float(near) * nf, 1.0]
    )
}

