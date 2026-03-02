// CRT Lottes
// Public Domain CRT Styled Scan-line Shader by Timothy Lottes
// Ported from https://github.com/libretro/common-shaders/blob/master/crt/shaders/crt-lottes.cg
// CGA arcade monitor style with RGB inputs

import bgfx;

struct CRTLottesParams
{
    [bgfx::PARAM_INT("Scanline Hardness", -8, -20, 0, "Controls sharpness of scanline edges (more negative = harder)")]
    int hardScan;

    [bgfx::PARAM_INT("Pixel Hardness", -3, -20, 0, "Controls sharpness of pixel edges (more negative = harder)")]
    int hardPix;

    [bgfx::PARAM("Horizontal Display Warp", 0.031, 0.0, 0.125, "Horizontal barrel distortion amount")]
    float warpX;

    [bgfx::PARAM("Vertical Display Warp", 0.041, 0.0, 0.125, "Vertical barrel distortion amount")]
    float warpY;

    [bgfx::PARAM("Mask Dark", 0.5, 0.0, 2.0, "Brightness of dark mask pixels")]
    float maskDark;

    [bgfx::PARAM("Mask Light", 1.5, 0.0, 2.0, "Brightness of light mask pixels")]
    float maskLight;

    [bgfx::PARAM_INT("Shadow Mask", 3, 0, 4, "Mask type: 0=none, 1=compressed TV, 2=aperture grille, 3=stretched VGA, 4=VGA")]
    int shadowMask;

    [bgfx::PARAM("Brightness Boost", 1.0, 0.0, 2.0, "Overall brightness multiplier")]
    float brightBoost;

    [bgfx::PARAM("Bloom-X Soft", -1.5, -2.0, -0.5, "Horizontal bloom softness (more negative = softer)")]
    float hardBloomPix;

    [bgfx::PARAM("Bloom-Y Soft", -2.0, -4.0, -1.0, "Vertical bloom softness (more negative = softer)")]
    float hardBloomScan;

    [bgfx::PARAM("Bloom Amount", 0.15, 0.0, 1.0, "Intensity of the bloom/glow effect")]
    float bloomAmount;

    [bgfx::PARAM("Filter Kernel Shape", 2.0, 0.0, 10.0, "Shape of the gaussian filter kernel")]
    float shape;
};

ConstantBuffer<CRTLottesParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

#pragma warning(disable: 3571)

#define DO_BLOOM 1
#define warp float2(params.warpX, params.warpY)

float3 Fetch(float2 pos, float2 off, float2 texture_size)
{
    pos = (floor(pos * texture_size.xy + off) + float2(0.5, 0.5)) / texture_size.xy;
    return params.brightBoost * pow(INPUT.SampleLevel(sam, pos, 0).rgb, 2.2f);
}

float2 Dist(float2 pos, float2 texture_size)
{
    pos = pos * texture_size.xy;
    return -((pos - floor(pos)) - float2(0.5, 0.5));
}

float Gaus(float pos, float scale)
{
    return exp2(scale * pow(abs(pos), params.shape));
}

float3 Horz3(float2 pos, float off, float2 texture_size)
{
    float3 b = Fetch(pos, float2(-1.0, off), texture_size);
    float3 c = Fetch(pos, float2(0.0, off), texture_size);
    float3 d = Fetch(pos, float2(1.0, off), texture_size);
    float dst = Dist(pos, texture_size).x;
    float scale = params.hardPix;
    float wb = Gaus(dst - 1.0, scale);
    float wc = Gaus(dst + 0.0, scale);
    float wd = Gaus(dst + 1.0, scale);
    return (b * wb + c * wc + d * wd) / (wb + wc + wd);
}

float3 Horz5(float2 pos, float off, float2 texture_size)
{
    float3 a = Fetch(pos, float2(-2.0, off), texture_size);
    float3 b = Fetch(pos, float2(-1.0, off), texture_size);
    float3 c = Fetch(pos, float2(0.0, off), texture_size);
    float3 d = Fetch(pos, float2(1.0, off), texture_size);
    float3 e = Fetch(pos, float2(2.0, off), texture_size);
    float dst = Dist(pos, texture_size).x;
    float scale = params.hardPix;
    float wa = Gaus(dst - 2.0, scale);
    float wb = Gaus(dst - 1.0, scale);
    float wc = Gaus(dst + 0.0, scale);
    float wd = Gaus(dst + 1.0, scale);
    float we = Gaus(dst + 2.0, scale);
    return (a * wa + b * wb + c * wc + d * wd + e * we) / (wa + wb + wc + wd + we);
}

float3 Horz7(float2 pos, float off, float2 texture_size)
{
    float3 a = Fetch(pos, float2(-3.0, off), texture_size);
    float3 b = Fetch(pos, float2(-2.0, off), texture_size);
    float3 c = Fetch(pos, float2(-1.0, off), texture_size);
    float3 d = Fetch(pos, float2(0.0, off), texture_size);
    float3 e = Fetch(pos, float2(1.0, off), texture_size);
    float3 f = Fetch(pos, float2(2.0, off), texture_size);
    float3 g = Fetch(pos, float2(3.0, off), texture_size);
    float dst = Dist(pos, texture_size).x;
    float scale = params.hardBloomPix;
    float wa = Gaus(dst - 3.0, scale);
    float wb = Gaus(dst - 2.0, scale);
    float wc = Gaus(dst - 1.0, scale);
    float wd = Gaus(dst + 0.0, scale);
    float we = Gaus(dst + 1.0, scale);
    float wf = Gaus(dst + 2.0, scale);
    float wg = Gaus(dst + 3.0, scale);
    return (a * wa + b * wb + c * wc + d * wd + e * we + f * wf + g * wg) / (wa + wb + wc + wd + we + wf + wg);
}

