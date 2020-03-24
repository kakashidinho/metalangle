//
// Copyright 2020 The ANGLE Project. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// copy_pixel_buffer.metal: implements compute shader that copy pixel data from buffer to texture.
//

#include "common.h"

#include <metal_pack>

using namespace rx::mtl_shader;

constant int kCopyFormatType [[function_constant(1)]];
constant int kCopyTextureType [[function_constant(2)]];
constant bool kCopyTextureType2D      = kCopyTextureType == kTextureType2D;
constant bool kCopyTextureType2DArray = kCopyTextureType == kTextureType2DArray;
constant bool kCopyTextureTypeCube    = kCopyTextureType == kTextureTypeCube;
constant bool kCopyTextureType3D      = kCopyTextureType == kTextureType3D;

struct CopyPixelParams
{
    uint3 copySize;
    uint3 textureOffset;

    uint bufferStartOffset;
    uint pixelSize;
    uint bufferRowPitch;
    uint bufferDepthPitch;
};

struct WritePixelParams
{
    uint2 copySize;
    uint2 textureOffset;

    uint bufferStartOffset;

    uint pixelSize;
    uint bufferRowPitch;

    uint textureLevel;
    uint textureLayer;

    bool reverseTextureRowOrder;
};

static inline float4 sRGBtoLinear(float4 color)
{
    float3 linear1 = color.rgb / 12.92;
    float3 linear2 = pow((color.rgb + float3(0.055)) / 1.055, 2.4);
    float3 factor  = float3(color.rgb <= float3(0.04045));
    float4 linear  = float4(factor * linear1 + float3(1.0 - factor) * linear2, color.a);

    return linear;
}

// clang-format off
#define TEXTURE_PARAMS(TYPE, ACCESS, NAME_PREFIX)               \
    texture2d<TYPE, ACCESS> NAME_PREFIX##Texture2d              \
    [[texture(0), function_constant(kCopyTextureType2D)]],      \
    texture2d_array<TYPE, ACCESS> NAME_PREFIX##Texture2dArray   \
    [[texture(0), function_constant(kCopyTextureType2DArray)]], \
    texture3d<TYPE, ACCESS> NAME_PREFIX##Texture3d              \
    [[texture(0), function_constant(kCopyTextureType3D)]],      \
    texturecube<TYPE, ACCESS> NAME_PREFIX##TextureCube          \
    [[texture(0), function_constant(kCopyTextureTypeCube)]]

#define FORWARD_TEXTURE_PARAMS(NAME_PREFIX) \
    NAME_PREFIX##Texture2d,                 \
    NAME_PREFIX##Texture2dArray,            \
    NAME_PREFIX##Texture3d,                 \
    NAME_PREFIX##TextureCube               

#define DEST_TEXTURE_PARAMS(TYPE)  TEXTURE_PARAMS(TYPE, access::write, dst)
#define FORWARD_DEST_TEXTURE_PARAMS FORWARD_TEXTURE_PARAMS(dst)

#define COMMON_READ_KERNEL_PARAMS(TEXTURE_TYPE)     \
    ushort3 gIndices [[thread_position_in_grid]],   \
    constant CopyPixelParams &options[[buffer(0)]], \
    constant uchar *buffer [[buffer(1)]],           \
    DEST_TEXTURE_PARAMS(TEXTURE_TYPE)

#define COMMON_READ_FUNC_PARAMS        \
    ushort3 gIndices,                  \
    constant CopyPixelParams &options, \
    uint bufferOffset,                 \
    constant uchar *buffer

#define FORWARD_COMMON_READ_FUNC_PARAMS gIndices, options, bufferOffset, buffer

#define SRC_TEXTURE_PARAMS(TYPE)  TEXTURE_PARAMS(TYPE, access::read, src)
#define FORWARD_SRC_TEXTURE_PARAMS FORWARD_TEXTURE_PARAMS(src)

#define COMMON_WRITE_KERNEL_PARAMS(TEXTURE_TYPE)     \
    ushort2 gIndices [[thread_position_in_grid]],    \
    constant WritePixelParams &options[[buffer(0)]], \
    SRC_TEXTURE_PARAMS(TEXTURE_TYPE),                \
    device uchar *buffer [[buffer(1)]]               \

#define COMMON_WRITE_FUNC_PARAMS(TYPE) \
    ushort2 gIndices,                  \
    constant WritePixelParams &options,\
    uint bufferOffset,                 \
    vec<TYPE, 4> color,                \
    device uchar *buffer               \

#define COMMON_WRITE_FLOAT_FUNC_PARAMS COMMON_WRITE_FUNC_PARAMS(float)
#define COMMON_WRITE_SINT_FUNC_PARAMS COMMON_WRITE_FUNC_PARAMS(int)
#define COMMON_WRITE_UINT_FUNC_PARAMS COMMON_WRITE_FUNC_PARAMS(uint)

#define FORWARD_COMMON_WRITE_FUNC_PARAMS gIndices, options, bufferOffset, color, buffer

// clang-format on

// Write to texture code based on texture type:
template <typename T>
static inline void textureWrite(ushort3 gIndices,
                                constant CopyPixelParams &options,
                                vec<T, 4> color,
                                DEST_TEXTURE_PARAMS(T))
{
    uint3 writeIndices = options.textureOffset + uint3(gIndices);
    switch (kCopyTextureType)
    {
        case kTextureType2D:
            dstTexture2d.write(color, writeIndices.xy);
            break;
        case kTextureType2DArray:
            dstTexture2dArray.write(color, writeIndices.xy, writeIndices.z);
            break;
        case kTextureType3D:
            dstTexture3d.write(color, writeIndices);
            break;
        case kTextureTypeCube:
            dstTextureCube.write(color, writeIndices.xy, writeIndices.z);
            break;
    }
}

