// NVIDIA Image Scaling SDK - v1.0.3
// Based on https://github.com/NVIDIAGameWorks/NVIDIAImageScaling
//
// The MIT License(MIT)
//
// Copyright(c) 2022 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files(the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and / or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#ifndef NIS_SCALER_SLANGI
#define NIS_SCALER_SLANGI

#ifndef NIS_SCALER
#define NIS_SCALER 1
#endif

#define NIS_HDR_MODE_NONE    0
#define NIS_HDR_MODE_LINEAR  1
#define NIS_HDR_MODE_PQ      2

#ifndef NIS_HDR_MODE
#define NIS_HDR_MODE NIS_HDR_MODE_NONE
#endif

#define kHDRCompressionFactor  0.282842712f

#ifndef NIS_VIEWPORT_SUPPORT
#define NIS_VIEWPORT_SUPPORT 0
#endif

#ifndef NIS_USE_HALF_PRECISION
#define NIS_USE_HALF_PRECISION 0
#endif

#ifndef NIS_TEXTURE_GATHER
#define NIS_TEXTURE_GATHER 0
#endif

#ifndef NIS_CLAMP_OUTPUT
#define NIS_CLAMP_OUTPUT 0
#endif

#define NIS_SCALE_INT 1
#define NIS_SCALE_FLOAT 1.0f

#if NIS_CLAMP_OUTPUT
#if NIS_HDR_MODE == NIS_HDR_MODE_LINEAR
#define NVCLAMP(x) ( clamp(x, 0.0f, 12.5f) )
#else
#define NVCLAMP(x) ( saturate(x) )
#endif
#else
#define NVCLAMP(x) (x)
#endif

float getY(float3 rgba)
{
#if NIS_HDR_MODE == NIS_HDR_MODE_PQ
    return 0.262f * rgba.x + 0.678f * rgba.y + 0.0593f * rgba.z;
#elif NIS_HDR_MODE == NIS_HDR_MODE_LINEAR
    return sqrt(0.2126f * rgba.x + 0.7152f * rgba.y + 0.0722f * rgba.z) * kHDRCompressionFactor;
#else
    return 0.2126f * rgba.x + 0.7152f * rgba.y + 0.0722f * rgba.z;
#endif
}

float getYLinear(float3 rgba)
{
    return 0.2126f * rgba.x + 0.7152f * rgba.y + 0.0722f * rgba.z;
}

float3 YUVtoRGB(float3 yuv)
{
    float y = yuv.x - 16.0f / 255.0f;
    float u = yuv.y - 128.0f / 255.0f;
    float v = yuv.z - 128.0f / 255.0f;
    float3 rgb;
    rgb.x = saturate(1.164f * y + 1.596f * v);
    rgb.y = saturate(1.164f * y - 0.392f * u - 0.813f * v);
    rgb.z = saturate(1.164f * y + 2.017f * u);
    return rgb;
}

#if NIS_SCALER
float4 GetEdgeMap(float p[4][4], int i, int j)
#else
float4 GetEdgeMap(float p[5][5], int i, int j)
#endif
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

#if NIS_SCALER

#ifndef NIS_BLOCK_WIDTH
#define NIS_BLOCK_WIDTH 32
#endif

#ifndef NIS_BLOCK_HEIGHT
#define NIS_BLOCK_HEIGHT 24
#endif

#ifndef NIS_THREAD_GROUP_SIZE
#define NIS_THREAD_GROUP_SIZE 256
#endif

#define kPhaseCount  64
#define kFilterSize  6
#define kSupportSize 6
#define kPadSize     kSupportSize

#define kTilePitch              (NIS_BLOCK_WIDTH + kPadSize)
#define kTileSize               (kTilePitch * (NIS_BLOCK_HEIGHT + kPadSize))

#define kEdgeMapPitch           (NIS_BLOCK_WIDTH + 2)
#define kEdgeMapSize            (kEdgeMapPitch * (NIS_BLOCK_HEIGHT + 2))

groupshared float shPixelsY[kTileSize];

