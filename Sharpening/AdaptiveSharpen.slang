// Adaptive Sharpen
// Based on: https://github.com/libretro/slang-shaders/blob/master/sharpen/shaders/adaptive-sharpen.slang
//
// Adaptive sharpen - version 2015-05-15 - (requires ps >= 3.0)
// Designed for use post-resize, expects full range gamma light

import bgfx;

struct EffectParams
{
    [bgfx::PARAM("Sharpness", 0.8, 0, 2, "Main sharpening strength control. Values between 0.3 and 2.0 work best for most content.")]
    float curveHeight;
};

ConstantBuffer<EffectParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

#define curveslope (params.curveHeight * 1.5f)
#define D_overshoot 0.016f
#define D_comp_ratio 0.250f
#define L_overshoot 0.004f
#define L_comp_ratio 0.167f
#define max_scale_lim 10.0f

float ComputeLuminance(float3 RGB)
{
    return sqrt((1.0f / 3.0f) * ((RGB * RGB).r + (RGB * RGB).g + (RGB * RGB).b));
}

[bgfx::EFFECT("Adaptive Sharpen", 2)]
[bgfx::CATEGORY("Sharpening")]
[bgfx::DESCRIPTION("Content-aware sharpening algorithm that adapts to local image features. Preserves smooth gradients while enhancing edges with minimal halo artifacts.")]
[bgfx::PASS(1, "Adaptive Sharpen")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    float4 src[8][8];
    $for(ii in Range(0, 4))
    {
        int i = ii * 2;
        $for(jj in Range(0, 4))
        {
            int j = jj * 2;
            if (!((i == 0 && j == 0) || (i == 6 && j == 0) || (i == 0 && j == 6) || (i == 6 && j == 6)))
            {
                float2 tpos = ((int2)gxy + int2(i, j) - 2) * inputPt;
                const float4 sr = INPUT.GatherRed(sam, tpos);
                const float4 sg = INPUT.GatherGreen(sam, tpos);
                const float4 sb = INPUT.GatherBlue(sam, tpos);

                src[i][j].rgb = float3(sr.w, sg.w, sb.w);
                src[i][j].w = ComputeLuminance(src[i][j].rgb);
                src[i][j + 1].rgb = float3(sr.x, sg.x, sb.x);
                src[i][j + 1].w = ComputeLuminance(src[i][j + 1].rgb);
                src[i + 1][j].rgb = float3(sr.z, sg.z, sb.z);
                src[i + 1][j].w = ComputeLuminance(src[i + 1][j].rgb);
                src[i + 1][j + 1].rgb = float3(sr.y, sg.y, sb.y);
                src[i + 1][j + 1].w = ComputeLuminance(src[i + 1][j + 1].rgb);
            }
        }
    }

    $for(i in Range(0, 2))
    {
        $for(j in Range(0, 2))
        {
            const uint2 destPos = gxy + uint2(i, j);
            if (destPos.x < outputSize.x && destPos.y < outputSize.y)
            {
                float2 pos = (destPos + 0.5f) * inputPt;

                float3 blur = (2 * (src[i + 3][j + 2].rgb + src[i + 2][j + 3].rgb + src[i + 4][j + 3].rgb + src[i + 3][j + 4].rgb) +
                               (src[i + 2][j + 2].rgb + src[i + 4][j + 2].rgb + src[i + 2][j + 4].rgb + src[i + 4][j + 4].rgb) +
                               4 * src[i + 3][j + 3].rgb) /
                              16;
                float blur_Y = (blur.r * (1.0 / 3.0) + blur.g * (1.0 / 3.0) + blur.b * (1.0 / 3.0));

                float edge = length(abs(blur - src[i + 3][j + 3].rgb) + abs(blur - src[i + 2][j + 2].rgb) +
                                    abs(blur - src[i + 3][j + 2].rgb) + abs(blur - src[i + 4][j + 2].rgb) +
                                    abs(blur - src[i + 2][j + 3].rgb) + abs(blur - src[i + 4][j + 3].rgb) +
                                    abs(blur - src[i + 2][j + 4].rgb) + abs(blur - src[i + 3][j + 4].rgb) +
                                    abs(blur - src[i + 4][j + 4].rgb) +
                                    0.25 * (abs(blur - src[i + 3][j + 1].rgb) + abs(blur - src[i + 1][j + 3].rgb) +
                                            abs(blur - src[i + 5][j + 3].rgb) + abs(blur - src[i + 3][j + 5].rgb))) *
                             (1.0 / 3.0);

                edge *= min((0.8 + 2.7 * pow(2, (-7.4 * blur_Y))), 3.2);

                float c0_Y = src[i + 3][j + 3].w;

                float kernel[25] = {
                    c0_Y, src[i + 2][j + 2].w, src[i + 3][j + 2].w, src[i + 4][j + 2].w,
                    src[i + 2][j + 3].w, src[i + 4][j + 3].w, src[i + 2][j + 4].w, src[i + 3][j + 4].w, src[i + 4][j + 4].w,
                    src[i + 3][j + 1].w, src[i + 1][j + 3].w, src[i + 5][j + 3].w, src[i + 3][j + 5].w, src[i + 3][j + 6].w,
                    src[i + 4][j + 5].w, src[i + 2][j + 5].w, src[i + 6][j + 3].w, src[i + 5][j + 4].w, src[i + 5][j + 2].w,
                    src[i][j + 3].w, src[i + 1][j + 4].w, src[i + 1][j + 2].w, src[i + 3][j].w, src[i + 4][j + 1].w, src[i + 2][j + 1].w
                };

                float mdiff_c0 = 0.03 + 4 * (abs(kernel[0] - kernel[2]) + abs(kernel[0] - kernel[4]) +
                                             abs(kernel[0] - kernel[5]) + abs(kernel[0] - kernel[7]) +
                                             0.25 * (abs(kernel[0] - kernel[1]) + abs(kernel[0] - kernel[3]) +
                                                     abs(kernel[0] - kernel[6]) + abs(kernel[0] - kernel[8])));

                float mdiff_c9 = (abs(kernel[9] - kernel[2]) + abs(kernel[9] - kernel[24]) +
                                  abs(kernel[9] - kernel[23]) + abs(kernel[9] - kernel[22]) +
                                  0.5 * (abs(kernel[9] - kernel[1]) + abs(kernel[9] - kernel[3])));

                float mdiff_c10 = (abs(kernel[10] - kernel[20]) + abs(kernel[10] - kernel[19]) +
                                   abs(kernel[10] - kernel[21]) + abs(kernel[10] - kernel[4]) +
                                   0.5 * (abs(kernel[10] - kernel[1]) + abs(kernel[10] - kernel[6])));

                float mdiff_c11 = (abs(kernel[11] - kernel[17]) + abs(kernel[11] - kernel[5]) +
                                   abs(kernel[11] - kernel[18]) + abs(kernel[11] - kernel[16]) +
                                   0.5 * (abs(kernel[11] - kernel[3]) + abs(kernel[11] - kernel[8])));

                float mdiff_c12 = (abs(kernel[12] - kernel[13]) + abs(kernel[12] - kernel[15]) +
                                   abs(kernel[12] - kernel[7]) + abs(kernel[12] - kernel[14]) +
                                   0.5 * (abs(kernel[12] - kernel[6]) + abs(kernel[12] - kernel[8])));

                float4 weights = float4(
                    min((mdiff_c0 / mdiff_c9), 2.0),
                    min((mdiff_c0 / mdiff_c10), 2.0),
                    min((mdiff_c0 / mdiff_c11), 2.0),
                    min((mdiff_c0 / mdiff_c12), 2.0));

                float neg_laplace = (0.25 * (kernel[2] + kernel[4] + kernel[5] + kernel[7]) +
                                     (kernel[1] + kernel[3] + kernel[6] + kernel[8]) +
                                     ((kernel[9] * weights.x) + (kernel[10] * weights.y) +
                                      (kernel[11] * weights.z) + (kernel[12] * weights.w))) /
                                    (5 + weights.x + weights.y + weights.z + weights.w);

                float sharpen_val = 0.01 + (params.curveHeight / (curveslope * pow(edge, 3.5) + 0.5)) -
                                    (params.curveHeight / (8192 * pow((edge * 2.2), 4.5) + 0.5));

                float sharpdiff = (c0_Y - neg_laplace) * (sharpen_val * 0.8);

                // k=0: Range(1, 25) for i1, Range(0, 23) for i2
                $for(i1 in Range(1, 25))
                {
                    float temp = kernel[i1 - 1];
                    kernel[i1 - 1] = min(kernel[i1 - 1], kernel[i1]);
                    kernel[i1] = max(temp, kernel[i1]);
                }
                $for(i2_offset in Range(0, 23))
                {
                    int i2 = 23 - i2_offset;
                    float temp = kernel[i2 - 1];
                    kernel[i2 - 1] = min(kernel[i2 - 1], kernel[i2]);
                    kernel[i2] = max(temp, kernel[i2]);
                }

                // k=1: Range(2, 24) for i1, Range(0, 21) for i2
                $for(i1 in Range(2, 24))
                {
                    float temp = kernel[i1 - 1];
                    kernel[i1 - 1] = min(kernel[i1 - 1], kernel[i1]);
                    kernel[i1] = max(temp, kernel[i1]);
                }
                $for(i2_offset in Range(0, 21))
                {
                    int i2 = 22 - i2_offset;
                    float temp = kernel[i2 - 1];
                    kernel[i2 - 1] = min(kernel[i2 - 1], kernel[i2]);
                    kernel[i2] = max(temp, kernel[i2]);
                }

                float nmax = max(((kernel[23] + kernel[24]) / 2), c0_Y);
                float nmin = min(((kernel[0] + kernel[1]) / 2), c0_Y);

                float nmax_scale = max((1 / ((nmax - c0_Y) + L_overshoot)), max_scale_lim);
                float nmin_scale = max((1 / ((c0_Y - nmin) + D_overshoot)), max_scale_lim);

                sharpdiff = lerp((tanh((max(sharpdiff, 0.0)) * nmax_scale) / nmax_scale), (max(sharpdiff, 0.0)), L_comp_ratio) +
                            lerp((tanh((min(sharpdiff, 0.0)) * nmin_scale) / nmin_scale), (min(sharpdiff, 0.0)), D_comp_ratio);

                OUTPUT[destPos] = float4(src[i + 3][j + 3].rgb + sharpdiff, 1);
            }
        }
    }
}