// Read from texture code based on texture type:
template <typename T>
static inline vec<T, 4> textureRead(ushort2 gIndices,
                                    constant WritePixelParams &options,
                                    SRC_TEXTURE_PARAMS(T))
{
    vec<T, 4> color;
    uint2 coords = uint2(gIndices);
    if (options.reverseTextureRowOrder)
    {
        coords.y = options.copySize.y - 1 - gIndices.y;
    }
    coords += options.textureOffset;
    switch (kCopyTextureType)
    {
        case kTextureType2D:
            color = srcTexture2d.read(coords.xy, options.textureLevel);
            break;
        case kTextureType2DArray:
            color = srcTexture2dArray.read(coords.xy, options.textureLayer, options.textureLevel);
            break;
        case kTextureType3D:
            color = srcTexture3d.read(uint3(coords, options.textureLayer), options.textureLevel);
            break;
        case kTextureTypeCube:
            color = srcTextureCube.read(coords.xy, options.textureLayer, options.textureLevel);
            break;
    }
    return color;
}

// Calculate offset into buffer:
#define CALC_BUFFER_READ_OFFSET(pixelSize)                               \
    options.bufferStartOffset + (gIndices.z * options.bufferDepthPitch + \
                                 gIndices.y * options.bufferRowPitch + gIndices.x * pixelSize)

#define CALC_BUFFER_WRITE_OFFSET(pixelSize) \
    options.bufferStartOffset + (gIndices.y * options.bufferRowPitch + gIndices.x * pixelSize)

// Per format handling code:
#define READ_FORMAT_SWITCH_CASE(format)                                      \
    case FormatID::format:                                                   \
    {                                                                        \
        auto color = read##format(FORWARD_COMMON_READ_FUNC_PARAMS);          \
        textureWrite(gIndices, options, color, FORWARD_DEST_TEXTURE_PARAMS); \
    }                                                                        \
    break;

#define WRITE_FORMAT_SWITCH_CASE(format)                                         \
    case FormatID::format:                                                       \
    {                                                                            \
        auto color = textureRead(gIndices, options, FORWARD_SRC_TEXTURE_PARAMS); \
        write##format(FORWARD_COMMON_WRITE_FUNC_PARAMS);                         \
    }                                                                            \
    break;

#define READ_KERNEL_GUARD                                                       \
    if (gIndices.x >= options.copySize.x || gIndices.y >= options.copySize.y || \
        gIndices.z >= options.copySize.z)                                       \
    {                                                                           \
        return;                                                                 \
    }

#define WRITE_KERNEL_GUARD                                                    \
    if (gIndices.x >= options.copySize.x || gIndices.y >= options.copySize.y) \
    {                                                                         \
        return;                                                               \
    }

// R5G6B5
static inline float4 readR5G6B5_UNORM(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    ushort src = bytesToShort<ushort>(buffer, bufferOffset);

    color.r = normalizedToFloat<5>(getShiftedData<5, 11>(src));
    color.g = normalizedToFloat<6>(getShiftedData<6, 5>(src));
    color.b = normalizedToFloat<5>(getShiftedData<5, 0>(src));
    color.a = 1.0;
    return color;
}
static inline void writeR5G6B5_UNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    ushort dst = shiftData<5, 11>(floatToNormalized<5, ushort>(color.r)) |
                 shiftData<6, 5>(floatToNormalized<6, ushort>(color.g)) |
                 shiftData<5, 0>(floatToNormalized<5, ushort>(color.b));

    shortToBytes(dst, bufferOffset, buffer);
}

// R4G4B4A4
static inline float4 readR4G4B4A4_UNORM(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    ushort src = bytesToShort<ushort>(buffer, bufferOffset);

    color.r = normalizedToFloat<4>(getShiftedData<4, 12>(src));
    color.g = normalizedToFloat<4>(getShiftedData<4, 8>(src));
    color.b = normalizedToFloat<4>(getShiftedData<4, 4>(src));
    color.a = normalizedToFloat<4>(getShiftedData<4, 0>(src));
    return color;
}
static inline void writeR4G4B4A4_UNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    ushort dst = shiftData<4, 12>(floatToNormalized<4, ushort>(color.r)) |
                 shiftData<4, 8>(floatToNormalized<4, ushort>(color.g)) |
                 shiftData<4, 4>(floatToNormalized<4, ushort>(color.b)) |
                 shiftData<4, 0>(floatToNormalized<4, ushort>(color.a));
    ;

    shortToBytes(dst, bufferOffset, buffer);
}

// R5G5B5A1
static inline float4 readR5G5B5A1_UNORM(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    ushort src = bytesToShort<ushort>(buffer, bufferOffset);

    color.r = normalizedToFloat<5>(getShiftedData<5, 11>(src));
    color.g = normalizedToFloat<5>(getShiftedData<5, 6>(src));
    color.b = normalizedToFloat<5>(getShiftedData<5, 1>(src));
    color.a = normalizedToFloat<1>(getShiftedData<1, 0>(src));
    return color;
}
static inline void writeR5G5B5A1_UNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    ushort dst = shiftData<5, 11>(floatToNormalized<5, ushort>(color.r)) |
                 shiftData<5, 6>(floatToNormalized<5, ushort>(color.g)) |
                 shiftData<5, 1>(floatToNormalized<5, ushort>(color.b)) |
                 shiftData<1, 0>(floatToNormalized<1, ushort>(color.a));
    ;

    shortToBytes(dst, bufferOffset, buffer);
}

