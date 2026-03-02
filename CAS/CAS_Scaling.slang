// AMD FidelityFX Contrast Adaptive Sharpening with Upscaling
// https://github.com/GPUOpen-Effects/FidelityFX-CAS/blob/9fabcc9a2c45f958aff55ddfda337e74ef894b7f/ffx-cas/ffx_cas.h

import bgfx;

struct CASScalingParams
{
    [bgfx::PARAM("Sharpness", 0.4, 0.0, 1.0, "Controls sharpening intensity. Higher values are sharper but may introduce artifacts.")]
    float sharpness;
};

ConstantBuffer<CASScalingParams> params : register(b2);

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

// #define CAS_BETTER_DIAGONALS

#define min3(x, y, z) (min(x, min(y, z)))
#define max3(x, y, z) (max(x, max(y, z)))

#ifdef BG_FP16

half2 half2_splat(half a)
{
    return half2(a, a);
}

void CasFilterHalfScaling(
    out half2 pixR,
    out half2 pixG,
    out half2 pixB,
    uint2 ip,
    float4 const0,
    float offset,
    half peak)
{
    float2 pp = float2(ip) * const0.xy + const0.zw;

    float2 fp0 = floor(pp);
    half2 ppX;
    ppX.x = half(pp.x - fp0.x);
    half ppY = half(pp.y - fp0.y);
    int2 sp0 = int2(fp0);

    half3 a0 = (half3)INPUT.Load(int3(sp0 + int2(-1, -1), 0)).rgb;
    half3 b0 = (half3)INPUT.Load(int3(sp0 + int2(0, -1), 0)).rgb;
    half3 c0 = (half3)INPUT.Load(int3(sp0 + int2(1, -1), 0)).rgb;
    half3 d0 = (half3)INPUT.Load(int3(sp0 + int2(2, -1), 0)).rgb;
    half3 e0 = (half3)INPUT.Load(int3(sp0 + int2(-1, 0), 0)).rgb;
    half3 f0 = (half3)INPUT.Load(int3(sp0, 0)).rgb;
    half3 g0 = (half3)INPUT.Load(int3(sp0 + int2(1, 0), 0)).rgb;
    half3 h0 = (half3)INPUT.Load(int3(sp0 + int2(2, 0), 0)).rgb;
    half3 i0 = (half3)INPUT.Load(int3(sp0 + int2(-1, 1), 0)).rgb;
    half3 j0 = (half3)INPUT.Load(int3(sp0 + int2(0, 1), 0)).rgb;
    half3 k0 = (half3)INPUT.Load(int3(sp0 + int2(1, 1), 0)).rgb;
    half3 l0 = (half3)INPUT.Load(int3(sp0 + int2(2, 1), 0)).rgb;
    half3 m0 = (half3)INPUT.Load(int3(sp0 + int2(-1, 2), 0)).rgb;
    half3 n0 = (half3)INPUT.Load(int3(sp0 + int2(0, 2), 0)).rgb;
    half3 o0 = (half3)INPUT.Load(int3(sp0 + int2(1, 2), 0)).rgb;
    half3 p0 = (half3)INPUT.Load(int3(sp0 + int2(2, 2), 0)).rgb;

    float pp1 = pp.x + offset;
    float fp1 = floor(pp1);
    ppX.y = half(pp1 - fp1);
    int2 sp1 = int2(int(fp1), sp0.y);

    half3 a1 = (half3)INPUT.Load(int3(sp1 + int2(-1, -1), 0)).rgb;
    half3 b1 = (half3)INPUT.Load(int3(sp1 + int2(0, -1), 0)).rgb;
    half3 c1 = (half3)INPUT.Load(int3(sp1 + int2(1, -1), 0)).rgb;
    half3 d1 = (half3)INPUT.Load(int3(sp1 + int2(2, -1), 0)).rgb;
    half3 e1 = (half3)INPUT.Load(int3(sp1 + int2(-1, 0), 0)).rgb;
    half3 f1 = (half3)INPUT.Load(int3(sp1, 0)).rgb;
    half3 g1 = (half3)INPUT.Load(int3(sp1 + int2(1, 0), 0)).rgb;
    half3 h1 = (half3)INPUT.Load(int3(sp1 + int2(2, 0), 0)).rgb;
    half3 i1 = (half3)INPUT.Load(int3(sp1 + int2(-1, 1), 0)).rgb;
    half3 j1 = (half3)INPUT.Load(int3(sp1 + int2(0, 1), 0)).rgb;
    half3 k1 = (half3)INPUT.Load(int3(sp1 + int2(1, 1), 0)).rgb;
    half3 l1 = (half3)INPUT.Load(int3(sp1 + int2(2, 1), 0)).rgb;
    half3 m1 = (half3)INPUT.Load(int3(sp1 + int2(-1, 2), 0)).rgb;
    half3 n1 = (half3)INPUT.Load(int3(sp1 + int2(0, 2), 0)).rgb;
    half3 o1 = (half3)INPUT.Load(int3(sp1 + int2(1, 2), 0)).rgb;
    half3 p1 = (half3)INPUT.Load(int3(sp1 + int2(2, 2), 0)).rgb;

    half2 aR = half2(a0.r, a1.r);
    half2 aG = half2(a0.g, a1.g);
    half2 aB = half2(a0.b, a1.b);
    half2 bR = half2(b0.r, b1.r);
    half2 bG = half2(b0.g, b1.g);
    half2 bB = half2(b0.b, b1.b);
    half2 cR = half2(c0.r, c1.r);
    half2 cG = half2(c0.g, c1.g);
    half2 cB = half2(c0.b, c1.b);
    half2 dR = half2(d0.r, d1.r);
    half2 dG = half2(d0.g, d1.g);
    half2 dB = half2(d0.b, d1.b);
    half2 eR = half2(e0.r, e1.r);
    half2 eG = half2(e0.g, e1.g);
    half2 eB = half2(e0.b, e1.b);
    half2 fR = half2(f0.r, f1.r);
    half2 fG = half2(f0.g, f1.g);
    half2 fB = half2(f0.b, f1.b);
    half2 gR = half2(g0.r, g1.r);
    half2 gG = half2(g0.g, g1.g);
    half2 gB = half2(g0.b, g1.b);
    half2 hR = half2(h0.r, h1.r);
    half2 hG = half2(h0.g, h1.g);
    half2 hB = half2(h0.b, h1.b);
    half2 iR = half2(i0.r, i1.r);
    half2 iG = half2(i0.g, i1.g);
    half2 iB = half2(i0.b, i1.b);
    half2 jR = half2(j0.r, j1.r);
    half2 jG = half2(j0.g, j1.g);
    half2 jB = half2(j0.b, j1.b);
    half2 kR = half2(k0.r, k1.r);
    half2 kG = half2(k0.g, k1.g);
    half2 kB = half2(k0.b, k1.b);
    half2 lR = half2(l0.r, l1.r);
    half2 lG = half2(l0.g, l1.g);
    half2 lB = half2(l0.b, l1.b);
    half2 mR = half2(m0.r, m1.r);
    half2 mG = half2(m0.g, m1.g);
    half2 mB = half2(m0.b, m1.b);
    half2 nR = half2(n0.r, n1.r);
    half2 nG = half2(n0.g, n1.g);
    half2 nB = half2(n0.b, n1.b);
    half2 oR = half2(o0.r, o1.r);
    half2 oG = half2(o0.g, o1.g);
    half2 oB = half2(o0.b, o1.b);
    half2 pR = half2(p0.r, p1.r);
    half2 pG = half2(p0.g, p1.g);
    half2 pB = half2(p0.b, p1.b);

    half2 mnfR = min3(min3(bR, eR, fR), gR, jR);
    half2 mnfG = min3(min3(bG, eG, fG), gG, jG);
    half2 mnfB = min3(min3(bB, eB, fB), gB, jB);
#ifdef CAS_BETTER_DIAGONALS
    half2 mnfR2 = min3(min3(mnfR, aR, cR), iR, kR);
    half2 mnfG2 = min3(min3(mnfG, aG, cG), iG, kG);
    half2 mnfB2 = min3(min3(mnfB, aB, cB), iB, kB);
    mnfR = mnfR + mnfR2;
    mnfG = mnfG + mnfG2;
    mnfB = mnfB + mnfB2;
#endif
    half2 mxfR = max3(max3(bR, eR, fR), gR, jR);
    half2 mxfG = max3(max3(bG, eG, fG), gG, jG);
    half2 mxfB = max3(max3(bB, eB, fB), gB, jB);
#ifdef CAS_BETTER_DIAGONALS
    half2 mxfR2 = max3(max3(mxfR, aR, cR), iR, kR);
    half2 mxfG2 = max3(max3(mxfG, aG, cG), iG, kG);
    half2 mxfB2 = max3(max3(mxfB, aB, cB), iB, kB);
    mxfR = mxfR + mxfR2;
    mxfG = mxfG + mxfG2;
    mxfB = mxfB + mxfB2;
#endif

    half2 mngR = min3(min3(cR, fR, gR), hR, kR);
    half2 mngG = min3(min3(cG, fG, gG), hG, kG);
    half2 mngB = min3(min3(cB, fB, gB), hB, kB);
#ifdef CAS_BETTER_DIAGONALS
    half2 mngR2 = min3(min3(mngR, bR, dR), jR, lR);
    half2 mngG2 = min3(min3(mngG, bG, dG), jG, lG);
    half2 mngB2 = min3(min3(mngB, bB, dB), jB, lB);
    mngR = mngR + mngR2;
    mngG = mngG + mngG2;
    mngB = mngB + mngB2;
#endif
    half2 mxgR = max3(max3(cR, fR, gR), hR, kR);
    half2 mxgG = max3(max3(cG, fG, gG), hG, kG);
    half2 mxgB = max3(max3(cB, fB, gB), hB, kB);
#ifdef CAS_BETTER_DIAGONALS
    half2 mxgR2 = max3(max3(mxgR, bR, dR), jR, lR);
    half2 mxgG2 = max3(max3(mxgG, bG, dG), jG, lG);
    half2 mxgB2 = max3(max3(mxgB, bB, dB), jB, lB);
    mxgR = mxgR + mxgR2;
    mxgG = mxgG + mxgG2;
    mxgB = mxgB + mxgB2;
#endif

    half2 mnjR = min3(min3(fR, iR, jR), kR, nR);
    half2 mnjG = min3(min3(fG, iG, jG), kG, nG);
    half2 mnjB = min3(min3(fB, iB, jB), kB, nB);
#ifdef CAS_BETTER_DIAGONALS
    half2 mnjR2 = min3(min3(mnjR, eR, gR), mR, oR);
    half2 mnjG2 = min3(min3(mnjG, eG, gG), mG, oG);
    half2 mnjB2 = min3(min3(mnjB, eB, gB), mB, oB);
    mnjR = mnjR + mnjR2;
    mnjG = mnjG + mnjG2;
    mnjB = mnjB + mnjB2;
#endif
    half2 mxjR = max3(max3(fR, iR, jR), kR, nR);
    half2 mxjG = max3(max3(fG, iG, jG), kG, nG);
    half2 mxjB = max3(max3(fB, iB, jB), kB, nB);
#ifdef CAS_BETTER_DIAGONALS
    half2 mxjR2 = max3(max3(mxjR, eR, gR), mR, oR);
    half2 mxjG2 = max3(max3(mxjG, eG, gG), mG, oG);
    half2 mxjB2 = max3(max3(mxjB, eB, gB), mB, oB);
    mxjR = mxjR + mxjR2;
    mxjG = mxjG + mxjG2;
    mxjB = mxjB + mxjB2;
#endif

    half2 mnkR = min3(min3(gR, jR, kR), lR, oR);
    half2 mnkG = min3(min3(gG, jG, kG), lG, oG);
    half2 mnkB = min3(min3(gB, jB, kB), lB, oB);
#ifdef CAS_BETTER_DIAGONALS
    half2 mnkR2 = min3(min3(mnkR, fR, hR), nR, pR);
    half2 mnkG2 = min3(min3(mnkG, fG, hG), nG, pG);
    half2 mnkB2 = min3(min3(mnkB, fB, hB), nB, pB);
    mnkR = mnkR + mnkR2;
    mnkG = mnkG + mnkG2;
    mnkB = mnkB + mnkB2;
#endif
    half2 mxkR = max3(max3(gR, jR, kR), lR, oR);
    half2 mxkG = max3(max3(gG, jG, kG), lG, oG);
    half2 mxkB = max3(max3(gB, jB, kB), lB, oB);
#ifdef CAS_BETTER_DIAGONALS
    half2 mxkR2 = max3(max3(mxkR, fR, hR), nR, pR);
    half2 mxkG2 = max3(max3(mxkG, fG, hG), nG, pG);
    half2 mxkB2 = max3(max3(mxkB, fB, hB), nB, pB);
    mxkR = mxkR + mxkR2;
    mxkG = mxkG + mxkG2;
    mxkB = mxkB + mxkB2;
#endif

    half2 rcpMfR = rcp(mxfR);
    half2 rcpMfG = rcp(mxfG);
    half2 rcpMfB = rcp(mxfB);
    half2 rcpMgR = rcp(mxgR);
    half2 rcpMgG = rcp(mxgG);
    half2 rcpMgB = rcp(mxgB);
    half2 rcpMjR = rcp(mxjR);
    half2 rcpMjG = rcp(mxjG);
    half2 rcpMjB = rcp(mxjB);
    half2 rcpMkR = rcp(mxkR);
    half2 rcpMkG = rcp(mxkG);
    half2 rcpMkB = rcp(mxkB);

#ifdef CAS_BETTER_DIAGONALS
    half2 ampfR = saturate(min(mnfR, half2_splat(2.0h) - mxfR) * rcpMfR);
    half2 ampfG = saturate(min(mnfG, half2_splat(2.0h) - mxfG) * rcpMfG);
    half2 ampfB = saturate(min(mnfB, half2_splat(2.0h) - mxfB) * rcpMfB);
    half2 ampgR = saturate(min(mngR, half2_splat(2.0h) - mxgR) * rcpMgR);
    half2 ampgG = saturate(min(mngG, half2_splat(2.0h) - mxgG) * rcpMgG);
    half2 ampgB = saturate(min(mngB, half2_splat(2.0h) - mxgB) * rcpMgB);
    half2 ampjR = saturate(min(mnjR, half2_splat(2.0h) - mxjR) * rcpMjR);
    half2 ampjG = saturate(min(mnjG, half2_splat(2.0h) - mxjG) * rcpMjG);
    half2 ampjB = saturate(min(mnjB, half2_splat(2.0h) - mxjB) * rcpMjB);
    half2 ampkR = saturate(min(mnkR, half2_splat(2.0h) - mxkR) * rcpMkR);
    half2 ampkG = saturate(min(mnkG, half2_splat(2.0h) - mxkG) * rcpMkG);
    half2 ampkB = saturate(min(mnkB, half2_splat(2.0h) - mxkB) * rcpMkB);
#else
    half2 ampfR = saturate(min(mnfR, half2_splat(1.0h) - mxfR) * rcpMfR);
    half2 ampfG = saturate(min(mnfG, half2_splat(1.0h) - mxfG) * rcpMfG);
    half2 ampfB = saturate(min(mnfB, half2_splat(1.0h) - mxfB) * rcpMfB);
    half2 ampgR = saturate(min(mngR, half2_splat(1.0h) - mxgR) * rcpMgR);
    half2 ampgG = saturate(min(mngG, half2_splat(1.0h) - mxgG) * rcpMgG);
    half2 ampgB = saturate(min(mngB, half2_splat(1.0h) - mxgB) * rcpMgB);
    half2 ampjR = saturate(min(mnjR, half2_splat(1.0h) - mxjR) * rcpMjR);
    half2 ampjG = saturate(min(mnjG, half2_splat(1.0h) - mxjG) * rcpMjG);
    half2 ampjB = saturate(min(mnjB, half2_splat(1.0h) - mxjB) * rcpMjB);
    half2 ampkR = saturate(min(mnkR, half2_splat(1.0h) - mxkR) * rcpMkR);
    half2 ampkG = saturate(min(mnkG, half2_splat(1.0h) - mxkG) * rcpMkG);
    half2 ampkB = saturate(min(mnkB, half2_splat(1.0h) - mxkB) * rcpMkB);
#endif

    ampfR = sqrt(ampfR);
    ampfG = sqrt(ampfG);
    ampfB = sqrt(ampfB);
    ampgR = sqrt(ampgR);
    ampgG = sqrt(ampgG);
    ampgB = sqrt(ampgB);
    ampjR = sqrt(ampjR);
    ampjG = sqrt(ampjG);
    ampjB = sqrt(ampjB);
    ampkR = sqrt(ampkR);
    ampkG = sqrt(ampkG);
    ampkB = sqrt(ampkB);

    half2 wfR = ampfR * peak;
    half2 wfG = ampfG * peak;
    half2 wfB = ampfB * peak;
    half2 wgR = ampgR * peak;
    half2 wgG = ampgG * peak;
    half2 wgB = ampgB * peak;
    half2 wjR = ampjR * peak;
    half2 wjG = ampjG * peak;
    half2 wjB = ampjB * peak;
    half2 wkR = ampkR * peak;
    half2 wkG = ampkG * peak;
    half2 wkB = ampkB * peak;

    half2 s = (half2_splat(1.0h) - ppX) * (half2_splat(1.0h) - half2_splat(ppY));
    half2 t = ppX * (half2_splat(1.0h) - half2_splat(ppY));
    half2 u = (half2_splat(1.0h) - ppX) * half2_splat(ppY);
    half2 v = ppX * half2_splat(ppY);

    half2 thinB = half2_splat(1.0h / 32.0h);
    s *= rcp(thinB + (mxfG - mnfG));
    t *= rcp(thinB + (mxgG - mngG));
    u *= rcp(thinB + (mxjG - mnjG));
    v *= rcp(thinB + (mxkG - mnkG));

    half2 qbeR = wfR * s;
    half2 qbeG = wfG * s;
    half2 qbeB = wfB * s;
    half2 qchR = wgR * t;
    half2 qchG = wgG * t;
    half2 qchB = wgB * t;
    half2 qfR = wgR * t + wjR * u + s;
    half2 qfG = wgG * t + wjG * u + s;
    half2 qfB = wgB * t + wjB * u + s;
    half2 qgR = wfR * s + wkR * v + t;
    half2 qgG = wfG * s + wkG * v + t;
    half2 qgB = wfB * s + wkB * v + t;
    half2 qjR = wfR * s + wkR * v + u;
    half2 qjG = wfG * s + wkG * v + u;
    half2 qjB = wfB * s + wkB * v + u;
    half2 qkR = wgR * t + wjR * u + v;
    half2 qkG = wgG * t + wjG * u + v;
    half2 qkB = wgB * t + wjB * u + v;
    half2 qinR = wjR * u;
    half2 qinG = wjG * u;
    half2 qinB = wjB * u;
    half2 qloR = wkR * v;
    half2 qloG = wkG * v;
    half2 qloB = wkB * v;

    half2 rcpWG = rcp(half2_splat(2.0h) * qbeG + half2_splat(2.0h) * qchG + half2_splat(2.0h) * qinG + half2_splat(2.0h) * qloG + qfG + qgG + qjG + qkG);
    pixR = saturate((bR * qbeG + eR * qbeG + cR * qchG + hR * qchG + iR * qinG + nR * qinG + lR * qloG + oR * qloG + fR * qfG + gR * qgG + jR * qjG + kR * qkG) * rcpWG);
    pixG = saturate((bG * qbeG + eG * qbeG + cG * qchG + hG * qchG + iG * qinG + nG * qinG + lG * qloG + oG * qloG + fG * qfG + gG * qgG + jG * qjG + kG * qkG) * rcpWG);
    pixB = saturate((bB * qbeG + eB * qbeG + cB * qchG + hB * qchG + iB * qinG + nB * qinG + lB * qloG + oB * qloG + fB * qfG + gB * qgG + jB * qjG + kB * qkG) * rcpWG);
}

