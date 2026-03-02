module bgfx;

/*
================================================================================
BGFX Effect System v2 - Slang Module
================================================================================

EFFECT METADATA (on first pass function):
  [bgfx::EFFECT("Name", version)]     - Effect name and version (required)
  [bgfx::CATEGORY("Category")]        - Category for grouping in UI
  [bgfx::DESCRIPTION("...")]          - Description shown in UI
  [bgfx::DYNAMIC]                     - Effect uses time/frame/mouse uniforms
  [bgfx::FP16]                        - Effect supports FP16 precision

PARAMETERS (on uniform variables):
  [bgfx::PARAM("Label", default, min, max, "desc")]        - Float parameter
  [bgfx::PARAM_INT("Label", default, min, max, "desc")]    - Integer parameter
  [bgfx::PARAM_BOOL("Label", default, "desc")]             - Boolean parameter
  [bgfx::PARAM_TEXTURE("Label", "desc", "filter")]         - User-selectable texture (LUTs)

TEXTURES:
  [bgfx::SIZE("width_expr", "height_expr")]   - Intermediate texture size
  [format("format")]                           - Texture format (e.g., "rgba16f")
  [bgfx::SOURCE("path")]                      - Load texture from file
  [bgfx::HISTORY(1-7)]                        - Previous INPUT frame (1=last frame)
  [bgfx::FEEDBACK("passName")]                - Previous frame output from named pass
  [bgfx::RAND(count)]                         - Buffer filled with random floats [0,1]

  _UAV SUFFIX CONVENTION:
    For intermediate textures that need both sampling (SampleLevel, Gather) and
    writing, declare both a Texture2D for reading and RWTexture2D for writing:

      [bgfx::SIZE("OUTPUT_WIDTH", "OUTPUT_HEIGHT")]
      [format("rgba16f")]
      Texture2D texName;              // For reading (SampleLevel, Gather)
      [format("rgba16f")]
      RWTexture2D<float4> texName_UAV; // For writing (same resource, UAV view)

    The _UAV suffix tells the system these refer to the same underlying texture.
    Use texName for sampling operations, texName_UAV for writes.
    In PASS_IO, reference "texName_UAV" for output - parser strips suffix.

SAMPLERS:
  [bgfx::SAMPLER(FilterMode, AddressMode)]
    FilterMode: POINT (0), LINEAR (1)
    AddressMode: CLAMP (0), WRAP (1), MIRROR (2)

PASSES (on pass functions):
  [bgfx::PASS(index, "description")]          - Pass number and description
  [bgfx::PASS_NAME("name")]                   - Name for FEEDBACK reference
  [bgfx::PASS_IO("inputs", "output")]         - Comma-separated input/output textures
  [bgfx::BLOCK_SIZE(width, height)]           - Pixel coverage per workgroup (default: numthreads)
                                                Use when processing multiple pixels per thread
                                                (e.g., 2x2 pixels = BLOCK_SIZE(16,16) with numthreads(8,8,1))

HELPER FUNCTIONS:
  GetInputSize() / GetOutputSize()            - Texture dimensions (uint2)
  GetInputPt() / GetOutputPt()                - Texel size (float2)
  GetScale()                                  - Output/Input ratio (float2)
  GetOutputUV(tid) / GetInputUV(tid)          - UV from thread ID
  IsInBounds(tid)                             - Check if thread is in output bounds
  Swizzle8x8(index)                           - 8x8 tile swizzle pattern
  GetFrameCount()                             - Current frame number
  GetTime() / GetTimeDelta()                  - Time in seconds
  GetMouse()                                  - Mouse state (xy=pos, zw=click, sign=pressed)
  GetHistoryTimeDelta(age)                    - Time delta for history frame
  GetRandom(seed) / GetRandom(tid)            - Random float [0,1]
  GetRandom2/3/4(seed)                        - Multiple random floats

================================================================================
*/

public enum FilterMode
{
    POINT = 0,
    LINEAR = 1
};

public enum AddressMode
{
    CLAMP = 0,
    WRAP = 1,
    MIRROR = 2
};

[__AttributeUsage(_AttributeTargets.Function)]
public struct bgfx_EFFECTAttribute
{
    string name;
    int version;
};

[__AttributeUsage(_AttributeTargets.Function)]
public struct bgfx_CATEGORYAttribute
{
    string name;
};