float Scan(float2 pos, float off, float2 texture_size)
{
    float dst = Dist(pos, texture_size).y;
    return Gaus(dst + off, params.hardScan);
}

float BloomScan(float2 pos, float off, float2 texture_size)
{
    float dst = Dist(pos, texture_size).y;
    return Gaus(dst + off, params.hardBloomScan);
}

float3 Tri(float2 pos, float2 texture_size)
{
    float3 a = Horz3(pos, -1.0, texture_size);
    float3 b = Horz5(pos, 0.0, texture_size);
    float3 c = Horz3(pos, 1.0, texture_size);
    float wa = Scan(pos, -1.0, texture_size);
    float wb = Scan(pos, 0.0, texture_size);
    float wc = Scan(pos, 1.0, texture_size);
    return a * wa + b * wb + c * wc;
}

float3 Bloom(float2 pos, float2 texture_size)
{
    float3 a = Horz5(pos, -2.0, texture_size);
    float3 b = Horz7(pos, -1.0, texture_size);
    float3 c = Horz7(pos, 0.0, texture_size);
    float3 d = Horz7(pos, 1.0, texture_size);
    float3 e = Horz5(pos, 2.0, texture_size);
    float wa = BloomScan(pos, -2.0, texture_size);
    float wb = BloomScan(pos, -1.0, texture_size);
    float wc = BloomScan(pos, 0.0, texture_size);
    float wd = BloomScan(pos, 1.0, texture_size);
    float we = BloomScan(pos, 2.0, texture_size);
    return a * wa + b * wb + c * wc + d * wd + e * we;
}

float2 Warp(float2 pos)
{
    pos = pos * 2.0 - 1.0;
    pos *= float2(1.0 + (pos.y * pos.y) * warp.x, 1.0 + (pos.x * pos.x) * warp.y);
    return pos * 0.5 + 0.5;
}

float3 Mask(float2 pos)
{
    float3 mask = float3(params.maskDark, params.maskDark, params.maskDark);

    if (params.shadowMask == 1)
    {
        float mask_line = params.maskLight;
        float odd = 0.0;
        if (frac(pos.x / 6.0) < 0.5)
            odd = 1.0;
        if (frac((pos.y + odd) / 2.0) < 0.5)
            mask_line = params.maskDark;
        pos.x = frac(pos.x / 3.0);

        if (pos.x < 0.333)
            mask.r = params.maskLight;
        else if (pos.x < 0.666)
            mask.g = params.maskLight;
        else
            mask.b = params.maskLight;
        mask *= mask_line;
    }
    else if (params.shadowMask == 2)
    {
        pos.x = frac(pos.x / 3.0);

        if (pos.x < 0.333)
            mask.r = params.maskLight;
        else if (pos.x < 0.666)
            mask.g = params.maskLight;
        else
            mask.b = params.maskLight;
    }
    else if (params.shadowMask == 3)
    {
        pos.x += pos.y * 3.0;
        pos.x = frac(pos.x / 6.0);

        if (pos.x < 0.333)
            mask.r = params.maskLight;
        else if (pos.x < 0.666)
            mask.g = params.maskLight;
        else
            mask.b = params.maskLight;
    }
    else if (params.shadowMask == 4)
    {
        pos.xy = floor(pos.xy * float2(1.0, 0.5));
        pos.x += pos.y * 3.0;
        pos.x = frac(pos.x / 6.0);

        if (pos.x < 0.333)
            mask.r = params.maskLight;
        else if (pos.x < 0.666)
            mask.g = params.maskLight;
        else
            mask.b = params.maskLight;
    }

    return mask;
}

[bgfx::EFFECT("CRT Lottes", 2)]
[bgfx::CATEGORY("CRT")]
[bgfx::DESCRIPTION("Timothy Lottes public domain CRT shader simulating a high-quality CGA arcade monitor. Features multiple shadow mask styles, bloom effects, and barrel distortion. Excellent for pixel art games.")]
[bgfx::PASS(1, "CRT Lottes")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    uint2 gxy = tid.xy;
    uint2 outputSize = GetOutputSize();
    float2 pos = (gxy + 0.5f) * GetOutputPt();

    uint2 inputSize = GetInputSize();
    float2 pos1 = Warp(pos);
    float3 outColor = Tri(pos1, inputSize);

#ifdef DO_BLOOM
    outColor.rgb += Bloom(pos1, inputSize) * params.bloomAmount;
#endif

    if (params.shadowMask)
    {
        outColor.rgb *= Mask(gxy + 0.5f);
    }

    OUTPUT[gxy] = float4(pow(outColor.rgb, 1.0f / 2.2f), 1);
}
