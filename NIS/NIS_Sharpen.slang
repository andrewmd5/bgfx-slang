// NVIDIA Image Scaling (Sharpen)
// Based on NVIDIA Image Scaling SDK
// https://github.com/NVIDIAGameWorks/NVIDIAImageScaling

import bgfx;

struct EffectParams
{
    [bgfx::PARAM("Sharpness", 0.5, 0.0, 1.0, "Controls the overall sharpening strength. Higher values create more pronounced edges.")]
    float sharpness;
};

ConstantBuffer<EffectParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState samplerLinearClamp;

#define NIS_SCALER 0
#define NIS_HLSL 1

#ifdef BG_FP16
#define NIS_USE_HALF_PRECISION 1
#else
#define NIS_USE_HALF_PRECISION 0
#endif

static const float kDetectRatio = 2.0f * 1127.f / 1024.f;
static const float kDetectThres = 64.0f / 1024.0f;
static const float kEps = 1.0f / 255.0f;

static const float kMinContrastRatio = 2.0f;
static const float kMaxContrastRatio = 10.0f;
static const float kRatioNorm = 1.0f / (kMaxContrastRatio - kMinContrastRatio);
static const float kContrastBoost = 1.0f;

static const float kSharpStartY = 0.45f;
static const float kSharpEndY = 0.9f;
static const float kSharpScaleY = 1.0f / (kSharpEndY - kSharpStartY);

float getSharpSlider()
{
    return params.sharpness - 0.5f;
}

float getMinScale()
{
    return (getSharpSlider() >= 0.0f) ? 1.25f : 1.0f;
}

float getMaxScale()
{
    return (getSharpSlider() >= 0.0f) ? 1.25f : 1.75f;
}

float getSharpStrengthMin()
{
    return max(0.0f, 0.4f + getSharpSlider() * getMinScale() * 1.2f);
}

float getSharpStrengthMax()
{
    return 1.6f + getSharpSlider() * getMaxScale() * 1.8f;
}

float getSharpStrengthScale()
{
    return getSharpStrengthMax() - getSharpStrengthMin();
}

float getLimitScale()
{
    return (getSharpSlider() >= 0.0f) ? 1.25f : 1.0f;
}

float getSharpLimitMin()
{
    return max(0.1f, 0.14f + getSharpSlider() * getLimitScale() * 0.32f);
}

float getSharpLimitMax()
{
    return 0.5f + getSharpSlider() * getLimitScale() * 0.6f;
}

float getSharpLimitScale()
{
    return getSharpLimitMax() - getSharpLimitMin();
}

#define NIS_BLOCK_WIDTH 32
#define NIS_BLOCK_HEIGHT 32
#define NIS_THREAD_GROUP_SIZE 256

#define kSupportSize 5
#define kNumPixelsX (NIS_BLOCK_WIDTH + kSupportSize + 1)
#define kNumPixelsY (NIS_BLOCK_HEIGHT + kSupportSize + 1)

groupshared float shPixelsY[kNumPixelsY][kNumPixelsX];

float getY(float3 rgba)
{
    return 0.2126f * rgba.x + 0.7152f * rgba.y + 0.0722f * rgba.z;
}