[__AttributeUsage(_AttributeTargets.Function)]
public struct bgfx_DESCRIPTIONAttribute
{
    string text;
};

[__AttributeUsage(_AttributeTargets.Function)]
public struct bgfx_DYNAMICAttribute
{
};

[__AttributeUsage(_AttributeTargets.Function)]
public struct bgfx_FP16Attribute
{
};

[__AttributeUsage(_AttributeTargets.Var)]
public struct bgfx_PARAMAttribute
{
    string label;
    float def;
    float min;
    float max;
    string desc;
};

[__AttributeUsage(_AttributeTargets.Var)]
public struct bgfx_PARAM_INTAttribute
{
    string label;
    int def;
    int min;
    int max;
    string desc;
};

[__AttributeUsage(_AttributeTargets.Var)]
public struct bgfx_PARAM_BOOLAttribute
{
    string label;
    bool def;
    string desc;
};

[__AttributeUsage(_AttributeTargets.Var)]
public struct bgfx_PARAM_TEXTUREAttribute
{
    string label;
    string desc;
    string filter;
};

[__AttributeUsage(_AttributeTargets.Var)]
public struct bgfx_SIZEAttribute
{
    string width;
    string height;
};

[__AttributeUsage(_AttributeTargets.Var)]
public struct bgfx_SOURCEAttribute
{
    string path;
};

[__AttributeUsage(_AttributeTargets.Var)]
public struct bgfx_FORMATAttribute
{
    string format;
};

[__AttributeUsage(_AttributeTargets.Var)]
public struct bgfx_HISTORYAttribute
{
    int index;
};

[__AttributeUsage(_AttributeTargets.Var)]
public struct bgfx_FEEDBACKAttribute
{
    string passName;
};

[__AttributeUsage(_AttributeTargets.Var)]
public struct bgfx_RANDAttribute
{
    int count;
};

[__AttributeUsage(_AttributeTargets.Var)]
public struct bgfx_SAMPLERAttribute
{
    FilterMode filter;
    AddressMode address;
};

[__AttributeUsage(_AttributeTargets.Function)]
public struct bgfx_PASSAttribute
{
    int index;
    string desc;
};

[__AttributeUsage(_AttributeTargets.Function)]
public struct bgfx_PASS_NAMEAttribute
{
    string name;
};

[__AttributeUsage(_AttributeTargets.Function)]
public struct bgfx_PASS_IOAttribute
{
    string inputs;
    string output;
};

[__AttributeUsage(_AttributeTargets.Function)]
public struct bgfx_BLOCK_SIZEAttribute
{
    int width;
    int height;
};

cbuffer _BGFX_Static : register(b0)
{
    uint2 _inputSize;
    uint2 _outputSize;
    float2 _inputPt;
    float2 _outputPt;
    float2 _scale;
};

cbuffer _BGFX_Dynamic : register(b1)
{
    uint _frameCount;
    float _time;
    float _timeDelta;
    float _padding0;
    float4 _mouse;
    float _historyTimeDelta[7];
    float _padding1;
};

[ForceInline]
public uint2 GetInputSize()
{
    return _inputSize;
}
[ForceInline]
public uint2 GetOutputSize()
{
    return _outputSize;
}
[ForceInline]
public float2 GetInputPt()
{
    return _inputPt;
}
[ForceInline]
public float2 GetOutputPt()
{
    return _outputPt;
}
[ForceInline]
public float2 GetScale()
{
    return _scale;
}
[ForceInline]
public uint GetFrameCount()
{
    return _frameCount;
}
[ForceInline]
public float GetTime()
{
    return _time;
}
[ForceInline]
public float GetTimeDelta()
{
    return _timeDelta;
}
[ForceInline]
public float4 GetMouse()
{
    return _mouse;
}
[ForceInline]
public float GetHistoryTimeDelta(int age)
{
    return _historyTimeDelta[clamp(age - 1, 0, 6)];
}

[ForceInline]
public float2 GetOutputUV(uint3 tid)
{
    return (float2(tid.xy) + 0.5) / float2(GetOutputSize());
}
[ForceInline]
public float2 GetInputUV(uint3 tid)
{
    return (float2(tid.xy) + 0.5) / float2(GetInputSize());
}
[ForceInline]
public bool IsInBounds(uint3 tid)
{
    return all(tid.xy < GetOutputSize());
}
[ForceInline]
public bool IsInBounds(uint3 tid, uint2 size)
{
    return all(tid.xy < size);
}