#ifdef BG_FP16
groupshared half shCoefScaler[kPhaseCount][kFilterSize];
groupshared half shCoefUSM[kPhaseCount][kFilterSize];
groupshared half4 shEdgeMap[kEdgeMapSize];
#else
groupshared float shCoefScaler[kPhaseCount][kFilterSize];
groupshared float shCoefUSM[kPhaseCount][kFilterSize];
groupshared float4 shEdgeMap[kEdgeMapSize];
#endif

static float kSharpStrengthMin;
static float kSharpStrengthScale;
static float kSharpLimitMin;
static float kSharpLimitScale;

void LoadFilterBanksSh(int i0,
    Texture2D coef_scaler,
    Texture2D coef_usm)
{
    int i = i0;
#if( kPhaseCount * 2 > NIS_THREAD_GROUP_SIZE )
    for (; i < kPhaseCount * 2; i += NIS_THREAD_GROUP_SIZE)
#else
    if (i < kPhaseCount * 2)
#endif
    {
        int phase = i >> 1;
        int vIdx = i & 1;

#ifdef BG_FP16
        half4 v = (half4)coef_scaler.Load(int3(vIdx, phase, 0));
#else
        float4 v = coef_scaler.Load(int3(vIdx, phase, 0));
#endif
        int filterOffset = vIdx * 4;
        shCoefScaler[phase][filterOffset + 0] = v.x;
        shCoefScaler[phase][filterOffset + 1] = v.y;
        if (vIdx == 0)
        {
            shCoefScaler[phase][2] = v.z;
            shCoefScaler[phase][3] = v.w;
        }

#ifdef BG_FP16
        v = (half4)coef_usm.Load(int3(vIdx, phase, 0));
#else
        v = coef_usm.Load(int3(vIdx, phase, 0));
#endif
        shCoefUSM[phase][filterOffset + 0] = v.x;
        shCoefUSM[phase][filterOffset + 1] = v.y;
        if (vIdx == 0)
        {
            shCoefUSM[phase][2] = v.z;
            shCoefUSM[phase][3] = v.w;
        }
    }
}

float CalcLTI(float p0, float p1, float p2, float p3, float p4, float p5, int phase_index)
{
    const bool selector = (phase_index <= kPhaseCount / 2);
    float sel = selector ? p0 : p3;
    const float a_min = min(min(p1, p2), sel);
    const float a_max = max(max(p1, p2), sel);
    sel = selector ? p2 : p5;
    const float b_min = min(min(p3, p4), sel);
    const float b_max = max(max(p3, p4), sel);

    const float a_cont = a_max - a_min;
    const float b_cont = b_max - b_min;

    const float cont_ratio = max(a_cont, b_cont) / (min(a_cont, b_cont) + kEps);
    return (1.0f - saturate((cont_ratio - kMinContrastRatio) * kRatioNorm)) * kContrastBoost;
}

float4 GetInterpEdgeMap(const float4 edge[2][2], float phase_frac_x, float phase_frac_y)
{
    float4 h0 = lerp(edge[0][0], edge[0][1], phase_frac_x);
    float4 h1 = lerp(edge[1][0], edge[1][1], phase_frac_x);
    return lerp(h0, h1, phase_frac_y);
}

float EvalPoly6(const float pxl[6], int phase_int)
{
    float y = 0.f;
    $for(i in Range(0, 6))
    {
        y += shCoefScaler[phase_int][i] * pxl[i];
    }

    float y_usm = 0.f;
    $for(i in Range(0, 6))
    {
        y_usm += shCoefUSM[phase_int][i] * pxl[i];
    }

    const float y_scale = 1.0f - saturate((y * (1.0f / NIS_SCALE_FLOAT) - kSharpStartY) * kSharpScaleY);

    const float y_sharpness = y_scale * kSharpStrengthScale + kSharpStrengthMin;
    y_usm *= y_sharpness;

    const float y_sharpness_limit = (y_scale * kSharpLimitScale + kSharpLimitMin) * y;
    y_usm = min(y_sharpness_limit, max(-y_sharpness_limit, y_usm));

    y_usm *= CalcLTI(pxl[0], pxl[1], pxl[2], pxl[3], pxl[4], pxl[5], phase_int);

    return y + y_usm;
}

