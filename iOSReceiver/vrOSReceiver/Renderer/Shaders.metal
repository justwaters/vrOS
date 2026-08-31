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
    float halfW_fov = uniforms.screenDistance / fx * 0.85;
    float halfH_fov = uniforms.screenDistance / fy * 0.85;
    float aspect = uniforms.textureSize.x / uniforms.textureSize.y;
    float halfW = halfW_fov;
    float halfH = halfW / aspect;
    if (halfH > halfH_fov) {
        halfH = halfH_fov;
        halfW = halfH * aspect;
    }
    float3 worldPos = float3(pos.x * halfW, pos.y * halfH,
                             -uniforms.screenDistance);

    // headRotation is already a world-to-head (view) transform, matching
    // Cardboard's own reference usage (hellocardboard-ios's HelloCardboardRenderer::
    // DrawFrame applies GetPose()'s quaternion-derived matrix directly, with no
    // extra inversion, as the view matrix). No transpose here -- see
    // MetalRenderer.computeHeadRotation for why an earlier version's transpose
    // (paired with a compensating raw-quaternion component negation) is gone too.
    float4 headPos = uniforms.headRotation * float4(worldPos, 1.0);
    float4 eyePos = uniforms.eyeFromHead * headPos;
    float4 clipPos = uniforms.projectionMatrix * eyePos;

    out.position = clipPos;
    out.texCoord = texCoords[vertexID];
    return out;
}

// Camera passthrough background, sized through Cardboard's own projection
// matrix instead of writing directly to clip space. An earlier version wrote
// straight to clip space (full -1..1 quad) and made the real world look
// "zoomed in" -- it bypassed the lens-calibrated projection matrix
// entirely, so it had no relationship to the physical lens's actual optical
// FOV (unlike the virtual screen quad above, which is correctly scaled
// specifically because it goes through this same projectionMatrix). This
// places a large, fixed quad directly in front of the eye (not affected by
// head rotation or world-anchoring -- the camera image already represents
// "whatever's currently in view", so the background should stay screen-filling
// regardless of gaze) and projects it the same way, so it appears at accurate
// real-world scale through the lens. No eyeFromHead IPD offset -- the
// passthrough is monocular (same image both eyes, see the single-camera
// hardware limitation noted elsewhere), so adding a per-eye positional offset
// to a flat 2D image would introduce a fake stereo mismatch.
vertex VertexOut vertexShaderPassthroughFOV(
    uint vertexID [[vertex_id]],
    constant float2* positions [[buffer(0)]],
    constant float2* texCoords [[buffer(1)]],
    constant Uniforms& uniforms [[buffer(2)]]
) {
    VertexOut out;
    float2 pos = positions[vertexID];

    float fx = uniforms.projectionMatrix[0][0];
    float fy = uniforms.projectionMatrix[1][1];
    // Distance is arbitrary (angular size is invariant to it as long as
    // halfW/halfH scale with it); large enough to sit behind the virtual
    // screen and any reasonable zNear.
    float dist = 10.0;
    float halfW = dist / fx;
    float halfH = dist / fy;

    float4 eyePos = float4(pos.x * halfW, -pos.y * halfH, -dist, 1.0);
    out.position = uniforms.projectionMatrix * eyePos;
    out.texCoord = texCoords[vertexID];
    return out;
}

// ARKit's capturedImage is two-plane YCbCr (kCVPixelFormatType_420YpCbCr8BiPlanarFullRange).
// Standard BT.601 full-range YCbCr -> RGB conversion.
fragment float4 fragmentShaderPassthrough(
    VertexOut in [[stage_in]],
    texture2d<float, access::sample> lumaTexture [[texture(0)]],
    texture2d<float, access::sample> chromaTexture [[texture(1)]],
    sampler samp [[sampler(0)]]
) {
    float y = lumaTexture.sample(samp, in.texCoord).r;
    float2 cbcr = chromaTexture.sample(samp, in.texCoord).rg - float2(0.5, 0.5);
    float3 rgb = float3(
        y + 1.402 * cbcr.y,
        y - 0.344136 * cbcr.x - 0.714136 * cbcr.y,
        y + 1.772 * cbcr.x
    );
    return float4(rgb, 1.0);
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