#else

float3 CasFilterScaling(uint2 ip, float4 const0, float peak)
{
    float2 pp = float2(ip) * const0.xy + const0.zw;
    float2 fp = floor(pp);
    pp -= fp;
    int2 sp = int2(fp);

    float3 a = INPUT.Load(int3(sp + int2(-1, -1), 0)).rgb;
    float3 b = INPUT.Load(int3(sp + int2(0, -1), 0)).rgb;
    float3 c = INPUT.Load(int3(sp + int2(1, -1), 0)).rgb;
    float3 d = INPUT.Load(int3(sp + int2(2, -1), 0)).rgb;
    float3 e = INPUT.Load(int3(sp + int2(-1, 0), 0)).rgb;
    float3 f = INPUT.Load(int3(sp, 0)).rgb;
    float3 g = INPUT.Load(int3(sp + int2(1, 0), 0)).rgb;
    float3 h = INPUT.Load(int3(sp + int2(2, 0), 0)).rgb;
    float3 i = INPUT.Load(int3(sp + int2(-1, 1), 0)).rgb;
    float3 j = INPUT.Load(int3(sp + int2(0, 1), 0)).rgb;
    float3 k = INPUT.Load(int3(sp + int2(1, 1), 0)).rgb;
    float3 l = INPUT.Load(int3(sp + int2(2, 1), 0)).rgb;
    float3 m = INPUT.Load(int3(sp + int2(-1, 2), 0)).rgb;
    float3 n = INPUT.Load(int3(sp + int2(0, 2), 0)).rgb;
    float3 o = INPUT.Load(int3(sp + int2(1, 2), 0)).rgb;
    float3 p = INPUT.Load(int3(sp + int2(2, 2), 0)).rgb;

    float mnfR = min3(min3(b.r, e.r, f.r), g.r, j.r);
    float mnfG = min3(min3(b.g, e.g, f.g), g.g, j.g);
    float mnfB = min3(min3(b.b, e.b, f.b), g.b, j.b);
#ifdef CAS_BETTER_DIAGONALS
    float mnfR2 = min3(min3(mnfR, a.r, c.r), i.r, k.r);
    float mnfG2 = min3(min3(mnfG, a.g, c.g), i.g, k.g);
    float mnfB2 = min3(min3(mnfB, a.b, c.b), i.b, k.b);
    mnfR = mnfR + mnfR2;
    mnfG = mnfG + mnfG2;
    mnfB = mnfB + mnfB2;
#endif
    float mxfR = max3(max3(b.r, e.r, f.r), g.r, j.r);
    float mxfG = max3(max3(b.g, e.g, f.g), g.g, j.g);
    float mxfB = max3(max3(b.b, e.b, f.b), g.b, j.b);
#ifdef CAS_BETTER_DIAGONALS
    float mxfR2 = max3(max3(mxfR, a.r, c.r), i.r, k.r);
    float mxfG2 = max3(max3(mxfG, a.g, c.g), i.g, k.g);
    float mxfB2 = max3(max3(mxfB, a.b, c.b), i.b, k.b);
    mxfR = mxfR + mxfR2;
    mxfG = mxfG + mxfG2;
    mxfB = mxfB + mxfB2;
#endif

    float mngR = min3(min3(c.r, f.r, g.r), h.r, k.r);
    float mngG = min3(min3(c.g, f.g, g.g), h.g, k.g);
    float mngB = min3(min3(c.b, f.b, g.b), h.b, k.b);
#ifdef CAS_BETTER_DIAGONALS
    float mngR2 = min3(min3(mngR, b.r, d.r), j.r, l.r);
    float mngG2 = min3(min3(mngG, b.g, d.g), j.g, l.g);
    float mngB2 = min3(min3(mngB, b.b, d.b), j.b, l.b);
    mngR = mngR + mngR2;
    mngG = mngG + mngG2;
    mngB = mngB + mngB2;
#endif
    float mxgR = max3(max3(c.r, f.r, g.r), h.r, k.r);
    float mxgG = max3(max3(c.g, f.g, g.g), h.g, k.g);
    float mxgB = max3(max3(c.b, f.b, g.b), h.b, k.b);
#ifdef CAS_BETTER_DIAGONALS
    float mxgR2 = max3(max3(mxgR, b.r, d.r), j.r, l.r);
    float mxgG2 = max3(max3(mxgG, b.g, d.g), j.g, l.g);
    float mxgB2 = max3(max3(mxgB, b.b, d.b), j.b, l.b);
    mxgR = mxgR + mxgR2;
    mxgG = mxgG + mxgG2;
    mxgB = mxgB + mxgB2;
#endif

    float mnjR = min3(min3(f.r, i.r, j.r), k.r, n.r);
    float mnjG = min3(min3(f.g, i.g, j.g), k.g, n.g);
    float mnjB = min3(min3(f.b, i.b, j.b), k.b, n.b);
#ifdef CAS_BETTER_DIAGONALS
    float mnjR2 = min3(min3(mnjR, e.r, g.r), m.r, o.r);
    float mnjG2 = min3(min3(mnjG, e.g, g.g), m.g, o.g);
    float mnjB2 = min3(min3(mnjB, e.b, g.b), m.b, o.b);
    mnjR = mnjR + mnjR2;
    mnjG = mnjG + mnjG2;
    mnjB = mnjB + mnjB2;
#endif
    float mxjR = max3(max3(f.r, i.r, j.r), k.r, n.r);
    float mxjG = max3(max3(f.g, i.g, j.g), k.g, n.g);
    float mxjB = max3(max3(f.b, i.b, j.b), k.b, n.b);
#ifdef CAS_BETTER_DIAGONALS
    float mxjR2 = max3(max3(mxjR, e.r, g.r), m.r, o.r);
    float mxjG2 = max3(max3(mxjG, e.g, g.g), m.g, o.g);
    float mxjB2 = max3(max3(mxjB, e.b, g.b), m.b, o.b);
    mxjR = mxjR + mxjR2;
    mxjG = mxjG + mxjG2;
    mxjB = mxjB + mxjB2;
#endif

    float mnkR = min3(min3(g.r, j.r, k.r), l.r, o.r);
    float mnkG = min3(min3(g.g, j.g, k.g), l.g, o.g);
    float mnkB = min3(min3(g.b, j.b, k.b), l.b, o.b);
#ifdef CAS_BETTER_DIAGONALS
    float mnkR2 = min3(min3(mnkR, f.r, h.r), n.r, p.r);
    float mnkG2 = min3(min3(mnkG, f.g, h.g), n.g, p.g);
    float mnkB2 = min3(min3(mnkB, f.b, h.b), n.b, p.b);
    mnkR = mnkR + mnkR2;
    mnkG = mnkG + mnkG2;
    mnkB = mnkB + mnkB2;
#endif
    float mxkR = max3(max3(g.r, j.r, k.r), l.r, o.r);
    float mxkG = max3(max3(g.g, j.g, k.g), l.g, o.g);
    float mxkB = max3(max3(g.b, j.b, k.b), l.b, o.b);
#ifdef CAS_BETTER_DIAGONALS
    float mxkR2 = max3(max3(mxkR, f.r, h.r), n.r, p.r);
    float mxkG2 = max3(max3(mxkG, f.g, h.g), n.g, p.g);
    float mxkB2 = max3(max3(mxkB, f.b, h.b), n.b, p.b);
    mxkR = mxkR + mxkR2;
    mxkG = mxkG + mxkG2;
    mxkB = mxkB + mxkB2;
#endif

    float rcpMfR = rcp(mxfR);
    float rcpMfG = rcp(mxfG);
    float rcpMfB = rcp(mxfB);
    float rcpMgR = rcp(mxgR);
    float rcpMgG = rcp(mxgG);
    float rcpMgB = rcp(mxgB);
    float rcpMjR = rcp(mxjR);
    float rcpMjG = rcp(mxjG);
    float rcpMjB = rcp(mxjB);
    float rcpMkR = rcp(mxkR);
    float rcpMkG = rcp(mxkG);
    float rcpMkB = rcp(mxkB);

#ifdef CAS_BETTER_DIAGONALS
    float ampfR = saturate(min(mnfR, 2.0 - mxfR) * rcpMfR);
    float ampfG = saturate(min(mnfG, 2.0 - mxfG) * rcpMfG);
    float ampfB = saturate(min(mnfB, 2.0 - mxfB) * rcpMfB);
    float ampgR = saturate(min(mngR, 2.0 - mxgR) * rcpMgR);
    float ampgG = saturate(min(mngG, 2.0 - mxgG) * rcpMgG);
    float ampgB = saturate(min(mngB, 2.0 - mxgB) * rcpMgB);
    float ampjR = saturate(min(mnjR, 2.0 - mxjR) * rcpMjR);
    float ampjG = saturate(min(mnjG, 2.0 - mxjG) * rcpMjG);
    float ampjB = saturate(min(mnjB, 2.0 - mxjB) * rcpMjB);
    float ampkR = saturate(min(mnkR, 2.0 - mxkR) * rcpMkR);
    float ampkG = saturate(min(mnkG, 2.0 - mxkG) * rcpMkG);
    float ampkB = saturate(min(mnkB, 2.0 - mxkB) * rcpMkB);
#else
    float ampfR = saturate(min(mnfR, 1.0 - mxfR) * rcpMfR);
    float ampfG = saturate(min(mnfG, 1.0 - mxfG) * rcpMfG);
    float ampfB = saturate(min(mnfB, 1.0 - mxfB) * rcpMfB);
    float ampgR = saturate(min(mngR, 1.0 - mxgR) * rcpMgR);
    float ampgG = saturate(min(mngG, 1.0 - mxgG) * rcpMgG);
    float ampgB = saturate(min(mngB, 1.0 - mxgB) * rcpMgB);
    float ampjR = saturate(min(mnjR, 1.0 - mxjR) * rcpMjR);
    float ampjG = saturate(min(mnjG, 1.0 - mxjG) * rcpMjG);
    float ampjB = saturate(min(mnjB, 1.0 - mxjB) * rcpMjB);
    float ampkR = saturate(min(mnkR, 1.0 - mxkR) * rcpMkR);
    float ampkG = saturate(min(mnkG, 1.0 - mxkG) * rcpMkG);
    float ampkB = saturate(min(mnkB, 1.0 - mxkB) * rcpMkB);
#endif

    ampfR = sqrt(ampfR);
    ampfG = sqrt(ampfG);
    ampfB = sqrt(ampfB);
    ampgR = sqrt(ampgR);
    ampgG = sqrt(ampgG);
    ampgB = sqrt(ampgB);
    ampjR = sqrt(ampjR);
    ampjG = sqrt(ampjG);
    ampjB = sqrt(ampjB);
    ampkR = sqrt(ampkR);
    ampkG = sqrt(ampkG);
    ampkB = sqrt(ampkB);

    float wfR = ampfR * peak;
    float wfG = ampfG * peak;
    float wfB = ampfB * peak;
    float wgR = ampgR * peak;
    float wgG = ampgG * peak;
    float wgB = ampgB * peak;
    float wjR = ampjR * peak;
    float wjG = ampjG * peak;
    float wjB = ampjB * peak;
    float wkR = ampkR * peak;
    float wkG = ampkG * peak;
    float wkB = ampkB * peak;

    float s = (1.0 - pp.x) * (1.0 - pp.y);
    float t = pp.x * (1.0 - pp.y);
    float u = (1.0 - pp.x) * pp.y;
    float v = pp.x * pp.y;

    float thinB = 1.0 / 32.0;
    s *= rcp(thinB + (mxfG - mnfG));
    t *= rcp(thinB + (mxgG - mngG));
    u *= rcp(thinB + (mxjG - mnjG));
    v *= rcp(thinB + (mxkG - mnkG));

    float qbeR = wfR * s;
    float qbeG = wfG * s;
    float qbeB = wfB * s;
    float qchR = wgR * t;
    float qchG = wgG * t;
    float qchB = wgB * t;
    float qfR = wgR * t + wjR * u + s;
    float qfG = wgG * t + wjG * u + s;
    float qfB = wgB * t + wjB * u + s;
    float qgR = wfR * s + wkR * v + t;
    float qgG = wfG * s + wkG * v + t;
    float qgB = wfB * s + wkB * v + t;
    float qjR = wfR * s + wkR * v + u;
    float qjG = wfG * s + wkG * v + u;
    float qjB = wfB * s + wkB * v + u;
    float qkR = wgR * t + wjR * u + v;
    float qkG = wgG * t + wjG * u + v;
    float qkB = wgB * t + wjB * u + v;
    float qinR = wjR * u;
    float qinG = wjG * u;
    float qinB = wjB * u;
    float qloR = wkR * v;
    float qloG = wkG * v;
    float qloB = wkB * v;

    float rcpWG = rcp(2.0 * qbeG + 2.0 * qchG + 2.0 * qinG + 2.0 * qloG + qfG + qgG + qjG + qkG);

    return float3(
        saturate((b.r * qbeG + e.r * qbeG + c.r * qchG + h.r * qchG + i.r * qinG + n.r * qinG + l.r * qloG + o.r * qloG + f.r * qfG + g.r * qgG + j.r * qjG + k.r * qkG) * rcpWG),
        saturate((b.g * qbeG + e.g * qbeG + c.g * qchG + h.g * qchG + i.g * qinG + n.g * qinG + l.g * qloG + o.g * qloG + f.g * qfG + g.g * qgG + j.g * qjG + k.g * qkG) * rcpWG),
        saturate((b.b * qbeG + e.b * qbeG + c.b * qchG + h.b * qchG + i.b * qinG + n.b * qinG + l.b * qloG + o.b * qloG + f.b * qfG + g.b * qgG + j.b * qjG + k.b * qkG) * rcpWG));
}

