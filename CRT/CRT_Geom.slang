// CRT Geom
// Based on CRT-interlaced shader by cgwg, Themaister and DOLLS (GPL License)
// Ported from https://github.com/libretro/common-shaders/blob/master/crt/shaders/crt-geom.cg
// Features screen curvature simulation and advanced scanline rendering

import bgfx;

// User parameters struct - parser reads attributes from struct fields
struct CRTGeomParams
{
    [bgfx::PARAM("Target Gamma", 2.4, 0.1, 5.0, "Gamma value of the simulated CRT display")]
    float CRTGamma;

    [bgfx::PARAM("Monitor Gamma", 2.2, 0.1, 5.0, "Gamma value of your actual display monitor")]
    float monitorGamma;

    [bgfx::PARAM("Distance", 1.5, 0.1, 3.0, "Simulated viewing distance from the CRT screen")]
    float dist;

    [bgfx::PARAM_INT("Curvature", 1, 0, 1, "Enable or disable screen curvature effect")]
    int curvature;

    [bgfx::PARAM("Curvature Radius", 2.0, 0.1, 10.0, "Radius of the screen curvature (lower = more curved)")]
    float R;

    [bgfx::PARAM("Corner Size", 0.03, 0.0, 1.0, "Size of the rounded corners")]
    float cornerSize;

    [bgfx::PARAM_INT("Corner Smoothness", 1000, 80, 2000, "Smoothness of the corner transition")]
    int cornerSmooth;

    [bgfx::PARAM("Horizontal Tilt", 0.0, -0.5, 0.5, "Horizontal tilt angle of the simulated screen")]
    float xTilt;

    [bgfx::PARAM("Vertical Tilt", 0.0, -0.5, 0.5, "Vertical tilt angle of the simulated screen")]
    float yTilt;

    [bgfx::PARAM_INT("Horizontal Overscan", 100, -125, 125, "Horizontal overscan percentage (100 = no overscan)")]
    int overScanX;

    [bgfx::PARAM_INT("Vertical Overscan", 100, -125, 125, "Vertical overscan percentage (100 = no overscan)")]
    int overScanY;

    [bgfx::PARAM("Dot Mask", 0.3, 0.0, 0.3, "Intensity of the alternating dot mask pattern")]
    float dotMask;

    [bgfx::PARAM_INT("Sharpness", 1, 1, 3, "Texture sampling sharpness multiplier")]
    int sharper;

    [bgfx::PARAM("Scanline Weight", 0.3, 0.1, 0.5, "Controls the width and intensity of scanlines")]
    float scanlineWeight;

    [bgfx::PARAM("Luminance Boost", 0.0, 0.0, 1.0, "Additional luminance added to the scanline calculation")]
    float lum;

    [bgfx::PARAM_INT("Interlacing", 0, 0, 1, "Enable interlacing simulation (alternates scanlines each frame)")]
    int interlace;
};

// User parameters cbuffer - Slang reflects this directly
ConstantBuffer<CRTGeomParams> params : register(b2);

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

// Uncomment for faster gaussian-only beam profile
// #define USEGAUSSIAN

#pragma warning(disable: 3571)

#define PI 3.141592653589
#define FIX(c) max(abs(c), 1e-5)
#define aspect float2(1.0, 0.75)
#define TEX2D(c) pow(INPUT.SampleLevel(sam, (c), 0), params.CRTGamma)

float intersect(float2 xy, float4 sin_cos_angle)
{
    float A = dot(xy, xy) + params.dist * params.dist;
    float B = 2.0 * (params.R * (dot(xy, sin_cos_angle.xy) - params.dist * sin_cos_angle.zw.x * sin_cos_angle.zw.y) - params.dist * params.dist);
    float C = params.dist * params.dist + 2.0 * params.R * params.dist * sin_cos_angle.zw.x * sin_cos_angle.zw.y;
    return (-B - sqrt(B * B - 4.0 * A * C)) / (2.0 * A);
}

float2 bkwtrans(float2 xy, float4 sin_cos_angle)
{
    float c = intersect(xy, sin_cos_angle);
    float2 point_ = c * xy;
    point_ += params.R * sin_cos_angle.xy;
    point_ /= params.R;
    float2 tang = sin_cos_angle.xy / sin_cos_angle.zw;
    float2 poc = point_ / sin_cos_angle.zw;
    float A = dot(tang, tang) + 1.0;
    float B = -2.0 * dot(poc, tang);
    float C = dot(poc, poc) - 1.0;
    float a = (-B + sqrt(B * B - 4.0 * A * C)) / (2.0 * A);
    float2 uv = (point_ - a * sin_cos_angle.xy) / sin_cos_angle.zw;
    float r = FIX(params.R * acos(a));
    return uv * r / sin(r / params.R);
}

float2 fwtrans(float2 uv, float4 sin_cos_angle)
{
    float r = FIX(sqrt(dot(uv, uv)));
    uv *= sin(r / params.R) / r;
    float x = 1.0 - cos(r / params.R);
    float D = params.dist / params.R + x * sin_cos_angle.z * sin_cos_angle.w + dot(uv, sin_cos_angle.xy);
    return params.dist * (uv * sin_cos_angle.zw - x * sin_cos_angle.xy) / D;
}

float3 maxscale(float4 sin_cos_angle)
{
    float2 c = bkwtrans(-params.R * sin_cos_angle.xy / (1.0 + params.R / params.dist * sin_cos_angle.z * sin_cos_angle.w), sin_cos_angle);
    float2 a = 0.5 * aspect;
    float2 lo = float2(fwtrans(float2(-a.x, c.y), sin_cos_angle).x,
                       fwtrans(float2(c.x, -a.y), sin_cos_angle).y) /
                aspect;
    float2 hi = float2(fwtrans(float2(+a.x, c.y), sin_cos_angle).x,
                       fwtrans(float2(c.x, +a.y), sin_cos_angle).y) /
                aspect;
    return float3((hi + lo) * aspect * 0.5, max(hi.x - lo.x, hi.y - lo.y));
}