// R8G8B8A8 generic
static inline float4 readR8G8B8A8(COMMON_READ_FUNC_PARAMS, bool isSRGB)
{
    float4 color;
    uint src = bytesToInt<uint>(buffer, bufferOffset);

    if (isSRGB)
    {
        color = unpack_unorm4x8_srgb_to_float(src);
    }
    else
    {
        color = unpack_unorm4x8_to_float(src);
    }
    return color;
}
static inline void writeR8G8B8A8(COMMON_WRITE_FLOAT_FUNC_PARAMS, bool isSRGB)
{
    uint dst;

    if (isSRGB)
    {
        dst = pack_float_to_srgb_unorm4x8(color);
    }
    else
    {
        dst = pack_float_to_unorm4x8(color);
    }

    intToBytes(dst, bufferOffset, buffer);
}

static inline float4 readR8G8B8(COMMON_READ_FUNC_PARAMS, bool isSRGB)
{
    float4 color;
    color.r = normalizedToFloat<uchar>(buffer[bufferOffset]);
    color.g = normalizedToFloat<uchar>(buffer[bufferOffset + 1]);
    color.b = normalizedToFloat<uchar>(buffer[bufferOffset + 2]);
    color.a = 1.0;

    if (isSRGB)
    {
        color = sRGBtoLinear(color);
    }
    return color;
}
static inline void writeR8G8B8(COMMON_WRITE_FLOAT_FUNC_PARAMS, bool isSRGB)
{
    color.a = 1.0;
    uint dst;

    if (isSRGB)
    {
        dst = pack_float_to_srgb_unorm4x8(color);
    }
    else
    {
        dst = pack_float_to_unorm4x8(color);
    }
    int24bitToBytes(dst, bufferOffset, buffer);
}

// RGBA8_SNORM
static inline float4 readR8G8B8A8_SNORM(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    uint src = bytesToInt<uint>(buffer, bufferOffset);

    color = unpack_snorm4x8_to_float(src);

    return color;
}
static inline void writeR8G8B8A8_SNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    uint dst = pack_float_to_snorm4x8(color);

    intToBytes(dst, bufferOffset, buffer);
}

// RGB8_SNORM
static inline float4 readR8G8B8_SNORM(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.r = normalizedToFloat<7, char>(buffer[bufferOffset]);
    color.g = normalizedToFloat<7, char>(buffer[bufferOffset + 1]);
    color.b = normalizedToFloat<7, char>(buffer[bufferOffset + 2]);
    color.a = 1.0;

    return color;
}
static inline void writeR8G8B8_SNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    uint dst = pack_float_to_snorm4x8(color);

    int24bitToBytes(dst, bufferOffset, buffer);
}

// RGBA8
static inline float4 readR8G8B8A8_UNORM(COMMON_READ_FUNC_PARAMS)
{
    return readR8G8B8A8(FORWARD_COMMON_READ_FUNC_PARAMS, false);
}
static inline void writeR8G8B8A8_UNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    return writeR8G8B8A8(FORWARD_COMMON_WRITE_FUNC_PARAMS, false);
}

static inline float4 readR8G8B8A8_UNORM_SRGB(COMMON_READ_FUNC_PARAMS)
{
    return readR8G8B8A8(FORWARD_COMMON_READ_FUNC_PARAMS, true);
}
static inline void writeR8G8B8A8_UNORM_SRGB(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    return writeR8G8B8A8(FORWARD_COMMON_WRITE_FUNC_PARAMS, true);
}

// BGRA8
static inline float4 readB8G8R8A8_UNORM(COMMON_READ_FUNC_PARAMS)
{
    return readR8G8B8A8(FORWARD_COMMON_READ_FUNC_PARAMS, false).bgra;
}
static inline void writeB8G8R8A8_UNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    color.rgba = color.bgra;
    return writeR8G8B8A8(FORWARD_COMMON_WRITE_FUNC_PARAMS, false);
}

static inline float4 readB8G8R8A8_UNORM_SRGB(COMMON_READ_FUNC_PARAMS)
{
    return readR8G8B8A8(FORWARD_COMMON_READ_FUNC_PARAMS, true).bgra;
}
static inline void writeB8G8R8A8_UNORM_SRGB(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    color.rgba = color.bgra;
    return writeR8G8B8A8(FORWARD_COMMON_WRITE_FUNC_PARAMS, true);
}

// RGB8
static inline float4 readR8G8B8_UNORM(COMMON_READ_FUNC_PARAMS)
{
    return readR8G8B8(FORWARD_COMMON_READ_FUNC_PARAMS, false);
}
static inline void writeR8G8B8_UNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    return writeR8G8B8(FORWARD_COMMON_WRITE_FUNC_PARAMS, false);
}

static inline float4 readR8G8B8_UNORM_SRGB(COMMON_READ_FUNC_PARAMS)
{
    return readR8G8B8(FORWARD_COMMON_READ_FUNC_PARAMS, true);
}
static inline void writeR8G8B8_UNORM_SRGB(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    return writeR8G8B8(FORWARD_COMMON_WRITE_FUNC_PARAMS, true);
}

// L8
static inline float4 readL8_UNORM(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.rgb = float3(normalizedToFloat<uchar>(buffer[bufferOffset]));
    color.a   = 1.0;
    return color;
}
static inline void writeL8_UNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    buffer[bufferOffset] = floatToNormalized<uchar>(color.r);
}

