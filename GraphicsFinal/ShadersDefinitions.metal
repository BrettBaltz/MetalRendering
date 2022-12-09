#include <simd/simd.h>

struct VertexIn {
    simd_float4 position [[attribute(0)]];
    simd_float3 normal [[attribute(1)]];
    simd_float2 texCoord [[attribute(2)]];
};

struct VertexOut {
    simd_float4 position [[position]];
    simd_float2 texCoord;
    simd_float4 eyeView;
    simd_float4 eyeNormal;
};

struct VertexUniforms {
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
};

struct FragmentUniforms {
    simd_float3 color;
    bool hasDiffuseTexture;
    bool hasSpecularTexture;
};
