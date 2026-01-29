// Ambient Edge Background
// Samples colors from game edges to create a dynamic ambient glow effect
// Similar to Philips Ambilight / bias lighting

import bgfx;

struct AmbientEdgeParams
{
    [bgfx::PARAM("Glow Intensity", 0.6, 0.1, 1.0, "Brightness of the ambient glow effect")]
    float glowIntensity;

    [bgfx::PARAM("Glow Spread", 0.5, 0.1, 1.0, "How far the glow extends into the bar area")]
    float glowSpread;

    [bgfx::PARAM("Sample Depth", 20.0, 5.0, 50.0, "How far into the content to sample for edge colors (in pixels)")]
    float sampleDepth;

    [bgfx::PARAM("Color Smoothing", 0.5, 0.0, 1.0, "Smooths the color transitions along edges. Higher = smoother")]
    float colorSmoothing;
};

ConstantBuffer<AmbientEdgeParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("RENDERER_WIDTH", "RENDERER_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState linearSampler;

float3 SampleEdgeColor(float2 edgePos, float2 normal, float depth)
{
    float2 pt = GetInputPt();
    float3 sum = float3(0, 0, 0);
    float weight = 0;

    for (float d = 0; d < depth; d += 2.0)
    {
        float2 samplePos = edgePos + normal * d * pt;
        samplePos = saturate(samplePos);
        float w = 1.0 / (1.0 + d * 0.1);
        sum += INPUT.SampleLevel(linearSampler, samplePos, 0).rgb * w;
        weight += w;
    }

    return sum / max(weight, 0.001);
}

[bgfx::EFFECT("Ambient Edge", 2)]
[bgfx::CATEGORY("Background")]
[bgfx::DESCRIPTION("Creates an ambient glow effect by sampling colors from the edges of the game content. Similar to Ambilight bias lighting.")]
[bgfx::DYNAMIC]
[bgfx::PASS(1, "Ambient Edge Background")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    float2 inputSize = float2(GetInputSize());
    float2 outputSize = float2(GetOutputSize());

    float inputAspect = inputSize.x / inputSize.y;
    float outputAspect = outputSize.x / outputSize.y;

    float2 contentScale;
    float2 contentOffset;

    if (inputAspect > outputAspect)
    {
        contentScale = float2(1.0, outputAspect / inputAspect);
        contentOffset = float2(0.0, (1.0 - contentScale.y) * 0.5);
    }
    else
    {
        contentScale = float2(inputAspect / outputAspect, 1.0);
        contentOffset = float2((1.0 - contentScale.x) * 0.5, 0.0);
    }

    float2 contentUV = (pos - contentOffset) / contentScale;
    bool insideContent = all(contentUV >= 0.0) && all(contentUV <= 1.0);

    float4 result = float4(0, 0, 0, 1);

    if (insideContent)
    {
        result = INPUT.SampleLevel(linearSampler, contentUV, 0);
    }
    else
    {
        float2 clampedUV = saturate(contentUV);
        float2 distFromEdge = abs(contentUV - clampedUV);

        float3 edgeColor = float3(0, 0, 0);

        if (contentUV.x < 0.0)
        {
            edgeColor = SampleEdgeColor(float2(0, clampedUV.y), float2(1, 0), params.sampleDepth);
        }
        else if (contentUV.x > 1.0)
        {
            edgeColor = SampleEdgeColor(float2(1, clampedUV.y), float2(-1, 0), params.sampleDepth);
        }
        else if (contentUV.y < 0.0)
        {
            edgeColor = SampleEdgeColor(float2(clampedUV.x, 0), float2(0, 1), params.sampleDepth);
        }
        else
        {
            edgeColor = SampleEdgeColor(float2(clampedUV.x, 1), float2(0, -1), params.sampleDepth);
        }

        if (params.colorSmoothing > 0.0)
        {
            float2 pt = GetInputPt() * 10.0;
            float3 neighbor1 = INPUT.SampleLevel(linearSampler, saturate(clampedUV + float2(pt.x, 0)), 0).rgb;
            float3 neighbor2 = INPUT.SampleLevel(linearSampler, saturate(clampedUV - float2(pt.x, 0)), 0).rgb;
            float3 neighbor3 = INPUT.SampleLevel(linearSampler, saturate(clampedUV + float2(0, pt.y)), 0).rgb;
            float3 neighbor4 = INPUT.SampleLevel(linearSampler, saturate(clampedUV - float2(0, pt.y)), 0).rgb;
            float3 avgNeighbor = (neighbor1 + neighbor2 + neighbor3 + neighbor4) * 0.25;
            edgeColor = lerp(edgeColor, avgNeighbor, params.colorSmoothing * 0.5);
        }

        float dist = length(distFromEdge);
        float maxDist = length(contentOffset) * params.glowSpread;
        float falloff = 1.0 - saturate(dist / max(maxDist, 0.001));
        falloff = pow(falloff, 1.5);

        float3 color = edgeColor * params.glowIntensity * falloff;
        result = float4(color, 1.0);
    }

    OUTPUT[tid.xy] = result;
}
