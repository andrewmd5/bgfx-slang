// Nearest Neighbor

import bgfx;

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState pointSampler;

[bgfx::EFFECT("Nearest Neighbor", 2)]
[bgfx::CATEGORY("Scaling")]
[bgfx::DESCRIPTION("Point sampling filter that preserves sharp pixel edges. Ideal for pixel art and retro graphics where you want to maintain crisp boundaries.")]
[bgfx::PASS(1, "Nearest Neighbor")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    OUTPUT[tid.xy] = INPUT.SampleLevel(pointSampler, pos, 0);
}
