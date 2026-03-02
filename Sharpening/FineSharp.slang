// FineSharp
// Based on: https://forum.doom9.org/showthread.php?t=171346
//
// FineSharp avisynth script by Didee converted to shader format.
// Originally designed for madVR (requires 16-bit accuracy in shader chain).
//
// Note: This sharpener does not filter noise or source artifacts and will
// sharpen those as well. Clean your source first if necessary.

import bgfx;

struct EffectParams
{
    [bgfx::PARAM("Sharpening Strength", 2.0, 0.0, 8.0, "Primary sharpening intensity. Effective range is 0.0 to 8.0. Adjust cstr when changing this value.")]
    float sstr;

    [bgfx::PARAM("Equalisation Strength", 0.9, 0.0, 2.0, "Controls sharpening equalisation. Suggested values based on sstr: 0->0, 0.5->0.1, 1.0->0.6, 2.0->0.9, 3.0->1.09, 4.0->1.19")]
    float cstr;

    [bgfx::PARAM("XSharpen Strength", 0.19, 0.0, 1.0, "Final XSharpen-style sharpening pass. Keep below 0.25 for best results.")]
    float xstr;

    [bgfx::PARAM("Repair Strength", 0.25, 0.0, 1.0, "Reduces artifacts from final sharpening pass. Higher values = more repair.")]
    float xrep;
};

ConstantBuffer<EffectParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex1;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex1_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex2;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex2_UAV;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

#define RGBtoYUV_Matrix(Kb, Kr) float3x3(float3(Kr, 1 - Kr - Kb, Kb), float3(-Kr, Kr + Kb - 1, 1 - Kb) / (2 * (1 - Kb)), float3(1 - Kr, Kr + Kb - 1, -Kb) / (2 * (1 - Kr)))
static const float3x3 RGBtoYUV_SD = RGBtoYUV_Matrix(0.114, 0.299);
static const float3x3 RGBtoYUV_HD = RGBtoYUV_Matrix(0.0722, 0.2126);

#define YUVtoRGB_Matrix(Kb, Kr) float3x3(float3(1, 0, 2 * (1 - Kr)), float3(Kb + Kr - 1, 2 * (1 - Kb) * Kb, 2 * Kr * (1 - Kr)) / (Kb + Kr - 1), float3(1, 2 * (1 - Kb), 0))
static const float3x3 YUVtoRGB_SD = YUVtoRGB_Matrix(0.114, 0.299);
static const float3x3 YUVtoRGB_HD = YUVtoRGB_Matrix(0.0722, 0.2126);

float3x3 GetRGBtoYUV()
{
    return GetInputSize().y <= 576 ? RGBtoYUV_SD : RGBtoYUV_HD;
}

float3x3 GetYUVtoRGB()
{
    return GetInputSize().y <= 576 ? YUVtoRGB_SD : YUVtoRGB_HD;
}

#define sort(a1, a2) (t = min(a1, a2), a2 = max(a1, a2), a1 = t)
#define median3(a1, a2, a3) (sort(a2, a3), sort(a1, a2), min(a2, a3))
#define median5(a1, a2, a3, a4, a5) (sort(a1, a2), sort(a3, a4), sort(a1, a3), sort(a2, a4), median3(a2, a3, a5))
#define median9(a1, a2, a3, a4, a5, a6, a7, a8, a9) (sort(a1, a2), sort(a3, a4), sort(a5, a6), sort(a7, a8),               \
                                                     sort(a1, a3), sort(a5, a7), sort(a1, a5), sort(a3, a5), sort(a3, a7), \
                                                     sort(a2, a4), sort(a6, a8), sort(a4, a8), sort(a4, a6), sort(a2, a6), median5(a2, a4, a5, a7, a9))

#define sort_min_max3(a1, a2, a3) (sort(a1, a2), sort(a1, a3), sort(a2, a3))
#define sort_min_max5(a1, a2, a3, a4, a5) (sort(a1, a2), sort(a3, a4), sort(a1, a3), sort(a2, a4), sort(a1, a5), sort(a4, a5))
#define sort_min_max7(a1, a2, a3, a4, a5, a6, a7) (sort(a1, a2), sort(a3, a4), sort(a5, a6), sort(a1, a3), sort(a1, a5), sort(a2, a6), sort(a4, a5), sort(a1, a7), sort(a6, a7))
#define sort_min_max9(a1, a2, a3, a4, a5, a6, a7, a8, a9) (sort(a1, a2), sort(a3, a4), sort(a5, a6), sort(a7, a8), sort(a1, a3), sort(a5, a7), sort(a1, a5), sort(a2, a4), sort(a6, a7), sort(a4, a8), sort(a1, a9), sort(a8, a9))
#define sort9_partial2(a1, a2, a3, a4, a5, a6, a7, a8, a9) (sort_min_max9(a1, a2, a3, a4, a5, a6, a7, a8, a9), sort_min_max7(a2, a3, a4, a5, a6, a7, a8))

