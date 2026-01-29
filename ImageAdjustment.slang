// Image Adjustment
// Comprehensive color and brightness controls
// Based on image-adjustment shader from libretro
// Ported from https://github.com/libretro/slang-shaders/blob/master/misc/image-adjustment.slang

import bgfx;

struct ImageAdjustmentParams
{
    [bgfx::PARAM("Target Gamma", 2.2, 0.01, 5, "The gamma value of the content being displayed")]
    float targetGamma;

    [bgfx::PARAM("Monitor Gamma", 2.2, 0.01, 5, "The gamma value of your display monitor")]
    float monitorGamma;

    [bgfx::PARAM("Saturation", 1, 0, 5, "Color saturation multiplier. Values below 1.0 desaturate, above 1.0 increase saturation.")]
    float saturation;

    [bgfx::PARAM("Luminance", 1, 0, 2, "Overall luminance/brightness multiplier in HSV color space")]
    float luminance;

    [bgfx::PARAM("Contrast", 1, 0, 10, "Image contrast adjustment. Values above 1.0 increase contrast.")]
    float contrast;

    [bgfx::PARAM("Brightness Boost", 0, -1, 1, "Additional brightness offset applied after contrast adjustment")]
    float brightBoost;

    [bgfx::PARAM("Black Level", 0, -1, 1, "Adjusts the black point of the image. Positive values crush blacks.")]
    float blackLevel;

    [bgfx::PARAM("Red Channel", 1, 0, 2, "Multiplier for the red color channel")]
    float redChannel;

    [bgfx::PARAM("Green Channel", 1, 0, 2, "Multiplier for the green color channel")]
    float greenChannel;

    [bgfx::PARAM("Blue Channel", 1, 0, 2, "Multiplier for the blue color channel")]
    float blueChannel;
};
ConstantBuffer<ImageAdjustmentParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

// Convert RGB to HSV color space
float3 ConvertRGBtoHSV(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = c.y < c.z ? float4(c.bg, K.wz) : float4(c.gb, K.xy);
    float4 q = c.x < p.x ? float4(p.xyw, c.x) : float4(c.x, p.yzx);

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Convert HSV to RGB color space
float3 ConvertHSVtoRGB(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

[bgfx::EFFECT("Image Adjustment", 2)]
[bgfx::CATEGORY("Post Processing")]
[bgfx::DESCRIPTION("Provides comprehensive color adjustment controls including gamma correction, saturation, luminance, contrast, brightness, black level, and individual RGB channel adjustment.")]
[bgfx::PASS(1, "Image Adjustment")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    float3 color = INPUT.SampleLevel(sam, pos, 0).rgb;

    // Apply saturation and luminance adjustments in HSV space
    float3 hsv = ConvertRGBtoHSV(color);
    hsv.y *= params.saturation;
    hsv.z *= params.luminance;
    color = saturate(ConvertHSVtoRGB(hsv));

    // Apply contrast and brightness adjustments
    color = saturate((color - 0.5) * params.contrast + 0.5 + params.brightBoost);

    // Apply black level adjustment
    color -= params.blackLevel;
    color = saturate(color / (1 - params.blackLevel));

    // Apply gamma correction
    color = pow(color, params.targetGamma / params.monitorGamma);

    // Apply individual channel adjustments
    color *= float3(params.redChannel, params.greenChannel, params.blueChannel);

    OUTPUT[tid.xy] = float4(color, 1);
}