float4 GetEdgeMap(float p[5][5], int i, int j)
{
    const float g_0 = abs(p[0 + i][0 + j] + p[0 + i][1 + j] + p[0 + i][2 + j] - p[2 + i][0 + j] - p[2 + i][1 + j] - p[2 + i][2 + j]);
    const float g_45 = abs(p[1 + i][0 + j] + p[0 + i][0 + j] + p[0 + i][1 + j] - p[2 + i][1 + j] - p[2 + i][2 + j] - p[1 + i][2 + j]);
    const float g_90 = abs(p[0 + i][0 + j] + p[1 + i][0 + j] + p[2 + i][0 + j] - p[0 + i][2 + j] - p[1 + i][2 + j] - p[2 + i][2 + j]);
    const float g_135 = abs(p[1 + i][0 + j] + p[2 + i][0 + j] + p[2 + i][1 + j] - p[0 + i][1 + j] - p[0 + i][2 + j] - p[1 + i][2 + j]);

    const float g_0_90_max = max(g_0, g_90);
    const float g_0_90_min = min(g_0, g_90);
    const float g_45_135_max = max(g_45, g_135);
    const float g_45_135_min = min(g_45, g_135);

    float e_0_90 = 0;
    float e_45_135 = 0;

    if (g_0_90_max + g_45_135_max == 0)
    {
        return float4(0, 0, 0, 0);
    }

    e_0_90 = min(g_0_90_max / (g_0_90_max + g_45_135_max), 1.0f);
    e_45_135 = 1.0f - e_0_90;

    bool c_0_90 = (g_0_90_max > (g_0_90_min * kDetectRatio)) && (g_0_90_max > kDetectThres) && (g_0_90_max > g_45_135_min);
    bool c_45_135 = (g_45_135_max > (g_45_135_min * kDetectRatio)) && (g_45_135_max > kDetectThres) && (g_45_135_max > g_0_90_min);
    bool c_g_0_90 = g_0_90_max == g_0;
    bool c_g_45_135 = g_45_135_max == g_45;

    float f_e_0_90 = (c_0_90 && c_45_135) ? e_0_90 : 1.0f;
    float f_e_45_135 = (c_0_90 && c_45_135) ? e_45_135 : 1.0f;

    float weight_0 = (c_0_90 && c_g_0_90) ? f_e_0_90 : 0.0f;
    float weight_90 = (c_0_90 && !c_g_0_90) ? f_e_0_90 : 0.0f;
    float weight_45 = (c_45_135 && c_g_45_135) ? f_e_45_135 : 0.0f;
    float weight_135 = (c_45_135 && !c_g_45_135) ? f_e_45_135 : 0.0f;

    return float4(weight_0, weight_90, weight_45, weight_135);
}

float CalcLTIFast(const float y[5])
{
    const float a_min = min(min(y[0], y[1]), y[2]);
    const float a_max = max(max(y[0], y[1]), y[2]);

    const float b_min = min(min(y[2], y[3]), y[4]);
    const float b_max = max(max(y[2], y[3]), y[4]);

    const float a_cont = a_max - a_min;
    const float b_cont = b_max - b_min;

    const float cont_ratio = max(a_cont, b_cont) / (min(a_cont, b_cont) + kEps);
    return (1.0f - saturate((cont_ratio - kMinContrastRatio) * kRatioNorm)) * kContrastBoost;
}

float EvalUSM(const float pxl[5], const float sharpnessStrength, const float sharpnessLimit)
{
    float y_usm = -0.6001f * pxl[1] + 1.2002f * pxl[2] - 0.6001f * pxl[3];

    y_usm *= sharpnessStrength;

    y_usm = min(sharpnessLimit, max(-sharpnessLimit, y_usm));

    y_usm *= CalcLTIFast(pxl);

    return y_usm;
}

float4 GetDirUSM(const float p[5][5])
{
    const float scaleY = 1.0f - saturate((p[2][2] - kSharpStartY) * kSharpScaleY);
    const float sharpnessStrength = scaleY * getSharpStrengthScale() + getSharpStrengthMin();
    const float sharpnessLimit = (scaleY * getSharpLimitScale() + getSharpLimitMin()) * p[2][2];

    float4 rval;

    float interp0Deg[5];
    [unroll]
    for (int i0 = 0; i0 < 5; ++i0)
    {
        interp0Deg[i0] = p[i0][2];
    }
    rval.x = EvalUSM(interp0Deg, sharpnessStrength, sharpnessLimit);

    float interp90Deg[5];
    [unroll]
    for (int i90 = 0; i90 < 5; ++i90)
    {
        interp90Deg[i90] = p[2][i90];
    }
    rval.y = EvalUSM(interp90Deg, sharpnessStrength, sharpnessLimit);

    float interp45Deg[5];
    interp45Deg[0] = p[1][1];
    interp45Deg[1] = lerp(p[2][1], p[1][2], 0.5f);
    interp45Deg[2] = p[2][2];
    interp45Deg[3] = lerp(p[3][2], p[2][3], 0.5f);
    interp45Deg[4] = p[3][3];
    rval.z = EvalUSM(interp45Deg, sharpnessStrength, sharpnessLimit);

    float interp135Deg[5];
    interp135Deg[0] = p[3][1];
    interp135Deg[1] = lerp(p[3][2], p[2][1], 0.5f);
    interp135Deg[2] = p[2][2];
    interp135Deg[3] = lerp(p[2][3], p[1][2], 0.5f);
    interp135Deg[4] = p[1][3];
    rval.w = EvalUSM(interp135Deg, sharpnessStrength, sharpnessLimit);

    return rval;
}

