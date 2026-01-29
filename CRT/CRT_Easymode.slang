// CRT Easymode
// Based on CRT Shader by EasyMode (GPL License)
// Ported from https://github.com/libretro/common-shaders/blob/master/crt/shaders/crt-easymode.cg
// A flat CRT shader ideally for 1080p or higher displays

import bgfx;

struct CRTEasymodeParams
{
    [bgfx::PARAM("Sharpness Horizontal", 0.5, 0.0, 1.0, "Controls horizontal sharpness of the image interpolation")]
    float sharpnessH;

    [bgfx::PARAM("Sharpness Vertical", 1.0, 0.0, 1.0, "Controls vertical sharpness of the image interpolation")]
    float sharpnessV;

    [bgfx::PARAM("Mask Strength", 0.3, 0.0, 1.0, "Intensity of the RGB phosphor mask effect")]
    float maskStrength;

    [bgfx::PARAM_INT("Mask Dot Width", 1, 1, 100, "Width of each phosphor dot in the mask pattern")]
    int maskDotWidth;

    [bgfx::PARAM_INT("Mask Dot Height", 1, 1, 100, "Height of each phosphor dot in the mask pattern")]
    int maskDotHeight;

    [bgfx::PARAM_INT("Mask Stagger", 0, 0, 100, "Offset pattern for alternating mask rows (0=aperture grille, 3=shadow mask)")]
    int maskStagger;

    [bgfx::PARAM_INT("Mask Size", 1, 1, 100, "Scale factor for the overall mask pattern")]
    int maskSize;

    [bgfx::PARAM("Scanline Strength", 1.0, 0.0, 1.0, "Intensity of the horizontal scanline effect")]
    float scanlineStrength;

    [bgfx::PARAM("Scanline Beam Width Min", 1.5, 0.5, 5.0, "Minimum width of the scanline beam (affects dark areas)")]
    float scanlineBeamWidthMin;

    [bgfx::PARAM("Scanline Beam Width Max", 1.5, 0.5, 5.0, "Maximum width of the scanline beam (affects bright areas)")]
    float scanlineBeamWidthMax;

    [bgfx::PARAM("Scanline Brightness Min", 0.35, 0.0, 1.0, "Minimum brightness level for scanline gaps")]
    float scanlineBrightMin;

    [bgfx::PARAM("Scanline Brightness Max", 0.65, 0.0, 1.0, "Maximum brightness level for scanline peaks")]
    float scanlineBrightMax;

    [bgfx::PARAM_INT("Scanline Cutoff", 400, 1, 1000, "Vertical resolution threshold above which scanlines are disabled")]
    int scanlineCutoff;

    [bgfx::PARAM("Gamma Input", 2.0, 0.1, 5.0, "Gamma correction applied to input image")]
    float gammaInput;

    [bgfx::PARAM("Gamma Output", 1.8, 0.1, 5.0, "Gamma correction applied to output image")]
    float gammaOutput;

    [bgfx::PARAM("Brightness Boost", 1.2, 1.0, 2.0, "Overall brightness multiplier for the final image")]
    float brightBoost;

    [bgfx::PARAM_INT("Dilation", 1, 0, 1, "Enables color dilation for enhanced bloom-like effect")]
    int dilation;
};

ConstantBuffer<CRTEasymodeParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

#pragma warning(disable: 3571)

#define PI 3.141592653589
#define FIX(c) max(abs(c), 1e-5)
#define mod(x, y) (x - y * trunc(x / y))

#define ENABLE_LANCZOS 1

#define TEX2D(c) dilate(INPUT.SampleLevel(sam, c, 0))

float4 dilate(float4 col)
{
    float4 x = lerp(float4(1, 1, 1, 1), col, params.dilation);
    return col * x;
}

float curve_distance(float x, float sharp)
{
    float x_step = step(0.5, x);
    float curve = 0.5 - sqrt(0.25 - (x - x_step) * (x - x_step)) * sign(0.5 - x);
    return lerp(x, curve, sharp);
}

