// Anime4K Thin HQ
// Based on Anime4K project by bloc97

import bgfx;

struct EffectParams
{
    [bgfx::PARAM("Strength", 0.6, 0.1, 10.0, "Strength of warping for each iteration.")]
    float strength;

    [bgfx::PARAM_INT("Iterations", 1, 1, 10, "Number of iterations for the forwards solver. Decreasing strength and increasing iterations improves quality at the cost of speed.")]
    int iterations;
};

ConstantBuffer<EffectParams> params : register(b2);

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam1;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rg16f")]
Texture2D tex1;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rg16f")]
RWTexture2D<float4> tex1_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rg16f")]
Texture2D tex2;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rg16f")]
RWTexture2D<float4> tex2_UAV;

float GetLuma(float3 rgb)
{
    return dot(float3(0.299, 0.587, 0.114), rgb);
}

float Gaussian(float x, float s, float m)
{
    float scaled = (x - m) / s;
    return exp(-0.5 * scaled * scaled);
}

float2 IterativeWarp(Texture2D gradTex, SamplerState s, float2 pos, float2 inputPt, float relstr, int iterations)
{
    for (int iter = 0; iter < iterations; ++iter)
    {
        float2 dn = gradTex.SampleLevel(s, pos, 0).xy;
        float2 dd = (dn / (length(dn) + 0.01f)) * inputPt * relstr;
        pos -= dd;
    }
    return pos;
}

float GaussianBlur1D(Texture2D src, SamplerState s, float2 pos, float2 step, float sigma, int kernelSize)
{
    int half_k = kernelSize >> 1;
    float g = 0.0;
    float gn = 0.0;
    for (int k = 0; k < kernelSize; ++k)
    {
        int di = k - half_k;
        float gf = Gaussian(di, sigma, 0.0);
        g += src.SampleLevel(s, pos + step * float(di), 0).x * gf;
        gn += gf;
    }
    return g / gn;
}

[bgfx::EFFECT("Anime4K Thin HQ", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("High quality line thinning effect for anime content. Uses iterative gradient-based warping to thin lines.")]
[bgfx::PASS(1, "Sobel")]
[bgfx::PASS_IO("INPUT", "tex2_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    float src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const float4 sr = INPUT.GatherRed(sam, tpos);
            const float4 sg = INPUT.GatherGreen(sam, tpos);
            const float4 sb = INPUT.GatherBlue(sam, tpos);

            src[i][j] = GetLuma(float3(sr.w, sg.w, sb.w));
            src[i][j + 1] = GetLuma(float3(sr.x, sg.x, sb.x));
            src[i + 1][j] = GetLuma(float3(sr.z, sg.z, sb.z));
            src[i + 1][j + 1] = GetLuma(float3(sr.y, sg.y, sb.y));
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                float xgrad = (-src[i - 1][j - 1] + src[i + 1][j - 1] - src[i - 1][j] + src[i + 1][j] - src[i - 1][j] + src[i + 1][j] - src[i - 1][j + 1] + src[i + 1][j + 1]) / 8.0f;
                float ygrad = (-src[i - 1][j - 1] - src[i][j - 1] - src[i][j - 1] - src[i + 1][j - 1] + src[i - 1][j + 1] + src[i][j + 1] + src[i][j + 1] + src[i + 1][j + 1]) / 8.0f;

                float norm = sqrt(xgrad * xgrad + ygrad * ygrad);
                tex2_UAV[destPos] = float4(pow(norm, 0.7), 0, 0, 0);
            }
        }
    }
}

[bgfx::PASS(2, "Gaussian-X")]
[bgfx::PASS_IO("tex2", "tex1_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    const float SPATIAL_SIGMA = 2.0f * GetInputSize().y / 1080.0f;
    const int KERNELSIZE = max(int(ceil(SPATIAL_SIGMA * 2.0)), 1) * 2 + 1;

    $for(i in Range(0, 2))
    {
        $for(j in Range(0, 2))
        {
            uint2 destPos = gxy + uint2(i, j);

            bool shouldProcess = true;
            if (i != 0 || j != 0)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                float2 pos = (destPos + 0.5f) * inputPt;
                float val = GaussianBlur1D(tex2, sam, pos, float2(inputPt.x, 0.0), SPATIAL_SIGMA, KERNELSIZE);
                tex1_UAV[destPos] = float4(val, 0, 0, 0);
            }
        }
    }
}

[bgfx::PASS(3, "Gaussian-Y")]
[bgfx::PASS_IO("tex1", "tex2_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass3(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    const float SPATIAL_SIGMA = 2.0f * GetInputSize().y / 1080.0f;
    const int KERNELSIZE = max(int(ceil(SPATIAL_SIGMA * 2.0)), 1) * 2 + 1;

    $for(i in Range(0, 2))
    {
        $for(j in Range(0, 2))
        {
            uint2 destPos = gxy + uint2(i, j);

            bool shouldProcess = true;
            if (i != 0 || j != 0)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                float2 pos = (destPos + 0.5f) * inputPt;
                float val = GaussianBlur1D(tex1, sam, pos, float2(0.0, inputPt.y), SPATIAL_SIGMA, KERNELSIZE);
                tex2_UAV[destPos] = float4(val, 0, 0, 0);
            }
        }
    }
}

[bgfx::PASS(4, "Kernel")]
[bgfx::PASS_IO("tex2", "tex1_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass4(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    float src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const float4 sr = tex2.GatherRed(sam, tpos);

            src[i][j] = sr.w;
            src[i][j + 1] = sr.x;
            src[i + 1][j] = sr.z;
            src[i + 1][j + 1] = sr.y;
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                float xgrad = -src[i - 1][j - 1] + src[i + 1][j - 1] - src[i - 1][j] + src[i + 1][j] - src[i - 1][j] + src[i + 1][j] - src[i - 1][j + 1] + src[i + 1][j + 1];
                float ygrad = -src[i - 1][j - 1] - src[i][j - 1] - src[i][j - 1] - src[i + 1][j - 1] + src[i - 1][j + 1] + src[i][j + 1] + src[i][j + 1] + src[i + 1][j + 1];

                tex1_UAV[destPos] = float4(xgrad / 8.0f, ygrad / 8.0f, 0, 0);
            }
        }
    }
}

[bgfx::PASS(5, "Warp")]
[bgfx::PASS_IO("tex1, INPUT", "OUTPUT")]
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

    float2 inputPt = GetInputPt();
    float relstr = GetInputSize().y / 1080.0f * params.strength;

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
                float2 pos = (destPos + 0.5f) * inputPt;
                pos = IterativeWarp(tex1, sam1, pos, inputPt, relstr, params.iterations);
                OUTPUT[destPos] = INPUT.SampleLevel(sam1, pos, 0);
            }
        }
    }
}
