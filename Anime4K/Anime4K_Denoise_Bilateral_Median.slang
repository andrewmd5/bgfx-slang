// Anime4K Denoise Bilateral Median
// Based on Anime4K project by bloc97

import bgfx;

#ifdef BG_FP16
#pragma warning(disable: 3557)
#endif

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

struct Params
{
    [bgfx::PARAM("Strength", 0.1, 0.01, 5.0, "Intensity window size, higher is stronger denoise.")]
    float intensitySigma;
};

ConstantBuffer<Params> params : register(b2);

#define SPATIAL_SIGMA 1.0
#define INTENSITY_POWER_CURVE 1.0
#define HISTOGRAM_REGULARIZATION 0.0

#define KERNELSIZE 3
#define KERNELHALFSIZE 1
#define KERNELLEN 9

#define GETOFFSET(idx) int2(int(idx % KERNELSIZE) - KERNELHALFSIZE, int(idx / KERNELSIZE) - KERNELHALFSIZE)

half get_luma(half3 rgb)
{
    return dot(half3(0.299h, 0.587h, 0.114h), rgb);
}

half gaussian(half x, half s, half m)
{
    half scaled = (x - m) / s;
    return exp(-0.5h * scaled * scaled);
}

half3 getMedian(half3 v[KERNELLEN], half w[KERNELLEN], half n)
{
    half3 result = half3(0);

    [unroll]
    for (uint i = 0; i < KERNELLEN; i++)
    {
        half w_above = 0.0h;
        half w_below = 0.0h;
        [unroll]
        for (uint j = 0; j < KERNELLEN; j++)
        {
            if (v[j].x > v[i].x)
            {
                w_above += w[j];
            }
            else if (v[j].x < v[i].x)
            {
                w_below += w[j];
            }
        }

        if ((n - w_above) / n >= 0.5h && w_below / n <= 0.5h)
        {
            result = v[i];
            break;
        }
    }

    return result;
}

[bgfx::EFFECT("Anime4K Denoise Bilateral Median", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("Bilateral median denoising filter. Computes a weighted median using intensity and spatial gaussians, providing strong edge-preserving noise reduction.")]
[bgfx::FP16]
[bgfx::PASS(1, "Bilateral Median Denoise")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 inputPt = GetInputPt();
    float2 pos = GetOutputUV(tid);

    half3 histogram_v[KERNELLEN];
    half histogram_l[KERNELLEN];
    half histogram_w[KERNELLEN];
    half n = 0.0h;

    half vc = get_luma(half3(INPUT.SampleLevel(sam, pos, 0).rgb));

    half is = half(pow(float(vc) + 0.0001, INTENSITY_POWER_CURVE) * params.intensitySigma);
    half ss = half(SPATIAL_SIGMA);

    [unroll]
    for (uint i = 0; i < KERNELLEN; i++)
    {
        int2 ipos = GETOFFSET(i);
        histogram_v[i] = half3(INPUT.SampleLevel(sam, pos + ipos * inputPt, 0).rgb);
        histogram_l[i] = get_luma(histogram_v[i]);
        histogram_w[i] = gaussian(histogram_l[i], is, vc) * gaussian(half(length(float2(ipos))), ss, 0.0h);
        n += histogram_w[i];
    }

    OUTPUT[tid.xy] = float4(float3(getMedian(histogram_v, histogram_w, n)), 1);
}
