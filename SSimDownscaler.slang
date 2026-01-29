// SSIM Downscaler
// Based on perceptual downscaling algorithm by igv
// https://gist.github.com/igv/36508af3ffc84410fe39761d6969be10

import bgfx;

struct SSimDownscalerParams
{
    [bgfx::PARAM("Oversharp", 1, 1, 3, "Controls sharpening intensity. Higher values are sharper but may ring.")]
    float oversharp;
};
ConstantBuffer<SSimDownscalerParams> params : register(b2);

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SIZE("INPUT_WIDTH", "OUTPUT_HEIGHT")]
[format("rgba16f")]
Texture2D texL2;
[format("rgba16f")]
RWTexture2D<float4> texL2_UAV;

[bgfx::SIZE("OUTPUT_WIDTH", "OUTPUT_HEIGHT")]
[format("rgba16f")]
Texture2D texL2_2;
[format("rgba16f")]
RWTexture2D<float4> texL2_2_UAV;

[bgfx::SIZE("OUTPUT_WIDTH", "OUTPUT_HEIGHT")]
[format("rgba16f")]
Texture2D texMR;
[format("rgba16f")]
RWTexture2D<float4> texMR_UAV;

[bgfx::SIZE("OUTPUT_WIDTH", "OUTPUT_HEIGHT")]
[format("rgba8")]
Texture2D texPostKernel;
[format("rgba8")]
RWTexture2D<float4> texPostKernel_UAV;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState samLinear;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState samPoint;

[bgfx::EFFECT("SSIM Downscaler", 2)]
[bgfx::CATEGORY("Scaling")]
[bgfx::DESCRIPTION("Perceptually-aware downscaling that preserves structural similarity and detail.")]
[bgfx::PASS(1, "CatmullRom Downscale")]
[bgfx::PASS_IO("INPUT", "texPostKernel_UAV")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 pos = GetOutputUV(tid);
    float2 inputSize = GetInputSize();
    float2 inputPt = GetInputPt();

    float2 samplePos = pos * inputSize;
    float2 texPos1 = floor(samplePos - 0.5f) + 0.5f;
    float2 f = samplePos - texPos1;

    float2 w0 = f * (-0.5f + f * (1.0f - 0.5f * f));
    float2 w1 = 1.0f + f * f * (-2.5f + 1.5f * f);
    float2 w2 = f * (0.5f + f * (2.0f - 1.5f * f));
    float2 w3 = f * f * (-0.5f + 0.5f * f);

    float2 w12 = w1 + w2;
    float2 offset12 = w2 / (w1 + w2);

    float2 texPos0 = (texPos1 - 1) * inputPt;
    float2 texPos3 = (texPos1 + 2) * inputPt;
    float2 texPos12 = (texPos1 + offset12) * inputPt;

    float4 result = 0.0f;
    result += INPUT.SampleLevel(samLinear, float2(texPos0.x, texPos0.y), 0) * w0.x * w0.y;
    result += INPUT.SampleLevel(samLinear, float2(texPos12.x, texPos0.y), 0) * w12.x * w0.y;
    result += INPUT.SampleLevel(samLinear, float2(texPos3.x, texPos0.y), 0) * w3.x * w0.y;
    result += INPUT.SampleLevel(samLinear, float2(texPos0.x, texPos12.y), 0) * w0.x * w12.y;
    result += INPUT.SampleLevel(samLinear, float2(texPos12.x, texPos12.y), 0) * w12.x * w12.y;
    result += INPUT.SampleLevel(samLinear, float2(texPos3.x, texPos12.y), 0) * w3.x * w12.y;
    result += INPUT.SampleLevel(samLinear, float2(texPos0.x, texPos3.y), 0) * w0.x * w3.y;
    result += INPUT.SampleLevel(samLinear, float2(texPos12.x, texPos3.y), 0) * w12.x * w3.y;
    result += INPUT.SampleLevel(samLinear, float2(texPos3.x, texPos3.y), 0) * w3.x * w3.y;

    texPostKernel_UAV[tid.xy] = result;
}

#define MN(B, C, x) (x < 1.0 ? ((2. - 1.5 * B - (C)) * x + (-3. + 2. * B + C)) * x * x + (1. - (B) / 3.) : (((-(B) / 6. - (C)) * x + (B + 5. * C)) * x + (-2. * B - 8. * C)) * x + ((4. / 3.) * B + 4. * C))
#define Kernel2(x) MN(0.0f, 0.5f, abs(x))

