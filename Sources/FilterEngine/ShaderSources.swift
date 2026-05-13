import Foundation

enum ShaderSources {
    static let basicYUV = """
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

    struct StillPreviewUniforms {
        float exposure;
        float contrast;
        float saturation;
        float tint;
        float grain;
        float vignette;
        float showOriginal;
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

    float3 apply_editor_params(float3 rgb, StillPreviewUniforms uniforms) {
        rgb *= pow(2.0, uniforms.exposure);

        float contrastFactor = 1.0 + uniforms.contrast;
        rgb = 0.5 + (rgb - 0.5) * contrastFactor;

        float luma = dot(rgb, float3(0.299, 0.587, 0.114));
        float saturationFactor = 1.0 + uniforms.saturation;
        rgb = float3(luma) + (rgb - float3(luma)) * saturationFactor;

        rgb.r += uniforms.tint * 0.1;
        rgb.b -= uniforms.tint * 0.1;
        return saturate(rgb);
    }

    float deterministic_noise(float2 pixel) {
        uint x = uint(pixel.x);
        uint y = uint(pixel.y);
        uint value = x * 374761393u + y * 668265263u;
        value = (value ^ (value >> 13u)) * 1274126177u;
        return (float(value & 0xffffu) / 65535.0) * 2.0 - 1.0;
    }

    float3 apply_spatial_adjustments(float3 rgb, float2 uv, float2 pixel, StillPreviewUniforms uniforms) {
        float vignetteStrength = clamp(uniforms.vignette, -1.0, 1.0);
        if (vignetteStrength != 0.0) {
            float2 centered = uv - float2(0.5);
            float normalizedDistance = clamp(length(centered) / length(float2(0.5)), 0.0, 1.0);
            float edgeWeight = normalizedDistance * normalizedDistance;
            float factor = 1.0 - vignetteStrength * 0.55 * edgeWeight;
            rgb *= factor;
        }

        float grainStrength = saturate(uniforms.grain);
        if (grainStrength > 0.0) {
            rgb += deterministic_noise(pixel) * grainStrength * 0.12;
        }

        return saturate(rgb);
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

    fragment float4 still_image_fragment(
        VertexOut in [[stage_in]],
        texture2d<float, access::sample> sourceTexture [[texture(0)]],
        texture3d<float, access::sample> lutTexture [[texture(1)]],
        constant StillPreviewUniforms& uniforms [[buffer(0)]]
    ) {
        constexpr sampler textureSampler(coord::normalized, address::clamp_to_edge, filter::linear);
        constexpr sampler lutSampler(coord::normalized, address::clamp_to_edge, filter::linear);

        float2 uv = aspect_fill_uv(in.uv, uniforms.frameAspectRatio, uniforms.drawableAspectRatio);
        float3 originalRGB = saturate(sourceTexture.sample(textureSampler, uv).rgb);
        if (uniforms.showOriginal > 0.5) {
            return float4(originalRGB, 1.0);
        }

        float3 lutRGB = saturate(lutTexture.sample(lutSampler, originalRGB).rgb);
        float3 adjustedRGB = apply_editor_params(lutRGB, uniforms);
        adjustedRGB = apply_spatial_adjustments(adjustedRGB, uv, in.position.xy, uniforms);
        return float4(adjustedRGB, 1.0);
    }
    """
}
