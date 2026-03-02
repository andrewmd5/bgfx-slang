// FXAA Medium Quality Anti-Aliasing
// Based on the FXAA algorithm by Timothy Lottes (NVIDIA)

import bgfx;

#define FXAA_PRESET 3
#include "FXAA.h"

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState linearSampler;

[bgfx::EFFECT("FXAA Medium", 2)]
[bgfx::CATEGORY("Anti-Aliasing")]
[bgfx::DESCRIPTION("Fast Approximate Anti-Aliasing with medium quality settings. Good balance between performance and visual quality with 16 search steps.")]
[bgfx::PASS(1, "FXAA Medium")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(64, 1, 1)]
void Pass1(uint3 threadId: SV_DispatchThreadID, uint3 groupId: SV_GroupID)
{
    uint2 gxy = (Swizzle8x8(threadId.x) << 1) + groupId.xy * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();
    uint i, j;

    float3 src[4][4];
    [unroll]
    for (i = 0; i <= 2; i += 2) {
        [unroll]
        for (j = 0; j <= 2; j += 2) {
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const float4 sr = INPUT.GatherRed(linearSampler, tpos);
            const float4 sg = INPUT.GatherGreen(linearSampler, tpos);
            const float4 sb = INPUT.GatherBlue(linearSampler, tpos);

            src[i][j] = float3(sr.w, sg.w, sb.w);
            src[i][j + 1] = float3(sr.x, sg.x, sb.x);
            src[i + 1][j] = float3(sr.z, sg.z, sb.z);
            src[i + 1][j + 1] = float3(sr.y, sg.y, sb.y);
        }
    }

    [unroll]
    for (i = 0; i <= 1; ++i) {
        [unroll]
        for (j = 0; j <= 1; ++j) {
            uint2 destPos = gxy + uint2(i, j);
            OUTPUT[destPos] = float4(ProcessFXAA(src, i + 1, j + 1, INPUT, linearSampler, (destPos + 0.5f) * inputPt, inputPt), 1);
        }
    }
}
