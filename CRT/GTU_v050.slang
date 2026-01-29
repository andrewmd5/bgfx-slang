// GTU v050
// Author: aliaspider - aliaspider@gmail.com (GPLv3 License)
// Ported from https://github.com/libretro/common-shaders/tree/master/crt/shaders/gtu-v050
// Gaussian TV Upscaler with NTSC color simulation

import bgfx;

struct GTUParams
{
    [bgfx::PARAM_INT("Composite Connection", 0, 0, 1, "Enable composite video signal simulation with color bleeding")]
    int compositeConnection;

    [bgfx::PARAM_INT("No Scanlines", 0, 0, 1, "Disable scanline effect for cleaner output")]
    int noScanlines;

    [bgfx::PARAM_INT("Signal Resolution Y", 256, 16, 1024, "Horizontal luminance resolution in TV lines")]
    int signalResolution;

    [bgfx::PARAM_INT("Signal Resolution I", 83, 1, 350, "Horizontal resolution of I chrominance channel (NTSC)")]
    int signalResolutionI;

    [bgfx::PARAM_INT("Signal Resolution Q", 25, 1, 350, "Horizontal resolution of Q chrominance channel (NTSC)")]
    int signalResolutionQ;

    [bgfx::PARAM_INT("TV Vertical Resolution", 250, 20, 1000, "Vertical resolution in TV lines")]
    int tvVerticalResolution;

    [bgfx::PARAM("Black Level", 0.07, -0.3, 0.3, "Adjusts the black level (brightness floor)")]
    float blackLevel;

    [bgfx::PARAM("Contrast", 1.0, 0.0, 2.0, "Output contrast adjustment")]
    float contrast;
};

ConstantBuffer<GTUParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

