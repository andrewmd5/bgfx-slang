// AMD FidelityFX Super Resolution - Edge Adaptive Spatial Upscaling (EASU)
// Based on FidelityFX-FSR from GPUOpen-Effects

import bgfx;

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

#define min3(a, b, c) min(a, min(b, c))
#define max3(a, b, c) max(a, max(b, c))

#ifdef BG_FP16

void FsrEasuTapH(
    inout half2 aCR,
    inout half2 aCG,
    inout half2 aCB,
    inout half2 aW,
    half2 offX,
    half2 offY,
    half2 dir,
    half2 len,
    half lob,
    half clp,
    half2 cR,
    half2 cG,
    half2 cB)
{
    half2 vX, vY;
    vX = offX * dir.xx + offY * dir.yy;
    vY = offX * (-dir.yy) + offY * dir.xx;

    vX *= len.x;
    vY *= len.y;

    half2 d2 = vX * vX + vY * vY;
    d2 = min(d2, clp);

    half2 wB = half(2.0 / 5.0) * d2 - half(1.0);
    half2 wA = lob * d2 - half(1.0);
    wB *= wB;
    wA *= wA;
    wB = half(25.0 / 16.0) * wB - half(25.0 / 16.0 - 1.0);
    half2 w = wB * wA;

    aCR += cR * w;
    aCG += cG * w;
    aCB += cB * w;
    aW += w;
}

void FsrEasuSetH(
    inout half2 dirPX,
    inout half2 dirPY,
    inout half2 lenP,
    half2 pp,
    bool biST,
    bool biUV,
    half2 lA,
    half2 lB,
    half2 lC,
    half2 lD,
    half2 lE)
{
    half2 w = half2(0, 0);
    if (biST)
        w = (half2(1.0, 0.0) + half2(-pp.x, pp.x)) * half(half(1.0) - pp.y);
    if (biUV)
        w = (half2(1.0, 0.0) + half2(-pp.x, pp.x)) * half(pp.y);

    half2 dc = lD - lC;
    half2 cb = lC - lB;
    half2 lenX = max(abs(dc), abs(cb));
    lenX = rcp(lenX);
    half2 dirX = lD - lB;
    dirPX += dirX * w;
    lenX = saturate(abs(dirX) * lenX);
    lenX *= lenX;
    lenP += lenX * w;

    half2 ec = lE - lC;
    half2 ca = lC - lA;
    half2 lenY = max(abs(ec), abs(ca));
    lenY = rcp(lenY);
    half2 dirY = lE - lA;
    dirPY += dirY * w;
    lenY = saturate(abs(dirY) * lenY);
    lenY *= lenY;
    lenP += lenY * w;
}

