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
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    float3 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
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

    $for(i in Range(0, 2))
    {
        $for(j in Range(0, 2))
        {
            uint2 destPos = gxy + uint2(i, j);
            if (destPos.x < outputSize.x && destPos.y < outputSize.y)
            {
                OUTPUT[destPos] = float4(ProcessFXAA(src, i + 1, j + 1, INPUT, linearSampler, (destPos + 0.5f) * inputPt, inputPt), 1);
            }
        }
    }
}
