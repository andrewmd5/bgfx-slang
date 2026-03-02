// Blur Fill Background
// Fills pillarbox/letterbox areas with a blurred, stretched version of the game content
// Creates an immersive ambient light effect around the game

import bgfx;

struct BlurFillParams
{
    [bgfx::PARAM("Blur Strength", 16.0, 4.0, 32.0, "How blurry the background fill should be. Higher = more blur")]
    float blurStrength;

    [bgfx::PARAM("Background Brightness", 0.5, 0.1, 1.0, "Brightness of the blurred background. Lower values are more subtle")]
    float bgBrightness;

    [bgfx::PARAM("Background Saturation", 0.8, 0.0, 1.5, "Color saturation of the background. Lower = more muted colors")]
    float bgSaturation;
};

ConstantBuffer<BlurFillParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("RENDERER_WIDTH", "RENDERER_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState linearSampler;

float3 RGBtoHSV(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = c.g < c.b ? float4(c.bg, K.wz) : float4(c.gb, K.xy);
    float4 q = c.r < p.x ? float4(p.xyw, c.r) : float4(c.r, p.yzx);
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 HSVtoRGB(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

float3 BlurSample(float2 uv, float radius)
{
    float2 pt = GetInputPt();
    float3 sum = float3(0, 0, 0);
    float count = 0;

    int r = (int)radius;
    for (int y = -r; y <= r; y += 2)
    {
        for (int x = -r; x <= r; x += 2)
        {
            float2 offset = float2(x, y) * pt;
            sum += INPUT.SampleLevel(linearSampler, uv + offset, 0).rgb;
            count += 1.0;
        }
    }

    return sum / count;
}

[bgfx::EFFECT("Blur Fill", 2)]
[bgfx::CATEGORY("Background")]
[bgfx::DESCRIPTION("Fills the black bars with a heavily blurred and stretched version of the game content, creating an ambient backlight effect similar to Philips Ambilight.")]
[bgfx::PASS(1, "Blur Fill Background")]
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
    }
    else
    {
        float2 clampedUV = saturate(contentUV);

        float3 blurred = BlurSample(clampedUV, params.blurStrength);

        float3 hsv = RGBtoHSV(blurred);
        hsv.y *= params.bgSaturation;
        float3 color = HSVtoRGB(hsv);

        color *= params.bgBrightness;

        float2 edgeDist = min(pos, 1.0 - pos);
        float edgeFade = saturate(min(edgeDist.x, edgeDist.y) * 10.0);
        color *= edgeFade;

        OUTPUT[tid.xy] = float4(color, 1.0);
    }
}
