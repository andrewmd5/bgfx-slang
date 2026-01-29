// AMD FidelityFX Contrast Adaptive Sharpening
// https://github.com/GPUOpen-Effects/FidelityFX-CAS/blob/master/ffx-cas/ffx_cas.h

import bgfx;

struct CASParams
{
    [bgfx::PARAM("Sharpness", 0.4, 0.0, 1.0, "Controls sharpening intensity. Higher values are sharper but may introduce artifacts.")]
    float sharpness;
};

ConstantBuffer<CASParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

// #define CAS_BETTER_DIAGONALS

#define min3(x, y, z) (min(x, min(y, z)))
#define max3(x, y, z) (max(x, max(y, z)))

#ifdef BG_FP16

void CasFilterHalf(
    out half2 pixR,
    out half2 pixG,
    out half2 pixB,
    half3 src[4][4],
    uint pos,
    half peak)
{
    half2 aR = half2(src[0][pos + 0].r, src[1][pos + 0].r);
    half2 aG = half2(src[0][pos + 0].g, src[1][pos + 0].g);
    half2 aB = half2(src[0][pos + 0].b, src[1][pos + 0].b);

    half2 bR = half2(src[1][pos + 0].r, src[2][pos + 0].r);
    half2 bG = half2(src[1][pos + 0].g, src[2][pos + 0].g);
    half2 bB = half2(src[1][pos + 0].b, src[2][pos + 0].b);

    half2 cR = half2(src[2][pos + 0].r, src[3][pos + 0].r);
    half2 cG = half2(src[2][pos + 0].g, src[3][pos + 0].g);
    half2 cB = half2(src[2][pos + 0].b, src[3][pos + 0].b);

    half2 dR = half2(src[0][pos + 1].r, src[1][pos + 1].r);
    half2 dG = half2(src[0][pos + 1].g, src[1][pos + 1].g);
    half2 dB = half2(src[0][pos + 1].b, src[1][pos + 1].b);

    half2 eR = half2(src[1][pos + 1].r, src[2][pos + 1].r);
    half2 eG = half2(src[1][pos + 1].g, src[2][pos + 1].g);
    half2 eB = half2(src[1][pos + 1].b, src[2][pos + 1].b);

    half2 fR = half2(src[2][pos + 1].r, src[3][pos + 1].r);
    half2 fG = half2(src[2][pos + 1].g, src[3][pos + 1].g);
    half2 fB = half2(src[2][pos + 1].b, src[3][pos + 1].b);

    half2 gR = half2(src[0][pos + 2].r, src[1][pos + 2].r);
    half2 gG = half2(src[0][pos + 2].g, src[1][pos + 2].g);
    half2 gB = half2(src[0][pos + 2].b, src[1][pos + 2].b);

    half2 hR = half2(src[1][pos + 2].r, src[2][pos + 2].r);
    half2 hG = half2(src[1][pos + 2].g, src[2][pos + 2].g);
    half2 hB = half2(src[1][pos + 2].b, src[2][pos + 2].b);

    half2 iR = half2(src[2][pos + 2].r, src[3][pos + 2].r);
    half2 iG = half2(src[2][pos + 2].g, src[3][pos + 2].g);
    half2 iB = half2(src[2][pos + 2].b, src[3][pos + 2].b);

    half2 mnR = min(min(fR, hR), min(min(bR, dR), eR));
    half2 mnG = min(min(fG, hG), min(min(bG, dG), eG));
    half2 mnB = min(min(fB, hB), min(min(bB, dB), eB));

#ifdef CAS_BETTER_DIAGONALS
    half2 mnR2 = min(min(gR, iR), min(min(aR, cR), mnR));
    half2 mnG2 = min(min(gG, iG), min(min(aG, cG), mnG));
    half2 mnB2 = min(min(gB, iB), min(min(aB, cB), mnB));
    mnR = mnR + mnR2;
    mnG = mnG + mnG2;
    mnB = mnB + mnB2;
#endif

    half2 mxR = max(max(fR, hR), max(max(bR, dR), eR));
    half2 mxG = max(max(fG, hG), max(max(bG, dG), eG));
    half2 mxB = max(max(fB, hB), max(max(bB, dB), eB));

#ifdef CAS_BETTER_DIAGONALS
    half2 mxR2 = max(max(gR, iR), max(max(aR, cR), mxR));
    half2 mxG2 = max(max(gG, iG), max(max(aG, cG), mxG));
    half2 mxB2 = max(max(gB, iB), max(max(aB, cB), mxB));
    mxR = mxR + mxR2;
    mxG = mxG + mxG2;
    mxB = mxB + mxB2;
#endif

    half2 rcpMR = rcp(mxR);
    half2 rcpMG = rcp(mxG);
    half2 rcpMB = rcp(mxB);

#ifdef CAS_BETTER_DIAGONALS
    half2 ampR = saturate(min(mnR, half2(2.0h, 2.0h) - mxR) * rcpMR);
    half2 ampG = saturate(min(mnG, half2(2.0h, 2.0h) - mxG) * rcpMG);
    half2 ampB = saturate(min(mnB, half2(2.0h, 2.0h) - mxB) * rcpMB);
#else
    half2 ampR = saturate(min(mnR, half2(1.0h, 1.0h) - mxR) * rcpMR);
    half2 ampG = saturate(min(mnG, half2(1.0h, 1.0h) - mxG) * rcpMG);
    half2 ampB = saturate(min(mnB, half2(1.0h, 1.0h) - mxB) * rcpMB);
#endif

    ampR = sqrt(ampR);
    ampG = sqrt(ampG);
    ampB = sqrt(ampB);

    half2 wR = ampR * peak;
    half2 wG = ampG * peak;
    half2 wB = ampB * peak;

    half2 rcpWeight = rcp(half2(1.0h, 1.0h) + 4.0h * wG);

    pixR = saturate((bR * wG + dR * wG + fR * wG + hR * wG + eR) * rcpWeight);
    pixG = saturate((bG * wG + dG * wG + fG * wG + hG * wG + eG) * rcpWeight);
    pixB = saturate((bB * wG + dB * wG + fB * wG + hB * wG + eB) * rcpWeight);
}