float FilterNormal(const float p[6][6], int phase_x_frac_int, int phase_y_frac_int)
{
    float h_acc = 0.0f;
    $for(j in Range(0, 6))
    {
        float v_acc = 0.0f;
        $for(i in Range(0, 6))
        {
            v_acc += p[i][j] * shCoefScaler[phase_y_frac_int][i];
        }
        h_acc += v_acc * shCoefScaler[phase_x_frac_int][j];
    }
    return h_acc;
}

float AddDirFilters(float p[6][6], float phase_x_frac, float phase_y_frac, int phase_x_frac_int, int phase_y_frac_int, float4 w)
{
    float f = 0;

    if (w.x > 0.0f)
    {
        float interp0Deg[6];
        $for(i in Range(0, 6))
        {
            interp0Deg[i] = lerp(p[i][2], p[i][3], phase_x_frac);
        }
        f += EvalPoly6(interp0Deg, phase_y_frac_int) * w.x;
    }

    if (w.y > 0.0f)
    {
        float interp90Deg[6];
        $for(i in Range(0, 6))
        {
            interp90Deg[i] = lerp(p[2][i], p[3][i], phase_y_frac);
        }
        f += EvalPoly6(interp90Deg, phase_x_frac_int) * w.y;
    }

    if (w.z > 0.0f)
    {
        float pphase_b45 = 0.5f + 0.5f * (phase_x_frac - phase_y_frac);

        float temp_interp45Deg[7];
        temp_interp45Deg[1] = lerp(p[2][1], p[1][2], pphase_b45);
        temp_interp45Deg[3] = lerp(p[3][2], p[2][3], pphase_b45);
        temp_interp45Deg[5] = lerp(p[4][3], p[3][4], pphase_b45);
        {
            pphase_b45 = pphase_b45 - 0.5f;
            float a = (pphase_b45 >= 0.f) ? p[0][2] : p[2][0];
            float b = (pphase_b45 >= 0.f) ? p[1][3] : p[3][1];
            float c = (pphase_b45 >= 0.f) ? p[2][4] : p[4][2];
            float d = (pphase_b45 >= 0.f) ? p[3][5] : p[5][3];
            temp_interp45Deg[0] = lerp(p[1][1], a, abs(pphase_b45));
            temp_interp45Deg[2] = lerp(p[2][2], b, abs(pphase_b45));
            temp_interp45Deg[4] = lerp(p[3][3], c, abs(pphase_b45));
            temp_interp45Deg[6] = lerp(p[4][4], d, abs(pphase_b45));
        }

        float interp45Deg[6];
        float pphase_p45 = phase_x_frac + phase_y_frac;
        if (pphase_p45 >= 1)
        {
            $for(i in Range(0, 6))
            {
                interp45Deg[i] = temp_interp45Deg[i + 1];
            }
            pphase_p45 = pphase_p45 - 1;
        }
        else
        {
            $for(i in Range(0, 6))
            {
                interp45Deg[i] = temp_interp45Deg[i];
            }
        }
        f += EvalPoly6(interp45Deg, int(pphase_p45 * 64)) * w.z;
    }

    if (w.w > 0.0f)
    {
        float pphase_b135 = 0.5f * (phase_x_frac + phase_y_frac);

        float temp_interp135Deg[7];
        temp_interp135Deg[1] = lerp(p[3][1], p[4][2], pphase_b135);
        temp_interp135Deg[3] = lerp(p[2][2], p[3][3], pphase_b135);
        temp_interp135Deg[5] = lerp(p[1][3], p[2][4], pphase_b135);
        {
            pphase_b135 = pphase_b135 - 0.5f;
            float a = (pphase_b135 >= 0.f) ? p[5][2] : p[3][0];
            float b = (pphase_b135 >= 0.f) ? p[4][3] : p[2][1];
            float c = (pphase_b135 >= 0.f) ? p[3][4] : p[1][2];
            float d = (pphase_b135 >= 0.f) ? p[2][5] : p[0][3];
            temp_interp135Deg[0] = lerp(p[4][1], a, abs(pphase_b135));
            temp_interp135Deg[2] = lerp(p[3][2], b, abs(pphase_b135));
            temp_interp135Deg[4] = lerp(p[2][3], c, abs(pphase_b135));
            temp_interp135Deg[6] = lerp(p[1][4], d, abs(pphase_b135));
        }

        float interp135Deg[6];
        float pphase_p135 = 1 + (phase_x_frac - phase_y_frac);
        if (pphase_p135 >= 1)
        {
            $for(i in Range(0, 6))
            {
                interp135Deg[i] = temp_interp135Deg[i + 1];
            }
            pphase_p135 = pphase_p135 - 1;
        }
        else
        {
            $for(i in Range(0, 6))
            {
                interp135Deg[i] = temp_interp135Deg[i];
            }
        }
        f += EvalPoly6(interp135Deg, int(pphase_p135 * 64)) * w.w;
    }

    return f;
}

