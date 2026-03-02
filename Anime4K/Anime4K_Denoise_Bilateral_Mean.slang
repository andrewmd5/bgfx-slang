// Anime4K Denoise Bilateral Mean
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

#define KERNELSIZE 5
#define KERNELHALFSIZE 2

half3 gaussian_vec(half3 x, half3 rcpS, half3 m)
{
    half3 scaled = (x - m) * rcpS;
    return exp(half3(-0.5h) * scaled * scaled);
}

half gaussian(half x, half rcpS, half m)
{
    half scaled = (x - m) * rcpS;
    return exp(-0.5h * scaled * scaled);
}

[bgfx::EFFECT("Anime4K Denoise Bilateral Mean", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("Bilateral mean denoising filter. Uses intensity and spatial gaussians to compute a weighted average, preserving edges while smoothing noise.")]
[bgfx::FP16]
[bgfx::PASS(1, "Bilateral Mean Denoise")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half3 src[KERNELSIZE + 1][KERNELSIZE + 1];
    [unroll]
    for (uint i = 0; i <= KERNELSIZE - 1; i += 2)
    {
        [unroll]
        for (uint j = 0; j <= KERNELSIZE - 1; j += 2)
        {
            float2 tpos = (gxy + int2(i, j) - KERNELHALFSIZE + 1) * inputPt;
            const half4 sr = half4(INPUT.GatherRed(sam, tpos));
            const half4 sg = half4(INPUT.GatherGreen(sam, tpos));
            const half4 sb = half4(INPUT.GatherBlue(sam, tpos));

            src[i][j] = half3(sr.w, sg.w, sb.w);
            src[i][j + 1] = half3(sr.x, sg.x, sb.x);
            src[i + 1][j] = half3(sr.z, sg.z, sb.z);
            src[i + 1][j + 1] = half3(sr.y, sg.y, sb.y);
        }
    }

    half len[KERNELSIZE][KERNELSIZE];
    [unroll]
    for (uint li = 0; li < KERNELSIZE; ++li)
    {
        [unroll]
        for (uint lj = 0; lj < KERNELSIZE; ++lj)
        {
            len[li][lj] = half(length(float2((int)li - KERNELHALFSIZE, (int)lj - KERNELHALFSIZE)));
        }
    }

    [unroll]
    for (uint oi = 0; oi <= 1; ++oi)
    {
        [unroll]
        for (uint oj = 0; oj <= 1; ++oj)
        {
            uint2 destPos = gxy + uint2(oi, oj);

            half3 sum = half3(0);
            half3 n = half3(0);

            half3 vc = src[KERNELHALFSIZE + oi][KERNELHALFSIZE + oj];

            half3 rcpIs = half3(rcp(pow(float3(vc) + 0.0001, INTENSITY_POWER_CURVE) * params.intensitySigma));
            half rcpSs = half(rcp(SPATIAL_SIGMA));

            [unroll]
            for (uint k = 0; k < KERNELSIZE; ++k)
            {
                [unroll]
                for (uint m = 0; m < KERNELSIZE; ++m)
                {
                    half3 v = src[k + oi][m + oj];
                    half3 d = gaussian_vec(v, rcpIs, vc) * gaussian(len[k][m], rcpSs, 0.0h);
                    sum += d * v;
                    n += d;
                }
            }

            OUTPUT[destPos] = float4(float3(sum / n), 1);
        }
    }
}
