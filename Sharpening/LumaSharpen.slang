// LumaSharpen
// Based on: https://github.com/CeeJayDK/SweetFX/blob/master/Shaders/LumaSharpen.fx
//
// LumaSharpen version 1.5.0
// by Christian Cann Schuldt Jensen ~ CeeJay.dk
//
// Blurs the original pixel with surrounding pixels and subtracts this blur
// to sharpen the image. Works in luma space to avoid color artifacts.
// Similar to Unsharp Mask in Photoshop.

import bgfx;

struct EffectParams
{
    [bgfx::PARAM("Sharpening Strength", 0.65, 0.0, 3.0, "Controls the intensity of the sharpening effect.")]
    float sharpStrength;

    [bgfx::PARAM("Sharpening Limit", 0.035, 0.0, 1.0, "Maximum sharpening amount per pixel. Helps prevent halo artifacts at high strength values.")]
    float sharpClamp;

    [bgfx::PARAM_INT("Sample Pattern", 1, 0, 3, "Blur kernel shape: 0=Fast (7-tap), 1=Normal (9-tap), 2=Wider (17-tap), 3=Pyramid")]
    int pattern;

    [bgfx::PARAM("Offset Bias", 1.0, 0.0, 6.0, "Adjusts the sampling radius. Default is 1.0, experiment for different effects.")]
    float offsetBias;
};

ConstantBuffer<EffectParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam;

#define CoefLuma float3(0.2126, 0.7152, 0.0722)

[bgfx::EFFECT("Luma Sharpen", 2)]
[bgfx::CATEGORY("Sharpening")]
[bgfx::DESCRIPTION("Unsharp mask style sharpening that works in luminance space to avoid color artifacts. Multiple sampling patterns available.")]
[bgfx::PASS(1, "Luma Sharpen")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    float2 BUFFER_PIXEL_SIZE = GetInputPt();

    float3 ori = INPUT.SampleLevel(sam, pos, 0).rgb;

    float3 sharp_strength_luma = (CoefLuma * params.sharpStrength);

    float3 blur_ori = float3(0, 0, 0);

    if (params.pattern == 0)
    {
        blur_ori = INPUT.SampleLevel(sam, pos + (BUFFER_PIXEL_SIZE / 3.0) * params.offsetBias, 0).rgb;
        blur_ori += INPUT.SampleLevel(sam, pos + (-BUFFER_PIXEL_SIZE / 3.0) * params.offsetBias, 0).rgb;
        blur_ori /= 2;

        sharp_strength_luma *= 1.5;
    }

    if (params.pattern == 1)
    {
        blur_ori = INPUT.SampleLevel(sam, pos + float2(BUFFER_PIXEL_SIZE.x, -BUFFER_PIXEL_SIZE.y) * 0.5 * params.offsetBias, 0).rgb;
        blur_ori += INPUT.SampleLevel(sam, pos - BUFFER_PIXEL_SIZE * 0.5 * params.offsetBias, 0).rgb;
        blur_ori += INPUT.SampleLevel(sam, pos + BUFFER_PIXEL_SIZE * 0.5 * params.offsetBias, 0).rgb;
        blur_ori += INPUT.SampleLevel(sam, pos - float2(BUFFER_PIXEL_SIZE.x, -BUFFER_PIXEL_SIZE.y) * 0.5 * params.offsetBias, 0).rgb;
        blur_ori *= 0.25;
    }

    if (params.pattern == 2)
    {
        blur_ori = INPUT.SampleLevel(sam, pos + BUFFER_PIXEL_SIZE * float2(0.4, -1.2) * params.offsetBias, 0).rgb;
        blur_ori += INPUT.SampleLevel(sam, pos - BUFFER_PIXEL_SIZE * float2(1.2, 0.4) * params.offsetBias, 0).rgb;
        blur_ori += INPUT.SampleLevel(sam, pos + BUFFER_PIXEL_SIZE * float2(1.2, 0.4) * params.offsetBias, 0).rgb;
        blur_ori += INPUT.SampleLevel(sam, pos - BUFFER_PIXEL_SIZE * float2(0.4, -1.2) * params.offsetBias, 0).rgb;
        blur_ori *= 0.25;

        sharp_strength_luma *= 0.51;
    }

    if (params.pattern == 3)
    {
        blur_ori = INPUT.SampleLevel(sam, pos + float2(0.5 * BUFFER_PIXEL_SIZE.x, -BUFFER_PIXEL_SIZE.y * params.offsetBias), 0).rgb;
        blur_ori += INPUT.SampleLevel(sam, pos + float2(params.offsetBias * -BUFFER_PIXEL_SIZE.x, 0.5 * -BUFFER_PIXEL_SIZE.y), 0).rgb;
        blur_ori += INPUT.SampleLevel(sam, pos + float2(params.offsetBias * BUFFER_PIXEL_SIZE.x, 0.5 * BUFFER_PIXEL_SIZE.y), 0).rgb;
        blur_ori += INPUT.SampleLevel(sam, pos + float2(0.5 * -BUFFER_PIXEL_SIZE.x, BUFFER_PIXEL_SIZE.y * params.offsetBias), 0).rgb;
        blur_ori /= 4.0;

        sharp_strength_luma *= 0.666;
    }

    float3 sharp = ori - blur_ori;

    float4 sharp_strength_luma_clamp = float4(sharp_strength_luma * (0.5 / params.sharpClamp), 0.5);

    float sharp_luma = saturate(dot(float4(sharp, 1.0), sharp_strength_luma_clamp));
    sharp_luma = (params.sharpClamp * 2.0) * sharp_luma - params.sharpClamp;

    float3 outputcolor = ori + sharp_luma;

    OUTPUT[tid.xy] = float4(saturate(outputcolor), 1);
}
