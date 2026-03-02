// History Test
// Displays all 8 frames (current + 7 history) in a 4x2 grid
// Top row: Current, History1, History2, History3
// Bottom row: History4, History5, History6, History7

import bgfx;

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::HISTORY(1)]
Texture2D History1;

[bgfx::HISTORY(2)]
Texture2D History2;

[bgfx::HISTORY(3)]
Texture2D History3;

[bgfx::HISTORY(4)]
Texture2D History4;

[bgfx::HISTORY(5)]
Texture2D History5;

[bgfx::HISTORY(6)]
Texture2D History6;

[bgfx::HISTORY(7)]
Texture2D History7;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::EFFECT("History Test", 2)]
[bgfx::CATEGORY("Temporal")]
[bgfx::DESCRIPTION("Test effect - shows current + 7 history frames in a 4x2 grid.")]
[bgfx::DYNAMIC]
[bgfx::PASS(1, "History Grid")]
[bgfx::PASS_IO("INPUT, History1, History2, History3, History4, History5, History6, History7", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);

    // Determine grid cell (4 columns x 2 rows)
    int col = int(pos.x * 4.0);
    int row = int(pos.y * 2.0);
    int cell = row * 4 + col;

    // Sample position within cell
    float2 cellPos = frac(pos * float2(4.0, 2.0));

    float4 result;
    switch (cell)
    {
    case 0:
        result = INPUT.SampleLevel(sam, cellPos, 0);
        break;
    case 1:
        result = History1.SampleLevel(sam, cellPos, 0);
        break;
    case 2:
        result = History2.SampleLevel(sam, cellPos, 0);
        break;
    case 3:
        result = History3.SampleLevel(sam, cellPos, 0);
        break;
    case 4:
        result = History4.SampleLevel(sam, cellPos, 0);
        break;
    case 5:
        result = History5.SampleLevel(sam, cellPos, 0);
        break;
    case 6:
        result = History6.SampleLevel(sam, cellPos, 0);
        break;
    case 7:
        result = History7.SampleLevel(sam, cellPos, 0);
        break;
    default:
        result = float4(0, 0, 0, 1);
        break;
    }

    OUTPUT[tid.xy] = result;
}
