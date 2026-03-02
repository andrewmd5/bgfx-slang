import bgfx;

struct BorderParams
{
    [bgfx::PARAM("Screen X", 0.5, 0.0, 1.0, "Horizontal position of game screen")]
    float screenX;

    [bgfx::PARAM("Screen Y", 0.5, 0.0, 1.0, "Vertical position of game screen")]
    float screenY;

    [bgfx::PARAM("Screen Width", 0.30, 0.1, 1.0, "Width of game screen area")]
    float screenWidth;

    [bgfx::PARAM("Screen Height", 0.45, 0.1, 1.0, "Height of game screen area")]
    float screenHeight;

    [bgfx::PARAM("Border Scale", 1.0, 0.1, 5.0, "Scale of the border image (>1 = larger, <1 = smaller)")]
    float borderScale;
}
ConstantBuffer<BorderParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("RENDERER_WIDTH", "RENDERER_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::PARAM_TEXTURE("Border Image", "Select device border image", "Images|*.png;*.jpg;*.bmp|All|*.*")]
Texture2D<float4> BORDER;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState borderSampler;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState inputSampler;

[bgfx::EFFECT("Device Border", 2)]
[bgfx::CATEGORY("Background")]
[bgfx::DESCRIPTION("Overlay a device border (PSP, GameBoy, etc.) around the game")]
[bgfx::PASS(1, "Composite")]
[bgfx::PASS_IO("INPUT, BORDER", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 outputSize = GetOutputSize();
    if (tid.x >= outputSize.x || tid.y >= outputSize.y)
        return;

    float2 uv = (float2(tid.xy) + 0.5) / float2(outputSize);

    float scale = max(params.borderScale, 0.1);
    float2 borderUV = (uv - 0.5) / scale + 0.5;
    float4 border = BORDER.SampleLevel(borderSampler, borderUV, 0);

    float2 screenMin = float2(params.screenX - params.screenWidth * 0.5,
                               params.screenY - params.screenHeight * 0.5);
    float2 screenMax = float2(params.screenX + params.screenWidth * 0.5,
                               params.screenY + params.screenHeight * 0.5);

    float4 result;
    if (uv.x >= screenMin.x && uv.x <= screenMax.x &&
        uv.y >= screenMin.y && uv.y <= screenMax.y)
    {
        // Inside game screen area: sample game content and blend with border
        float2 gameUV = (uv - screenMin) / (screenMax - screenMin);
        float4 game = INPUT.SampleLevel(inputSampler, gameUV, 0);
        result = lerp(game, border, border.a);
    }
    else
    {
        // Outside game screen: use border (transparent areas show through)
        result = border;
    }

    OUTPUT[tid.xy] = result;
}
