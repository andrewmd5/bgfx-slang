// Lanczos6 Resampling
// Ported from https://github.com/libretro/common-shaders/blob/master/windowed/shaders/lanczos6.cg

import bgfx;

struct EffectParams
{
    [bgfx::PARAM("Anti-ringing Strength", 0.5, 0, 1, "Controls how much ringing artifacts are suppressed. Higher values reduce ringing but may slightly soften the image.")]
    float antiRingStrength;
};

ConstantBuffer<EffectParams> params : register(b2);

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState pointSampler;

#define PI 3.14159265359
#define SAFE_ABS(val) max(abs(val), 1e-5)
#define MIN4(a, b, c, d) min(min(a, b), min(c, d))
#define MAX4(a, b, c, d) max(max(a, b), max(c, d))

float3 computeWeights(float offset)
{
    const float invRadius = 1.0f / 3.0f;
    float3 sincArg = SAFE_ABS(2.0 * PI * float3(offset - 1.5, offset - 0.5, offset + 0.5));
    return sin(sincArg) * sin(sincArg * invRadius) * rcp(sincArg * sincArg);
}

void gatherSamples(Texture2D tex, SamplerState samp, float2 uv, out float3 s00, out float3 s01, out float3 s10, out float3 s11)
{
    const float4 redChannel = tex.GatherRed(samp, uv);
    const float4 greenChannel = tex.GatherGreen(samp, uv);
    const float4 blueChannel = tex.GatherBlue(samp, uv);

    s00 = float3(redChannel.w, greenChannel.w, blueChannel.w);
    s01 = float3(redChannel.x, greenChannel.x, blueChannel.x);
    s10 = float3(redChannel.z, greenChannel.z, blueChannel.z);
    s11 = float3(redChannel.y, greenChannel.y, blueChannel.y);
}

[bgfx::EFFECT("Lanczos6 Resampling", 2)]
[bgfx::CATEGORY("Scaling")]
[bgfx::DESCRIPTION("High-quality Lanczos 6-tap interpolation filter. Provides sharp results with minimal ringing artifacts when anti-ringing is enabled.")]
[bgfx::PASS(1, "Lanczos6")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 texCoord = GetOutputUV(tid);
    float2 pixelPos = texCoord * GetInputSize();
    float2 texelSize = GetInputPt();

    uint row, col;

    float2 fractional = frac(pixelPos + 0.5f);
    float3 horizWeights1 = computeWeights(0.5f - fractional.x * 0.5f);
    float3 horizWeights2 = computeWeights(1.0f - fractional.x * 0.5f);
    float3 vertWeights1 = computeWeights(0.5f - fractional.y * 0.5f);
    float3 vertWeights2 = computeWeights(1.0f - fractional.y * 0.5f);

    float horizSum = dot(horizWeights1, float3(1, 1, 1)) + dot(horizWeights2, float3(1, 1, 1));
    float vertSum = dot(vertWeights1, float3(1, 1, 1)) + dot(vertWeights2, float3(1, 1, 1));
    horizWeights1 /= horizSum;
    horizWeights2 /= horizSum;
    vertWeights1 /= vertSum;
    vertWeights2 /= vertSum;

    pixelPos -= fractional + 1.5f;

    float3 samples[6][6];

    $for(row in Range(0, 3))
    {
        $for(col in Range(0, 3))
        {
            float2 sampleUV = (pixelPos + uint2(row * 2, col * 2)) * texelSize;
            gatherSamples(INPUT, pointSampler, sampleUV,
                          samples[row * 2][col * 2], samples[row * 2][col * 2 + 1],
                          samples[row * 2 + 1][col * 2], samples[row * 2 + 1][col * 2 + 1]);
        }
    }

    float3 result = float3(0, 0, 0);
    $for(row in Range(0, 3))
    {
        float3 rowResult1 = mul(horizWeights1, float3x3(samples[0][row * 2], samples[2][row * 2], samples[4][row * 2]));
        float3 rowResult2 = mul(horizWeights2, float3x3(samples[1][row * 2], samples[3][row * 2], samples[5][row * 2]));
        float3 rowResult3 = mul(horizWeights1, float3x3(samples[0][row * 2 + 1], samples[2][row * 2 + 1], samples[4][row * 2 + 1]));
        float3 rowResult4 = mul(horizWeights2, float3x3(samples[1][row * 2 + 1], samples[3][row * 2 + 1], samples[5][row * 2 + 1]));
        result += (rowResult1 + rowResult2) * vertWeights1[row] + (rowResult3 + rowResult4) * vertWeights2[row];
    }

    float3 localMin = MIN4(samples[2][2], samples[3][2], samples[2][3], samples[3][3]);
    float3 localMax = MAX4(samples[2][2], samples[3][2], samples[2][3], samples[3][3]);
    result = lerp(result, clamp(result, localMin, localMax), params.antiRingStrength);

    OUTPUT[tid.xy] = float4(result, 1);
}