[ForceInline]
public uint2 Swizzle8x8(uint index)
{
    return uint2(
        ((index & 0x01) | ((index & 0x04) >> 1) | ((index & 0x10) >> 2)),
        ((index & 0x02) >> 1) | ((index & 0x08) >> 2) | ((index & 0x20) >> 3));
}

[ForceInline]
public float2 MulAdd(float2 x, float2x2 y, float2 a)
{
    float2 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    return r;
}
[ForceInline]
public float3 MulAdd(float2 x, float2x3 y, float3 a)
{
    float3 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    return r;
}
[ForceInline]
public float4 MulAdd(float2 x, float2x4 y, float4 a)
{
    float4 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    return r;
}
[ForceInline]
public float2 MulAdd(float3 x, float3x2 y, float2 a)
{
    float2 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    return r;
}
[ForceInline]
public float3 MulAdd(float3 x, float3x3 y, float3 a)
{
    float3 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    return r;
}
[ForceInline]
public float4 MulAdd(float3 x, float3x4 y, float4 a)
{
    float4 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    return r;
}
[ForceInline]
public float2 MulAdd(float4 x, float4x2 y, float2 a)
{
    float2 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    r = mad(x.w, y[3], r);
    return r;
}
[ForceInline]
public float3 MulAdd(float4 x, float4x3 y, float3 a)
{
    float3 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    r = mad(x.w, y[3], r);
    return r;
}
[ForceInline]
public float4 MulAdd(float4 x, float4x4 y, float4 a)
{
    float4 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    r = mad(x.w, y[3], r);
    return r;
}

[ForceInline]
public half2 MulAdd(half2 x, half2x2 y, half2 a)
{
    half2 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    return r;
}
[ForceInline]
public half3 MulAdd(half2 x, half2x3 y, half3 a)
{
    half3 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    return r;
}
[ForceInline]
public half4 MulAdd(half2 x, half2x4 y, half4 a)
{
    half4 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    return r;
}
[ForceInline]
public half2 MulAdd(half3 x, half3x2 y, half2 a)
{
    half2 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    return r;
}
[ForceInline]
public half3 MulAdd(half3 x, half3x3 y, half3 a)
{
    half3 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    return r;
}
[ForceInline]
public half4 MulAdd(half3 x, half3x4 y, half4 a)
{
    half4 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    return r;
}
[ForceInline]
public half2 MulAdd(half4 x, half4x2 y, half2 a)
{
    half2 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    r = mad(x.w, y[3], r);
    return r;
}
[ForceInline]
public half3 MulAdd(half4 x, half4x3 y, half3 a)
{
    half3 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    r = mad(x.w, y[3], r);
    return r;
}
[ForceInline]
public half4 MulAdd(half4 x, half4x4 y, half4 a)
{
    half4 r = a;
    r = mad(x.x, y[0], r);
    r = mad(x.y, y[1], r);
    r = mad(x.z, y[2], r);
    r = mad(x.w, y[3], r);
    return r;
}

[ForceInline]
public uint PcgHash(uint seed)
{
    uint state = seed * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

[ForceInline]
public float GetRandom(uint seed)
{
    return float(PcgHash(seed)) / 4294967295.0;
}

[ForceInline]
public float GetRandom(uint2 pos, uint seed)
{
    return GetRandom(pos.x ^ (pos.y << 16) ^ seed);
}

[ForceInline]
public float GetRandom(uint3 tid, uint seed)
{
    return GetRandom(tid.xy, seed);
}

[ForceInline]
public float GetRandom(uint3 tid)
{
    return GetRandom(tid.xy, GetFrameCount());
}

[ForceInline]
public float2 GetRandom2(uint seed)
{
    return float2(GetRandom(seed), GetRandom(seed + 1u));
}

[ForceInline]
public float3 GetRandom3(uint seed)
{
    return float3(GetRandom(seed), GetRandom(seed + 1u), GetRandom(seed + 2u));
}

[ForceInline]
public float4 GetRandom4(uint seed)
{
    return float4(GetRandom(seed), GetRandom(seed + 1u), GetRandom(seed + 2u), GetRandom(seed + 3u));
}