#endif

[bgfx::EFFECT("AMD CAS (Scaling)", 2)]
[bgfx::CATEGORY("Sharpening")]
[bgfx::DESCRIPTION("AMD Contrast Adaptive Sharpening with integrated upscaling.")]
[bgfx::FP16]
[bgfx::PASS(1, "CAS Sharpen + Scale")]
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

    float4 const0;
    const0.xy = float2(GetInputSize()) * GetOutputPt();
    const0.zw = 0.5 * const0.xy - 0.5;

    const float peak = -rcp(lerp(8.0, 5.0, params.sharpness));

#ifdef BG_FP16
    const float offset = 8.0 / GetScale().x;

    half2 pixR, pixG, pixB;
    CasFilterHalfScaling(pixR, pixG, pixB, gxy, const0, offset, half(peak));

    OUTPUT[gxy] = float4(pixR.x, pixG.x, pixB.x, 1);

    gxy.x += 8u;
    OUTPUT[gxy] = float4(pixR.y, pixG.y, pixB.y, 1);

    gxy += int2(-8, 8);
    CasFilterHalfScaling(pixR, pixG, pixB, gxy, const0, offset, half(peak));

    OUTPUT[gxy] = float4(pixR.x, pixG.x, pixB.x, 1);

    gxy.x += 8u;
    OUTPUT[gxy] = float4(pixR.y, pixG.y, pixB.y, 1);
#else
    OUTPUT[gxy] = float4(CasFilterScaling(gxy, const0, peak), 1);

    gxy.x += 8u;
    OUTPUT[gxy] = float4(CasFilterScaling(gxy, const0, peak), 1);

    gxy.y += 8u;
    OUTPUT[gxy] = float4(CasFilterScaling(gxy, const0, peak), 1);

    gxy.x -= 8u;
    OUTPUT[gxy] = float4(CasFilterScaling(gxy, const0, peak), 1);
#endif
}