void NVScaler(uint2 blockIdx, uint threadIdx,
    Texture2D in_texture,
    RWTexture2D<float4> out_texture,
    Texture2D coef_scaler,
    Texture2D coef_usm,
    SamplerState samplerLinearClamp,
    float kScaleX, float kScaleY,
    float kSrcNormX, float kSrcNormY,
    float kSharpStrengthMin_param, float kSharpStrengthScale_param,
    float kSharpLimitMin_param, float kSharpLimitScale_param)
{
    kSharpStrengthMin = kSharpStrengthMin_param;
    kSharpStrengthScale = kSharpStrengthScale_param;
    kSharpLimitMin = kSharpLimitMin_param;
    kSharpLimitScale = kSharpLimitScale_param;

    int dstBlockX = int(NIS_BLOCK_WIDTH * blockIdx.x);
    int dstBlockY = int(NIS_BLOCK_HEIGHT * blockIdx.y);

    const int srcBlockStartX = int(floor((dstBlockX + 0.5f) * kScaleX - 0.5f));
    const int srcBlockStartY = int(floor((dstBlockY + 0.5f) * kScaleY - 0.5f));
    const int srcBlockEndX = int(ceil((dstBlockX + NIS_BLOCK_WIDTH + 0.5f) * kScaleX - 0.5f));
    const int srcBlockEndY = int(ceil((dstBlockY + NIS_BLOCK_HEIGHT + 0.5f) * kScaleY - 0.5f));

    int numTilePixelsX = srcBlockEndX - srcBlockStartX + kSupportSize - 1;
    int numTilePixelsY = srcBlockEndY - srcBlockStartY + kSupportSize - 1;

    numTilePixelsX += numTilePixelsX & 0x1;
    numTilePixelsY += numTilePixelsY & 0x1;
    const int numTilePixels = numTilePixelsX * numTilePixelsY;

    const int numEdgeMapPixelsX = numTilePixelsX - kSupportSize + 2;
    const int numEdgeMapPixelsY = numTilePixelsY - kSupportSize + 2;
    const int numEdgeMapPixels = numEdgeMapPixelsX * numEdgeMapPixelsY;

    {
        for (uint i = threadIdx * 2; i < uint(numTilePixels) >> 1; i += NIS_THREAD_GROUP_SIZE * 2)
        {
            uint py = (i / numTilePixelsX) * 2;
            uint px = i % numTilePixelsX;

            float kShift = 0.5f - (kSupportSize - 1) / 2;
#if NIS_VIEWPORT_SUPPORT
            const float tx = (srcBlockStartX + px + kInputViewportOriginX + kShift) * kSrcNormX;
            const float ty = (srcBlockStartY + py + kInputViewportOriginY + kShift) * kSrcNormY;
#else
            const float tx = (srcBlockStartX + px + kShift) * kSrcNormX;
            const float ty = (srcBlockStartY + py + kShift) * kSrcNormY;
#endif
            float p[2][2];
#if NIS_TEXTURE_GATHER
            {
                const float4 sr = in_texture.GatherRed(samplerLinearClamp, float2(tx, ty));
                const float4 sg = in_texture.GatherGreen(samplerLinearClamp, float2(tx, ty));
                const float4 sb = in_texture.GatherBlue(samplerLinearClamp, float2(tx, ty));

                p[0][0] = getY(float3(sr.w, sg.w, sb.w));
                p[0][1] = getY(float3(sr.z, sg.z, sb.z));
                p[1][0] = getY(float3(sr.x, sg.x, sb.x));
                p[1][1] = getY(float3(sr.y, sg.y, sb.y));
            }
#else
            $for(j in Range(0, 2))
            {
                $for(k in Range(0, 2))
                {
                    const float4 px_val = in_texture.SampleLevel(samplerLinearClamp, float2(tx + k * kSrcNormX, ty + j * kSrcNormY), 0);
                    p[j][k] = getY(px_val.xyz);
                }
            }
#endif
            const uint idx = py * kTilePitch + px;
            shPixelsY[idx] = p[0][0];
            shPixelsY[idx + 1] = p[0][1];
            shPixelsY[idx + kTilePitch] = p[1][0];
            shPixelsY[idx + kTilePitch + 1] = p[1][1];
        }
    }

    GroupMemoryBarrierWithGroupSync();

    {
        for (uint i = threadIdx * 2; i < uint(numEdgeMapPixels) >> 1; i += NIS_THREAD_GROUP_SIZE * 2)
        {
            uint py = (i / numEdgeMapPixelsX) * 2;
            uint px = i % numEdgeMapPixelsX;

            const uint edgeMapIdx = py * kEdgeMapPitch + px;
            uint tileCornerIdx = (py + 1) * kTilePitch + px + 1;

            float p_arr[4][4];
            $for(j in Range(0, 4))
            {
                $for(k in Range(0, 4))
                {
                    p_arr[j][k] = shPixelsY[tileCornerIdx + j * kTilePitch + k];
                }
            }

#ifdef BG_FP16
            shEdgeMap[edgeMapIdx] = (half4)GetEdgeMap(p_arr, 0, 0);
            shEdgeMap[edgeMapIdx + 1] = (half4)GetEdgeMap(p_arr, 0, 1);
            shEdgeMap[edgeMapIdx + kEdgeMapPitch] = (half4)GetEdgeMap(p_arr, 1, 0);
            shEdgeMap[edgeMapIdx + kEdgeMapPitch + 1] = (half4)GetEdgeMap(p_arr, 1, 1);
#else
            shEdgeMap[edgeMapIdx] = GetEdgeMap(p_arr, 0, 0);
            shEdgeMap[edgeMapIdx + 1] = GetEdgeMap(p_arr, 0, 1);
            shEdgeMap[edgeMapIdx + kEdgeMapPitch] = GetEdgeMap(p_arr, 1, 0);
            shEdgeMap[edgeMapIdx + kEdgeMapPitch + 1] = GetEdgeMap(p_arr, 1, 1);
#endif
        }
    }

    LoadFilterBanksSh(int(threadIdx), coef_scaler, coef_usm);
    GroupMemoryBarrierWithGroupSync();

    const int2 pos = int2(uint(threadIdx) % uint(NIS_BLOCK_WIDTH), uint(threadIdx) / uint(NIS_BLOCK_WIDTH));
    const int dstX = dstBlockX + pos.x;

    const float srcX = (0.5f + dstX) * kScaleX - 0.5f;
    const int px_coord = int(floor(srcX) - srcBlockStartX);
    const float fx = srcX - floor(srcX);
    const int fx_int = int(fx * kPhaseCount);

#if NIS_VIEWPORT_SUPPORT
    if (uint(srcX) > kInputViewportWidth || uint(dstX) > kOutputViewportWidth)
    {
        return;
    }
#endif

    for (int k = 0; k < NIS_BLOCK_WIDTH * NIS_BLOCK_HEIGHT / NIS_THREAD_GROUP_SIZE; ++k)
    {
        const int dstY = dstBlockY + pos.y + k * (NIS_THREAD_GROUP_SIZE / NIS_BLOCK_WIDTH);
        const float srcY = (0.5f + dstY) * kScaleY - 0.5f;

#if NIS_VIEWPORT_SUPPORT
        if (!(uint(srcY) > kInputViewportHeight || uint(dstY) > kOutputViewportHeight))
#endif
        {
            const int py_coord = int(floor(srcY) - srcBlockStartY);
            const float fy = srcY - floor(srcY);
            const int fy_int = int(fy * kPhaseCount);

            const int startEdgeMapIdx = py_coord * kEdgeMapPitch + px_coord;
            float4 edge[2][2];
            $for(i in Range(0, 2))
            {
                $for(j in Range(0, 2))
                {
                    edge[i][j] = shEdgeMap[startEdgeMapIdx + (i * kEdgeMapPitch) + j];
                }
            }
            const float4 w = GetInterpEdgeMap(edge, fx, fy) * NIS_SCALE_INT;

            const int startTileIdx = py_coord * kTilePitch + px_coord;
            float p_arr[6][6];
            {
                $for(i in Range(0, 6))
                {
                    $for(j in Range(0, 6))
                    {
                        p_arr[i][j] = shPixelsY[startTileIdx + i * kTilePitch + j];
                    }
                }
            }

            const float baseWeight = NIS_SCALE_FLOAT - w.x - w.y - w.z - w.w;

            float opY = 0;
            opY += FilterNormal(p_arr, fx_int, fy_int) * baseWeight;
            opY += AddDirFilters(p_arr, fx, fy, fx_int, fy_int, w);

#if NIS_VIEWPORT_SUPPORT
            float2 coord = float2((srcX + kInputViewportOriginX + 0.5f) * kSrcNormX, (srcY + kInputViewportOriginY + 0.5f) * kSrcNormY);
            float2 dstCoord = float2(dstX + kOutputViewportOriginX, dstY + kOutputViewportOriginY);
#else
            float2 coord = float2((srcX + 0.5f) * kSrcNormX, (srcY + 0.5f) * kSrcNormY);
            float2 dstCoord = float2(dstX, dstY);
#endif

            float4 op = in_texture.SampleLevel(samplerLinearClamp, coord, 0);
            float y = getY(float3(op.x, op.y, op.z));

#if NIS_HDR_MODE == NIS_HDR_MODE_LINEAR
            const float kEps_hdr = 1e-4f;
            const float kNorm = 1.0f / (NIS_SCALE_FLOAT * kHDRCompressionFactor);
            const float opYN = max(opY, 0.0f) * kNorm;
            const float corr = (opYN * opYN + kEps_hdr) / (max(getYLinear(float3(op.x, op.y, op.z)), 0.0f) + kEps_hdr);
            op.x *= corr;
            op.y *= corr;
            op.z *= corr;
#else
            const float corr = opY * (1.0f / NIS_SCALE_FLOAT) - y;
            op.x += corr;
            op.y += corr;
            op.z += corr;
#endif
            out_texture[int2(dstCoord)] = float4(NVCLAMP(op).xyz, 1.0);
        }
    }
}

