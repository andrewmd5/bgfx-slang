# BGFX Effects for Borderless Gaming

Custom shader effects for [Borderless Gaming](https://store.steampowered.com/app/388080/Borderless_Gaming/) on Steam.

## What is BGFX?

BGFX is the effect format used by Borderless Gaming to apply real-time image processing to games. Effects can upscale, sharpen, add CRT filters, apply color grading, and more.

## Using Effects

1. Open Borderless Gaming
2. Go to the Effect Editor
3. Create a preset and add effects to your pipeline
4. Adjust parameters to taste

## Effect Categories

- **Upscaling** - FSR, FSRCNNX, RAVU, CuNNy, and more
- **Sharpening** - CAS, Adaptive Sharpen, LumaSharpen
- **CRT** - CRT-Geom, CRT-Lottes, CRT-Hyllian, Easymode
- **Anti-aliasing** - FXAA, SMAA
- **Post Processing** - LUT color grading, Deband, Image Adjustment
- **Pixel Art** - xBRZ, MMPX, Sharp Bilinear
- **Background** - Blur fill, gradient, ambient edge

## Creating Custom Effects

Effects are written in [Slang](https://shader-slang.com/), a modern shading language. See [BGFX-v2.md](BGFX-v2.md) for the full specification.

### Minimal Example

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

## Installing Custom Effects

Place `.slang` files in:
- **Windows**: `%APPDATA%\coreutils\borderless-gaming\effects`

Effects are loaded on startup and can be refreshed from the Effect Editor.

## Links

- [Buy on Steam](https://store.steampowered.com/app/388080/Borderless_Gaming/)
- [BGFX-v2 Specification](BGFX-v2.md)