// A8
static inline void writeA8_UNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    buffer[bufferOffset] = floatToNormalized<uchar>(color.a);
}

// L8A8
static inline float4 readL8A8_UNORM(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.rgb = float3(normalizedToFloat<uchar>(buffer[bufferOffset]));
    color.a   = normalizedToFloat<uchar>(buffer[bufferOffset + 1]);
    return color;
}
static inline void writeL8A8_UNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    buffer[bufferOffset]     = floatToNormalized<uchar>(color.r);
    buffer[bufferOffset + 1] = floatToNormalized<uchar>(color.a);
}

// R8
static inline float4 readR8_UNORM(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.r = normalizedToFloat<uchar>(buffer[bufferOffset]);
    color.g = color.b = 0.0;
    color.a           = 1.0;
    return color;
}
static inline void writeR8_UNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    buffer[bufferOffset] = floatToNormalized<uchar>(color.r);
}

static inline float4 readR8_SNORM(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.r = normalizedToFloat<7, char>(buffer[bufferOffset]);
    color.g = color.b = 0.0;
    color.a           = 1.0;
    return color;
}
static inline void writeR8_SNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    buffer[bufferOffset] = as_type<uchar>(floatToNormalized<7, char>(color.r));
}

// R8_SINT
static inline int4 readR8_SINT(COMMON_READ_FUNC_PARAMS)
{
    int4 color;
    color.r = as_type<char>(buffer[bufferOffset]);
    color.g = color.b = 0;
    color.a           = 1;
    return color;
}
static inline void writeR8_SINT(COMMON_WRITE_SINT_FUNC_PARAMS)
{
    buffer[bufferOffset] = static_cast<uchar>(color.r);
}

// R8_UINT
static inline uint4 readR8_UINT(COMMON_READ_FUNC_PARAMS)
{
    uint4 color;
    color.r = as_type<uchar>(buffer[bufferOffset]);
    color.g = color.b = 0;
    color.a           = 1;
    return color;
}
static inline void writeR8_UINT(COMMON_WRITE_UINT_FUNC_PARAMS)
{
    buffer[bufferOffset] = static_cast<uchar>(color.r);
}

// R8G8
static inline float4 readR8G8_UNORM(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.r = normalizedToFloat<uchar>(buffer[bufferOffset]);
    color.g = normalizedToFloat<uchar>(buffer[bufferOffset + 1]);
    color.b = 0.0;
    color.a = 1.0;
    return color;
}
static inline void writeR8G8_UNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    buffer[bufferOffset]     = floatToNormalized<uchar>(color.r);
    buffer[bufferOffset + 1] = floatToNormalized<uchar>(color.g);
}

static inline float4 readR8G8_SNORM(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.r = normalizedToFloat<7, char>(buffer[bufferOffset]);
    color.g = normalizedToFloat<7, char>(buffer[bufferOffset + 1]);
    color.b = 0.0;
    color.a = 1.0;
    return color;
}
static inline void writeR8G8_SNORM(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    buffer[bufferOffset]     = as_type<uchar>(floatToNormalized<7, char>(color.r));
    buffer[bufferOffset + 1] = as_type<uchar>(floatToNormalized<7, char>(color.g));
}

// RG8_SINT
static inline int4 readR8G8_SINT(COMMON_READ_FUNC_PARAMS)
{
    int4 color;
    color.r = as_type<char>(buffer[bufferOffset]);
    color.g = as_type<char>(buffer[bufferOffset + 1]);
    color.b = 0;
    color.a = 1;
    return color;
}
static inline void writeR8G8_SINT(COMMON_WRITE_SINT_FUNC_PARAMS)
{
    buffer[bufferOffset]     = static_cast<uchar>(color.r);
    buffer[bufferOffset + 1] = static_cast<uchar>(color.g);
}

// RG8_UINT
static inline uint4 readR8G8_UINT(COMMON_READ_FUNC_PARAMS)
{
    uint4 color;
    color.r = as_type<uchar>(buffer[bufferOffset]);
    color.g = as_type<uchar>(buffer[bufferOffset + 1]);
    color.b = 0;
    color.a = 1;
    return color;
}
static inline void writeR8G8_UINT(COMMON_WRITE_UINT_FUNC_PARAMS)
{
    buffer[bufferOffset]     = static_cast<uchar>(color.r);
    buffer[bufferOffset + 1] = static_cast<uchar>(color.g);
}

// R8G8G8A8_SINT
static inline int4 readR8G8B8A8_SINT(COMMON_READ_FUNC_PARAMS)
{
    int4 color;
    color.r = as_type<char>(buffer[bufferOffset]);
    color.g = as_type<char>(buffer[bufferOffset + 1]);
    color.b = as_type<char>(buffer[bufferOffset + 2]);
    color.a = as_type<char>(buffer[bufferOffset + 3]);
    return color;
}
static inline void writeR8G8B8A8_SINT(COMMON_WRITE_SINT_FUNC_PARAMS)
{
    buffer[bufferOffset]     = static_cast<uchar>(color.r);
    buffer[bufferOffset + 1] = static_cast<uchar>(color.g);
    buffer[bufferOffset + 2] = static_cast<uchar>(color.b);
    buffer[bufferOffset + 3] = static_cast<uchar>(color.a);
}