#define lstr 1.49
#define pstr 1.272

float ComputeSharpDiff(float4 c, float sstr_local, float ldmp)
{
    float t = c.a - c.x;
    return sign(t) * (sstr_local / 255.0f) * pow(abs(t) / (lstr / 255.0f), 1.0f / pstr) * ((t * t) / (t * t + ldmp / (255.0f * 255.0f)));
}

[bgfx::EFFECT("FineSharp", 2)]
[bgfx::CATEGORY("Sharpening")]
[bgfx::DESCRIPTION("Multi-pass sharpening algorithm with equalisation and repair. Provides fine detail enhancement with minimal artifacts when properly tuned.")]
[bgfx::PASS(1, "RGB to YUV conversion with Gaussian blur")]
[bgfx::PASS_IO("INPUT", "tex1")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();
    float3x3 RGBtoYUV = GetRGBtoYUV();

    float3 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const float4 sr = INPUT.GatherRed(sam, tpos);
            const float4 sg = INPUT.GatherGreen(sam, tpos);
            const float4 sb = INPUT.GatherBlue(sam, tpos);

            src[i][j] = mul(RGBtoYUV, float3(sr.w, sg.w, sb.w)) + float3(0, 0.5, 0.5);
            src[i][j + 1] = mul(RGBtoYUV, float3(sr.x, sg.x, sb.x)) + float3(0, 0.5, 0.5);
            src[i + 1][j] = mul(RGBtoYUV, float3(sr.z, sg.z, sb.z)) + float3(0, 0.5, 0.5);
            src[i + 1][j + 1] = mul(RGBtoYUV, float3(sr.y, sg.y, sb.y)) + float3(0, 0.5, 0.5);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            float4 o = src[i][j].rgbr;

            o.x += o.x;
            o.x += src[i][j - 1].x + src[i - 1][j].x + src[i + 1][j].x + src[i][j + 1].x;
            o.x += o.x;
            o.x += src[i - 1][j - 1].x + src[i + 1][j - 1].x + src[i - 1][j + 1].x + src[i + 1][j + 1].x;
            o.x *= 0.0625f;

            tex1_UAV[gxy + uint2(i - 1, j - 1)] = o;
        }
    }
}

[bgfx::PASS(2, "Median filter pass (RemoveGrain4)")]
[bgfx::PASS_IO("tex1", "tex2")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    float4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const float4 sr = tex1.GatherRed(sam, tpos);

            src[i][j].r = sr.w;
            src[i][j + 1].r = sr.x;
            src[i + 1][j].r = sr.z;
            src[i + 1][j + 1].r = sr.y;
        }
    }

    float2 tpos = (gxy + 1) * inputPt;
    const float4 sg = tex1.GatherGreen(sam, tpos);
    const float4 sb = tex1.GatherBlue(sam, tpos);
    const float4 sa = tex1.GatherAlpha(sam, tpos);
    src[1][1].gba = float3(sg.w, sb.w, sa.w);
    src[1][2].gba = float3(sg.x, sb.x, sa.x);
    src[2][1].gba = float3(sg.z, sb.z, sa.z);
    src[2][2].gba = float3(sg.y, sb.y, sa.y);

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            float4 o = src[i][j];

            o.x += o.x;
            o.x += src[i][j - 1].x + src[i - 1][j].x + src[i + 1][j].x + src[i][j + 1].x;
            o.x += o.x;
            o.x += src[i - 1][j - 1].x + src[i + 1][j - 1].x + src[i - 1][j + 1].x + src[i + 1][j + 1].x;
            o.x *= 0.0625f;

            float t;
            float t1 = src[i - 1][j - 1].x;
            float t2 = src[i][j - 1].x;
            float t3 = src[i + 1][j - 1].x;
            float t4 = src[i - 1][j].x;
            float t5 = o.x;
            float t6 = src[i + 1][j].x;
            float t7 = src[i - 1][j + 1].x;
            float t8 = src[i][j + 1].x;
            float t9 = src[i + 1][j + 1].x;
            o.x = median9(t1, t2, t3, t4, t5, t6, t7, t8, t9);

            tex2_UAV[gxy + uint2(i - 1, j - 1)] = o;
        }
    }
}

