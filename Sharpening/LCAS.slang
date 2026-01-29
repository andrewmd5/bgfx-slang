// LCAS - Light Contrast Adaptive Sharpening
// A combination of linear interpolation and a lightweight CAS implementation

import bgfx;

struct EffectParams
{
    [bgfx::PARAM("Sharpness", 0.5, 0, 1, "Controls the intensity of the sharpening effect. Higher values = sharper image.")]
    float sharpness;
};

ConstantBuffer<EffectParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam;

float3 LightCAS(uint2 ip, float peak)
{
    float2 pos = (ip + 0.5f) * GetOutputPt();
    float2 inputPt = GetInputPt();

    float3 a = INPUT.SampleLevel(sam, pos + float2(-inputPt.x, -inputPt.y), 0).rgb;
    float3 b = INPUT.SampleLevel(sam, pos + float2(0, -inputPt.y), 0).rgb;
    float3 c = INPUT.SampleLevel(sam, pos + float2(inputPt.x, -inputPt.y), 0).rgb;
    float3 d = INPUT.SampleLevel(sam, pos + float2(-inputPt.x, 0), 0).rgb;
    float3 f = INPUT.SampleLevel(sam, pos + float2(inputPt.x, 0), 0).rgb;
    float3 g = INPUT.SampleLevel(sam, pos + float2(-inputPt.x, inputPt.y), 0).rgb;
    float3 h = INPUT.SampleLevel(sam, pos + float2(0, inputPt.y), 0).rgb;
    float3 i = INPUT.SampleLevel(sam, pos + float2(inputPt.x, inputPt.y), 0).rgb;

    float3 x = a + c + g + i;
    float3 y = b + d + f + h;

    float3 e = INPUT.SampleLevel(sam, pos + float2(inputPt.x * 0.25, inputPt.y * 0.5), 0).rgb;
    e += INPUT.SampleLevel(sam, pos + float2(-inputPt.x * 0.25, -inputPt.y * 0.5), 0).rgb;
    e += INPUT.SampleLevel(sam, pos + float2(inputPt.x * 0.5, -inputPt.y * 0.25), 0).rgb;
    e += INPUT.SampleLevel(sam, pos + float2(-inputPt.x * 0.5, inputPt.y * 0.25), 0).rgb;
    e /= 4;

    float3 mnRGB = min(min(min(min(d, e), min(f, b)), h), min(min(a, i), min(c, g)));
    float3 mxRGB = max(max(max(max(d, e), max(f, b)), h), max(max(a, i), max(c, g)));

    float3 wRGB = sqrt(min(mnRGB, 1.0 - mxRGB) / mxRGB) * peak;

    float3 color = ((x + y) * wRGB + (e * 5.0 - (x + y * 2.0 + e * 4.0) / 4.0)) / (1.0 + 8.0 * wRGB);

    return (color + clamp(color, mnRGB, mxRGB) * 4.0) / 5.0;
}

[bgfx::EFFECT("Light CAS", 2)]
[bgfx::CATEGORY("Sharpening")]
[bgfx::DESCRIPTION("Lightweight Contrast Adaptive Sharpening that combines linear interpolation with CAS principles. Good balance between performance and quality.")]
[bgfx::PASS(1, "Light CAS")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (tid.xy / 8) * 16 + Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8));

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    const float peak = lerp(0, -0.1111111111111111, params.sharpness);

    OUTPUT[gxy] = float4(LightCAS(gxy, peak), 1);

    gxy.x += 8u;
    OUTPUT[gxy] = float4(LightCAS(gxy, peak), 1);

    gxy.y += 8u;
    OUTPUT[gxy] = float4(LightCAS(gxy, peak), 1);

    gxy.x -= 8u;
    OUTPUT[gxy] = float4(LightCAS(gxy, peak), 1);
}