// R8G8G8A8_UINT
static inline uint4 readR8G8B8A8_UINT(COMMON_READ_FUNC_PARAMS)
{
    uint4 color;
    color.r = as_type<uchar>(buffer[bufferOffset]);
    color.g = as_type<uchar>(buffer[bufferOffset + 1]);
    color.b = as_type<uchar>(buffer[bufferOffset + 2]);
    color.a = as_type<uchar>(buffer[bufferOffset + 3]);
    return color;
}
static inline void writeR8G8B8A8_UINT(COMMON_WRITE_UINT_FUNC_PARAMS)
{
    buffer[bufferOffset]     = static_cast<uchar>(color.r);
    buffer[bufferOffset + 1] = static_cast<uchar>(color.g);
    buffer[bufferOffset + 2] = static_cast<uchar>(color.b);
    buffer[bufferOffset + 3] = static_cast<uchar>(color.a);
}

// R16_FLOAT
static inline float4 readR16_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.r = as_type<half>(bytesToShort<ushort>(buffer, bufferOffset));
    color.g = color.b = 0.0;
    color.a           = 1.0;
    return color;
}
static inline void writeR16_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    shortToBytes(as_type<ushort>(static_cast<half>(color.r)), bufferOffset, buffer);
}

// R16_SINT
static inline int4 readR16_SINT(COMMON_READ_FUNC_PARAMS)
{
    int4 color;
    color.r = bytesToShort<short>(buffer, bufferOffset);
    color.g = color.b = 0;
    color.a           = 1;
    return color;
}
static inline void writeR16_SINT(COMMON_WRITE_SINT_FUNC_PARAMS)
{
    shortToBytes(static_cast<short>(color.r), bufferOffset, buffer);
}

// R16_UINT
static inline uint4 readR16_UINT(COMMON_READ_FUNC_PARAMS)
{
    uint4 color;
    color.r = bytesToShort<ushort>(buffer, bufferOffset);
    color.g = color.b = 0;
    color.a           = 1;
    return color;
}
static inline void writeR16_UINT(COMMON_WRITE_UINT_FUNC_PARAMS)
{
    shortToBytes(static_cast<ushort>(color.r), bufferOffset, buffer);
}

// A16_FLOAT
static inline float4 readA16_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.a   = as_type<half>(bytesToShort<ushort>(buffer, bufferOffset));
    color.rgb = 0.0;
    return color;
}
static inline void writeA16_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    shortToBytes(as_type<ushort>(static_cast<half>(color.a)), bufferOffset, buffer);
}

// L16_FLOAT
static inline float4 readL16_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.rgb = as_type<half>(bytesToShort<ushort>(buffer, bufferOffset));
    color.a   = 1.0;
    return color;
}
static inline void writeL16_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    shortToBytes(as_type<ushort>(static_cast<half>(color.r)), bufferOffset, buffer);
}

// L16A16_FLOAT
static inline float4 readL16A16_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.rgb = as_type<half>(bytesToShort<ushort>(buffer, bufferOffset));
    color.a   = as_type<half>(bytesToShort<ushort>(buffer, bufferOffset + 2));
    return color;
}
static inline void writeL16A16_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    shortToBytes(as_type<ushort>(static_cast<half>(color.r)), bufferOffset, buffer);
    shortToBytes(as_type<ushort>(static_cast<half>(color.a)), bufferOffset + 2, buffer);
}

// R16G16_FLOAT
static inline float4 readR16G16_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.r = as_type<half>(bytesToShort<ushort>(buffer, bufferOffset));
    color.g = as_type<half>(bytesToShort<ushort>(buffer, bufferOffset + 2));
    color.b = 0.0;
    color.a = 1.0;
    return color;
}
static inline void writeR16G16_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    shortToBytes(as_type<ushort>(static_cast<half>(color.r)), bufferOffset, buffer);
    shortToBytes(as_type<ushort>(static_cast<half>(color.g)), bufferOffset + 2, buffer);
}

// R16G16_SINT
static inline int4 readR16G16_SINT(COMMON_READ_FUNC_PARAMS)
{
    int4 color;
    color.r = bytesToShort<short>(buffer, bufferOffset);
    color.g = bytesToShort<short>(buffer, bufferOffset + 2);
    color.b = 0;
    color.a = 1;
    return color;
}
static inline void writeR16G16_SINT(COMMON_WRITE_SINT_FUNC_PARAMS)
{
    shortToBytes(static_cast<short>(color.r), bufferOffset, buffer);
    shortToBytes(static_cast<short>(color.g), bufferOffset + 2, buffer);
}

// R16G16_UINT
static inline uint4 readR16G16_UINT(COMMON_READ_FUNC_PARAMS)
{
    uint4 color;
    color.r = bytesToShort<ushort>(buffer, bufferOffset);
    color.g = bytesToShort<ushort>(buffer, bufferOffset + 2);
    color.b = 0;
    color.a = 1;
    return color;
}
static inline void writeR16G16_UINT(COMMON_WRITE_UINT_FUNC_PARAMS)
{
    shortToBytes(static_cast<ushort>(color.r), bufferOffset, buffer);
    shortToBytes(static_cast<ushort>(color.g), bufferOffset + 2, buffer);
}

// R16G16B16A16_FLOAT
static inline float4 readR16G16B16A16_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.r = as_type<half>(bytesToShort<ushort>(buffer, bufferOffset));
    color.g = as_type<half>(bytesToShort<ushort>(buffer, bufferOffset + 2));
    color.b = as_type<half>(bytesToShort<ushort>(buffer, bufferOffset + 4));
    color.a = as_type<half>(bytesToShort<ushort>(buffer, bufferOffset + 6));
    return color;
}
static inline void writeR16G16B16A16_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    shortToBytes(as_type<ushort>(static_cast<half>(color.r)), bufferOffset, buffer);
    shortToBytes(as_type<ushort>(static_cast<half>(color.g)), bufferOffset + 2, buffer);
    shortToBytes(as_type<ushort>(static_cast<half>(color.b)), bufferOffset + 4, buffer);
    shortToBytes(as_type<ushort>(static_cast<half>(color.a)), bufferOffset + 6, buffer);
}