[bgfx::PASS(3, "Sharpening calculation (Part A)")]
[bgfx::PASS_IO("tex2", "tex1")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass3(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();
    float ldmp = params.sstr + 0.1f;

    float4 src[4][4];
    float sharpDiffs[4][4];

    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const float4 sr = tex2.GatherRed(sam, tpos);
            const float4 sa = tex2.GatherAlpha(sam, tpos);

            src[i][j].ra = float2(sr.w, sa.w);
            src[i][j + 1].ra = float2(sr.x, sa.x);
            src[i + 1][j].ra = float2(sr.z, sa.z);
            src[i + 1][j + 1].ra = float2(sr.y, sa.y);

            sharpDiffs[i][j] = ComputeSharpDiff(src[i][j], params.sstr, ldmp);
            sharpDiffs[i][j + 1] = ComputeSharpDiff(src[i][j + 1], params.sstr, ldmp);
            sharpDiffs[i + 1][j] = ComputeSharpDiff(src[i + 1][j], params.sstr, ldmp);
            sharpDiffs[i + 1][j + 1] = ComputeSharpDiff(src[i + 1][j + 1], params.sstr, ldmp);
        }
    }

    float2 tpos = (gxy + 1) * inputPt;
    const float4 sg = tex2.GatherGreen(sam, tpos);
    const float4 sb = tex2.GatherBlue(sam, tpos);
    src[1][1].gb = float2(sg.w, sb.w);
    src[1][2].gb = float2(sg.x, sb.x);
    src[2][1].gb = float2(sg.z, sb.z);
    src[2][2].gb = float2(sg.y, sb.y);

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            float4 o = src[i][j];

            float sd = sharpDiffs[i][j];
            o.x = o.a + sd;

            sd += sd;
            sd += sharpDiffs[i][j - 1] + sharpDiffs[i - 1][j] + sharpDiffs[i + 1][j] + sharpDiffs[i][j + 1];
            sd += sd;
            sd += sharpDiffs[i - 1][j - 1] + sharpDiffs[i + 1][j - 1] + sharpDiffs[i - 1][j + 1] + sharpDiffs[i + 1][j + 1];
            sd *= 0.0625f;
            o.x -= params.cstr * sd;
            o.a = o.x;

            tex1_UAV[gxy + uint2(i - 1, j - 1)] = o;
        }
    }
}

[bgfx::PASS(4, "Edge-aware repair (Part B)")]
[bgfx::PASS_IO("tex1", "tex2")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass4(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    float4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const float4 sa = tex1.GatherAlpha(sam, tpos);

            src[i][j].a = sa.w;
            src[i][j + 1].a = sa.x;
            src[i + 1][j].a = sa.z;
            src[i + 1][j + 1].a = sa.y;
        }
    }

    float2 tpos = (gxy + 1) * inputPt;
    const float4 sr = tex1.GatherRed(sam, tpos);
    const float4 sg = tex1.GatherGreen(sam, tpos);
    const float4 sb = tex1.GatherBlue(sam, tpos);
    src[1][1].rgb = float3(sr.w, sg.w, sb.w);
    src[1][2].rgb = float3(sr.x, sg.x, sb.x);
    src[2][1].rgb = float3(sr.z, sg.z, sb.z);
    src[2][2].rgb = float3(sr.y, sg.y, sb.y);

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            float4 o = src[i][j];

            float t;
            float t1 = src[i - 1][j - 1].a;
            float t2 = src[i][j - 1].a;
            float t3 = src[i + 1][j - 1].a;
            float t4 = src[i - 1][j].a;
            float t5 = o.a;
            float t6 = src[i + 1][j].a;
            float t7 = src[i - 1][j + 1].a;
            float t8 = src[i][j + 1].a;
            float t9 = src[i + 1][j + 1].a;

            o.x += t1 + t2 + t3 + t4 + t6 + t7 + t8 + t9;
            o.x /= 9.0f;
            o.x = o.a + 9.9f * (o.a - o.x);

            sort9_partial2(t1, t2, t3, t4, t5, t6, t7, t8, t9);
            o.x = max(o.x, min(t2, o.a));
            o.x = min(o.x, max(t8, o.a));

            tex2_UAV[gxy + uint2(i - 1, j - 1)] = o;
        }
    }
}

[bgfx::PASS(5, "Final XSharpen and YUV to RGB (Part C)")]
[bgfx::PASS_IO("tex2", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass5(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();
    float3x3 YUVtoRGB = GetYUVtoRGB();

    float4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const float4 sr = tex2.GatherRed(sam, tpos);

            src[i][j].r = sr.w;
            src[i][j + 1].r = sr.x;
            src[i + 1][j].r = sr.z;
            src[i + 1][j + 1].r = sr.y;
        }
    }

    float2 tpos = (gxy + 1) * inputPt;
    const float4 sg = tex2.GatherGreen(sam, tpos);
    const float4 sb = tex2.GatherBlue(sam, tpos);
    const float4 sa = tex2.GatherAlpha(sam, tpos);
    src[1][1].gba = float3(sg.w, sb.w, sa.w);
    src[1][2].gba = float3(sg.x, sb.x, sa.x);
    src[2][1].gba = float3(sg.z, sb.z, sa.z);
    src[2][2].gba = float3(sg.y, sb.y, sa.y);

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            float4 o = src[i][j];

            float edge = abs(src[i][j - 1].x + src[i - 1][j].x + src[i + 1][j].x + src[i][j + 1].x - 4 * o.x);
            o.x = lerp(o.a, o.x, params.xstr * (1 - saturate(edge * params.xrep)));

            OUTPUT[destPos] = float4(mul(YUVtoRGB, o.xyz - float3(0.0, 0.5, 0.5)), 1);
        }
    }
}
