// Mouse Test Effect
// - Spotlight follows mouse cursor
// - Click to leave a colored mark at click position
// - Shows current mouse coordinates

import bgfx;

struct MouseTestParams
{
    [bgfx::PARAM("Spotlight Size", 100, 20, 300, "Radius of the spotlight effect in pixels")]
    float spotlightSize;

    [bgfx::PARAM("Spotlight Intensity", 0.5, 0, 1, "Brightness of the spotlight effect")]
    float spotlightIntensity;
};
ConstantBuffer<MouseTestParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::EFFECT("Mouse Test", 2)]
[bgfx::CATEGORY("Test")]
[bgfx::DESCRIPTION("Test mouse position - shows spotlight that follows cursor, click to leave a mark")]
[bgfx::DYNAMIC]
[bgfx::PASS(1, "Mouse Test")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    float4 color = INPUT.SampleLevel(sam, pos, 0);
    uint2 outputSize = GetOutputSize();
    float2 pixelPos = pos * outputSize;

    // Get mouse data (xy=current pos, zw=click pos, all in normalized 0-1 coordinates)
    float4 mouse = GetMouse();
    float2 mousePos = abs(mouse.xy) * outputSize;
    float2 clickPos = abs(mouse.zw) * outputSize;
    bool isClicked = mouse.z > 0;

    // Spotlight effect following mouse
    float distToMouse = length(pixelPos - mousePos);
    float spotlight = 1.0 - smoothstep(0, params.spotlightSize, distToMouse);

    // Brighten around mouse cursor
    color.rgb = lerp(color.rgb, color.rgb + float3(0.3, 0.3, 0.3), spotlight * params.spotlightIntensity);

    // Show click marker (red when clicked, blue for last click position)
    float distToClick = length(pixelPos - clickPos);
    if (distToClick < 15)
    {
        float3 clickColor = isClicked ? float3(1, 0.2, 0.2) : float3(0.2, 0.2, 1);
        color.rgb = lerp(color.rgb, clickColor, 0.8);
    }

    // Draw crosshair at mouse position
    if (abs(pixelPos.x - mousePos.x) < 1 || abs(pixelPos.y - mousePos.y) < 1)
    {
        if (distToMouse < params.spotlightSize * 0.5 && distToMouse > 5)
        {
            color.rgb = lerp(color.rgb, float3(1, 1, 0), 0.5);
        }
    }

    OUTPUT[tid.xy] = color;
}
