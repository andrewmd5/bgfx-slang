// Feedback Test
// Demonstrates PassFeedback by creating a strong motion trail effect
// The image smears/trails as objects move, proving feedback accumulation works
// 90% previous frame + 10% current = strong persistence

import bgfx;

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::FEEDBACK("Smear")]
Texture2D PrevFrame;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::EFFECT("Feedback Test", 2)]
[bgfx::CATEGORY("Temporal")]
[bgfx::DESCRIPTION("Test effect - creates obvious motion trail/smear using PassFeedback.")]
[bgfx::DYNAMIC]
[bgfx::PASS(1, "Smear")]
[bgfx::PASS_NAME("Smear")]
[bgfx::PASS_IO("INPUT, PrevFrame", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    float4 current = INPUT.SampleLevel(sam, pos, 0);
    float4 prev = PrevFrame.SampleLevel(sam, pos, 0);

    // Strong blend with previous frame creates obvious trail
    float4 result = lerp(current, prev, 0.9);
    result.a = 1.0;
    OUTPUT[tid.xy] = result;
}
