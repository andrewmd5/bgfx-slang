// AMD FidelityFX Super Resolution - Robust Contrast Adaptive Sharpening (RCAS)
// Based on FidelityFX-FSR from GPUOpen-Effects

import bgfx;

struct EffectParams
{
    [bgfx::PARAM("Sharpness", 0.87, 0, 1, "Controls sharpening intensity. Higher values produce sharper output but may introduce artifacts. Default 0.87 provides balanced sharpening.")]
    float sharpness;
};
ConstantBuffer<EffectParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

#define min3(a, b, c) min(a, min(b, c))
#define max3(a, b, c) max(a, max(b, c))

#define FSR_RCAS_LIMIT (0.25 - (1.0 / 16.0))

#ifdef BG_FP16

void FsrRcasHx2(
    out half2 pixR,
    out half2 pixG,
    out half2 pixB,
    float3 b0, float3 d0, float3 e0, float3 f0, float3 h0,
    float3 b1, float3 d1, float3 e1, float3 f1, float3 h1,
    half s)
{
    half2 bR = half2(b0.r, b1.r);
    half2 bG = half2(b0.g, b1.g);
    half2 bB = half2(b0.b, b1.b);
    half2 dR = half2(d0.r, d1.r);
    half2 dG = half2(d0.g, d1.g);
    half2 dB = half2(d0.b, d1.b);
    half2 eR = half2(e0.r, e1.r);
    half2 eG = half2(e0.g, e1.g);
    half2 eB = half2(e0.b, e1.b);
    half2 fR = half2(f0.r, f1.r);
    half2 fG = half2(f0.g, f1.g);
    half2 fB = half2(f0.b, f1.b);
    half2 hR = half2(h0.r, h1.r);
    half2 hG = half2(h0.g, h1.g);
    half2 hB = half2(h0.b, h1.b);

    half2 bL = bB * 0.5 + (bR * 0.5 + bG);
    half2 dL = dB * 0.5 + (dR * 0.5 + dG);
    half2 eL = eB * 0.5 + (eR * 0.5 + eG);
    half2 fL = fB * 0.5 + (fR * 0.5 + fG);
    half2 hL = hB * 0.5 + (hR * 0.5 + hG);

    half2 nz = 0.25 * bL + 0.25 * dL + 0.25 * fL + 0.25 * hL - eL;
    nz = saturate(abs(nz) * rcp(max3(max3(bL, dL, eL), fL, hL) - min3(min3(bL, dL, eL), fL, hL)));
    nz = -0.5 * nz + 1.0;

    half2 mn4R = min(min3(bR, dR, fR), hR);
    half2 mn4G = min(min3(bG, dG, fG), hG);
    half2 mn4B = min(min3(bB, dB, fB), hB);
    half2 mx4R = max(min3(bR, dR, fR), hR);
    half2 mx4G = max(min3(bG, dG, fG), hG);
    half2 mx4B = max(min3(bB, dB, fB), hB);

    half2 peakC = half2(1.0, -1.0 * 4.0);

    half2 hitMinR = min(mn4R, eR) * rcp(4.0 * mx4R);
    half2 hitMinG = min(mn4G, eG) * rcp(4.0 * mx4G);
    half2 hitMinB = min(mn4B, eB) * rcp(4.0 * mx4B);
    half2 hitMaxR = (peakC.x - max(mx4R, eR)) * rcp(4.0 * mn4R + peakC.y);
    half2 hitMaxG = (peakC.x - max(mx4G, eG)) * rcp(4.0 * mn4G + peakC.y);
    half2 hitMaxB = (peakC.x - max(mx4B, eB)) * rcp(4.0 * mn4B + peakC.y);
    half2 lobeR = max(-hitMinR, hitMaxR);
    half2 lobeG = max(-hitMinG, hitMaxG);
    half2 lobeB = max(-hitMinB, hitMaxB);
    half2 lobe = max(-FSR_RCAS_LIMIT, min(max3(lobeR, lobeG, lobeB), 0.0)) * s;

    lobe *= nz;

    half2 rcpL = rcp(4.0 * lobe + 1.0);
    pixR = (lobe * bR + lobe * dR + lobe * hR + lobe * fR + eR) * rcpL;
    pixG = (lobe * bG + lobe * dG + lobe * hG + lobe * fG + eG) * rcpL;
    pixB = (lobe * bB + lobe * dB + lobe * hB + lobe * fB + eB) * rcpL;
}

#else

