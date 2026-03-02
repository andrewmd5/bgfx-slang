// VHS
// by hunterk, adapted from ompuco's AVdistortion: https://www.shadertoy.com/view/XlsczN
// Rewind effect from caaaaaaarter: https://www.shadertoy.com/view/4lB3Dc

import bgfx;

struct VHSParams
{
    [bgfx::PARAM("Wiggle", 0.0, 0.0, 10.0, "Horizontal tracking distortion intensity")]
    float wiggle;

    [bgfx::PARAM("Chroma Smear", 0.5, 0.0, 1.0, "YIQ chroma channel bleeding amount")]
    float smear;

    [bgfx::PARAM_BOOL("Rewind", false, "Enable VHS rewind distortion and static")]
    bool rewind;

    [bgfx::PARAM_BOOL("Show OSD", true, "Show PLAY/REW on-screen display overlay")]
    bool showOSD;
}
ConstantBuffer<VHSParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
Texture2D vhsPass1;
[format("rgba8")]
RWTexture2D<float4> vhsPass1_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SOURCE("play.png")]
Texture2D<float4> playTex;

[bgfx::SOURCE("rew.png")]
Texture2D<float4> rewTex;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState linearSampler;

float3 rgb2yiq(float3 c)
{
    return float3(
        0.2989 * c.x + 0.5959 * c.y + 0.2115 * c.z,
        0.5870 * c.x - 0.2744 * c.y - 0.5229 * c.z,
        0.1140 * c.x - 0.3216 * c.y + 0.3114 * c.z);
}

float3 yiq2rgb(float3 c)
{
    return float3(
        1.0 * c.x + 1.0 * c.y + 1.0 * c.z,
        0.956 * c.x - 0.2720 * c.y - 1.1060 * c.z,
        0.6210 * c.x - 0.6474 * c.y + 1.7046 * c.z);
}

float2 CircleOffset(float start, float points, float point)
{
    float rad = (3.141592 * 2.0 * (1.0 / points)) * (point + start);
    return float2(-(0.3 + rad), cos(rad));
}

float3 ChromaBlur(float2 uv, float d)
{
    float2 pixelOffset = float2(d, 0);
    float start = 2.0 / 14.0;
    float2 scale = 0.66 * 4.0 * 2.0 * pixelOffset;

    float3 acc = float3(0, 0, 0);
    for (int i = 0; i < 14; ++i)
        acc += INPUT.SampleLevel(linearSampler, uv + CircleOffset(start, 14.0, float(i)) * scale, 0).rgb;
    acc += INPUT.SampleLevel(linearSampler, uv, 0).rgb;

    return acc / 15.0;
}

float onOff(float a, float b, float c, float fc)
{
    return step(c, sin((fc * 0.001) + a * cos((fc * 0.001) * b)));
}

float2 jumpy(float2 uv, float fc, float wiggleAmt)
{
    float2 look = uv;
    float window = 1.0 / (1.0 + 80.0 * (look.y - frac(fc / 4.0)) * (look.y - frac(fc / 4.0)));
    look.x += 0.05 * sin(look.y * 10.0 + fc) / 20.0 * onOff(4.0, 4.0, 0.3, fc) * (0.5 + cos(fc * 20.0)) * window;
    float vShift = (0.1 * wiggleAmt) * 0.4 * onOff(2.0, 3.0, 0.9, fc) *
        (sin(fc) * sin(fc * 20.0) + (0.5 + 0.1 * sin(fc * 200.0) * cos(fc)));
    look.y = frac(look.y - 0.01 * vShift);
    return look;
}

float hashRand2(float2 co)
{
    return GetRandom(asuint(co.x) ^ (asuint(co.y) << 16));
}

