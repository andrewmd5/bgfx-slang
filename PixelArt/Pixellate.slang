// Pixellate - Area-weighted pixel sampling filter
// Based on https://github.com/libretro/common-shaders/blob/master/interpolation/shaders/pixellate.cg

import bgfx;

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::EFFECT("Pixellate", 2)]
[bgfx::CATEGORY("Pixel Art")]
[bgfx::DESCRIPTION("Area-weighted sampling filter that produces clean pixel scaling by blending colors based on coverage area.")]
[bgfx::PASS(1, "Pixellate")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    float2 texelSize = GetInputPt();

    float2 range = GetOutputPt() / 2.0 * 0.999;

    float left = pos.x - range.x;
    float right = pos.x + range.x;
    float top = pos.y + range.y;
    float bottom = pos.y - range.y;

    float3 topLeftColor = INPUT.SampleLevel(sam, (floor(float2(left, top) / texelSize) + 0.5) * texelSize, 0).rgb;
    float3 topRightColor = INPUT.SampleLevel(sam, (floor(float2(right, top) / texelSize) + 0.5) * texelSize, 0).rgb;
    float3 bottomLeftColor = INPUT.SampleLevel(sam, (floor(float2(left, bottom) / texelSize) + 0.5) * texelSize, 0).rgb;
    float3 bottomRightColor = INPUT.SampleLevel(sam, (floor(float2(right, bottom) / texelSize) + 0.5) * texelSize, 0).rgb;

    float2 border = clamp(round(pos / texelSize) * texelSize, float2(left, bottom), float2(right, top));

    float totalArea = 4.0 * range.x * range.y;

    float3 averageColor;
    averageColor = ((border.x - left) * (top - border.y) / totalArea) * topLeftColor;
    averageColor += ((right - border.x) * (border.y - bottom) / totalArea) * bottomRightColor;
    averageColor += ((border.x - left) * (border.y - bottom) / totalArea) * bottomLeftColor;
    averageColor += ((right - border.x) * (top - border.y) / totalArea) * topRightColor;

    OUTPUT[tid.xy] = float4(averageColor, 1.0);
}