[bgfx::EFFECT("NVIDIA Image Scaling (Sharpen)", 2)]
[bgfx::CATEGORY("Sharpening")]
[bgfx::DESCRIPTION("NVIDIA adaptive directional sharpening algorithm. Enhances edges and details without upscaling, using edge-aware filtering.")]
[bgfx::FP16]
[bgfx::PASS(1, "NVSharpen")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[bgfx::BLOCK_SIZE(32, 32)]
[shader("compute")]
[numthreads(16, 16, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    const float2 srcPt = GetInputPt();
    const float kSrcNormX = srcPt.x;
    const float kSrcNormY = srcPt.y;

    const uint2 blockIdx = tid.xy / uint2(NIS_BLOCK_WIDTH, NIS_BLOCK_HEIGHT);
    const uint threadIdx = (tid.y % NIS_BLOCK_HEIGHT) * NIS_BLOCK_WIDTH + (tid.x % NIS_BLOCK_WIDTH);

    const int dstBlockX = int(NIS_BLOCK_WIDTH * blockIdx.x);
    const int dstBlockY = int(NIS_BLOCK_HEIGHT * blockIdx.y);

    const float kShift = 0.5f - kSupportSize / 2;

    for (int i = int(threadIdx) * 2; i < kNumPixelsX * kNumPixelsY / 2; i += NIS_THREAD_GROUP_SIZE * 2)
    {
        uint2 pos = uint2(uint(i) % uint(kNumPixelsX), uint(i) / uint(kNumPixelsX) * 2);
        [unroll]
        for (int dy = 0; dy < 2; dy++)
        {
            [unroll]
            for (int dx = 0; dx < 2; dx++)
            {
                const float tx = (dstBlockX + pos.x + dx + kShift) * kSrcNormX;
                const float ty = (dstBlockY + pos.y + dy + kShift) * kSrcNormY;
                const float4 px = INPUT.SampleLevel(samplerLinearClamp, float2(tx, ty), 0);
                shPixelsY[pos.y + dy][pos.x + dx] = getY(px.xyz);
            }
        }
    }

    GroupMemoryBarrierWithGroupSync();

    for (int k = int(threadIdx); k < NIS_BLOCK_WIDTH * NIS_BLOCK_HEIGHT; k += NIS_THREAD_GROUP_SIZE)
    {
        const int2 pos = int2(uint(k) % uint(NIS_BLOCK_WIDTH), uint(k) / uint(NIS_BLOCK_WIDTH));

        float p[5][5];
        [unroll]
        for (int pi = 0; pi < 5; ++pi)
        {
            [unroll]
            for (int pj = 0; pj < 5; ++pj)
            {
                p[pi][pj] = shPixelsY[pos.y + pi][pos.x + pj];
            }
        }

        float4 dirUSM = GetDirUSM(p);

        float4 w = GetEdgeMap(p, kSupportSize / 2 - 1, kSupportSize / 2 - 1);

        const float usmY = (dirUSM.x * w.x + dirUSM.y * w.y + dirUSM.z * w.z + dirUSM.w * w.w);

        const int dstX = dstBlockX + pos.x;
        const int dstY = dstBlockY + pos.y;

        float2 coord = float2((dstX + 0.5f) * kSrcNormX, (dstY + 0.5f) * kSrcNormY);
        float2 dstCoord = float2(dstX, dstY);

        uint2 outputSize = GetOutputSize();
        if (uint(dstX) < outputSize.x && uint(dstY) < outputSize.y)
        {
            float4 op = INPUT.SampleLevel(samplerLinearClamp, coord, 0);
            op.x += usmY;
            op.y += usmY;
            op.z += usmY;
            OUTPUT[int2(dstCoord)] = float4(saturate(op).xyz, 1.0);
        }
    }
}