#else

#ifndef NIS_BLOCK_WIDTH
#define NIS_BLOCK_WIDTH 32
#endif

#ifndef NIS_BLOCK_HEIGHT
#define NIS_BLOCK_HEIGHT 32
#endif

#ifndef NIS_THREAD_GROUP_SIZE
#define NIS_THREAD_GROUP_SIZE 256
#endif

#define kSupportSize 5
#define kNumPixelsX  (NIS_BLOCK_WIDTH + kSupportSize + 1)
#define kNumPixelsY  (NIS_BLOCK_HEIGHT + kSupportSize + 1)

groupshared float shPixelsY[kNumPixelsY][kNumPixelsX];

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
    const float sharpnessStrength = scaleY * kSharpStrengthScale + kSharpStrengthMin;
    const float sharpnessLimit = (scaleY * kSharpLimitScale + kSharpLimitMin) * p[2][2];

    float4 rval;

    float interp0Deg[5];
    $for(i in Range(0, 5))
    {
        interp0Deg[i] = p[i][2];
    }
    rval.x = EvalUSM(interp0Deg, sharpnessStrength, sharpnessLimit);

    float interp90Deg[5];
    $for(i in Range(0, 5))
    {
        interp90Deg[i] = p[2][i];
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

void NVSharpen(uint2 blockIdx, uint threadIdx,
    Texture2D in_texture,
    RWTexture2D<float4> out_texture,
    SamplerState samplerLinearClamp,
    float kSrcNormX, float kSrcNormY)
{
    const int dstBlockX = int(NIS_BLOCK_WIDTH * blockIdx.x);
    const int dstBlockY = int(NIS_BLOCK_HEIGHT * blockIdx.y);

    const float kShift = 0.5f - kSupportSize / 2;

    for (int i = int(threadIdx) * 2; i < kNumPixelsX * kNumPixelsY / 2; i += NIS_THREAD_GROUP_SIZE * 2)
    {
        uint2 pos = uint2(uint(i) % uint(kNumPixelsX), uint(i) / uint(kNumPixelsX) * 2);
        $for(dy in Range(0, 2))
        {
            $for(dx in Range(0, 2))
            {
#if NIS_VIEWPORT_SUPPORT
                const float tx = (dstBlockX + pos.x + kInputViewportOriginX + dx + kShift) * kSrcNormX;
                const float ty = (dstBlockY + pos.y + kInputViewportOriginY + dy + kShift) * kSrcNormY;
#else
                const float tx = (dstBlockX + pos.x + dx + kShift) * kSrcNormX;
                const float ty = (dstBlockY + pos.y + dy + kShift) * kSrcNormY;
#endif
                const float4 px_val = in_texture.SampleLevel(samplerLinearClamp, float2(tx, ty), 0);
                shPixelsY[pos.y + dy][pos.x + dx] = getY(px_val.xyz);
            }
        }
    }

    GroupMemoryBarrierWithGroupSync();

    for (int k = int(threadIdx); k < NIS_BLOCK_WIDTH * NIS_BLOCK_HEIGHT; k += NIS_THREAD_GROUP_SIZE)
    {
        const int2 pos = int2(uint(k) % uint(NIS_BLOCK_WIDTH), uint(k) / uint(NIS_BLOCK_WIDTH));

        float p[5][5];
        $for(i in Range(0, 5))
        {
            $for(j in Range(0, 5))
            {
                p[i][j] = shPixelsY[pos.y + i][pos.x + j];
            }
        }

        float4 dirUSM = GetDirUSM(p);

        float4 w = GetEdgeMap(p, kSupportSize / 2 - 1, kSupportSize / 2 - 1);

        const float usmY = (dirUSM.x * w.x + dirUSM.y * w.y + dirUSM.z * w.z + dirUSM.w * w.w);

        const int dstX = dstBlockX + pos.x;
        const int dstY = dstBlockY + pos.y;

#if NIS_VIEWPORT_SUPPORT
        float2 coord = float2((dstX + kInputViewportOriginX + 0.5f) * kSrcNormX, (dstY + kInputViewportOriginY + 0.5f) * kSrcNormY);
        float2 dstCoord = float2(dstX + kOutputViewportOriginX, dstY + kOutputViewportOriginY);
        if (!(uint(dstX) > kOutputViewportWidth || uint(dstY) > kOutputViewportHeight))
#else
        float2 coord = float2((dstX + 0.5f) * kSrcNormX, (dstY + 0.5f) * kSrcNormY);
        float2 dstCoord = float2(dstX, dstY);
#endif
        {
            float4 op = in_texture.SampleLevel(samplerLinearClamp, coord, 0);

#if NIS_HDR_MODE == NIS_HDR_MODE_LINEAR
            const float kEps_hdr = 1e-4f * kHDRCompressionFactor * kHDRCompressionFactor;
            float newY = p[2][2] + usmY;
            newY = max(newY, 0.0f);
            const float oldY = p[2][2];
            const float corr = (newY * newY + kEps_hdr) / (oldY * oldY + kEps_hdr);
            op.x *= corr;
            op.y *= corr;
            op.z *= corr;
#else
            op.x += usmY;
            op.y += usmY;
            op.z += usmY;
#endif
            out_texture[int2(dstCoord)] = float4(NVCLAMP(op).xyz, 1.0);
        }
    }
}

#endif

#endif