float4 scanlineWeights(float distance1, float4 color)
{
#ifdef USEGAUSSIAN
    float4 wid = 0.3 + 0.1 * pow(color, 3.0);
    float v = distance1 / (wid * params.scanlineWeight / 0.3);
    float4 weights = { v, v, v, v };
    return (params.lum + 0.4) * exp(-weights * weights) / wid;
#else
    float4 wid = 2.0 + 2.0 * pow(color, 4.0);
    float v = distance1 / params.scanlineWeight;
    float4 weights = float4(v, v, v, v);
    return (params.lum + 1.4) * exp(-pow(weights * rsqrt(0.5 * wid), wid)) / (0.6 + 0.2 * wid);
#endif
}

[bgfx::EFFECT("CRT Geom", 2)]
[bgfx::CATEGORY("CRT")]
[bgfx::DESCRIPTION("A comprehensive CRT simulation with barrel distortion, screen curvature, corner rounding, and authentic scanline rendering. Provides a realistic curved CRT monitor appearance.")]
[bgfx::DYNAMIC]
[bgfx::PASS(1, "CRT Geom")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    uint2 outputSize = GetOutputSize();
    uint2 inputSize = GetInputSize();

    float4 sin_cos_angle = { sin(float2(params.xTilt, params.yTilt)), cos(float2(params.xTilt, params.yTilt)) };
    float3 stretch = maxscale(sin_cos_angle);
    float2 TextureSize = float2(params.sharper * inputSize.x, inputSize.y);

    float mod_factor = pos.x * outputSize.x;
    float2 ilfac = { 1.0, clamp(floor(inputSize.y / (200.0 * (-4 * params.interlace + 5))), 1.0, 2.0) };
    float2 one = ilfac / TextureSize;

    float2 xy = 0.0;
    if (params.curvature > 0)
    {
        float2 cd = pos;
        cd = (cd - 0.5) * aspect * stretch.z + stretch.xy;
        xy = bkwtrans(cd, sin_cos_angle) / float2(params.overScanX / 100.0, params.overScanY / 100.0) / aspect + float2(0.5, 0.5);
    }
    else
    {
        xy = pos;
    }

    float2 cd2 = xy;
    cd2 = (cd2 - 0.5) * float2(params.overScanX, params.overScanY) / 100.0 + 0.5;
    cd2 = min(cd2, 1.0 - cd2) * aspect;
    float2 cdist = float2(params.cornerSize, params.cornerSize);
    cd2 = (cdist - min(cd2, cdist));
    float cornerDist = sqrt(dot(cd2, cd2));
    float cval = clamp((cdist.x - cornerDist) * params.cornerSmooth, 0.0, 1.0);

    float2 ratio_scale = (xy * TextureSize - 0.5) / ilfac;
    float filter = rcp(GetScale().y);
    float2 uv_ratio = frac(ratio_scale);

    xy = (floor(ratio_scale) * ilfac + 0.5) / TextureSize;

    float4 coeffs = PI * float4(1.0 + uv_ratio.x, uv_ratio.x, 1.0 - uv_ratio.x, 2.0 - uv_ratio.x);
    coeffs = FIX(coeffs);
    coeffs = 2.0 * sin(coeffs) * sin(coeffs / 2.0) / (coeffs * coeffs);
    coeffs /= dot(coeffs, float4(1.0, 1.0, 1.0, 1.0));

    float4 col = clamp(mul(coeffs, float4x4(
                                       TEX2D(xy + float2(-one.x, 0.0)),
                                       TEX2D(xy),
                                       TEX2D(xy + float2(one.x, 0.0)),
                                       TEX2D(xy + float2(2.0 * one.x, 0.0)))),
                       0.0, 1.0);
    float4 col2 = clamp(mul(coeffs, float4x4(
                                        TEX2D(xy + float2(-one.x, one.y)),
                                        TEX2D(xy + float2(0.0, one.y)),
                                        TEX2D(xy + one),
                                        TEX2D(xy + float2(2.0 * one.x, one.y)))),
                        0.0, 1.0);

    col = pow(col, params.CRTGamma);
    col2 = pow(col2, params.CRTGamma);

    float4 weights = scanlineWeights(uv_ratio.y, col);
    float4 weights2 = scanlineWeights(1.0 - uv_ratio.y, col2);

    uv_ratio.y = uv_ratio.y + 1.0 / 3.0 * filter;
    weights = (weights + scanlineWeights(uv_ratio.y, col)) / 3.0;
    weights2 = (weights2 + scanlineWeights(abs(1.0 - uv_ratio.y), col2)) / 3.0;
    uv_ratio.y = uv_ratio.y - 2.0 / 3.0 * filter;
    weights = weights + scanlineWeights(abs(uv_ratio.y), col) / 3.0;
    weights2 = weights2 + scanlineWeights(abs(1.0 - uv_ratio.y), col2) / 3.0;

    float3 mul_res = (col * weights + col2 * weights2).rgb;
    mul_res *= float3(cval, cval, cval);

    float3 dotMaskWeights = lerp(
        float3(1.0, 1.0 - params.dotMask, 1.0),
        float3(1.0 - params.dotMask, 1.0, 1.0 - params.dotMask),
        floor(fmod(mod_factor, 2.0)));
    mul_res *= dotMaskWeights;

    mul_res = pow(mul_res, 1.0 / params.monitorGamma);

    OUTPUT[tid.xy] = float4(mul_res, 1.0);
}
