// Film Grain
// by Martins Upitis (martinsh) - CC BY 3.0
// https://devlog-martinsh.blogspot.com/2013/05/image-imperfections-and-film-grain-post.html
// Perlin noise by toneburst
// Ported from libretro by Hyllian (2024)

import bgfx;

struct FilmGrainParams
{
    [bgfx::PARAM("Grain Amount", 0.02, 0.01, 0.2, "Intensity of the grain overlay")]
    float grainAmount;

    [bgfx::PARAM("Color Amount", 0.6, 0.0, 1.0, "Per-channel color variation in grain")]
    float colorAmount;

    [bgfx::PARAM("Grain Size", 1.6, 1.5, 2.5, "Size of grain particles")]
    float grainSize;

    [bgfx::PARAM("Luminance Amount", 1.0, 0.0, 1.0, "How much scene luminance affects grain visibility")]
    float lumAmount;

    [bgfx::PARAM_BOOL("Colored Noise", false, "Use colored noise instead of monochrome")]
    bool colored;
}
ConstantBuffer<FilmGrainParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

static const float permTexUnit = 1.0 / 256.0;
static const float permTexUnitHalf = 0.5 / 256.0;
static const float3 rotOffset = float3(1.425, 3.892, 5.835);
static const float3 lumcoeff = float3(0.299, 0.587, 0.114);
static const float4 nRGBA = float4(1.0, 1.2154, 1.3453, 1.3647);

float noise(float2 x, float timer)
{
    return sin(dot(x + float2(timer, timer), float2(12.9898, 78.233))) * 43758.5453;
}

float rnmA(float2 tc, float timer)
{
    return frac(noise(tc, timer) * nRGBA.a) * 2.0 - 1.0;
}

float2 rnmRG(float2 tc, float timer)
{
    return frac(noise(tc, timer) * nRGBA.rg) * 2.0 - float2(1.0, 1.0);
}

float2 fade(float2 t)
{
    return t * t * t * (t * (t * 6.0 - float2(15.0, 15.0)) + float2(10.0, 10.0));
}

float noise2D_contr(float2 pi, float2 pf, float2 pxy, float2 ptu, float timer)
{
    float perm = rnmA(pi.xy + ptu, timer);
    float2 grad = rnmRG(float2(perm, 0.0), timer) * 4.0 - float2(1.0, 1.0);
    return dot(grad, pf - pxy);
}

float pnoise2D(float2 p, float timer)
{
    float2 pi = permTexUnit * floor(p) + permTexUnitHalf;
    float2 pf = frac(p);

    float n00 = noise2D_contr(pi, pf, float2(0.0, 0.0), float2(0.0, 0.0), timer);
    float n01 = noise2D_contr(pi, pf, float2(0.0, 1.0), float2(0.0, permTexUnit), timer);
    float n10 = noise2D_contr(pi, pf, float2(1.0, 0.0), float2(permTexUnit, 0.0), timer);
    float n11 = noise2D_contr(pi, pf, float2(1.0, 1.0), float2(permTexUnit, permTexUnit), timer);

    float2 fd = fade(pf);
    float2 n_x = lerp(float2(n00, n01), float2(n10, n11), fd.x);
    return lerp(n_x.x, n_x.y, fd.y);
}

float2 coordRot(float2 tc, float angle, float aspect)
{
    float2 centered = tc * 2.0 - 1.0;
    float rotX = (centered.x * aspect * cos(angle)) - (centered.y * sin(angle));
    float rotY = (centered.x * aspect * sin(angle)) + (centered.y * cos(angle));
    return float2((rotX / aspect) * 0.5 + 0.5, rotY * 0.5 + 0.5);
}

[bgfx::EFFECT("Film Grain", 2)]
[bgfx::CATEGORY("Film")]
[bgfx::DESCRIPTION("Procedural film grain with luminance-aware intensity.")]
[bgfx::DYNAMIC]
[bgfx::PASS(1, "Film Grain")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 uv = GetOutputUV(tid);
    uint2 inputSize = GetInputSize();
    float width = float(inputSize.x);
    float height = float(inputSize.y);
    float aspect = width / height;
    float timer = fmod(float(GetFrameCount()), 4268.0);

    float2 rotCoordsR = coordRot(uv, timer + rotOffset.x, aspect);
    float2 grainScale = float2(width, height) / params.grainSize;
    float3 grain = float3(pnoise2D(rotCoordsR * grainScale, timer),
                          pnoise2D(rotCoordsR * grainScale, timer),
                          pnoise2D(rotCoordsR * grainScale, timer));

    if (params.colored)
    {
        float2 rotCoordsG = coordRot(uv, timer + rotOffset.y, aspect);
        float2 rotCoordsB = coordRot(uv, timer + rotOffset.z, aspect);
        grain.g = lerp(grain.r, pnoise2D(rotCoordsG * grainScale, timer), params.colorAmount);
        grain.b = lerp(grain.r, pnoise2D(rotCoordsB * grainScale, timer), params.colorAmount);
    }

    float3 col = INPUT.SampleLevel(sam, uv, 0).rgb;

    float luminance = lerp(0.0, dot(col, lumcoeff), params.lumAmount);
    float lum = smoothstep(0.2, 0.0, luminance) + luminance;

    grain = lerp(grain, float3(0.0, 0.0, 0.0), pow(lum, 4.0));
    col += grain * params.grainAmount;

    OUTPUT[tid.xy] = float4(col, 1.0);
}
