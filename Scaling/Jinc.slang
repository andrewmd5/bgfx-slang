// Jinc2 Resampling
// Ported from https://github.com/libretro/common-shaders/blob/master/windowed/shaders/jinc2.cg
//
// This approximates Jinc(x)*Jinc(x*r1/r2) for x < 2.5,
// where r1 and r2 are the first two zeros of the jinc function.
// For best jinc 2-lobe approximation: A=0.5, B=0.825
// When B=1.0, this becomes a lanczos filter.
// Increase A for more blur, decrease for sharper output.
// B=0.825 helps reduce dithering; increase B for finer sharpness at cost of dithering.

import bgfx;

struct EffectParams
{
    [bgfx::PARAM("Window Sinc", 0.5, 0, 1, "Controls the window function width. Lower values produce sharper results, higher values add blur.")]
    float windowParam;

    [bgfx::PARAM("Sinc Factor", 0.825, 0, 1, "Adjusts the sinc function behavior. 0.825 minimizes dithering artifacts, 1.0 for maximum sharpness.")]
    float sincParam;

    [bgfx::PARAM("Anti-ringing Strength", 0.5, 0, 1, "Controls suppression of ringing artifacts. Higher values reduce ringing but may soften details.")]
    float antiRingStrength;
};

ConstantBuffer<EffectParams> params : register(b2);

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState pointSampler;

#define PI 3.1415926535897932384626433832795
#define MIN4(a, b, c, d) min(min(a, b), min(c, d))
#define MAX4(a, b, c, d) max(max(a, b), max(c, d))

float euclideanDist(float2 pointA, float2 pointB)
{
    float2 delta = pointB - pointA;
    return sqrt(dot(delta, delta));
}

float4 computeJincWeights(float4 dist, float windowScale, float sincScale)
{
    return (dist == float4(0.0, 0.0, 0.0, 0.0))
               ? float4(windowScale * sincScale, windowScale * sincScale, windowScale * sincScale, windowScale * sincScale)
               : sin(dist * windowScale) * sin(dist * sincScale) * rcp(dist * dist);
}

void fetchSampleBlock(Texture2D tex, SamplerState samp, float2 uv, out float3 s00, out float3 s01, out float3 s10, out float3 s11)
{
    const float4 rCh = tex.GatherRed(samp, uv);
    const float4 gCh = tex.GatherGreen(samp, uv);
    const float4 bCh = tex.GatherBlue(samp, uv);

    s00 = float3(rCh.w, gCh.w, bCh.w);
    s01 = float3(rCh.x, gCh.x, bCh.x);
    s10 = float3(rCh.z, gCh.z, bCh.z);
    s11 = float3(rCh.y, gCh.y, bCh.y);
}

float3 weightedAccumulate(float4 weights, float4x3 colorMatrix, float3 accumulator)
{
    return mul(weights, colorMatrix) + accumulator;
}

[bgfx::EFFECT("Jinc2 Resampling", 2)]
[bgfx::CATEGORY("Upscaling")]
[bgfx::DESCRIPTION("Jinc 2-lobe windowed filter for high-quality image scaling. Uses a circular impulse response for better isotropy than separable filters.")]
[bgfx::PASS(1, "Jinc2 Resample")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[bgfx::BLOCK_SIZE(8, 8)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 outputPos = (tid.xy / 8) * 8 + Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8));

    const uint2 outputDims = GetOutputSize();
    if (outputPos.x >= outputDims.x || outputPos.y >= outputDims.y)
    {
        return;
    }

    float2 texelSize = GetInputPt();
    float2 offsetX = float2(1.0, 0.0);
    float2 offsetY = float2(0.0, 1.0);

    float2 centerPixel = (outputPos + 0.5f) * GetOutputPt() * GetInputSize();
    float2 baseCoord = floor(centerPixel - 0.5f) + 0.5f;

    float windowFactor = params.windowParam * PI;
    float sincFactor = params.sincParam * PI;

    float4x4 weightMatrix = {
        computeJincWeights(float4(
                               euclideanDist(centerPixel, baseCoord - offsetX - offsetY),
                               euclideanDist(centerPixel, baseCoord - offsetY),
                               euclideanDist(centerPixel, baseCoord + offsetX - offsetY),
                               euclideanDist(centerPixel, baseCoord + 2.0 * offsetX - offsetY)),
                           windowFactor, sincFactor),
        computeJincWeights(float4(
                               euclideanDist(centerPixel, baseCoord - offsetX),
                               euclideanDist(centerPixel, baseCoord),
                               euclideanDist(centerPixel, baseCoord + offsetX),
                               euclideanDist(centerPixel, baseCoord + 2.0 * offsetX)),
                           windowFactor, sincFactor),
        computeJincWeights(float4(
                               euclideanDist(centerPixel, baseCoord - offsetX + offsetY),
                               euclideanDist(centerPixel, baseCoord + offsetY),
                               euclideanDist(centerPixel, baseCoord + offsetX + offsetY),
                               euclideanDist(centerPixel, baseCoord + 2.0 * offsetX + offsetY)),
                           windowFactor, sincFactor),
        computeJincWeights(float4(
                               euclideanDist(centerPixel, baseCoord - offsetX + 2.0 * offsetY),
                               euclideanDist(centerPixel, baseCoord + 2.0 * offsetY),
                               euclideanDist(centerPixel, baseCoord + offsetX + 2.0 * offsetY),
                               euclideanDist(centerPixel, baseCoord + 2.0 * offsetX + 2.0 * offsetY)),
                           windowFactor, sincFactor)
    };

    baseCoord -= 0.5f;

    float3 pixels[4][4];

    $for(i in Range(0, 2))
    {
        $for(j in Range(0, 2))
        {
            float2 sampleUV = (baseCoord + uint2(i * 2, j * 2)) * texelSize;
            fetchSampleBlock(INPUT, pointSampler, sampleUV,
                             pixels[i * 2][j * 2], pixels[i * 2][j * 2 + 1],
                             pixels[i * 2 + 1][j * 2], pixels[i * 2 + 1][j * 2 + 1]);
        }
    }

    float3 outputColor = weightedAccumulate(weightMatrix[0], float4x3(pixels[0][0], pixels[1][0], pixels[2][0], pixels[3][0]), float3(0, 0, 0));
    outputColor = weightedAccumulate(weightMatrix[1], float4x3(pixels[0][1], pixels[1][1], pixels[2][1], pixels[3][1]), outputColor);
    outputColor = weightedAccumulate(weightMatrix[2], float4x3(pixels[0][2], pixels[1][2], pixels[2][2], pixels[3][2]), outputColor);
    outputColor = weightedAccumulate(weightMatrix[3], float4x3(pixels[0][3], pixels[1][3], pixels[2][3], pixels[3][3]), outputColor);

    outputColor *= rcp(dot(mul(weightMatrix, float4(1, 1, 1, 1)), 1));

    float3 localMinimum = MIN4(pixels[1][1], pixels[2][1], pixels[1][2], pixels[2][2]);
    float3 localMaximum = MAX4(pixels[1][1], pixels[2][1], pixels[1][2], pixels[2][2]);
    outputColor = lerp(outputColor, clamp(outputColor, localMinimum, localMaximum), params.antiRingStrength);

    OUTPUT[outputPos] = float4(outputColor, 1);
}
