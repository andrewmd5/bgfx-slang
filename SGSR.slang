// Snapdragon Game Super Resolution (SGSR)
// High-quality edge-aware upscaling algorithm
// Based on Qualcomm's Snapdragon GSR
// Ported from https://github.com/SnapdragonStudios/snapdragon-gsr

import bgfx;

struct SGSRParams
{
    [bgfx::PARAM("Edge Sharpness", 2.0, 0.0, 10.0, "Controls the sharpening strength applied along detected edges. Higher values produce sharper edges.")]
    float edgeSharpness;

    [bgfx::PARAM("Edge Threshold", 8.0, 0.0, 16.0, "Minimum edge detection threshold. Lower values detect more edges but may introduce artifacts.")]
    float edgeThreshold;
};
ConstantBuffer<SGSRParams> params : register(b2);

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

#define UseEdgeDirection

// Fast Lanczos2 approximation
float fastLanczos2(float x)
{
    float wA = x - float(4.0);
    float wB = x * wA - wA;
    wA *= wA;
    return wB * wA;
}

// Calculate weight for Y channel sampling
#if defined(UseEdgeDirection)
float2 weightY(float dx, float dy, float c, float3 data)
#else
float2 weightY(float dx, float dy, float c, float data)
#endif
{
#if defined(UseEdgeDirection)
    float std = data.x;
    float2 dir = data.yz;
    float edgeDis = ((dx * dir.y) + (dy * dir.x));
    float x = (((dx * dx) + (dy * dy)) + ((edgeDis * edgeDis) * ((clamp(((c * c) * std), 0.0, 1.0) * 0.7) + -1.0)));
#else
    float std = data;
    float x = ((dx * dx) + (dy * dy)) * float(0.5) + clamp(abs(c) * std, 0.0, 1.0);
#endif

    float w = fastLanczos2(x);
    return float2(w, w * c);
}

// Calculate edge direction from neighboring samples
float2 edgeDirection(float4 left, float4 right)
{
    float2 dir;
    float RxLz = (right.x + (-left.z));
    float RwLy = (right.w + (-left.y));
    float2 delta;
    delta.x = (RxLz + RwLy);
    delta.y = (RxLz + (-RwLy));
    float lengthInv = rsqrt((delta.x * delta.x + 3.075740e-05) + (delta.y * delta.y));
    dir.x = (delta.x * lengthInv);
    dir.y = (delta.y * lengthInv);
    return dir;
}

// Helper functions for texture sampling
float4 GatherGreen(float2 p)
{
    return INPUT.GatherGreen(sam, p);
}

float4 SampleRGBA(float2 p)
{
    return INPUT.SampleLevel(sam, p, 0);
}

// Main SGSR algorithm
float3 SgsrProcess(float2 uv, float4 viewportInfo)
{
    float3 pix;
    float thresholdNorm = params.edgeThreshold / 255.0;
    float sharpness = params.edgeSharpness;

    pix = SampleRGBA(uv).xyz;

    float xCenter = abs(uv.x - 0.5);
    float yCenter = abs(uv.y - 0.5);

    float2 imgCoord = ((uv.xy * viewportInfo.zw) + float2(-0.5, 0.5));
    float2 imgCoordPixel = floor(imgCoord);
    float2 coord = (imgCoordPixel * viewportInfo.xy);
    float2 pl = (imgCoord + (-imgCoordPixel));
    float4 left = GatherGreen(coord);

    float edgeVote = abs(left.z - left.y) + abs(pix[1] - left.y) + abs(pix[1] - left.z);

    if (edgeVote > thresholdNorm)
    {
        coord.x += viewportInfo.x;

        float4 right = GatherGreen(coord + float2(viewportInfo.x, 0.0));
        float4 upDown;
        upDown.xy = GatherGreen(coord + float2(0.0, -viewportInfo.y)).wz;
        upDown.zw = GatherGreen(coord + float2(0.0, viewportInfo.y)).yx;

        float mean = (left.y + left.z + right.x + right.w) * float(0.25);
        left = left - float4(mean, mean, mean, mean);
        right = right - float4(mean, mean, mean, mean);
        upDown = upDown - float4(mean, mean, mean, mean);
        float pix_G = pix[1] - mean;

        float sum = (((((abs(left.x) + abs(left.y)) + abs(left.z)) + abs(left.w)) +
                      (((abs(right.x) + abs(right.y)) + abs(right.z)) + abs(right.w))) +
                     (((abs(upDown.x) + abs(upDown.y)) + abs(upDown.z)) + abs(upDown.w)));
        float sumMean = 1.014185e+01 / sum;
        float std = (sumMean * sumMean);

#if defined(UseEdgeDirection)
        float3 data = float3(std, edgeDirection(left, right));
#else
        float data = std;
#endif

        float2 aWY = weightY(pl.x, pl.y + 1.0, upDown.x, data);
        aWY += weightY(pl.x - 1.0, pl.y + 1.0, upDown.y, data);
        aWY += weightY(pl.x - 1.0, pl.y - 2.0, upDown.z, data);
        aWY += weightY(pl.x, pl.y - 2.0, upDown.w, data);
        aWY += weightY(pl.x + 1.0, pl.y - 1.0, left.x, data);
        aWY += weightY(pl.x, pl.y - 1.0, left.y, data);
        aWY += weightY(pl.x, pl.y, left.z, data);
        aWY += weightY(pl.x + 1.0, pl.y, left.w, data);
        aWY += weightY(pl.x - 1.0, pl.y - 1.0, right.x, data);
        aWY += weightY(pl.x - 2.0, pl.y - 1.0, right.y, data);
        aWY += weightY(pl.x - 2.0, pl.y, right.z, data);
        aWY += weightY(pl.x - 1.0, pl.y, right.w, data);

        float finalY = aWY.y / aWY.x;

        float max4 = max(max(left.y, left.z), max(right.x, right.w));
        float min4 = min(min(left.y, left.z), min(right.x, right.w));
        finalY = clamp(sharpness * finalY, min4, max4);

        float deltaY = finalY - pix_G;
        pix = saturate(pix + deltaY);
    }

    return pix;
}

[bgfx::EFFECT("Snapdragon GSR", 2)]
[bgfx::CATEGORY("Upscaling")]
[bgfx::DESCRIPTION("Qualcomm Snapdragon Game Super Resolution algorithm. Provides high-quality upscaling with edge-aware sharpening using directional filtering for crisp results with minimal artifacts.")]
[bgfx::PASS(1, "SGSR")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    float2 texCoord = GetOutputUV(tid);
    float2 inputSize = GetInputSize();
    float2 inputPt = GetInputPt();
    float4 viewportInfo = float4(inputPt.x, inputPt.y, inputSize.x, inputSize.y);

    OUTPUT[tid.xy] = float4(SgsrProcess(texCoord, viewportInfo), 1);
}
