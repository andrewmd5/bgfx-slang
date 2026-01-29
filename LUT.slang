// LUT - Color Grading
// Apply color grading using LUT images (like in OBS or Photoshop).
// Convert .cube files to PNG at: streamshark.io/obs-guide/converting-cube-3dl-lut-to-image

import bgfx;

struct LUTParams
{
    [bgfx::PARAM("Intensity", 1.0, 0.0, 1.0, "How much of the LUT color to apply")]
    float intensity;

    [bgfx::PARAM_INT("LUT Size", 64, 16, 64, "Match your LUT image (usually 64)")]
    int lutSize;
}
ConstantBuffer<LUTParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::PARAM_TEXTURE("LUT Image", "Select a LUT file (PNG)", "LUT Images|*.png;*.dds;*.bmp|All Files|*.*")]
Texture2D<float4> LUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState LUTSampler;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState InputSampler;

float3 SampleLUT(float3 color, float size)
{
    float sliceSize = 1.0 / size;
    float slicePixelSize = sliceSize / size;
    float sliceInnerSize = slicePixelSize * (size - 1.0);

    float blueSlice0 = floor(color.b * (size - 1.0));
    float blueSlice1 = min(blueSlice0 + 1.0, size - 1.0);
    float blueMix = (color.b * (size - 1.0)) - blueSlice0;

    float2 uv0;
    uv0.x = (blueSlice0 * sliceSize) + (slicePixelSize * 0.5) + (color.r * sliceInnerSize);
    uv0.y = (slicePixelSize * 0.5) + (color.g * sliceInnerSize);

    float2 uv1;
    uv1.x = (blueSlice1 * sliceSize) + (slicePixelSize * 0.5) + (color.r * sliceInnerSize);
    uv1.y = uv0.y;

    float3 color0 = LUT.SampleLevel(LUTSampler, uv0, 0).rgb;
    float3 color1 = LUT.SampleLevel(LUTSampler, uv1, 0).rgb;

    return lerp(color0, color1, blueMix);
}

[bgfx::EFFECT("LUT", 2)]
[bgfx::CATEGORY("Post Processing")]
[bgfx::DESCRIPTION("Apply color grading using a LUT image")]
[bgfx::PASS(1, "Apply LUT")]
[bgfx::PASS_IO("INPUT, LUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 uv = GetOutputUV(tid);
    float3 color = INPUT.SampleLevel(InputSampler, uv, 0).rgb;
    float3 lutColor = SampleLUT(saturate(color), float(params.lutSize));
    color = lerp(color, lutColor, params.intensity);

    OUTPUT[tid.xy] = float4(color, 1.0);
}
