// NVIDIA Image Scaling - Upscaler
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

import bgfx;

struct EffectParams
{
    [bgfx::PARAM("Sharpness", 0.5, 0.0, 1.0, "Controls the strength of the sharpening effect during upscaling. Higher values produce sharper edges.")]
    float sharpness;
};

ConstantBuffer<EffectParams> params : register(b2);

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SOURCE("Coef_Scale.dds")]
[format("rgba16f")]
Texture2D coef_scaler;

[bgfx::SOURCE("Coef_USM.dds")]
[format("rgba16f")]
Texture2D coef_usm;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState samplerLinearClamp;

#define NIS_SCALER 1
#define NIS_TEXTURE_GATHER 1

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

#define NIS_BLOCK_WIDTH 32
#define NIS_BLOCK_HEIGHT 24
#define NIS_THREAD_GROUP_SIZE 256

#include "NIS_Scaler.h"

[bgfx::EFFECT("NVIDIA Image Scaling (Upscaler)", 2)]
[bgfx::CATEGORY("Upscaling")]
[bgfx::DESCRIPTION("NVIDIA directional scaling algorithm with adaptive sharpening. Uses 6-tap filters with edge-aware processing for high quality upscaling.")]
[bgfx::FP16]
[bgfx::PASS(1, "NIS Upscale")]
[bgfx::PASS_IO("INPUT, coef_scaler, coef_usm", "OUTPUT")]
[bgfx::BLOCK_SIZE(32, 24)]
[shader("compute")]
[numthreads(256, 1, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID, uint3 gid: SV_GroupID, uint3 gtid: SV_GroupThreadID)
{
    uint2 blockIdx = gid.xy;
    uint threadIdx = gtid.x;

    float2 scale = GetScale();
    float kScaleX = 1.0 / scale.x;
    float kScaleY = 1.0 / scale.y;
    float2 inputPt = GetInputPt();
    float kSrcNormX = inputPt.x;
    float kSrcNormY = inputPt.y;

    float sharpen_slider = params.sharpness - 0.5f;
    float MinScale = (sharpen_slider >= 0.0f) ? 1.25f : 1.0f;
    float MaxScale = (sharpen_slider >= 0.0f) ? 1.25f : 1.75f;
    float kSharpStrengthMin = max(0.0f, 0.4f + sharpen_slider * MinScale * 1.2f);
    float kSharpStrengthMax = 1.6f + sharpen_slider * MaxScale * 1.8f;
    float kSharpStrengthScale = kSharpStrengthMax - kSharpStrengthMin;
    float LimitScale = (sharpen_slider >= 0.0f) ? 1.25f : 1.0f;
    float kSharpLimitMin = max(0.1f, 0.14f + sharpen_slider * LimitScale * 0.32f);
    float kSharpLimitMax = 0.5f + sharpen_slider * LimitScale * 0.6f;
    float kSharpLimitScale = kSharpLimitMax - kSharpLimitMin;

    NVScaler(blockIdx, threadIdx,
             INPUT, OUTPUT,
             coef_scaler, coef_usm,
             samplerLinearClamp,
             kScaleX, kScaleY,
             kSrcNormX, kSrcNormY,
             kSharpStrengthMin, kSharpStrengthScale,
             kSharpLimitMin, kSharpLimitScale);
}