half3 FsrEasu(
    uint2 ip,
    float4 con0,
    float4 con1,
    float4 con2,
    float2 con3)
{
    float2 pp = float2(ip) * con0.xy + con0.zw;
    float2 fp = floor(pp);
    pp -= fp;
    half2 ppp = half2(pp);

    float2 p0 = fp * con1.xy + con1.zw;
    float2 p1 = p0 + con2.xy;
    float2 p2 = p0 + con2.zw;
    float2 p3 = p0 + con3.xy;

    half4 bczzR = (half4)INPUT.GatherRed(sam, p0);
    half4 bczzG = (half4)INPUT.GatherGreen(sam, p0);
    half4 bczzB = (half4)INPUT.GatherBlue(sam, p0);
    half4 ijfeR = (half4)INPUT.GatherRed(sam, p1);
    half4 ijfeG = (half4)INPUT.GatherGreen(sam, p1);
    half4 ijfeB = (half4)INPUT.GatherBlue(sam, p1);
    half4 klhgR = (half4)INPUT.GatherRed(sam, p2);
    half4 klhgG = (half4)INPUT.GatherGreen(sam, p2);
    half4 klhgB = (half4)INPUT.GatherBlue(sam, p2);
    half4 zzonR = (half4)INPUT.GatherRed(sam, p3);
    half4 zzonG = (half4)INPUT.GatherGreen(sam, p3);
    half4 zzonB = (half4)INPUT.GatherBlue(sam, p3);

    half4 bczzL = bczzB * half(0.5) + (bczzR * half(0.5) + bczzG);
    half4 ijfeL = ijfeB * half(0.5) + (ijfeR * half(0.5) + ijfeG);
    half4 klhgL = klhgB * half(0.5) + (klhgR * half(0.5) + klhgG);
    half4 zzonL = zzonB * half(0.5) + (zzonR * half(0.5) + zzonG);

    half bL = bczzL.x;
    half cL = bczzL.y;
    half iL = ijfeL.x;
    half jL = ijfeL.y;
    half fL = ijfeL.z;
    half eL = ijfeL.w;
    half kL = klhgL.x;
    half lL = klhgL.y;
    half hL = klhgL.z;
    half gL = klhgL.w;
    half oL = zzonL.z;
    half nL = zzonL.w;

    half2 dirPX = half2(0, 0);
    half2 dirPY = half2(0, 0);
    half2 lenP = half2(0, 0);
    FsrEasuSetH(dirPX, dirPY, lenP, ppp, true, false, half2(bL, cL), half2(eL, fL), half2(fL, gL), half2(gL, hL), half2(jL, kL));
    FsrEasuSetH(dirPX, dirPY, lenP, ppp, false, true, half2(fL, gL), half2(iL, jL), half2(jL, kL), half2(kL, lL), half2(nL, oL));
    half2 dir = half2(dirPX.r + dirPX.g, dirPY.r + dirPY.g);
    half len = lenP.r + lenP.g;

    half2 dir2 = dir * dir;
    half dirR = dir2.x + dir2.y;
    bool zro = dirR < half(1.0 / 32768.0);
    dirR = rsqrt(dirR);
    dirR = zro ? half(1.0) : dirR;
    dir.x = zro ? half(1.0) : dir.x;
    dir *= dirR;

    len = len * half(0.5);
    len *= len;
    half stretch = (dir.x * dir.x + dir.y * dir.y) * rcp(max(abs(dir.x), abs(dir.y)));
    half2 len2 = half2(half(1.0) + (stretch - half(1.0)) * len, half(1.0) + half(-0.5) * len);
    half lob = half(0.5) + half((1.0 / 4.0 - 0.04) - 0.5) * len;
    half clp = rcp(lob);

    half2 bothR = max(max(half2(-ijfeR.z, ijfeR.z), half2(-klhgR.w, klhgR.w)), max(half2(-ijfeR.y, ijfeR.y), half2(-klhgR.x, klhgR.x)));
    half2 bothG = max(max(half2(-ijfeG.z, ijfeG.z), half2(-klhgG.w, klhgG.w)), max(half2(-ijfeG.y, ijfeG.y), half2(-klhgG.x, klhgG.x)));
    half2 bothB = max(max(half2(-ijfeB.z, ijfeB.z), half2(-klhgB.w, klhgB.w)), max(half2(-ijfeB.y, ijfeB.y), half2(-klhgB.x, klhgB.x)));

    half2 pR = half2(0, 0);
    half2 pG = half2(0, 0);
    half2 pB = half2(0, 0);
    half2 pW = half2(0, 0);
    FsrEasuTapH(pR, pG, pB, pW, half2(0.0, 1.0) - ppp.xx, half2(-1.0, -1.0) - ppp.yy, dir, len2, lob, clp, bczzR.xy, bczzG.xy, bczzB.xy);
    FsrEasuTapH(pR, pG, pB, pW, half2(-1.0, 0.0) - ppp.xx, half2(1.0, 1.0) - ppp.yy, dir, len2, lob, clp, ijfeR.xy, ijfeG.xy, ijfeB.xy);
    FsrEasuTapH(pR, pG, pB, pW, half2(0.0, -1.0) - ppp.xx, half2(0.0, 0.0) - ppp.yy, dir, len2, lob, clp, ijfeR.zw, ijfeG.zw, ijfeB.zw);
    FsrEasuTapH(pR, pG, pB, pW, half2(1.0, 2.0) - ppp.xx, half2(1.0, 1.0) - ppp.yy, dir, len2, lob, clp, klhgR.xy, klhgG.xy, klhgB.xy);
    FsrEasuTapH(pR, pG, pB, pW, half2(2.0, 1.0) - ppp.xx, half2(0.0, 0.0) - ppp.yy, dir, len2, lob, clp, klhgR.zw, klhgG.zw, klhgB.zw);
    FsrEasuTapH(pR, pG, pB, pW, half2(1.0, 0.0) - ppp.xx, half2(2.0, 2.0) - ppp.yy, dir, len2, lob, clp, zzonR.zw, zzonG.zw, zzonB.zw);

    half3 aC = half3(pR.x + pR.y, pG.x + pG.y, pB.x + pB.y);
    half aW = pW.x + pW.y;

    return min(half3(bothR.y, bothG.y, bothB.y), max(-half3(bothR.x, bothG.x, bothB.x), aC * rcp(aW)));
}

