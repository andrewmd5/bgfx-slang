// Bicubic Interpolation
// Ported from https://github.com/ActualMandM/cemu_graphic_packs

import bgfx;

struct EffectParams
{
    [bgfx::PARAM("B Parameter", 0.33, 0, 1, "Controls the blur/ringing tradeoff. B=0 for sharper output, B=1 for smooth cubic B-spline.")]
    float parameterB;

    [bgfx::PARAM("C Parameter", 0.33, 0, 1, "Controls edge sharpness. C=0.5 with B=0 gives Catmull-Rom spline for sharp edges.")]
    float parameterC;
};

ConstantBuffer<EffectParams> params : register(b2);

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState linearSampler;

float kernelWeight(float dist, float b, float c)
{
    float absDist = abs(dist);

    if (absDist < 1.0)
    {
        return (dist * dist * ((12.0 - 9.0 * b - 6.0 * c) * absDist + (-18.0 + 12.0 * b + 6.0 * c)) + (6.0 - 2.0 * b)) / 6.0;
    }
    else if (absDist < 2.0)
    {
        return (dist * dist * ((-b - 6.0 * c) * absDist + (6.0 * b + 30.0 * c)) + (-12.0 * b - 48.0 * c) * absDist + (8.0 * b + 24.0 * c)) / 6.0;
    }
    return 0.0;
}

float4 computeKernelWeights(float offset, float b, float c)
{
    return float4(
        kernelWeight(offset - 2.0, b, c),
        kernelWeight(offset - 1.0, b, c),
        kernelWeight(offset, b, c),
        kernelWeight(offset + 1.0, b, c));
}

[bgfx::EFFECT("Bicubic Interpolation", 2)]
[bgfx::CATEGORY("Scaling")]
[bgfx::DESCRIPTION("Mitchell-Netravali bicubic filter with adjustable B and C parameters. B=C=1/3 gives balanced results. B=0,C=0.5 is Catmull-Rom for sharp edges. B=1,C=0 is cubic B-spline for smooth blending.")]
[bgfx::PASS(1, "Bicubic Interpolation")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 texCoord = GetOutputUV(tid);
    const float2 texelSize = GetInputPt();
    const float2 inputDimensions = float2(GetInputSize());

    float b = params.parameterB;
    float c = params.parameterC;

    float2 pixelPos = texCoord * inputDimensions;
    float2 basePos = floor(pixelPos - 0.5) + 0.5;
    float2 fractional = pixelPos - basePos;

    float4 horizWeights = computeKernelWeights(1 - fractional.x, b, c);
    float4 vertWeights = computeKernelWeights(1 - fractional.y, b, c);

    horizWeights /= horizWeights.r + horizWeights.g + horizWeights.b + horizWeights.a;
    vertWeights /= vertWeights.r + vertWeights.g + vertWeights.b + vertWeights.a;

    float2 uv1 = basePos * texelSize;
    float2 uv0 = uv1 - texelSize;
    float2 uv2 = uv1 + texelSize;
    float2 uv3 = uv2 + texelSize;

    float sumHorizMiddle = horizWeights.y + horizWeights.z;
    float horizMiddleOffset = horizWeights.z * texelSize.x / sumHorizMiddle;
    float horizMiddleCoord = uv1.x + horizMiddleOffset;

    float sumVertMiddle = vertWeights.y + vertWeights.z;
    float vertMiddleOffset = vertWeights.z * texelSize.y / sumVertMiddle;
    float vertMiddleCoord = uv1.y + vertMiddleOffset;

    int2 topLeftCoord = int2(max(uv0 * inputDimensions, 0.5));
    int2 bottomRightCoord = int2(min(uv3 * inputDimensions, inputDimensions - 0.5));

    float3 topRow = INPUT.Load(int3(topLeftCoord, 0)).rgb * horizWeights.x;
    topRow += INPUT.SampleLevel(linearSampler, float2(horizMiddleCoord, uv0.y), 0).rgb * sumHorizMiddle;
    topRow += INPUT.Load(int3(bottomRightCoord.x, topLeftCoord.y, 0)).rgb * horizWeights.w;
    float3 accumulated = topRow * vertWeights.x;

    float3 middleRow = INPUT.SampleLevel(linearSampler, float2(uv0.x, vertMiddleCoord), 0).rgb * horizWeights.x;
    middleRow += INPUT.SampleLevel(linearSampler, float2(horizMiddleCoord, vertMiddleCoord), 0).rgb * sumHorizMiddle;
    middleRow += INPUT.SampleLevel(linearSampler, float2(uv3.x, vertMiddleCoord), 0).rgb * horizWeights.w;
    accumulated += middleRow * sumVertMiddle;

    float3 bottomRow = INPUT.Load(int3(topLeftCoord.x, bottomRightCoord.y, 0)).rgb * horizWeights.x;
    bottomRow += INPUT.SampleLevel(linearSampler, float2(horizMiddleCoord, uv3.y), 0).rgb * sumHorizMiddle;
    bottomRow += INPUT.Load(int3(bottomRightCoord, 0)).rgb * horizWeights.w;
    accumulated += bottomRow * vertWeights.w;

    OUTPUT[tid.xy] = float4(accumulated, 1);
}
