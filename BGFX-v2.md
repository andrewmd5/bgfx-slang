# BGFX v2 Effect Format

Slang-based compute shaders for image scaling and post-processing.

## Minimal example

```slang
import bgfx;

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::EFFECT("My Effect", 2)]
[bgfx::CATEGORY("Post Processing")]
[bgfx::PASS(1, "Main")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid : SV_DispatchThreadID)
{
    if (!IsInBounds(tid)) return;
    OUTPUT[tid.xy] = INPUT.SampleLevel(sam, GetOutputUV(tid), 0);
}
```

## Effect metadata

Put these on your first pass function:

```slang
[bgfx::EFFECT("Effect Name", 2)]     // name and version (always 2)
[bgfx::CATEGORY("Sharpening")]       // UI grouping
[bgfx::DESCRIPTION("Does things")]   // tooltip
[bgfx::DYNAMIC]                      // enables time/mouse/framecount
[bgfx::FP16]                         // hint that FP16 path exists
```

## Parameters

Declare in a struct, bind to register b2:

```slang
struct MyParams {
    [bgfx::PARAM("Strength", 0.5, 0.0, 1.0, "How strong")]
    float strength;

    [bgfx::PARAM_INT("Quality", 2, 1, 4, "Quality level")]
    int quality;

    [bgfx::PARAM_BOOL("Enable", true, "Turn it on")]
    bool enable;

    // PARAM_INT with min=0, max=1 shows as a toggle in the UI
    [bgfx::PARAM_INT("Scanlines", 1, 0, 1, "Show scanlines")]
    int scanlines;
};

ConstantBuffer<MyParams> params : register(b2);
```

b0 and b1 are reserved. Use b2 or higher.

## Textures

```slang
// Input (read-only, always available)
Texture2D INPUT;

// Output (needs format)
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

// Custom size
[bgfx::SIZE("INPUT_WIDTH / 2", "INPUT_HEIGHT / 2")]
[format("rgba16f")]
RWTexture2D<float4> halfRes;

// From file
[bgfx::SOURCE("lut.dds")]
Texture2D lutTexture;

// Previous frames (1-7)
[bgfx::HISTORY(1)]
Texture2D lastFrame;

// Previous output of a named pass
[bgfx::FEEDBACK("MainPass")]
Texture2D prevOutput;

// Random data
[bgfx::RAND(1024)]
Buffer<float> noise;

// User-selectable texture (LUTs, etc.)
[bgfx::PARAM_TEXTURE("LUT File", "Color lookup table", "LUT|*.png;*.dds")]
[bgfx::SOURCE("default.png")]  // optional default
Texture2D lut;
```

**Important:** All textures read by a pass must be listed in `PASS_IO`, including user-selectable textures:
```slang
[bgfx::PASS_IO("INPUT, lut", "OUTPUT")]  // lut must be listed to be bound
```

**Size expressions:** `INPUT_WIDTH`, `INPUT_HEIGHT`, `OUTPUT_WIDTH`, `OUTPUT_HEIGHT`, `RENDERER_WIDTH`, `RENDERER_HEIGHT`

**Formats:** `rgba8`, `rgba16f`, `rgba32f`, `r11g11b10f`, `rg16f`, `r32f`, `r16f`, `r8`, `rg8`, `r16`, `rg32f`, `rgb10a2`

### OUTPUT size rules

OUTPUT defines what `OUTPUT_WIDTH` and `OUTPUT_HEIGHT` mean, so it can't reference them (circular).

| Effect type | OUTPUT attributes |
|-------------|-------------------|
| Scaling | `[format("rgba8")]` only — size from user settings |
| Non-scaling | `[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]` + format |
| Background | `[bgfx::SIZE("RENDERER_WIDTH", "RENDERER_HEIGHT")]` + format |

Intermediate textures *can* use `OUTPUT_WIDTH`/`OUTPUT_HEIGHT` since OUTPUT is defined first.

### Reading and writing the same texture

`RWTexture2D` can't do `SampleLevel()` or `Gather()`. If you need both sampling and writing, declare both views:

