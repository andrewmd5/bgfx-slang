// Temporal Accumulate
// Uses PassFeedback to blend current input with previous output
// Creates smooth motion trails and temporal anti-aliasing effect
// Higher retention = stronger persistence/ghosting

import bgfx;

struct TemporalAccumulateParams
{
    [bgfx::PARAM("Retention", 0.8, 0.0, 0.95, "Blend factor for previous frame (higher = more ghosting)")]
    float retention;
};
ConstantBuffer<TemporalAccumulateParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::FEEDBACK("Accumulate")]
Texture2D PrevOutput;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::EFFECT("Temporal Accumulate", 2)]
[bgfx::CATEGORY("Temporal")]
[bgfx::DESCRIPTION("Accumulates current frame with previous output for temporal persistence.")]
[bgfx::DYNAMIC]
[bgfx::PASS(1, "Accumulate")]
[bgfx::PASS_NAME("Accumulate")]
[bgfx::PASS_IO("INPUT, PrevOutput", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    float4 current = INPUT.SampleLevel(sam, pos, 0);
    float4 prev = PrevOutput.SampleLevel(sam, pos, 0);

    // Blend current with accumulated previous output
    float4 result = lerp(current, prev, params.retention);
    result.a = 1.0;
    OUTPUT[tid.xy] = result;
}
