// Bilinear Interpolation

import bgfx;

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState linearSampler;

[bgfx::EFFECT("Bilinear Interpolation", 2)]
[bgfx::CATEGORY("Scaling")]
[bgfx::DESCRIPTION("Simple bilinear texture filtering for smooth image scaling with linear interpolation between neighboring pixels.")]
[bgfx::PASS(1, "Bilinear")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    OUTPUT[tid.xy] = INPUT.SampleLevel(linearSampler, pos, 0);
}
