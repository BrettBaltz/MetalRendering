import simd

struct Geometry : Codable {
    var vertexdata: [Float]
    var indexdata: [UInt16]
    var groups: [String: [Int]] = [:]
}

struct Material: Codable {
    var color: simd_float3
    var diffuse: String
    var specular: String
}

struct Vertex {
    var position: simd_float3
    var normal: simd_float3
    var texCoord: simd_float2
}

struct VertexUniforms {
    var modelMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var projectionMatrix: simd_float4x4
}

struct FragmentUniforms {
    var color: simd_float3
    var hasDiffuseTexture: Bool
    var hasSpecularTexture: Bool
}