[bgfx::EFFECT("VHS", 2)]
[bgfx::CATEGORY("Film")]
[bgfx::DESCRIPTION("VHS tape playback with chroma smear, tracking wiggle, and rewind mode.")]
[bgfx::DYNAMIC]
[bgfx::PASS(1, "VHS Distortion")]
[bgfx::PASS_IO("INPUT, playTex", "vhsPass1_UAV")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 uv = GetOutputUV(tid);
    float iTime = fmod(float(GetFrameCount()), 7.0);

    float d = 0.1 - round(fmod(iTime / 3.0, 1.0)) * 0.1;
    float2 jitteredUV = jumpy(uv, iTime, params.wiggle);
    float2 osdUV = jitteredUV;

    float s = 0.0001 * params.wiggle * -d + 0.0001 * params.wiggle * sin(iTime);
    float e = min(0.30, pow(max(0.0, cos(jitteredUV.y * 4.0 + 0.3) - 0.75) * (s + 0.5) * 1.0, 3.0)) * 25.0;
    float r = iTime * (2.0 * s);
    jitteredUV.x += abs(r * pow(min(0.003, (-jitteredUV.y + (0.01 * iTime)) * 3.0), 2.0));

    d = 0.051 + abs(sin(s / 4.0));
    float c = max(0.0001, 0.002 * d) * params.smear;

    float y = rgb2yiq(ChromaBlur(jitteredUV, c + c * jitteredUV.x)).r;

    jitteredUV.x += 0.01 * d;
    float i = rgb2yiq(ChromaBlur(jitteredUV, c * 6.0)).g;

    jitteredUV.x += 0.005 * d;
    float q = rgb2yiq(ChromaBlur(jitteredUV, c * 15.0)).b;

    float4 final4 = float4(yiq2rgb(float3(y, i, q)) - pow(s + e * 2.0, 3.0), 1.0);

    if (params.showOSD && !params.rewind)
    {
        float4 playOSD = playTex.SampleLevel(linearSampler, osdUV, 0);
        float show = fmod(float(GetFrameCount()), 100.0) < 50.0 ? playOSD.a : 0.0;
        final4 = lerp(final4, playOSD, saturate(show));
    }

    vhsPass1_UAV[tid.xy] = final4;
}

[bgfx::PASS(2, "Rewind")]
[bgfx::PASS_IO("vhsPass1, rewTex", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 uv = GetOutputUV(tid);
    float iTime = float(GetFrameCount());

    if (!params.rewind)
    {
        OUTPUT[tid.xy] = vhsPass1.SampleLevel(linearSampler, uv, 0);
        return;
    }

    float2 rewUV = uv;
    rewUV.x -= sin(0.0006 * fmod(iTime, 11.0)) * cos(fmod(iTime, 17.0) * -rewUV.y);
    float2 jUV = jumpy(rewUV, iTime, 10.0);
    float4 texColor = vhsPass1.SampleLevel(linearSampler, jUV, 0);

    if (params.showOSD)
    {
        float4 rewOSD = rewTex.SampleLevel(linearSampler, jumpy(uv, iTime, 10.0), 0);
        float show = fmod(iTime, 100.0) < 50.0 ? rewOSD.a : 0.0;
        texColor = lerp(texColor, rewOSD, saturate(show));
    }

    float2 samplePos = rewUV - float2(0.0, 0.45);
    samplePos.x += hashRand2(float2(iTime, uv.y)) + 0.5;
    samplePos.y += (hashRand2(float2(iTime, iTime)) - 0.5) / 32.0;

    texColor += float4(
        hashRand2(float2(uv.y, iTime)) - 0.5,
        hashRand2(float2(uv.y, iTime + 1.0)) - 0.5,
        hashRand2(float2(uv.y, iTime + 2.0)) - 0.5,
        0.0) * 0.1;

    float whiteNoise = hashRand2(float2(floor(samplePos.y * 160.0), floor(samplePos.x * cos(iTime))) + float2(iTime, 0.0));
    bool inStatic = !((whiteNoise > 11.5 - 30.0 * samplePos.y || whiteNoise < 1.5 - 5.0 * samplePos.y) &&
                      (whiteNoise > 11.5 - 30.0 * (samplePos.y + 0.5) || whiteNoise < 1.5 - 5.0 * (samplePos.y + 0.4)));
    if (inStatic)
        texColor += float4(0.5 + hashRand2(samplePos), 0.5 + hashRand2(samplePos), 0.5 + hashRand2(samplePos), 0.0);

    OUTPUT[tid.xy] = texColor;
}