[bgfx::PASS(2, "L2 Vertical Pass")]
[bgfx::PASS_IO("INPUT", "texL2_UAV")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid: SV_DispatchThreadID)
{
    uint texL2Width = GetInputSize().x;
    uint texL2Height = GetOutputSize().y;
    if (tid.x >= texL2Width || tid.y >= texL2Height)
        return;

    float2 pos = (float2(tid.xy) + 0.5) / float2(texL2Width, texL2Height);

    float inputPtY = GetInputPt().y;
    uint inputHeight = GetInputSize().y;
    float outputPtY = GetOutputPt().y;
    uint outputHeight = GetOutputSize().y;

    int low = (int)ceil((pos.y - 2.0f * outputPtY) * inputHeight - 0.5f);
    int high = (int)floor((pos.y + 2.0f * outputPtY) * inputHeight - 0.5f);

    float W = 0;
    float3 avg = 0;

    for (int k = low; k <= high; k++)
    {
        float2 samplePos = float2(pos.x, inputPtY * (k + 0.5f));
        float rel = (samplePos.y - pos.y) * outputHeight;
        float w = Kernel2(rel);

        float3 tex = INPUT.SampleLevel(samPoint, samplePos, 0).rgb;
        avg += w * tex * tex;
        W += w;
    }
    avg /= max(W, 0.0001);

    texL2_UAV[tid.xy] = float4(avg, 1);
}

#define Kernel3(x) MN(0.0f, 0.5f, abs(x))