```slang
[bgfx::SIZE("OUTPUT_WIDTH", "OUTPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex;                    // for SampleLevel, Gather
RWTexture2D<float4> tex_UAV;      // for writing

// Pass 1 writes
[bgfx::PASS_IO("INPUT", "tex_UAV")]
void Pass1(uint3 tid : SV_DispatchThreadID) {
    tex_UAV[tid.xy] = INPUT.SampleLevel(sam, uv, 0);
}

// Pass 2 reads with Gather
[bgfx::PASS_IO("tex", "OUTPUT")]
void Pass2(uint3 tid : SV_DispatchThreadID) {
    float4 g = tex.GatherRed(sam, uv);  // needs Texture2D
    OUTPUT[tid.xy] = g;
}
```

The `_UAV` suffix tells the parser it's the same resource.

## Samplers

```slang
[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.WRAP)]
SamplerState samPoint;
```

**FilterMode:** `POINT` (0), `LINEAR` (1)

**AddressMode:** `CLAMP` (0), `WRAP` (1), `MIRROR` (2)

## Passes

```slang
[bgfx::PASS(1, "First pass")]
[bgfx::PASS_IO("INPUT", "temp")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid : SV_DispatchThreadID) { ... }

[bgfx::PASS(2, "Second pass")]
[bgfx::PASS_IO("temp", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid : SV_DispatchThreadID) { ... }
```

Pass index is 1-based. Inputs are comma-separated, output is single.

For feedback, name your pass:

```slang
[bgfx::PASS(1, "Main")]
[bgfx::PASS_NAME("MainPass")]
```

## Built-in functions

Always available:

```slang
uint2 GetInputSize();
uint2 GetOutputSize();
float2 GetInputPt();              // 1.0 / InputSize
float2 GetOutputPt();             // 1.0 / OutputSize
float2 GetScale();                // OutputSize / InputSize
float2 GetOutputUV(uint3 tid);
float2 GetInputUV(uint3 tid);
bool IsInBounds(uint3 tid);
bool IsInBounds(uint3 tid, uint2 size);
uint2 Swizzle8x8(uint index);     // Morton code for cache-friendly access
```

Requires `[bgfx::DYNAMIC]`:

```slang
uint GetFrameCount();
float GetTime();
float GetTimeDelta();
float4 GetMouse();                // xy=pos, zw=click (sign = pressed)
float GetHistoryTimeDelta(int age);
```

Random numbers (PCG-based):

```slang
uint PcgHash(uint seed);
float GetRandom(uint seed);                 // [0, 1]
float GetRandom(uint2 pos, uint seed);
float GetRandom(uint3 tid, uint seed);
float GetRandom(uint3 tid);                 // uses GetFrameCount()
float2 GetRandom2(uint seed);
float3 GetRandom3(uint seed);
float4 GetRandom4(uint seed);
```

Matrix multiply-add (float and half):

```slang
float4 MulAdd(float2 x, float2x4 y, float4 a);  // mul(x, y) + a
// other dimension variants exist
```

## History and feedback

History gives you previous INPUT frames:

```slang
[bgfx::HISTORY(1)] Texture2D hist1;  // 1 frame ago
[bgfx::HISTORY(2)] Texture2D hist2;  // 2 frames ago
// up to 7

[bgfx::DYNAMIC]
[bgfx::PASS_IO("INPUT, hist1, hist2", "OUTPUT")]
```

Feedback gives you the previous output of a named pass:

```slang
[bgfx::FEEDBACK("MainPass")]
Texture2D prevFrame;

[bgfx::PASS(1, "Main")]
[bgfx::PASS_NAME("MainPass")]
[bgfx::PASS_IO("INPUT, prevFrame", "OUTPUT")]
```

## Block processing

For effects that process multiple pixels per thread (neural networks, etc.), use `[bgfx::BLOCK_SIZE]` to tell the dispatcher the actual coverage:

```slang
[bgfx::BLOCK_SIZE(16, 16)]        // each 8x8 workgroup covers 16x16 pixels
[numthreads(8, 8, 1)]
void Pass1(uint3 tid : SV_DispatchThreadID) {
    // Calculate position with swizzle for cache efficiency
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    // Process 2x2 pixels per thread
    $for(i in Range(0, 2)) {
        $for(j in Range(0, 2)) {
            OUTPUT[gxy + uint2(i, j)] = ...;
        }
    }
}
```

Without `BLOCK_SIZE`, the system assumes coverage equals numthreads.

## LUTs (Look-Up Tables)

LUTs are 3D color cubes stored as 2D horizontal strip images. Common sizes are 16x16x16 (256x16), 32x32x32 (1024x32), and 64x64x64 (4096x64).

