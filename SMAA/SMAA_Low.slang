// SMAA Low Quality Anti-Aliasing
// Subpixel Morphological Anti-Aliasing

import bgfx;

#define SMAA_RT_METRICS float4(GetInputPt(), GetInputSize())
#define SMAA_LINEAR_SAMPLER LinearSampler
#define SMAA_POINT_SAMPLER PointSampler
#define SMAA_PRESET_LOW
#include "SMAA.h"

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState PointSampler;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState LinearSampler;

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rg8")]
RWTexture2D<float2> edgesTex;
Texture2D<float2> edgesTexRead;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> blendTex;
Texture2D<float4> blendTexRead;

[bgfx::SOURCE("AreaTex.dds")]
Texture2D<float4> areaTex;

[bgfx::SOURCE("SearchTex.dds")]
Texture2D<float> searchTex;

[bgfx::EFFECT("SMAA Low", 2)]
[bgfx::CATEGORY("Anti-Aliasing")]
[bgfx::DESCRIPTION("Subpixel Morphological Anti-Aliasing with low quality preset. Fastest SMAA variant with 4 search steps. Disables diagonal and corner detection for maximum performance.")]
[bgfx::PASS(1, "Edge Detection")]
[bgfx::PASS_IO("INPUT", "edgesTex")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = tid.xy;

    uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 pos = (gxy + 0.5) * GetInputPt();
    edgesTex[gxy] = SMAALumaEdgeDetectionPS(pos, INPUT);
}

[bgfx::PASS(2, "Weight Calculation")]
[bgfx::PASS_IO("edgesTexRead, areaTex, searchTex", "blendTex")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = tid.xy;

    uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 pos = (gxy + 0.5) * GetInputPt();
    blendTex[gxy] = SMAABlendingWeightCalculationPS(pos, edgesTexRead, areaTex, searchTex, 0);
}

[bgfx::PASS(3, "Neighborhood Blend")]
[bgfx::PASS_IO("INPUT, blendTexRead", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass3(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = tid.xy;

    uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 pos = (gxy + 0.5) * GetInputPt();
    OUTPUT[gxy] = SMAANeighborhoodBlendingPS(pos, INPUT, blendTexRead);
}