[bgfx::PASS(3, "L2 Horizontal Pass")]
[bgfx::PASS_IO("texL2", "texL2_2_UAV")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass3(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    uint texL2Width = GetInputSize().x;
    uint texL2Height = GetOutputSize().y;
    float2 texL2Pt = 1.0 / float2(texL2Width, texL2Height);

    float outputPtX = GetOutputPt().x;
    uint outputWidth = GetOutputSize().x;

    float posX = (float(tid.x) + 0.5) / float(outputWidth);

    int low = (int)ceil((posX - 2.0f * outputPtX) * texL2Width - 0.5f);
    int high = (int)floor((posX + 2.0f * outputPtX) * texL2Width - 0.5f);

    float W = 0;
    float3 avg = 0;

    float texL2Y = (float(tid.y) + 0.5) / float(texL2Height);

    for (int k = low; k <= high; k++)
    {
        int sampleX = clamp(k, 0, (int)texL2Width - 1);
        float rel = ((float(sampleX) + 0.5f) / texL2Width - posX) * outputWidth;
        float w = Kernel3(rel);

        float2 sampleUV = float2((float(sampleX) + 0.5) * texL2Pt.x, texL2Y);
        avg += w * texL2.SampleLevel(samPoint, sampleUV, 0).rgb;
        W += w;
    }
    avg /= max(W, 0.0001);

    texL2_2_UAV[tid.xy] = float4(avg, 1);
}

#define sigma_nsq (10.0 / (255.0 * 255.0))
#define locality4 2.0
#define Luma4(rgb) dot(rgb, float3(0.2126, 0.7152, 0.0722))
#define Kernel4(x) pow(1.0 / locality4, abs(float(x)))
#define taps4 3

[bgfx::PASS(4, "Mean and R Calculation")]
[bgfx::PASS_IO("texL2_2, texPostKernel", "texMR_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass4(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 outputPt = GetOutputPt();

    float3 src1[taps4 + 1][taps4 + 1];
    float3 src2[taps4 + 1][taps4 + 1];

    // taps4 = 3, so we need i = 0, 2 -> Range(0, 2) with i = ii * 2
    $for(ii in Range(0, 2))
    {
        int i = ii * 2;
        $for(jj in Range(0, 2))
        {
            int j = jj * 2;
            float2 tpos = (int2(gxy + uint2(i, j)) - taps4 / 2 + 1) * outputPt;
            float4 sr = texPostKernel.GatherRed(samPoint, tpos);
            float4 sg = texPostKernel.GatherGreen(samPoint, tpos);
            float4 sb = texPostKernel.GatherBlue(samPoint, tpos);

            src1[i][j] = float3(sr.w, sg.w, sb.w);
            src1[i][j + 1] = float3(sr.x, sg.x, sb.x);
            src1[i + 1][j] = float3(sr.z, sg.z, sb.z);
            src1[i + 1][j + 1] = float3(sr.y, sg.y, sb.y);

            sr = texL2_2.GatherRed(samPoint, tpos);
            sg = texL2_2.GatherGreen(samPoint, tpos);
            sb = texL2_2.GatherBlue(samPoint, tpos);

            src2[i][j] = float3(sr.w, sg.w, sb.w);
            src2[i][j + 1] = float3(sr.x, sg.x, sb.x);
            src2[i + 1][j] = float3(sr.z, sg.z, sb.z);
            src2[i + 1][j + 1] = float3(sr.y, sg.y, sb.y);
        }
    }

    float kernels4[taps4];
    $for(i in Range(0, taps4))
    {
        kernels4[i] = Kernel4((int)i - taps4 / 2);
    }

    $for(i in Range(0, 2))
    {
        $for(j in Range(0, 2))
        {
            uint2 destPos = gxy + uint2(i, j);

            bool shouldProcess = true;
            if (i != 0 || j != 0)
            {
                if (destPos.x >= outputSize.x || destPos.y >= outputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                float W = 0.0;
                float3x3 avg = 0;

                $for(i1 in Range(0, taps4))
                {
                    float W1 = 0;
                    float3x3 avg1 = 0;

                    $for(j1 in Range(0, taps4))
                    {
                        float3 L = src1[j1 + i][i1 + j];
                        avg1 += kernels4[j1] * float3x3(L, L * L, src2[j1 + i][i1 + j]);
                        W1 += kernels4[j1];
                    }
                    avg1 /= W1;

                    avg += kernels4[i1] * avg1;
                    W += kernels4[i1];
                }
                avg /= W;

                float Sl = Luma4(max(avg[1] - avg[0] * avg[0], 0.));
                float Sh = Luma4(max(avg[2] - avg[0] * avg[0], 0.));
                texMR_UAV[destPos] = float4(avg[0], lerp(sqrt((Sh + sigma_nsq) / (Sl + sigma_nsq)) * params.oversharp, clamp(Sh / Sl, 0., 1.), int(Sl > Sh)));
            }
        }
    }
}

#define locality5 2.0f
#define Kernel5(x) pow(1.0f / locality5, abs(float(x)))
#define taps5 3

[bgfx::PASS(5, "Final Output")]
[bgfx::PASS_IO("texMR, texPostKernel", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass5(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }
    float2 outputPt = GetOutputPt();

    float4 src1[taps5 + 1][taps5 + 1];
    // taps5 = 3, so we need i = 0, 2 -> Range(0, 2) with i = ii * 2
    $for(ii in Range(0, 2))
    {
        int i = ii * 2;
        $for(jj in Range(0, 2))
        {
            int j = jj * 2;
            float2 tpos = (int2(gxy + uint2(i, j)) - taps5 / 2 + 1) * outputPt;
            float4 sr = texMR.GatherRed(samPoint, tpos);
            float4 sg = texMR.GatherGreen(samPoint, tpos);
            float4 sb = texMR.GatherBlue(samPoint, tpos);
            float4 sa = texMR.GatherAlpha(samPoint, tpos);
            src1[i][j] = float4(sr.w, sg.w, sb.w, sa.w);
            src1[i][j + 1] = float4(sr.x, sg.x, sb.x, sa.x);
            src1[i + 1][j] = float4(sr.z, sg.z, sb.z, sa.z);
            src1[i + 1][j + 1] = float4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    float3 src2[2][2];
    float2 tpos = (gxy + 1) * outputPt;
    float4 sr = texPostKernel.GatherRed(samPoint, tpos);
    float4 sg = texPostKernel.GatherGreen(samPoint, tpos);
    float4 sb = texPostKernel.GatherBlue(samPoint, tpos);
    src2[0][0] = float3(sr.w, sg.w, sb.w);
    src2[0][1] = float3(sr.x, sg.x, sb.x);
    src2[1][0] = float3(sr.z, sg.z, sb.z);
    src2[1][1] = float3(sr.y, sg.y, sb.y);

    float kernels5[taps5];
    $for(i in Range(0, taps5))
    {
        kernels5[i] = Kernel5((int)i - taps5 / 2);
    }

    $for(i in Range(0, 2))
    {
        $for(j in Range(0, 2))
        {
            uint2 destPos = gxy + uint2(i, j);
            float W = 0;
            float3x3 avg = 0;

            $for(i1 in Range(0, taps5))
            {
                float W1 = 0;
                float3x3 avg1 = 0;

                $for(j1 in Range(0, taps5))
                {
                    float4 MRc = src1[j1 + i][i1 + j];
                    avg1 += kernels5[j1] * float3x3(MRc.a * MRc.rgb, MRc.rgb, MRc.aaa);
                    W1 += kernels5[j1];
                }
                avg1 /= W1;

                avg += kernels5[i1] * avg1;
                W += kernels5[i1];
            }
            avg /= W;

            OUTPUT[destPos] = float4(avg[1] + avg[2] * src2[i][j] - avg[0], 1);
        }
    }
}
