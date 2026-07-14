#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float eyeIndex;
    float2 ndcPos;
};

struct Uniforms {
    float2 viewportSize;
    float2 textureSize;
    float distortionK1;
    float distortionK2;
    float eyeSeparation;
    float verticalScale;
    float eyeRoundness;
    float caRed;
    float caBlue;
};

vertex VertexOut vertexShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant float2* positions [[buffer(0)]],
    constant float2* texCoords [[buffer(1)]],
    constant Uniforms& uniforms [[buffer(2)]]
) {
    VertexOut out;
    float eye = float(instanceID);
    float2 pos = positions[vertexID];
    float halfSep = uniforms.eyeSeparation * 0.5;
    pos.x = pos.x * halfSep + (eye - 0.5) * uniforms.eyeSeparation;
    pos.y = pos.y * uniforms.verticalScale;
    out.position = float4(pos, 0.0, 1.0);
    out.ndcPos = pos;
    out.texCoord = texCoords[vertexID];
    out.eyeIndex = eye;
    return out;
}

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float, access::sample> texture [[texture(0)]],
    sampler samp [[sampler(0)]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    float2 uv = in.texCoord;

    float2 centered = uv - 0.5;
    float r2 = dot(centered, centered);
    float r4 = r2 * r2;
    float k1 = uniforms.distortionK1;
    float k2 = uniforms.distortionK2;
    float dist = 1.0 + k1 * r2 + k2 * r4;
    float2 distorted = centered * dist;

    float2 distortedR = centered * (1.0 + (k1 + uniforms.caRed) * r2 + k2 * r4);
    float2 distortedB = centered * (1.0 + (k1 + uniforms.caBlue) * r2 + k2 * r4);

    float4 color;
    color.r = texture.sample(samp, distortedR + 0.5).r;
    color.g = texture.sample(samp, distorted + 0.5).g;
    color.b = texture.sample(samp, distortedB + 0.5).b;
    color.a = 1.0;

    float2 eyeCenter = float2(in.eyeIndex == 0 ? -0.425 : 0.425, 0.0);
    float2 local = in.ndcPos - eyeCenter;
    float2 norm = local / float2(0.425, uniforms.verticalScale);
    float2 q = abs(norm) - float2(1.0) + uniforms.eyeRoundness;
    float sdf = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - uniforms.eyeRoundness;
    float mask = 1.0 - smoothstep(-0.03, 0.04, sdf);
    color.rgb *= mask;
    return color;
}