// R16G16B16A16_SINT
static inline int4 readR16G16B16A16_SINT(COMMON_READ_FUNC_PARAMS)
{
    int4 color;
    color.r = bytesToShort<short>(buffer, bufferOffset);
    color.g = bytesToShort<short>(buffer, bufferOffset + 2);
    color.b = bytesToShort<short>(buffer, bufferOffset + 4);
    color.a = bytesToShort<short>(buffer, bufferOffset + 6);
    return color;
}
static inline void writeR16G16B16A16_SINT(COMMON_WRITE_SINT_FUNC_PARAMS)
{
    shortToBytes(static_cast<short>(color.r), bufferOffset, buffer);
    shortToBytes(static_cast<short>(color.g), bufferOffset + 2, buffer);
    shortToBytes(static_cast<short>(color.b), bufferOffset + 4, buffer);
    shortToBytes(static_cast<short>(color.a), bufferOffset + 6, buffer);
}

// R16G16B16A16_UINT
static inline uint4 readR16G16B16A16_UINT(COMMON_READ_FUNC_PARAMS)
{
    uint4 color;
    color.r = bytesToShort<ushort>(buffer, bufferOffset);
    color.g = bytesToShort<ushort>(buffer, bufferOffset + 2);
    color.b = bytesToShort<ushort>(buffer, bufferOffset + 4);
    color.a = bytesToShort<ushort>(buffer, bufferOffset + 6);
    return color;
}
static inline void writeR16G16B16A16_UINT(COMMON_WRITE_UINT_FUNC_PARAMS)
{
    shortToBytes(static_cast<ushort>(color.r), bufferOffset, buffer);
    shortToBytes(static_cast<ushort>(color.g), bufferOffset + 2, buffer);
    shortToBytes(static_cast<ushort>(color.b), bufferOffset + 4, buffer);
    shortToBytes(static_cast<ushort>(color.a), bufferOffset + 6, buffer);
}

// R32_FLOAT
static inline float4 readR32_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.r = as_type<float>(bytesToInt<uint>(buffer, bufferOffset));
    color.g = color.b = 0.0;
    color.a           = 1.0;
    return color;
}
static inline void writeR32_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    intToBytes(as_type<uint>(color.r), bufferOffset, buffer);
}

// A32_FLOAT
static inline float4 readA32_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.a   = as_type<float>(bytesToInt<uint>(buffer, bufferOffset));
    color.rgb = 0.0;
    return color;
}
static inline void writeA32_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    intToBytes(as_type<uint>(color.a), bufferOffset, buffer);
}

// L32_FLOAT
static inline float4 readL32_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.rgb = as_type<float>(bytesToInt<uint>(buffer, bufferOffset));
    color.a   = 1.0;
    return color;
}
static inline void writeL32_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    intToBytes(as_type<uint>(color.r), bufferOffset, buffer);
}

// R32_SINT
static inline int4 readR32_SINT(COMMON_READ_FUNC_PARAMS)
{
    int4 color;
    color.r = bytesToInt<int>(buffer, bufferOffset);
    color.g = color.b = 0;
    color.a           = 1;
    return color;
}
static inline void writeR32_SINT(COMMON_WRITE_SINT_FUNC_PARAMS)
{
    intToBytes(color.r, bufferOffset, buffer);
}

// R32_UINT
static inline uint4 readR32_UINT(COMMON_READ_FUNC_PARAMS)
{
    uint4 color;
    color.r = bytesToInt<uint>(buffer, bufferOffset);
    color.g = color.b = 0;
    color.a           = 1;
    return color;
}
static inline void writeR32_UINT(COMMON_WRITE_UINT_FUNC_PARAMS)
{
    intToBytes(color.r, bufferOffset, buffer);
}

// L32A32_FLOAT
static inline float4 readL32A32_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.rgb = as_type<float>(bytesToInt<uint>(buffer, bufferOffset));
    color.a   = as_type<float>(bytesToInt<uint>(buffer, bufferOffset + 4));
    return color;
}
static inline void writeL32A32_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    intToBytes(as_type<uint>(color.r), bufferOffset, buffer);
    intToBytes(as_type<uint>(color.a), bufferOffset + 4, buffer);
}

// R32G32_FLOAT
static inline float4 readR32G32_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.r = as_type<float>(bytesToInt<uint>(buffer, bufferOffset));
    color.g = as_type<float>(bytesToInt<uint>(buffer, bufferOffset + 4));
    color.b = 0.0;
    color.a = 1.0;
    return color;
}
static inline void writeR32G32_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    intToBytes(as_type<uint>(color.r), bufferOffset, buffer);
    intToBytes(as_type<uint>(color.g), bufferOffset + 4, buffer);
}

// R32G32_SINT
static inline int4 readR32G32_SINT(COMMON_READ_FUNC_PARAMS)
{
    int4 color;
    color.r = bytesToInt<int>(buffer, bufferOffset);
    color.g = bytesToInt<int>(buffer, bufferOffset + 4);
    color.b = 0;
    color.a = 1;
    return color;
}
static inline void writeR32G32_SINT(COMMON_WRITE_SINT_FUNC_PARAMS)
{
    intToBytes(color.r, bufferOffset, buffer);
    intToBytes(color.g, bufferOffset + 4, buffer);
}