#else

void FsrEasuTapF(
    inout float3 aC,
    inout float aW,
    float2 off,
    float2 dir,
    float2 len,
    float lob,
    float clp,
    float3 c)
{
    float2 v;
    v.x = (off.x * (dir.x)) + (off.y * dir.y);
    v.y = (off.x * (-dir.y)) + (off.y * dir.x);

    v *= len;

    float d2 = v.x * v.x + v.y * v.y;
    d2 = min(d2, clp);

    float wB = 2.0f / 5.0f * d2 - 1;
    float wA = lob * d2 - 1;
    wB *= wB;
    wA *= wA;
    wB = 25.0f / 16.0f * wB - (25.0f / 16.0f - 1.0f);
    float w = wB * wA;

    aC += c * w;
    aW += w;
}

void FsrEasuSetF(
    inout float2 dir,
    inout float len,
    float2 pp,
    bool biS,
    bool biT,
    bool biU,
    bool biV,
    float lA,
    float lB,
    float lC,
    float lD,
    float lE)
{
    float w = 0;
    if (biS)
        w = (1 - pp.x) * (1 - pp.y);
    if (biT)
        w = pp.x * (1 - pp.y);
    if (biU)
        w = (1.0 - pp.x) * pp.y;
    if (biV)
        w = pp.x * pp.y;

    float dc = lD - lC;
    float cb = lC - lB;
    float lenX = max(abs(dc), abs(cb));
    lenX = rcp(lenX);
    float dirX = lD - lB;
    dir.x += dirX * w;
    lenX = saturate(abs(dirX) * lenX);
    lenX *= lenX;
    len += lenX * w;

    float ec = lE - lC;
    float ca = lC - lA;
    float lenY = max(abs(ec), abs(ca));
    lenY = rcp(lenY);
    float dirY = lE - lA;
    dir.y += dirY * w;
    lenY = saturate(abs(dirY) * lenY);
    lenY *= lenY;
    len += lenY * w;
}

