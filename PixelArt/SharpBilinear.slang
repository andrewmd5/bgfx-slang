// Sharp Bilinear - Crisp bilinear interpolation for pixel art
// Based on https://github.com/libretro/common-shaders/blob/master/interpolation/shaders/sharp-bilinear.cg

import bgfx;

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::EFFECT("Sharp Bilinear", 2)]
[bgfx::CATEGORY("Pixel Art")]
[bgfx::DESCRIPTION("Produces sharp pixel art scaling by constraining bilinear interpolation to texel boundaries, avoiding the typical blurry look of standard bilinear filtering.")]
[bgfx::PASS(1, "Sharp Bilinear")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 inputPt = GetInputPt();
    float2 scale = GetScale();
    float2 inputSize = float2(GetInputSize());

    float2 pos = GetOutputUV(tid);

    float2 texel = pos * inputSize;
    float2 texel_floored = floor(texel);

    float2 s = frac(texel);

    float2 region_range = 0.5 - 0.5 / scale;

    float2 center_dist = s - 0.5;

    float2 f = (center_dist - clamp(center_dist, -region_range, region_range)) * scale + 0.5;

    float2 mod_texel = texel_floored + f;

    OUTPUT[tid.xy] = INPUT.SampleLevel(sam, mod_texel * inputPt, 0);
}