### Converting LUT files

Most color grading LUTs come as `.cube` or `.3dl` files. Convert them to PNG:
https://streamshark.io/obs-guide/converting-cube-3dl-lut-to-image

### Using the built-in LUT effect

The `LUT.slang` effect in the Effects folder lets users apply any LUT without writing code. Add it to your preset and select a LUT image.

### Creating custom LUT effects

```slang
[bgfx::PARAM_TEXTURE("LUT", "Color grading LUT", "LUT|*.png")]
Texture2D LUT;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState LUTSampler;

float3 SampleLUT(float3 color, float size)
{
    float sliceSize = 1.0 / size;
    float slicePixelSize = sliceSize / size;
    float sliceInnerSize = slicePixelSize * (size - 1.0);

    float blueSlice0 = floor(color.b * (size - 1.0));
    float blueSlice1 = min(blueSlice0 + 1.0, size - 1.0);
    float blueMix = (color.b * (size - 1.0)) - blueSlice0;

    float2 uv0, uv1;
    uv0.x = (blueSlice0 * sliceSize) + (slicePixelSize * 0.5) + (color.r * sliceInnerSize);
    uv1.x = (blueSlice1 * sliceSize) + (slicePixelSize * 0.5) + (color.r * sliceInnerSize);
    uv0.y = uv1.y = (slicePixelSize * 0.5) + (color.g * sliceInnerSize);

    return lerp(
        LUT.SampleLevel(LUTSampler, uv0, 0).rgb,
        LUT.SampleLevel(LUTSampler, uv1, 0).rgb,
        blueMix
    );
}
```

The `PARAM_TEXTURE` attribute creates a file picker in the UI. Selected files are copied to the user's data folder for portability.

## Categories

Use these for consistency: `Sharpening`, `Upscaling`, `Downscaling`, `Deband`, `CRT`, `Scanlines`, `Background`, `Post Processing`, `Misc`

## Full example

```slang
import bgfx;

struct CASParams {
    [bgfx::PARAM("Sharpness", 0.4, 0.0, 1.0, "Sharpening intensity")]
    float sharpness;
};
ConstantBuffer<CASParams> params : register(b2);

Texture2D INPUT;

[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::EFFECT("CAS", 2)]
[bgfx::CATEGORY("Sharpening")]
[bgfx::DESCRIPTION("Contrast Adaptive Sharpening")]
[bgfx::PASS(1, "Sharpen")]
[bgfx::PASS_IO("INPUT", "OUTPUT")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid : SV_DispatchThreadID)
{
    if (!IsInBounds(tid)) return;

    float2 pt = GetInputPt();
    float2 uv = GetOutputUV(tid);

    float3 a = INPUT.SampleLevel(sam, uv + float2(-pt.x, -pt.y), 0).rgb;
    float3 b = INPUT.SampleLevel(sam, uv + float2(0, -pt.y), 0).rgb;
    float3 c = INPUT.SampleLevel(sam, uv + float2(pt.x, -pt.y), 0).rgb;
    float3 d = INPUT.SampleLevel(sam, uv + float2(-pt.x, 0), 0).rgb;
    float3 e = INPUT.SampleLevel(sam, uv, 0).rgb;
    float3 f = INPUT.SampleLevel(sam, uv + float2(pt.x, 0), 0).rgb;
    float3 g = INPUT.SampleLevel(sam, uv + float2(-pt.x, pt.y), 0).rgb;
    float3 h = INPUT.SampleLevel(sam, uv + float2(0, pt.y), 0).rgb;
    float3 i = INPUT.SampleLevel(sam, uv + float2(pt.x, pt.y), 0).rgb;

    float3 mnRGB = min(min(min(d, e), min(f, b)), h);
    float3 mxRGB = max(max(max(d, e), max(f, b)), h);
    mnRGB = min(mnRGB, min(min(a, c), min(g, i)));
    mxRGB = max(mxRGB, max(max(a, c), max(g, i)));

    float3 amp = saturate(min(mnRGB, 2.0 - mxRGB) / mxRGB);
    amp = sqrt(amp);

    float peak = -1.0 / lerp(8.0, 5.0, params.sharpness);
    float3 w = amp * peak;
    float3 rcpW = rcp(1.0 + 4.0 * w);

    OUTPUT[tid.xy] = float4(saturate((b*w + d*w + f*w + h*w + e) * rcpW), 1.0);
}
```