// Intermediate texture for horizontal pass
[bgfx::SIZE("OUTPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex1;
[format("rgba16f")]
RWTexture2D<float4> tex1_UAV;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

// Color space conversion matrices
#define RGB_to_YIQ transpose(float3x3(0.299, 0.595716, 0.211456, 0.587, -0.274453, -0.522591, 0.114, -0.321263, 0.311135))
#define YIQ_to_RGB transpose(float3x3(1.0, 1.0, 1.0, 0.9563, -0.2721, -1.1070, 0.6210, -0.6474, 1.7046))
#define pi 3.14159265358

float d(float x, float b)
{
    return pi * b * min(abs(x) + 0.5, 1.0 / b);
}

float e(float x, float b)
{
    return (pi * b * min(max(abs(x) - 0.5, -1.0 / b), 1.0 / b));
}

float STU(float x, float b)
{
    return ((d(x, b) + sin(d(x, b)) - e(x, b) - sin(e(x, b))) / (2.0 * pi));
}

[bgfx::EFFECT("GTU v050", 2)]
[bgfx::CATEGORY("CRT")]
[bgfx::DESCRIPTION("Gaussian TV Upscaler v0.50 - Simulates analog TV signal processing with optional composite video artifacts, NTSC color space conversion, and authentic scanline rendering.")]
[bgfx::PASS(1, "Horizontal filtering")]
[bgfx::PASS_IO("INPUT", "tex1_UAV")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 tex1Size = uint2(GetOutputSize().x, GetInputSize().y);
    if (tid.x >= tex1Size.x || tid.y >= tex1Size.y)
        return;

    float2 inputSize = GetInputSize();
    float2 inputPt = GetInputPt();
    float2 pos = (tid.xy + 0.5) / float2(tex1Size);

    float offset = frac((pos.x * inputSize.x) - 0.5);
    float3 tempColor = 0;
    float X;
    float3 c;
    float range;
    float i;

    if (params.compositeConnection)
    {
        range = ceil(0.5 + inputSize.x / min(min(params.signalResolution, params.signalResolutionI), params.signalResolutionQ));

        for (i = -range; i < range + 2.0; i++)
        {
            X = (offset - (i));
            c = INPUT.SampleLevel(sam, float2(pos.x - X * inputPt.x, pos.y), 0).rgb;
            c = mul(RGB_to_YIQ, c);
            tempColor += float3(
                (c.x * STU(X, (params.signalResolution * inputPt.x))),
                (c.y * STU(X, (params.signalResolutionI * inputPt.x))),
                (c.z * STU(X, (params.signalResolutionQ * inputPt.x))));
        }

        tempColor = clamp(mul(YIQ_to_RGB, tempColor), 0.0, 1.0);
    }
    else
    {
        range = ceil(0.5 + inputSize.x / params.signalResolution);

        for (i = -range; i < range + 2.0; i++)
        {
            X = (offset - (i));
            c = INPUT.SampleLevel(sam, float2(pos.x - X * inputPt.x, pos.y), 0).rgb;
            tempColor += (c * STU(X, (params.signalResolution * inputPt.x)));
        }

        tempColor = clamp(tempColor, 0.0, 1.0);
    }

    tex1_UAV[tid.xy] = float4(tempColor, 1.0);
}

#define normalGauss(x) ((exp(-(x) * (x) * 0.5)) / sqrt(2.0 * pi))

float normalGaussIntegral(float x)
{
    float a1 = 0.4361836;
    float a2 = -0.1201676;
    float a3 = 0.9372980;
    float p = 0.3326700;
    float t = 1.0 / (1.0 + p * abs(x));
    return (0.5 - normalGauss(x) * (t * (a1 + t * (a2 + a3 * t)))) * sign(x);
}

float3 scanlines(float x, float3 c)
{
    float inputHeight = GetInputSize().y;
    float inputPtY = GetInputPt().y;
    float outputHeight = GetOutputSize().y;
    float outputPtY = GetOutputPt().y;

    float temp = sqrt(2 * pi) * (params.tvVerticalResolution * inputPtY);

    float rrr = 0.5 * (inputHeight * outputPtY);
    float x1 = (x + rrr) * temp;
    float x2 = (x - rrr) * temp;
    c.r = (c.r * (normalGaussIntegral(x1) - normalGaussIntegral(x2)));
    c.g = (c.g * (normalGaussIntegral(x1) - normalGaussIntegral(x2)));
    c.b = (c.b * (normalGaussIntegral(x1) - normalGaussIntegral(x2)));
    c *= GetScale().y;
    return c;
}

[bgfx::PASS(2, "Vertical filtering and scanlines")]
[bgfx::PASS_IO("tex1", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid: SV_DispatchThreadID)
{
    if (!IsInBounds(tid))
        return;

    uint2 inputSize = GetInputSize();
    float2 inputPt = GetInputPt();
    float2 pos = GetOutputUV(tid);

    float2 offset = frac((pos * uint2(GetOutputSize().x, inputSize.y)) - 0.5);
    float3 tempColor = 0;
    float3 Cj;

    float range = ceil(0.5 + inputSize.y / params.tvVerticalResolution);

    float i;

    if (params.noScanlines)
    {
        for (i = -range; i < range + 2.0; i++)
        {
            Cj = tex1.SampleLevel(sam, float2(pos.x, pos.y - (offset.y - (i)) * inputPt.y), 0).xyz;
            tempColor += Cj * STU(offset.y - (i), (params.tvVerticalResolution * inputPt.y));
        }
    }
    else
    {
        for (i = -range; i < range + 2.0; i++)
        {
            Cj = tex1.SampleLevel(sam, float2(pos.x, pos.y - (offset.y - (i)) * inputPt.y), 0).xyz;
            tempColor += scanlines(offset.y - (i), Cj);
        }
    }

    tempColor -= params.blackLevel;
    tempColor *= params.contrast / (1.0 - params.blackLevel);

    OUTPUT[tid.xy] = float4(tempColor, 1.0);
}
