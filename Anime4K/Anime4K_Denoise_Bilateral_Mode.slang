// Anime4K Denoise Bilateral Mode
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
#define HISTOGRAM_REGULARIZATION 0.2
#define INTENSITY_POWER_CURVE 1.0

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

[bgfx::EFFECT("Anime4K Denoise Bilateral Mode", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("Bilateral mode denoising filter. Finds the statistical mode of the weighted histogram using intensity and spatial gaussians with regularization.")]
[bgfx::FP16]
[bgfx::PASS(1, "Bilateral Mode Denoise")]
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

    half4 src[KERNELSIZE + 1][KERNELSIZE + 1];
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

            src[i][j] = half4(sr.w, sg.w, sb.w, get_luma(half3(sr.w, sg.w, sb.w)));
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, get_luma(half3(sr.x, sg.x, sb.x)));
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, get_luma(half3(sr.z, sg.z, sb.z)));
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, get_luma(half3(sr.y, sg.y, sb.y)));
        }
    }

    [unroll]
    for (uint oi = 0; oi <= 1; ++oi)
    {
        [unroll]
        for (uint oj = 0; oj <= 1; ++oj)
        {
            const uint2 destPos = gxy + uint2(oi, oj);

            half3 histogram_v[KERNELLEN];
            half histogram_l[KERNELLEN];
            half histogram_w[KERNELLEN];
            half histogram_wn[KERNELLEN];

            half vc = src[KERNELHALFSIZE + oi][KERNELHALFSIZE + oj].a;

            half is = half(pow(float(vc) + 0.0001, INTENSITY_POWER_CURVE) * params.intensitySigma);
            half ss = half(SPATIAL_SIGMA);

            [unroll]
            for (uint k = 0; k < KERNELLEN; k++)
            {
                const int2 ipos = GETOFFSET(k);
                const uint2 idx = uint2(oi, oj) + ipos.yx + KERNELHALFSIZE;
                histogram_v[k] = src[idx.x][idx.y].rgb;
                histogram_l[k] = src[idx.x][idx.y].a;
                histogram_w[k] = gaussian(histogram_l[k], is, vc) * gaussian(half(length(float2(ipos))), ss, 0.0h);
                histogram_wn[k] = 0.0h;
            }

            [unroll]
            for (uint ki = 0; ki < KERNELLEN; ki++)
            {
                histogram_wn[ki] += gaussian(0.0h, half(HISTOGRAM_REGULARIZATION), 0.0h) * histogram_w[ki];
                [unroll]
                for (uint mi = (ki + 1); mi < KERNELLEN; mi++)
                {
                    half d = gaussian(histogram_l[mi], half(HISTOGRAM_REGULARIZATION), histogram_l[ki]);
                    histogram_wn[mi] += d * histogram_w[ki];
                    histogram_wn[ki] += d * histogram_w[mi];
                }
            }

            half3 maxv = half3(0);
            half maxw = 0.0h;

            [unroll]
            for (uint fi = 0; fi < KERNELLEN; ++fi)
            {
                if (histogram_wn[fi] >= maxw)
                {
                    maxw = histogram_wn[fi];
                    maxv = histogram_v[fi];
                }
            }

            OUTPUT[destPos] = float4(float3(maxv), 1);
        }
    }
}