float3 FsrEasu(uint2 ip, float4 con0, float4 con1, float4 con2, float2 con3)
{
    float2 pp = ip * con0.xy + con0.zw;
    float2 fp = floor(pp);
    pp -= fp;

    float2 p0 = fp * con1.xy + con1.zw;
    float2 p1 = p0 + con2.xy;
    float2 p2 = p0 + con2.zw;
    float2 p3 = p0 + con3;

    float4 bczzR = INPUT.GatherRed(sam, p0);
    float4 bczzG = INPUT.GatherGreen(sam, p0);
    float4 bczzB = INPUT.GatherBlue(sam, p0);
    float4 ijfeR = INPUT.GatherRed(sam, p1);
    float4 ijfeG = INPUT.GatherGreen(sam, p1);
    float4 ijfeB = INPUT.GatherBlue(sam, p1);
    float4 klhgR = INPUT.GatherRed(sam, p2);
    float4 klhgG = INPUT.GatherGreen(sam, p2);
    float4 klhgB = INPUT.GatherBlue(sam, p2);
    float4 zzonR = INPUT.GatherRed(sam, p3);
    float4 zzonG = INPUT.GatherGreen(sam, p3);
    float4 zzonB = INPUT.GatherBlue(sam, p3);

    float4 bczzL = bczzB * 0.5 + (bczzR * 0.5 + bczzG);
    float4 ijfeL = ijfeB * 0.5 + (ijfeR * 0.5 + ijfeG);
    float4 klhgL = klhgB * 0.5 + (klhgR * 0.5 + klhgG);
    float4 zzonL = zzonB * 0.5 + (zzonR * 0.5 + zzonG);

    float bL = bczzL.x;
    float cL = bczzL.y;
    float iL = ijfeL.x;
    float jL = ijfeL.y;
    float fL = ijfeL.z;
    float eL = ijfeL.w;
    float kL = klhgL.x;
    float lL = klhgL.y;
    float hL = klhgL.z;
    float gL = klhgL.w;
    float oL = zzonL.z;
    float nL = zzonL.w;

    float2 dir = 0;
    float len = 0;
    FsrEasuSetF(dir, len, pp, true, false, false, false, bL, eL, fL, gL, jL);
    FsrEasuSetF(dir, len, pp, false, true, false, false, cL, fL, gL, hL, kL);
    FsrEasuSetF(dir, len, pp, false, false, true, false, fL, iL, jL, kL, nL);
    FsrEasuSetF(dir, len, pp, false, false, false, true, gL, jL, kL, lL, oL);

    float2 dir2 = dir * dir;
    float dirR = dir2.x + dir2.y;
    bool zro = dirR < 1.0f / 32768.0f;
    dirR = rsqrt(dirR);
    dirR = zro ? 1 : dirR;
    dir.x = zro ? 1 : dir.x;
    dir *= dirR;

    len = len * 0.5;
    len *= len;

    float stretch = (dir.x * dir.x + dir.y * dir.y) * rcp(max(abs(dir.x), abs(dir.y)));

    float2 len2 = { 1 + (stretch - 1) * len, 1 - 0.5 * len };

    float lob = 0.5 + ((1.0 / 4.0 - 0.04) - 0.5) * len;
    float clp = rcp(lob);

    float3 min4 = min(min3(float3(ijfeR.z, ijfeG.z, ijfeB.z), float3(klhgR.w, klhgG.w, klhgB.w), float3(ijfeR.y, ijfeG.y, ijfeB.y)),
                      float3(klhgR.x, klhgG.x, klhgB.x));
    float3 max4 = max(max3(float3(ijfeR.z, ijfeG.z, ijfeB.z), float3(klhgR.w, klhgG.w, klhgB.w), float3(ijfeR.y, ijfeG.y, ijfeB.y)),
                      float3(klhgR.x, klhgG.x, klhgB.x));

    float3 aC = 0;
    float aW = 0;
    FsrEasuTapF(aC, aW, float2(0.0, -1.0) - pp, dir, len2, lob, clp, float3(bczzR.x, bczzG.x, bczzB.x));
    FsrEasuTapF(aC, aW, float2(1.0, -1.0) - pp, dir, len2, lob, clp, float3(bczzR.y, bczzG.y, bczzB.y));
    FsrEasuTapF(aC, aW, float2(-1.0, 1.0) - pp, dir, len2, lob, clp, float3(ijfeR.x, ijfeG.x, ijfeB.x));
    FsrEasuTapF(aC, aW, float2(0.0, 1.0) - pp, dir, len2, lob, clp, float3(ijfeR.y, ijfeG.y, ijfeB.y));
    FsrEasuTapF(aC, aW, float2(0.0, 0.0) - pp, dir, len2, lob, clp, float3(ijfeR.z, ijfeG.z, ijfeB.z));
    FsrEasuTapF(aC, aW, float2(-1.0, 0.0) - pp, dir, len2, lob, clp, float3(ijfeR.w, ijfeG.w, ijfeB.w));
    FsrEasuTapF(aC, aW, float2(1.0, 1.0) - pp, dir, len2, lob, clp, float3(klhgR.x, klhgG.x, klhgB.x));
    FsrEasuTapF(aC, aW, float2(2.0, 1.0) - pp, dir, len2, lob, clp, float3(klhgR.y, klhgG.y, klhgB.y));
    FsrEasuTapF(aC, aW, float2(2.0, 0.0) - pp, dir, len2, lob, clp, float3(klhgR.z, klhgG.z, klhgB.z));
    FsrEasuTapF(aC, aW, float2(1.0, 0.0) - pp, dir, len2, lob, clp, float3(klhgR.w, klhgG.w, klhgB.w));
    FsrEasuTapF(aC, aW, float2(1.0, 2.0) - pp, dir, len2, lob, clp, float3(zzonR.z, zzonG.z, zzonB.z));
    FsrEasuTapF(aC, aW, float2(0.0, 2.0) - pp, dir, len2, lob, clp, float3(zzonR.w, zzonG.w, zzonB.w));

    return min(max4, max(min4, aC * rcp(aW)));
}