#else

float3 CasFilter(float3 src[4][4], uint2 pos, float peak)
{
    float3 a = src[pos.x - 1][pos.y - 1];
    float3 b = src[pos.x][pos.y - 1];
    float3 c = src[pos.x + 1][pos.y - 1];
    float3 d = src[pos.x - 1][pos.y];
    float3 e = src[pos.x][pos.y];
    float3 f = src[pos.x + 1][pos.y];
    float3 g = src[pos.x - 1][pos.y + 1];
    float3 h = src[pos.x][pos.y + 1];
    float3 i = src[pos.x + 1][pos.y + 1];

    float mnR = min3(min3(d.r, e.r, f.r), b.r, h.r);
    float mnG = min3(min3(d.g, e.g, f.g), b.g, h.g);
    float mnB = min3(min3(d.b, e.b, f.b), b.b, h.b);

#ifdef CAS_BETTER_DIAGONALS
    float mnR2 = min3(min3(mnR, a.r, c.r), g.r, i.r);
    float mnG2 = min3(min3(mnG, a.g, c.g), g.g, i.g);
    float mnB2 = min3(min3(mnB, a.b, c.b), g.b, i.b);
    mnR = mnR + mnR2;
    mnG = mnG + mnG2;
    mnB = mnB + mnB2;
#endif

    float mxR = max3(max3(d.r, e.r, f.r), b.r, h.r);
    float mxG = max3(max3(d.g, e.g, f.g), b.g, h.g);
    float mxB = max3(max3(d.b, e.b, f.b), b.b, h.b);

#ifdef CAS_BETTER_DIAGONALS
    float mxR2 = max3(max3(mxR, a.r, c.r), g.r, i.r);
    float mxG2 = max3(max3(mxG, a.g, c.g), g.g, i.g);
    float mxB2 = max3(max3(mxB, a.b, c.b), g.b, i.b);
    mxR = mxR + mxR2;
    mxG = mxG + mxG2;
    mxB = mxB + mxB2;
#endif

    float rcpMR = rcp(mxR);
    float rcpMG = rcp(mxG);
    float rcpMB = rcp(mxB);

#ifdef CAS_BETTER_DIAGONALS
    float ampR = saturate(min(mnR, 2.0 - mxR) * rcpMR);
    float ampG = saturate(min(mnG, 2.0 - mxG) * rcpMG);
    float ampB = saturate(min(mnB, 2.0 - mxB) * rcpMB);
#else
    float ampR = saturate(min(mnR, 1.0 - mxR) * rcpMR);
    float ampG = saturate(min(mnG, 1.0 - mxG) * rcpMG);
    float ampB = saturate(min(mnB, 1.0 - mxB) * rcpMB);
#endif

    ampR = sqrt(ampR);
    ampG = sqrt(ampG);
    ampB = sqrt(ampB);

    float wR = ampR * peak;
    float wG = ampG * peak;
    float wB = ampB * peak;

    float rcpWeight = rcp(1.0 + 4.0 * wG);

    return float3(
        saturate((b.r * wG + d.r * wG + f.r * wG + h.r * wG + e.r) * rcpWeight),
        saturate((b.g * wG + d.g * wG + f.g * wG + h.g * wG + e.g) * rcpWeight),
        saturate((b.b * wG + d.b * wG + f.b * wG + h.b * wG + e.b) * rcpWeight));
}

