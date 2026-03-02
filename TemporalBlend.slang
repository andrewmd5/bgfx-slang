// Temporal Blend
// Uses OriginalHistory to blend multiple previous INPUT frames
// Creates a smooth, slightly ghosted image that reduces temporal noise

import bgfx;

struct TemporalBlendParams
{
    [bgfx::PARAM("Blend Strength", 0.5, 0.0, 0.9, "How much history frames contribute to the result")]
    float blendStrength;
};
ConstantBuffer<TemporalBlendParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::HISTORY(1)]
Texture2D Prev1;

[bgfx::HISTORY(2)]
Texture2D Prev2;

[bgfx::HISTORY(3)]
Texture2D Prev3;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::EFFECT("Temporal Blend", 2)]
[bgfx::CATEGORY("Temporal")]
[bgfx::DESCRIPTION("Blends current frame with previous INPUT frames for motion smoothing.")]
[bgfx::DYNAMIC]
[bgfx::PASS(1, "Blend")]
[bgfx::PASS_IO("INPUT, Prev1, Prev2, Prev3", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    float4 current = INPUT.SampleLevel(sam, pos, 0);
    float4 prev1 = Prev1.SampleLevel(sam, pos, 0);
    float4 prev2 = Prev2.SampleLevel(sam, pos, 0);
    float4 prev3 = Prev3.SampleLevel(sam, pos, 0);

    // Weighted average of history frames (more recent = higher weight)
    float4 history = prev1 * 0.5 + prev2 * 0.3 + prev3 * 0.2;

    // Blend current with history
    float4 result = lerp(current, history, params.blendStrength);
    result.a = 1.0;
    OUTPUT[tid.xy] = result;
}