// R32G32_UINT
static inline uint4 readR32G32_UINT(COMMON_READ_FUNC_PARAMS)
{
    uint4 color;
    color.r = bytesToInt<uint>(buffer, bufferOffset);
    color.g = bytesToInt<uint>(buffer, bufferOffset + 4);
    color.b = 0;
    color.a = 1;
    return color;
}
static inline void writeR32G32_UINT(COMMON_WRITE_UINT_FUNC_PARAMS)
{
    intToBytes(color.r, bufferOffset, buffer);
    intToBytes(color.g, bufferOffset + 4, buffer);
}

// R32G32B32A32_FLOAT
static inline float4 readR32G32B32A32_FLOAT(COMMON_READ_FUNC_PARAMS)
{
    float4 color;
    color.r = as_type<float>(bytesToInt<uint>(buffer, bufferOffset));
    color.g = as_type<float>(bytesToInt<uint>(buffer, bufferOffset + 4));
    color.b = as_type<float>(bytesToInt<uint>(buffer, bufferOffset + 8));
    color.a = as_type<float>(bytesToInt<uint>(buffer, bufferOffset + 12));
    return color;
}
static inline void writeR32G32B32A32_FLOAT(COMMON_WRITE_FLOAT_FUNC_PARAMS)
{
    intToBytes(as_type<uint>(color.r), bufferOffset, buffer);
    intToBytes(as_type<uint>(color.g), bufferOffset + 4, buffer);
    intToBytes(as_type<uint>(color.b), bufferOffset + 8, buffer);
    intToBytes(as_type<uint>(color.a), bufferOffset + 12, buffer);
}

// R32G32B32A32_SINT
static inline int4 readR32G32B32A32_SINT(COMMON_READ_FUNC_PARAMS)
{
    int4 color;
    color.r = bytesToInt<int>(buffer, bufferOffset);
    color.g = bytesToInt<int>(buffer, bufferOffset + 4);
    color.b = bytesToInt<int>(buffer, bufferOffset + 8);
    color.a = bytesToInt<int>(buffer, bufferOffset + 12);
    return color;
}
static inline void writeR32G32B32A32_SINT(COMMON_WRITE_SINT_FUNC_PARAMS)
{
    intToBytes(color.r, bufferOffset, buffer);
    intToBytes(color.g, bufferOffset + 4, buffer);
    intToBytes(color.b, bufferOffset + 8, buffer);
    intToBytes(color.a, bufferOffset + 12, buffer);
}

// R32G32B32A32_UINT
static inline uint4 readR32G32B32A32_UINT(COMMON_READ_FUNC_PARAMS)
{
    uint4 color;
    color.r = bytesToInt<uint>(buffer, bufferOffset);
    color.g = bytesToInt<uint>(buffer, bufferOffset + 4);
    color.b = bytesToInt<uint>(buffer, bufferOffset + 8);
    color.a = bytesToInt<uint>(buffer, bufferOffset + 12);
    return color;
}
static inline void writeR32G32B32A32_UINT(COMMON_WRITE_UINT_FUNC_PARAMS)
{
    intToBytes(color.r, bufferOffset, buffer);
    intToBytes(color.g, bufferOffset + 4, buffer);
    intToBytes(color.b, bufferOffset + 8, buffer);
    intToBytes(color.a, bufferOffset + 12, buffer);
}

// Copy pixels from buffer to texture
kernel void readFromBufferToFloatTexture(COMMON_READ_KERNEL_PARAMS(float))
{
    READ_KERNEL_GUARD

#define SUPPORTED_FORMATS(PROC) \
    PROC(R5G6B5_UNORM)          \
    PROC(R8G8B8A8_UNORM)        \
    PROC(R8G8B8A8_UNORM_SRGB)   \
    PROC(R8G8B8A8_SNORM)        \
    PROC(B8G8R8A8_UNORM)        \
    PROC(B8G8R8A8_UNORM_SRGB)   \
    PROC(R8G8B8_UNORM)          \
    PROC(R8G8B8_UNORM_SRGB)     \
    PROC(R8G8B8_SNORM)          \
    PROC(L8_UNORM)              \
    PROC(L8A8_UNORM)            \
    PROC(R5G5B5A1_UNORM)        \
    PROC(R4G4B4A4_UNORM)        \
    PROC(R8_UNORM)              \
    PROC(R8_SNORM)              \
    PROC(R8G8_UNORM)            \
    PROC(R8G8_SNORM)            \
    PROC(R16_FLOAT)             \
    PROC(A16_FLOAT)             \
    PROC(L16_FLOAT)             \
    PROC(L16A16_FLOAT)          \
    PROC(R16G16_FLOAT)          \
    PROC(R16G16B16A16_FLOAT)    \
    PROC(R32_FLOAT)             \
    PROC(A32_FLOAT)             \
    PROC(L32_FLOAT)             \
    PROC(L32A32_FLOAT)          \
    PROC(R32G32_FLOAT)          \
    PROC(R32G32B32A32_FLOAT)

    uint bufferOffset = CALC_BUFFER_READ_OFFSET(options.pixelSize);

    switch (kCopyFormatType)
    {
        SUPPORTED_FORMATS(READ_FORMAT_SWITCH_CASE)
    }

#undef SUPPORTED_FORMATS
}