#endif

[bgfx::EFFECT("FSR EASU (Upscaling)", 2)]
[bgfx::CATEGORY("Upscaling")]
[bgfx::DESCRIPTION("AMD FidelityFX Super Resolution 1.0 upscaling pass. EASU performs edge-adaptive spatial upscaling using a 12-tap filter kernel that preserves sharp edges while avoiding artifacts.")]
[bgfx::FP16]
[bgfx::PASS(1, "EASU")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) + (tid.xy / 8) * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    uint2 inputSize = GetInputSize();
    float2 inputPt = GetInputPt();

    float4 con0, con1, con2;
    float2 con3;

    con0[0] = (float)inputSize.x / (float)outputSize.x;
    con0[1] = (float)inputSize.y / (float)outputSize.y;
    con0[2] = 0.5f * con0[0] - 0.5f;
    con0[3] = 0.5f * con0[1] - 0.5f;

    con1[0] = inputPt.x;
    con1[1] = inputPt.y;

    con1[2] = inputPt.x;
    con1[3] = -inputPt.y;
    con2[0] = -inputPt.x;
    con2[1] = 2.0f * inputPt.y;
    con2[2] = inputPt.x;
    con2[3] = 2.0f * inputPt.y;
    con3[0] = 0;
    con3[1] = 4.0f * inputPt.y;

#ifdef BG_FP16
    OUTPUT[gxy] = half4(FsrEasu(gxy, con0, con1, con2, con3), 1);

    gxy.x += 8u;
    if (gxy.x < outputSize.x && gxy.y < outputSize.y)
    {
        OUTPUT[gxy] = half4(FsrEasu(gxy, con0, con1, con2, con3), 1);
    }

    gxy.y += 8u;
    if (gxy.x < outputSize.x && gxy.y < outputSize.y)
    {
        OUTPUT[gxy] = half4(FsrEasu(gxy, con0, con1, con2, con3), 1);
    }

    gxy.x -= 8u;
    if (gxy.x < outputSize.x && gxy.y < outputSize.y)
    {
        OUTPUT[gxy] = half4(FsrEasu(gxy, con0, con1, con2, con3), 1);
    }
#else
    OUTPUT[gxy] = float4(FsrEasu(gxy, con0, con1, con2, con3), 1);

    uint2 gxy1 = gxy + uint2(8u, 0u);
    if (gxy1.x < outputSize.x)
    if (gxy1.y < outputSize.y)
    {
        OUTPUT[gxy1] = float4(FsrEasu(gxy1, con0, con1, con2, con3), 1);
    }

    uint2 gxy2 = gxy + uint2(8u, 8u);
    if (gxy2.x < outputSize.x)
    if (gxy2.y < outputSize.y)
    {
        OUTPUT[gxy2] = float4(FsrEasu(gxy2, con0, con1, con2, con3), 1);
    }

    uint2 gxy3 = gxy + uint2(0u, 8u);
    if (gxy3.x < outputSize.x)
    if (gxy3.y < outputSize.y)
    {
        OUTPUT[gxy3] = float4(FsrEasu(gxy3, con0, con1, con2, con3), 1);
    }
#endif
}