// CRT Hyllian
// Based on Hyllian's CRT Shader (MIT License)
// Copyright (C) 2011-2016 Hyllian - sergiogdb@gmail.com
// Ported from https://github.com/libretro/common-shaders/blob/master/crt/shaders/crt-hyllian.cg
// Note: Best results with integer scaling

import bgfx;

struct CRTHyllianParams
{
    [bgfx::PARAM_INT("Phosphor", 1, 0, 1, "Enable phosphor mask pattern simulation")]
    int phosphor;

    [bgfx::PARAM_INT("Vertical Scanlines", 0, 0, 1, "Use vertical scanlines instead of horizontal")]
    int vScanlines;

    [bgfx::PARAM("Input Gamma", 2.5, 0.0, 5.0, "Gamma correction for input image decoding")]
    float inputGamma;

    [bgfx::PARAM("Output Gamma", 2.2, 0.0, 5.0, "Gamma correction for output image encoding")]
    float outputGamma;

    [bgfx::PARAM_INT("Sharpness", 1, 1, 5, "Texture sampling sharpness (higher = sharper pixels)")]
    int sharpness;

    [bgfx::PARAM("Color Boost", 1.5, 1.0, 2.0, "Overall color saturation multiplier")]
    float colorBoost;

    [bgfx::PARAM("Red Boost", 1.0, 1.0, 2.0, "Red channel intensity multiplier")]
    float redBoost;

    [bgfx::PARAM("Green Boost", 1.0, 1.0, 2.0, "Green channel intensity multiplier")]
    float greenBoost;

    [bgfx::PARAM("Blue Boost", 1.0, 1.0, 2.0, "Blue channel intensity multiplier")]
    float blueBoost;

    [bgfx::PARAM("Scanline Strength", 0.5, 0.0, 1.0, "Intensity of the scanline darkening effect")]
    float scanlinesStrength;

    [bgfx::PARAM("Min Beam Width", 0.86, 0.0, 1.0, "Minimum scanline beam width (affects dark areas)")]
    float beamMinWidth;

    [bgfx::PARAM("Max Beam Width", 1.0, 0.0, 1.0, "Maximum scanline beam width (affects bright areas)")]
    float beamMaxWidth;

    [bgfx::PARAM("Anti-Ringing", 0.8, 0.0, 1.0, "Reduces ringing artifacts from cubic filtering")]
    float crtAntiRinging;
};

ConstantBuffer<CRTHyllianParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

#pragma warning(disable: 3571)

#define GAMMA_IN(color) pow(color, float3(params.inputGamma, params.inputGamma, params.inputGamma))
#define GAMMA_OUT(color) pow(color, float3(1.0 / params.outputGamma, 1.0 / params.outputGamma, 1.0 / params.outputGamma))

// Cubic filter configuration - Catmull-Rom Spline
const static float B = 0.0;
const static float C = 0.5;

const static float4x4 invX = float4x4(
    (-B - 6.0 * C) / 6.0, (3.0 * B + 12.0 * C) / 6.0, (-3.0 * B - 6.0 * C) / 6.0, B / 6.0,
    (12.0 - 9.0 * B - 6.0 * C) / 6.0, (-18.0 + 12.0 * B + 6.0 * C) / 6.0, 0.0, (6.0 - 2.0 * B) / 6.0,
    -(12.0 - 9.0 * B - 6.0 * C) / 6.0, (18.0 - 15.0 * B - 12.0 * C) / 6.0, (3.0 * B + 6.0 * C) / 6.0, B / 6.0,
    (B + 6.0 * C) / 6.0, -C, 0.0, 0.0);

