import bgfx;

struct CropZoomParams
{
    [bgfx::PARAM("Zoom", 1.0, 0.5, 4.0, "Zoom level (>1 = crop inward to remove borders, <1 = zoom out)")]
    float zoom;

    [bgfx::PARAM("Offset X", 0.0, -1.0, 1.0, "Horizontal offset to pan the visible area")]
    float offsetX;

    [bgfx::PARAM("Offset Y", 0.0, -1.0, 1.0, "Vertical offset to pan the visible area")]
    float offsetY;
}
ConstantBuffer<CropZoomParams> params : register(b2);

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState linearSampler;

[bgfx::EFFECT("Crop & Zoom", 2)]
[bgfx::CATEGORY("Transform")]
[bgfx::DESCRIPTION("Zoom and pan the input to crop out letterboxing or borders.")]
[bgfx::PASS(1, "Crop & Zoom")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 uv = GetOutputUV(tid);

    float z = max(params.zoom, 0.5);
    float2 cropUV = (uv - 0.5) / z + 0.5 + float2(params.offsetX, params.offsetY) / z;

    // Out-of-bounds pixels become black
    float4 result = float4(0, 0, 0, 1);
    if (cropUV.x >= 0.0 && cropUV.x <= 1.0 && cropUV.y >= 0.0 && cropUV.y <= 1.0)
    {
        result = INPUT.SampleLevel(linearSampler, cropUV, 0);
    }

    OUTPUT[tid.xy] = result;
}
