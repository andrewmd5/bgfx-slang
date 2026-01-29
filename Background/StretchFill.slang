// Stretch Fill Background
// Fills pillarbox/letterbox areas by stretching/mirroring edge content
// Creates a seamless extended view effect

import bgfx;

struct StretchFillParams
{
    [bgfx::PARAM_BOOL("Stretch Mode", false, "Off = Mirror (reflects content), On = Stretch (extends edges)")]
    bool stretchMode;

    [bgfx::PARAM("Edge Blur", 8.0, 0.0, 20.0, "Amount of blur applied to the fill area. Higher = smoother transition")]
    float edgeBlur;

    [bgfx::PARAM("Fill Brightness", 0.7, 0.2, 1.0, "Brightness of the fill area. Lower values make it more subtle")]
    float fillBrightness;

    [bgfx::PARAM("Vignette Strength", 0.5, 0.0, 1.0, "Darkening towards the outer edges of the fill area")]
    float vignetteStrength;
};

ConstantBuffer<StretchFillParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("RENDERER_WIDTH", "RENDERER_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState linearSampler;

float3 SampleBlurred(float2 uv, float radius)
{
    if (radius < 1.0)
    {
        return INPUT.SampleLevel(linearSampler, saturate(uv), 0).rgb;
    }

    float2 pt = GetInputPt();
    float3 sum = float3(0, 0, 0);
    float weight = 0;

    int r = (int)radius;
    for (int y = -r; y <= r; y += 2)
    {
        for (int x = -r; x <= r; x += 2)
        {
            float2 offset = float2(x, y) * pt;
            float w = 1.0 / (1.0 + length(float2(x, y)));
            sum += INPUT.SampleLevel(linearSampler, saturate(uv + offset), 0).rgb * w;
            weight += w;
        }
    }

    return sum / weight;
}

[bgfx::EFFECT("Stretch Fill", 2)]
[bgfx::CATEGORY("Background")]
[bgfx::DESCRIPTION("Fills the black bars by stretching and mirroring the edge pixels of the game content, creating a seamless extended view.")]
[bgfx::PASS(1, "Stretch Fill Background")]
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

    float2 fillUV;

    if (!params.stretchMode)
    {
        fillUV = contentUV;
        if (fillUV.x < 0.0)
            fillUV.x = -fillUV.x;
        if (fillUV.x > 1.0)
            fillUV.x = 2.0 - fillUV.x;
        if (fillUV.y < 0.0)
            fillUV.y = -fillUV.y;
        if (fillUV.y > 1.0)
            fillUV.y = 2.0 - fillUV.y;
        fillUV = saturate(fillUV);
    }
    else
    {
        fillUV = saturate(contentUV);
    }

    float3 color = SampleBlurred(fillUV, params.edgeBlur);

    color *= params.fillBrightness;

    float2 distFromContent = abs(contentUV - saturate(contentUV));
    float distFactor = length(distFromContent);
    float vignette = 1.0 - saturate(distFactor * params.vignetteStrength * 3.0);
    color *= vignette;

    OUTPUT[tid.xy] = float4(color, 1.0);
}