kernel void readFromBufferToIntTexture(COMMON_READ_KERNEL_PARAMS(int))
{
    READ_KERNEL_GUARD

#define SUPPORTED_FORMATS(PROC) \
    PROC(R8_SINT)               \
    PROC(R8G8_SINT)             \
    PROC(R8G8B8A8_SINT)         \
    PROC(R16_SINT)              \
    PROC(R16G16_SINT)           \
    PROC(R16G16B16A16_SINT)     \
    PROC(R32_SINT)              \
    PROC(R32G32_SINT)           \
    PROC(R32G32B32A32_SINT)

    uint bufferOffset = CALC_BUFFER_READ_OFFSET(options.pixelSize);

    switch (kCopyFormatType)
    {
        SUPPORTED_FORMATS(READ_FORMAT_SWITCH_CASE)
    }

#undef SUPPORTED_FORMATS
}

kernel void readFromBufferToUIntTexture(COMMON_READ_KERNEL_PARAMS(uint))
{
    READ_KERNEL_GUARD

#define SUPPORTED_FORMATS(PROC) \
    PROC(R8_UINT)               \
    PROC(R8G8_UINT)             \
    PROC(R8G8B8A8_UINT)         \
    PROC(R16_UINT)              \
    PROC(R16G16_UINT)           \
    PROC(R16G16B16A16_UINT)     \
    PROC(R32_UINT)              \
    PROC(R32G32_UINT)           \
    PROC(R32G32B32A32_UINT)

    uint bufferOffset = CALC_BUFFER_READ_OFFSET(options.pixelSize);

    switch (kCopyFormatType)
    {
        SUPPORTED_FORMATS(READ_FORMAT_SWITCH_CASE)
    }

#undef SUPPORTED_FORMATS
}

// Copy pixels from texture to buffer
kernel void writeFromFloatTextureToBuffer(COMMON_WRITE_KERNEL_PARAMS(float))
{
    WRITE_KERNEL_GUARD

#define SUPPORTED_FORMATS(PROC) \
    PROC(R5G6B5_UNORM)          \
    PROC(R8G8B8A8_UNORM)        \
    PROC(R8G8B8A8_UNORM_SRGB)   \
    PROC(R8G8B8A8_SNORM)        \
    PROC(B8G8R8A8_UNORM)        \
    PROC(B8G8R8A8_UNORM_SRGB)   \
    PROC(R8G8B8_UNORM)          \
    PROC(R8G8B8_UNORM_SRGB)     \
    PROC(R8G8B8_SNORM)          \
    PROC(L8_UNORM)              \
    PROC(A8_UNORM)              \
    PROC(L8A8_UNORM)            \
    PROC(R5G5B5A1_UNORM)        \
    PROC(R4G4B4A4_UNORM)        \
    PROC(R8_UNORM)              \
    PROC(R8_SNORM)              \
    PROC(R8G8_UNORM)            \
    PROC(R8G8_SNORM)            \
    PROC(R16_FLOAT)             \
    PROC(A16_FLOAT)             \
    PROC(L16_FLOAT)             \
    PROC(L16A16_FLOAT)          \
    PROC(R16G16_FLOAT)          \
    PROC(R16G16B16A16_FLOAT)    \
    PROC(R32_FLOAT)             \
    PROC(A32_FLOAT)             \
    PROC(L32_FLOAT)             \
    PROC(L32A32_FLOAT)          \
    PROC(R32G32_FLOAT)          \
    PROC(R32G32B32A32_FLOAT)

    uint bufferOffset = CALC_BUFFER_WRITE_OFFSET(options.pixelSize);

    switch (kCopyFormatType)
    {
        SUPPORTED_FORMATS(WRITE_FORMAT_SWITCH_CASE)
    }

#undef SUPPORTED_FORMATS
}

kernel void writeFromIntTextureToBuffer(COMMON_WRITE_KERNEL_PARAMS(int))
{
    WRITE_KERNEL_GUARD

#define SUPPORTED_FORMATS(PROC) \
    PROC(R8_SINT)               \
    PROC(R8G8_SINT)             \
    PROC(R8G8B8A8_SINT)         \
    PROC(R16_SINT)              \
    PROC(R16G16_SINT)           \
    PROC(R16G16B16A16_SINT)     \
    PROC(R32_SINT)              \
    PROC(R32G32_SINT)           \
    PROC(R32G32B32A32_SINT)

    uint bufferOffset = CALC_BUFFER_WRITE_OFFSET(options.pixelSize);

    switch (kCopyFormatType)
    {
        SUPPORTED_FORMATS(WRITE_FORMAT_SWITCH_CASE)
    }

#undef SUPPORTED_FORMATS
}

kernel void writeFromUIntTextureToBuffer(COMMON_WRITE_KERNEL_PARAMS(uint))
{
    WRITE_KERNEL_GUARD

#define SUPPORTED_FORMATS(PROC) \
    PROC(R8_UINT)               \
    PROC(R8G8_UINT)             \
    PROC(R8G8B8A8_UINT)         \
    PROC(R16_UINT)              \
    PROC(R16G16_UINT)           \
    PROC(R16G16B16A16_UINT)     \
    PROC(R32_UINT)              \
    PROC(R32G32_UINT)           \
    PROC(R32G32B32A32_UINT)

    uint bufferOffset = CALC_BUFFER_WRITE_OFFSET(options.pixelSize);

    switch (kCopyFormatType)
    {
        SUPPORTED_FORMATS(WRITE_FORMAT_SWITCH_CASE)
    }

#undef SUPPORTED_FORMATS
}