float4x4 get_color_matrix(float2 co)
{
    float2 inputPt = GetInputPt();
    return float4x4(
        TEX2D(co - float2(inputPt.x, 0)),
        TEX2D(co),
        TEX2D(co + float2(inputPt.x, 0)),
        TEX2D(co + float2(2.0 * inputPt.x, 0)));
}

float3 filter_lanczos(float4 coeffs, float4x4 color_matrix)
{
    float4 col = mul(coeffs, color_matrix);
    float4 sample_min = min(color_matrix[1], color_matrix[2]);
    float4 sample_max = max(color_matrix[1], color_matrix[2]);
    col = clamp(col, sample_min, sample_max);
    return col.rgb;
}

[bgfx::EFFECT("CRT Easymode", 2)]
[bgfx::CATEGORY("CRT")]
[bgfx::DESCRIPTION("A flat CRT simulation shader optimized for high resolution displays. Features customizable scanlines, phosphor mask patterns, and gamma correction. Ideal for 1080p+ displays with integer or non-integer scaling.")]
[bgfx::PASS(1, "CRT Easymode")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    float2 inputPt = GetInputPt();
    uint2 inputSize = GetInputSize();
    uint2 outputSize = GetOutputSize();

    float2 pix_co = pos * inputSize - 0.5f;
    float2 tex_co = (floor(pix_co) + 0.5) * inputPt;
    float2 dist = frac(pix_co);

    float curve_x;
    float3 col, col2;

#if ENABLE_LANCZOS
    curve_x = curve_distance(dist.x, params.sharpnessH * params.sharpnessH);

    float4 coeffs = PI * float4(1.0 + curve_x, curve_x, 1.0 - curve_x, 2.0 - curve_x);
    coeffs = FIX(coeffs);
    coeffs = 2.0 * sin(coeffs) * sin(coeffs / 2.0) / (coeffs * coeffs);
    coeffs /= dot(coeffs, 1.0);

    col = filter_lanczos(coeffs, get_color_matrix(tex_co));
    col2 = filter_lanczos(coeffs, get_color_matrix(tex_co + float2(0, inputPt.y)));
#else
    curve_x = curve_distance(dist.x, params.sharpnessH);
    col = lerp(TEX2D(tex_co).rgb, TEX2D(tex_co + float2(inputPt.x, 0)).rgb, curve_x);
    col2 = lerp(TEX2D(tex_co + float2(0, inputPt.y)).rgb, TEX2D(tex_co + float2(inputPt.x, inputPt.y)).rgb, curve_x);
#endif

    col = lerp(col, col2, curve_distance(dist.y, params.sharpnessV));
    col = pow(col, params.gammaInput / (params.dilation + 1.0));

    float luma = dot(float3(0.2126, 0.7152, 0.0722), col);
    float bright = (max(col.r, max(col.g, col.b)) + luma) / 2.0;
    float scan_bright = clamp(bright, params.scanlineBrightMin, params.scanlineBrightMax);
    float scan_beam = clamp(bright * params.scanlineBeamWidthMax, params.scanlineBeamWidthMin, params.scanlineBeamWidthMax);

    float scan_weight = 1.0 - pow(cos(pos.y * 2.0 * PI * inputSize.y) * 0.5 + 0.5, scan_beam) * params.scanlineStrength;

    float mask = 1.0 - params.maskStrength;
    float2 mod_fac = floor(pos * outputSize / float2(params.maskSize, params.maskDotHeight * params.maskSize));
    int dot_no = int(mod((mod_fac.x + mod(mod_fac.y, 2.0) * params.maskStagger) / params.maskDotWidth, 3.0));

    float3 mask_weight;
    if (dot_no == 0)
        mask_weight = float3(1.0, mask, mask);
    else if (dot_no == 1)
        mask_weight = float3(mask, 1.0, mask);
    else
        mask_weight = float3(mask, mask, 1.0);

    if (inputSize.y >= params.scanlineCutoff)
        scan_weight = 1.0;

    col2 = col.rgb;
    col *= scan_weight;
    col = lerp(col, col2, scan_bright);
    col *= mask_weight;

    col = pow(col, 1.0 / params.gammaOutput);

    OUTPUT[tid.xy] = float4(col * params.brightBoost, 1);
}
