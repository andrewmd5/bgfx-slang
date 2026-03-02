// Vintage Film
// by hunterk - public domain
// Technicolor effect from aybe: https://github.com/aybe/RetroArch-shaders
// Combines chromatic aberration, technicolor color shift, film grain,
// vignette, hotspot, and film scratch effects

import bgfx;

struct VintageFilmParams
{
    [bgfx::PARAM("Technicolor", 0.5, 0.0, 1.0, "Two-strip technicolor color shift intensity")]
    float technicolor;

    [bgfx::PARAM("Grain Strength", 24.0, 0.0, 60.0, "Film grain intensity")]
    float grainStr;

    [bgfx::PARAM("Vignette Amount", 0.15, 0.0, 1.0, "Vignette darkening strength")]
    float vigAmt;

    [bgfx::PARAM("Red Offset X", 0.12, -1.0, 1.0, "Horizontal chromatic aberration for red channel")]
    float xOffR;

    [bgfx::PARAM("Red Offset Y", 0.07, -1.0, 1.0, "Vertical chromatic aberration for red channel")]
    float yOffR;

    [bgfx::PARAM("Green Offset X", -0.06, -1.0, 1.0, "Horizontal chromatic aberration for green channel")]
    float xOffG;

    [bgfx::PARAM("Green Offset Y", -0.08, -1.0, 1.0, "Vertical chromatic aberration for green channel")]
    float yOffG;

    [bgfx::PARAM("Blue Offset X", -0.11, -1.0, 1.0, "Horizontal chromatic aberration for blue channel")]
    float xOffB;

    [bgfx::PARAM("Blue Offset Y", 0.09, -1.0, 1.0, "Vertical chromatic aberration for blue channel")]
    float yOffB;

    [bgfx::PARAM_BOOL("Jitter", true, "Vertical frame jitter")]
    bool jitter;

    [bgfx::PARAM_BOOL("Film Scratches", true, "Random film scratch overlay")]
    bool scratches;

    [bgfx::PARAM_BOOL("Hotspot", true, "Center hotspot brightening")]
    bool hotspot;

    [bgfx::PARAM_BOOL("Vignette", true, "Edge vignette darkening")]
    bool vignette;

    [bgfx::PARAM_BOOL("Vignette Flicker", true, "Pseudo-random vignette size variation")]
    bool vigFlicker;
}
ConstantBuffer<VintageFilmParams> params : register(b2);

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SOURCE("film_noise1.png")]
Texture2D<float4> scratchTex;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.WRAP)]
SamplerState wrapSampler;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState clampSampler;

static const float3 redfilter = float3(1.0, 0.0, 0.0);
static const float3 bluegreenfilter = float3(0.0, 1.0, 0.7);

float hash(float n)
{
    return frac(sin(n) * 43758.5453123);
}

float filmGrain(float2 uv, float strength, float timer)
{
    float x = (uv.x + 4.0) * (uv.y + 4.0) * ((fmod(timer, 800.0) + 10.0) * 10.0);
    return (fmod((fmod(x, 13.0) + 1.0) * (fmod(x, 123.0) + 1.0), 0.01) - 0.005) * strength;
}

[bgfx::EFFECT("Vintage Film", 2)]
[bgfx::CATEGORY("Film")]
[bgfx::DESCRIPTION("Vintage film look with chromatic aberration, technicolor, grain, and vignette.")]
[bgfx::DYNAMIC]
[bgfx::PASS(1, "Vintage Film")]
[bgfx::PASS_IO("INPUT, scratchTex", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 uv = GetOutputUV(tid);
    float time = fmod(float(GetFrameCount()), 4268.0);

    float hashNum1 = sin(hash(fmod(time, 147.0)));
    float hashNum2 = hash(cos(fmod(time, 292.0)));
    float hashNum3 = cos(hash(fmod(time, 361.0)));
    float frameHash = hash(time);

    float2 centerCoord = uv - 0.5;
    if (params.jitter)
        centerCoord.y += 0.003 * hash(sin(fmod(time, 403.0)));

    float len = length(centerCoord) / 1.25;
    float vig = smoothstep(0.0, 1.0 - params.vigAmt, len);

    float2 noiseCoord;
    noiseCoord.x = (hashNum1 > 0.15) ? uv.x : 1.0 - uv.x;
    noiseCoord.y = ((hashNum1 + hashNum2 - 0.5) > 0.66) ? uv.y : 1.0 - uv.y;

    float4 filmNoise1 = scratchTex.SampleLevel(wrapSampler, noiseCoord.xx + (hashNum1 + hashNum3 - 0.85), 0);
    float4 filmNoise2 = scratchTex.SampleLevel(wrapSampler, noiseCoord.xy + (hashNum1 + hashNum2 - 0.85), 0);

    float2 redCoord = (centerCoord + 0.01 * float2(params.xOffR, params.yOffR)) + 0.5;
    float2 greenCoord = (centerCoord + 0.01 * float2(params.xOffG, params.yOffG)) + 0.5;
    float2 blueCoord = (centerCoord + 0.01 * float2(params.xOffB, params.yOffB)) + 0.5;

    float3 film = float3(
        INPUT.SampleLevel(clampSampler, redCoord, 0).r,
        INPUT.SampleLevel(clampSampler, greenCoord, 0).g,
        INPUT.SampleLevel(clampSampler, blueCoord, 0).b);

    float3 redrecord = film * redfilter;
    float3 bluegreenrecord = film * bluegreenfilter;
    float3 rednegative = float3(redrecord.r, redrecord.r, redrecord.r);
    float3 bluegreennegative = float3((bluegreenrecord.g + bluegreenrecord.b) / 2.0,
                                       (bluegreenrecord.g + bluegreenrecord.b) / 2.0,
                                       (bluegreenrecord.g + bluegreenrecord.b) / 2.0);
    float3 result = rednegative * redfilter + bluegreennegative * bluegreenfilter;
    film = lerp(film, result, float3(params.technicolor, params.technicolor, params.technicolor));

    film += filmGrain(uv, params.grainStr, time / 10.0);

    float vigMod = 1.0 + 0.1 * hashNum3 * (params.vigFlicker ? 1.0 : 0.0);
    if (params.vignette)
        film *= 1.0 - vig * vigMod;
    if (params.hotspot)
        film += (1.0 - vig) * 0.2 * vigMod;

    if (params.scratches && frameHash > 0.99)
        film = lerp(film, filmNoise1.rgb, filmNoise1.a);
    else if (params.scratches && frameHash < 0.01)
        film = lerp(film, filmNoise2.rgb, filmNoise2.a);

    OUTPUT[tid.xy] = float4(film, 1.0);
}
