import bgfx;

struct MotionInterpParams
{
    [bgfx::PARAM("Motion Scale", 300.0, 100.0, 1000.0, "Scale divisor for motion vectors (higher = subtler motion)")]
    float motionScale;

    [bgfx::PARAM("Blend Factor", 0.5, 0.0, 1.0, "Mix between previous and current frame (0 = previous, 1 = current)")]
    float blendFactor;
}
ConstantBuffer<MotionInterpParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::HISTORY(1)]
Texture2D PrevFrame;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rg16f")]
RWTexture2D<float2> motionVectors;
Texture2D<float2> motionVectorsRead;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState linearSampler;

float SampleLuminance(Texture2D tex, float2 uv, float2 shift, float2 texelSize)
{
    float4 c = tex.SampleLevel(linearSampler, uv + shift, 0);
    c += tex.SampleLevel(linearSampler, uv + shift + float2(texelSize.x, 0), 0);
    c += tex.SampleLevel(linearSampler, uv + shift + float2(0, texelSize.y), 0);
    c += tex.SampleLevel(linearSampler, uv + shift + float2(-texelSize.x, 0), 0);
    c += tex.SampleLevel(linearSampler, uv + shift + float2(0, -texelSize.y), 0);
    return c.r + c.g + c.b;
}

[bgfx::EFFECT("Motion Interpolation", 2)]
[bgfx::CATEGORY("Temporal")]
[bgfx::DESCRIPTION("Frame interpolation using motion vector estimation.")]
[bgfx::DYNAMIC]
[bgfx::PASS(1, "Motion Estimation")]
[bgfx::PASS_IO("INPUT, PrevFrame", "motionVectors")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 uv = GetOutputUV(tid);
    float2 texelSize = GetInputPt();

    float prevLuminance = SampleLuminance(PrevFrame, uv, float2(0, 0), texelSize);
    float bestMatch = abs(prevLuminance - SampleLuminance(INPUT, uv, float2(0, 0), texelSize));
    float2 bestShift = float2(0, 0);

    static const float TAU = 6.28318530718;

    for (int circle = 1; circle < 4; ++circle)
    {
        float circleF = float(circle);
        int steps = 4 * circle;
        float angleStep = TAU / float(steps);

        for (int j = 0; j < steps; ++j)
        {
            float angle = angleStep * float(j);
            float2 checkShift = float2(sin(angle), cos(angle));
            float currentLuminance = SampleLuminance(INPUT, uv, checkShift * texelSize * circleF, texelSize);
            float diff = abs(prevLuminance - currentLuminance);

            if (diff < bestMatch)
            {
                bestMatch = diff;
                bestShift = checkShift;
            }
        }
    }

    motionVectors[tid.xy] = bestShift;
}

[bgfx::PASS(2, "Interpolation")]
[bgfx::PASS_IO("INPUT, PrevFrame, motionVectorsRead", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 uv = GetOutputUV(tid);

    float scale = max(params.motionScale, 100.0);
    float2 shift = motionVectorsRead.SampleLevel(linearSampler, uv, 0).rg / scale;

    float4 prev = PrevFrame.SampleLevel(linearSampler, uv - shift * 0.5, 0);
    float4 curr = INPUT.SampleLevel(linearSampler, uv - shift * 0.5, 0);

    OUTPUT[tid.xy] = lerp(prev, curr, params.blendFactor);
}
