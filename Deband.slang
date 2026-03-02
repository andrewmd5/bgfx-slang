// Deband
// Removes color banding artifacts from compressed video and images
// Based on deband shader by haasn
// Ported from https://github.com/haasn/gentoo-conf/blob/xor/home/nand/.mpv/shaders/deband.glsl

import bgfx;

struct DebandParams
{
    [bgfx::PARAM("Threshold", 64, 0, 512, "The threshold of difference below which a pixel is considered to be part of a gradient. Higher values increase debanding strength but may reduce image detail.")]
    float threshold;

    [bgfx::PARAM("Range", 8, 0, 16, "The range (in source pixels) at which to sample for neighbors. Higher values find more gradients but lower values deband more aggressively.")]
    float range;

    [bgfx::PARAM_INT("Iterations", 4, 1, 10, "The number of debanding iterations to perform. Each iteration samples from random positions, increasing quality at the cost of performance.")]
    int iterations;

    [bgfx::PARAM("Grain", 48, 0, 256, "Amount of noise to add to the output. Helps cover remaining banding artifacts. Set to 0 to disable.")]
    float grain;
};
ConstantBuffer<DebandParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState samLinear;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState samPoint;

// PRNG functions for randomized sampling
float mod289(float x)
{
    return x - floor(x / 289.0) * 289.0;
}

float permute(float x)
{
    return mod289((34.0 * x + 1.0) * x);
}

float rand(float x)
{
    return frac(x / 41.0);
}

// Calculate stochastic approximation of average color around a pixel
float3 computeAverage(float2 pos, float r, inout float h)
{
    const float2 pt = GetInputPt();

    // Generate random distance and direction
    float dist = rand(h) * r;
    h = permute(h);
    float dir = rand(h) * 6.2831853;
    h = permute(h);

    float2 offset = float2(cos(dir), sin(dir)) * pt * dist;

    // Sample at quarter-turn intervals around the source pixel
    float3 samples[4];
    samples[0] = INPUT.SampleLevel(samLinear, pos + float2(offset.x, offset.y), 0).rgb;
    samples[1] = INPUT.SampleLevel(samLinear, pos + float2(-offset.y, offset.x), 0).rgb;
    samples[2] = INPUT.SampleLevel(samLinear, pos + float2(-offset.x, -offset.y), 0).rgb;
    samples[3] = INPUT.SampleLevel(samLinear, pos + float2(offset.y, -offset.x), 0).rgb;

    // Return normalized average
    return (samples[0] + samples[1] + samples[2] + samples[3]) * 0.25;
}

[bgfx::EFFECT("Deband", 2)]
[bgfx::CATEGORY("Post Processing")]
[bgfx::DESCRIPTION("Reduces color banding artifacts commonly found in compressed video and images. Uses randomized sampling to smooth gradients while preserving detail. Includes optional grain to mask remaining artifacts.")]
[bgfx::PASS(1, "Deband")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);

    // Initialize PRNG by hashing position
    float3 m = float3(pos, 4.6);
    float h = permute(permute(permute(m.x) + m.y) + m.z);

    // Sample source pixel
    float3 col = INPUT.SampleLevel(samPoint, pos, 0).rgb;

    // Debanding iterations
    for (int i = 1; i <= params.iterations; i++)
    {
        float3 avg = computeAverage(pos, i * params.range, h);
        float3 diff = abs(col - avg);
        float3 thres = params.threshold / (i * 16384.0);
        col = lerp(avg, col, step(thres, diff));
    }

    // Add random noise to output
    float3 noise;
    noise.x = rand(h);
    h = permute(h);
    noise.y = rand(h);
    h = permute(h);
    noise.z = rand(h);
    h = permute(h);
    col += (params.grain / 8192.0) * (noise - 0.5);

    OUTPUT[tid.xy] = float4(col, 1.0);
}