[bgfx::EFFECT("CRT Hyllian", 2)]
[bgfx::CATEGORY("CRT")]
[bgfx::DESCRIPTION("Hyllian CRT shader featuring cubic filtering, phosphor mask simulation, and configurable scanlines. Supports both horizontal and vertical scanline modes. Best with integer scaling.")]
[bgfx::PASS(1, "CRT Hyllian")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    uint2 inputSize = GetInputSize();
    uint2 outputSize = GetOutputSize();
    float3 color;

    float2 TextureSize = float2(params.sharpness * inputSize.x, inputSize.y);

    float2 dx = lerp(float2(1.0 / TextureSize.x, 0.0), float2(0.0, 1.0 / TextureSize.y), params.vScanlines);
    float2 dy = lerp(float2(0.0, 1.0 / TextureSize.y), float2(1.0 / TextureSize.x, 0.0), params.vScanlines);

    float2 pix_coord = pos * TextureSize + float2(-0.5, 0.5);
    float2 tc = lerp(
        (floor(pix_coord) + float2(0.5, 0.5)) / TextureSize,
        (floor(pix_coord) + float2(1.0, -0.5)) / TextureSize,
        params.vScanlines);
    float2 fp = lerp(frac(pix_coord), frac(pix_coord.yx), params.vScanlines);

    float3 c00 = GAMMA_IN(INPUT.SampleLevel(sam, tc - dx - dy, 0).xyz);
    float3 c01 = GAMMA_IN(INPUT.SampleLevel(sam, tc - dy, 0).xyz);
    float3 c02 = GAMMA_IN(INPUT.SampleLevel(sam, tc + dx - dy, 0).xyz);
    float3 c03 = GAMMA_IN(INPUT.SampleLevel(sam, tc + 2.0 * dx - dy, 0).xyz);
    float3 c10 = GAMMA_IN(INPUT.SampleLevel(sam, tc - dx, 0).xyz);
    float3 c11 = GAMMA_IN(INPUT.SampleLevel(sam, tc, 0).xyz);
    float3 c12 = GAMMA_IN(INPUT.SampleLevel(sam, tc + dx, 0).xyz);
    float3 c13 = GAMMA_IN(INPUT.SampleLevel(sam, tc + 2.0 * dx, 0).xyz);

    float3 min_sample = min(min(c01, c11), min(c02, c12));
    float3 max_sample = max(max(c01, c11), max(c02, c12));

    float4x3 color_matrix0 = float4x3(c00, c01, c02, c03);
    float4x3 color_matrix1 = float4x3(c10, c11, c12, c13);

    float4 invX_Px = mul(invX, float4(fp.x * fp.x * fp.x, fp.x * fp.x, fp.x, 1.0));
    float3 color0 = mul(invX_Px, color_matrix0);
    float3 color1 = mul(invX_Px, color_matrix1);

    float3 aux = color0;
    color0 = clamp(color0, min_sample, max_sample);
    color0 = lerp(aux, color0, params.crtAntiRinging);
    aux = color1;
    color1 = clamp(color1, min_sample, max_sample);
    color1 = lerp(aux, color1, params.crtAntiRinging);

    float pos0 = fp.y;
    float pos1 = 1 - fp.y;

    float3 lum0 = lerp(params.beamMinWidth, params.beamMaxWidth, color0);
    float3 lum1 = lerp(params.beamMinWidth, params.beamMaxWidth, color1);

    float3 d0 = clamp(pos0 / (lum0 + 0.0000001), 0.0, 1.0);
    float3 d1 = clamp(pos1 / (lum1 + 0.0000001), 0.0, 1.0);

    d0 = exp(-10.0 * params.scanlinesStrength * d0 * d0);
    d1 = exp(-10.0 * params.scanlinesStrength * d1 * d1);

    color = clamp(color0 * d0 + color1 * d1, 0.0, 1.0);

    color *= params.colorBoost * float3(params.redBoost, params.greenBoost, params.blueBoost);

    float mod_factor = lerp(pos.x * outputSize.x, pos.y * outputSize.y, params.vScanlines);
    float3 dotMaskWeights = lerp(
        float3(1.0, 0.7, 1.0),
        float3(0.7, 1.0, 0.7),
        floor(fmod(mod_factor, 2.0)));
    color.rgb *= lerp(1.0, dotMaskWeights, params.phosphor);

    color = GAMMA_OUT(color);

    OUTPUT[tid.xy] = float4(color, 1.0);
}
