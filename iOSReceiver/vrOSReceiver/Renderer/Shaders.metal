#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float2 viewportSize;
    float2 textureSize;
    float4x4 headRotation;
    float4x4 eyeFromHead;
    float4x4 projectionMatrix;
    float screenDistance;
};

vertex VertexOut vertexShader(
    uint vertexID [[vertex_id]],
    constant float2* positions [[buffer(0)]],
    constant float2* texCoords [[buffer(1)]],
    constant Uniforms& uniforms [[buffer(2)]]
) {
    VertexOut out;
    float2 pos = positions[vertexID];

    float fx = uniforms.projectionMatrix[0][0];
    float fy = uniforms.projectionMatrix[1][1];
    float halfW = uniforms.screenDistance / fx;
    float halfH = uniforms.screenDistance / fy;
    float3 worldPos = float3(pos.x * halfW * 1.8, pos.y * halfH * 1.8, -uniforms.screenDistance);

    float4 headPos = uniforms.headRotation * float4(worldPos, 1.0);
    float4 eyePos = uniforms.eyeFromHead * headPos;
    float4 clipPos = uniforms.projectionMatrix * eyePos;

    out.position = clipPos;
    out.texCoord = texCoords[vertexID];
    return out;
}

vertex VertexOut vertexShaderSimple(
    uint vertexID [[vertex_id]],
    constant float2* positions [[buffer(0)]],
    constant float2* texCoords [[buffer(1)]]
) {
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float, access::sample> texture [[texture(0)]],
    sampler samp [[sampler(0)]]
) {
    return float4(texture.sample(samp, in.texCoord).rgb, 1.0);
}
