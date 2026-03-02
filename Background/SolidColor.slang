// Solid Color Background
// Fills pillarbox/letterbox areas with a customizable solid color

import bgfx;

struct SolidColorParams
{
    [bgfx::PARAM("Red", 0.1, 0.0, 1.0, "Red color component (0-1)")]
    float colorR;

    [bgfx::PARAM("Green", 0.1, 0.0, 1.0, "Green color component (0-1)")]
    float colorG;

    [bgfx::PARAM("Blue", 0.1, 0.0, 1.0, "Blue color component (0-1)")]
    float colorB;
};

ConstantBuffer<SolidColorParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("RENDERER_WIDTH", "RENDERER_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState linearSampler;

[bgfx::EFFECT("Solid Color", 2)]
[bgfx::CATEGORY("Background")]
[bgfx::DESCRIPTION("Fills the black bars with a solid color of your choice. Simple and clean.")]
[bgfx::PASS(1, "Solid Color Background")]
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

    OUTPUT[tid.xy] = float4(params.colorR, params.colorG, params.colorB, 1.0);
}
