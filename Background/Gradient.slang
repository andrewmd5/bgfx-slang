// Gradient Background
// Fills pillarbox/letterbox areas with a customizable gradient

import bgfx;

struct GradientParams
{
    [bgfx::PARAM("Color 1 Red", 0.05, 0.0, 1.0, "Red component of the first gradient color")]
    float color1R;

    [bgfx::PARAM("Color 1 Green", 0.0, 0.0, 1.0, "Green component of the first gradient color")]
    float color1G;

    [bgfx::PARAM("Color 1 Blue", 0.15, 0.0, 1.0, "Blue component of the first gradient color")]
    float color1B;

    [bgfx::PARAM("Color 2 Red", 0.15, 0.0, 1.0, "Red component of the second gradient color")]
    float color2R;

    [bgfx::PARAM("Color 2 Green", 0.0, 0.0, 1.0, "Green component of the second gradient color")]
    float color2G;

    [bgfx::PARAM("Color 2 Blue", 0.05, 0.0, 1.0, "Blue component of the second gradient color")]
    float color2B;

    [bgfx::PARAM("Gradient Angle", 45.0, 0.0, 360.0, "Direction of the gradient in degrees (0 = horizontal, 90 = vertical)")]
    float gradientAngle;
};

ConstantBuffer<GradientParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("RENDERER_WIDTH", "RENDERER_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState linearSampler;

[bgfx::EFFECT("Gradient", 2)]
[bgfx::CATEGORY("Background")]
[bgfx::DESCRIPTION("Fills the black bars with a smooth gradient between two colors.")]
[bgfx::PASS(1, "Gradient Background")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    float2 inputSize = float2(GetInputSize());
    float2 outputSize = float2(GetOutputSize());

    float inputAspect = inputSize.x / inputSize.y;
    float outputAspect = outputSize.x / outputSize.y;

    float2 contentScale;
    float2 contentOffset;

    if (inputAspect > outputAspect)
    {
        contentScale = float2(1.0, outputAspect / inputAspect);
        contentOffset = float2(0.0, (1.0 - contentScale.y) * 0.5);
    }
    else
    {
        contentScale = float2(inputAspect / outputAspect, 1.0);
        contentOffset = float2((1.0 - contentScale.x) * 0.5, 0.0);
    }

    float2 contentUV = (pos - contentOffset) / contentScale;
    bool insideContent = all(contentUV >= 0.0) && all(contentUV <= 1.0);

    if (insideContent)
    {
        OUTPUT[tid.xy] = INPUT.SampleLevel(linearSampler, contentUV, 0);
        return;
    }

    float3 color1 = float3(params.color1R, params.color1G, params.color1B);
    float3 color2 = float3(params.color2R, params.color2G, params.color2B);

    float angleRad = radians(params.gradientAngle);
    float2 dir = float2(cos(angleRad), sin(angleRad));
    float t = dot(pos - 0.5, dir) + 0.5;
    t = saturate(t);

    float3 color = lerp(color1, color2, t);

    OUTPUT[tid.xy] = float4(color, 1.0);
}