#endif

[bgfx::EFFECT("AMD CAS", 2)]
[bgfx::CATEGORY("Sharpening")]
[bgfx::DESCRIPTION("AMD Contrast Adaptive Sharpening - enhances image clarity by increasing local contrast in a content-aware manner.")]
[bgfx::FP16]
[bgfx::PASS(1, "CAS Sharpen")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();
    uint i, j;

#ifdef BG_FP16
    half3 src[4][4];
    [unroll]
    for (i = 0; i < 3; i += 2)
    {
        [unroll]
        for (j = 0; j < 3; j += 2)
        {
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = (half4)INPUT.GatherRed(sam, tpos);
            const half4 sg = (half4)INPUT.GatherGreen(sam, tpos);
            const half4 sb = (half4)INPUT.GatherBlue(sam, tpos);

            src[i][j] = half3(sr.w, sg.w, sb.w);
            src[i][j + 1] = half3(sr.x, sg.x, sb.x);
            src[i + 1][j] = half3(sr.z, sg.z, sb.z);
            src[i + 1][j + 1] = half3(sr.y, sg.y, sb.y);
        }
    }

    const half peak = (half)(-rcp(lerp(8.0, 5.0, params.sharpness)));

    half2 pixR, pixG, pixB;
    CasFilterHalf(pixR, pixG, pixB, src, 0, peak);

    OUTPUT[gxy] = float4(pixR.x, pixG.x, pixB.x, 1);

    ++gxy.x;
    OUTPUT[gxy] = float4(pixR.y, pixG.y, pixB.y, 1);

    CasFilterHalf(pixR, pixG, pixB, src, 1, peak);

    ++gxy.y;
    OUTPUT[gxy] = float4(pixR.y, pixG.y, pixB.y, 1);

    --gxy.x;
    OUTPUT[gxy] = float4(pixR.x, pixG.x, pixB.x, 1);
#else
    float3 src[4][4];
    [unroll]
    for (i = 0; i < 3; i += 2)
    {
        [unroll]
        for (j = 0; j < 3; j += 2)
        {
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const float4 sr = INPUT.GatherRed(sam, tpos);
            const float4 sg = INPUT.GatherGreen(sam, tpos);
            const float4 sb = INPUT.GatherBlue(sam, tpos);

            src[i][j] = float3(sr.w, sg.w, sb.w);
            src[i][j + 1] = float3(sr.x, sg.x, sb.x);
            src[i + 1][j] = float3(sr.z, sg.z, sb.z);
            src[i + 1][j + 1] = float3(sr.y, sg.y, sb.y);
        }
    }

    const float peak = -rcp(lerp(8.0, 5.0, params.sharpness));

    OUTPUT[gxy] = float4(CasFilter(src, uint2(1, 1), peak), 1);

    ++gxy.x;
    OUTPUT[gxy] = float4(CasFilter(src, uint2(2, 1), peak), 1);

    ++gxy.y;
    OUTPUT[gxy] = float4(CasFilter(src, uint2(2, 2), peak), 1);

    --gxy.x;
    OUTPUT[gxy] = float4(CasFilter(src, uint2(1, 2), peak), 1);
#endif
}