float3 FsrRcasF(float3 b, float3 d, float3 e, float3 f, float3 h)
{
    float bR = b.r;
    float bG = b.g;
    float bB = b.b;
    float dR = d.r;
    float dG = d.g;
    float dB = d.b;
    float eR = e.r;
    float eG = e.g;
    float eB = e.b;
    float fR = f.r;
    float fG = f.g;
    float fB = f.b;
    float hR = h.r;
    float hG = h.g;
    float hB = h.b;

    float bL = bB * 0.5 + (bR * 0.5 + bG);
    float dL = dB * 0.5 + (dR * 0.5 + dG);
    float eL = eB * 0.5 + (eR * 0.5 + eG);
    float fL = fB * 0.5 + (fR * 0.5 + fG);
    float hL = hB * 0.5 + (hR * 0.5 + hG);

    float nz = 0.25 * bL + 0.25 * dL + 0.25 * fL + 0.25 * hL - eL;
    nz = saturate(abs(nz) * rcp(max3(max3(bL, dL, eL), fL, hL) - min3(min3(bL, dL, eL), fL, hL)));
    nz = -0.5 * nz + 1.0;

    float mn4R = min(min3(bR, dR, fR), hR);
    float mn4G = min(min3(bG, dG, fG), hG);
    float mn4B = min(min3(bB, dB, fB), hB);
    float mx4R = max(max3(bR, dR, fR), hR);
    float mx4G = max(max3(bG, dG, fG), hG);
    float mx4B = max(max3(bB, dB, fB), hB);

    float2 peakC = { 1.0, -1.0 * 4.0 };

    float hitMinR = min(mn4R, eR) * rcp(4.0 * mx4R);
    float hitMinG = min(mn4G, eG) * rcp(4.0 * mx4G);
    float hitMinB = min(mn4B, eB) * rcp(4.0 * mx4B);
    float hitMaxR = (peakC.x - max(mx4R, eR)) * rcp(4.0 * mn4R + peakC.y);
    float hitMaxG = (peakC.x - max(mx4G, eG)) * rcp(4.0 * mn4G + peakC.y);
    float hitMaxB = (peakC.x - max(mx4B, eB)) * rcp(4.0 * mn4B + peakC.y);
    float lobeR = max(-hitMinR, hitMaxR);
    float lobeG = max(-hitMinG, hitMaxG);
    float lobeB = max(-hitMinB, hitMaxB);
    float lobe = max(-FSR_RCAS_LIMIT, min(max3(lobeR, lobeG, lobeB), 0)) * params.sharpness;

    lobe *= nz;

    float rcpL = rcp(4.0 * lobe + 1.0);
    float3 c = {
        (lobe * bR + lobe * dR + lobe * hR + lobe * fR + eR) * rcpL,
        (lobe * bG + lobe * dG + lobe * hG + lobe * fG + eG) * rcpL,
        (lobe * bB + lobe * dB + lobe * hB + lobe * fB + eB) * rcpL
    };

    return c;
}

#endif

[bgfx::EFFECT("FSR RCAS (Sharpening)", 2)]
[bgfx::CATEGORY("Sharpening")]
[bgfx::DESCRIPTION("AMD FidelityFX Super Resolution 1.0 sharpening pass. RCAS applies contrast-adaptive sharpening with built-in noise reduction for cleaner results.")]
[bgfx::FP16]
[bgfx::PASS(1, "RCAS")]
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

    float3 src[4][4];
    $for(i in Range(1, 3))
    {
        $for(j in Range(0, 4))
        {
            src[i][j] = INPUT.Load(int3(gxy.x + i - 1, gxy.y + j - 1, 0)).rgb;
        }
    }

    src[0][1] = INPUT.Load(int3(gxy.x - 1, gxy.y, 0)).rgb;
    src[0][2] = INPUT.Load(int3(gxy.x - 1, gxy.y + 1, 0)).rgb;
    src[3][1] = INPUT.Load(int3(gxy.x + 2, gxy.y, 0)).rgb;
    src[3][2] = INPUT.Load(int3(gxy.x + 2, gxy.y + 1, 0)).rgb;

#ifdef BG_FP16
    half2 pixR, pixG, pixB;
    const half s = (half)params.sharpness;

    FsrRcasHx2(pixR, pixG, pixB, src[1][0], src[0][1], src[1][1], src[2][1], src[1][2], src[2][0], src[1][1], src[2][1], src[3][1], src[2][2], s);
    OUTPUT[gxy] = half4(pixR.x, pixG.x, pixB.x, 1);
    ++gxy.x;
    OUTPUT[gxy] = half4(pixR.y, pixG.y, pixB.y, 1);

    FsrRcasHx2(pixR, pixG, pixB, src[2][1], src[1][2], src[2][2], src[3][2], src[2][3], src[1][1], src[0][2], src[1][2], src[2][2], src[1][3], s);
    ++gxy.y;
    OUTPUT[gxy] = half4(pixR.x, pixG.x, pixB.x, 1);
    --gxy.x;
    OUTPUT[gxy] = half4(pixR.y, pixG.y, pixB.y, 1);
#else
    OUTPUT[gxy] = float4(FsrRcasF(src[1][0], src[0][1], src[1][1], src[2][1], src[1][2]), 1);

    ++gxy.x;
    if (gxy.x < outputSize.x && gxy.y < outputSize.y)
    {
        OUTPUT[gxy] = float4(FsrRcasF(src[2][0], src[1][1], src[2][1], src[3][1], src[2][2]), 1);
    }

    ++gxy.y;
    if (gxy.x < outputSize.x && gxy.y < outputSize.y)
    {
        OUTPUT[gxy] = float4(FsrRcasF(src[2][1], src[1][2], src[2][2], src[3][2], src[2][3]), 1);
    }

    --gxy.x;
    if (gxy.x < outputSize.x && gxy.y < outputSize.y)
    {
        OUTPUT[gxy] = float4(FsrRcasF(src[1][1], src[0][2], src[1][2], src[2][2], src[1][3]), 1);
    }
#endif
}
