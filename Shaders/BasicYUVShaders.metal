#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct PreviewUniforms {
    float intensity;
    float frameAspectRatio;
    float drawableAspectRatio;
};

float2 aspect_fill_uv(float2 uv, float frameAspectRatio, float drawableAspectRatio) {
    float frameAspect = max(frameAspectRatio, 0.0001);
    float drawableAspect = max(drawableAspectRatio, 0.0001);

    if (frameAspect > drawableAspect) {
        float visibleWidth = drawableAspect / frameAspect;
        uv.x = (uv.x - 0.5) * visibleWidth + 0.5;
    } else {
        float visibleHeight = frameAspect / drawableAspect;
        uv.y = (uv.y - 0.5) * visibleHeight + 0.5;
    }

    return uv;
}

vertex VertexOut fullscreen_vertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0),
    };

    float2 uvs[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0),
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = uvs[vertexID];
    return out;
}

fragment float4 yuv_to_rgb_fragment(
    VertexOut in [[stage_in]],
    texture2d<float, access::sample> yTexture [[texture(0)]],
    texture2d<float, access::sample> cbcrTexture [[texture(1)]],
    texture3d<float, access::sample> lutTexture [[texture(2)]],
    constant PreviewUniforms& uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    constexpr sampler lutSampler(coord::normalized, address::clamp_to_edge, filter::linear);

    float2 uv = aspect_fill_uv(in.uv, uniforms.frameAspectRatio, uniforms.drawableAspectRatio);
    float y = yTexture.sample(textureSampler, uv).r;
    float2 cbcr = cbcrTexture.sample(textureSampler, uv).rg - float2(0.5, 0.5);

    float3 rgb;
    rgb.r = y + 1.5748 * cbcr.y;
    rgb.g = y - 0.1873 * cbcr.x - 0.4681 * cbcr.y;
    rgb.b = y + 1.8556 * cbcr.x;

    rgb = saturate(rgb);
    float3 lutRGB = lutTexture.sample(lutSampler, rgb).rgb;
    return float4(mix(rgb, lutRGB, saturate(uniforms.intensity)), 1.0);
}
