//
// Copyright 2019 The ANGLE Project. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// blit.metal: Implements blitting texture content to current frame buffer.

#include "common.h"

using namespace rx::mtl_shader;

// function_constant(0) is already used by common.h
constant bool kPremultiplyAlpha [[function_constant(1)]];
constant bool kUnmultiplyAlpha [[function_constant(2)]];
constant int kSourceTextureType [[function_constant(3)]];   // Source color/depth texture type.
constant int kSourceTexture2Type [[function_constant(4)]];  // Source stencil texture type.
constant bool kSourceTextureType2D      = kSourceTextureType == kTextureType2D;
constant bool kSourceTextureType2DArray = kSourceTextureType == kTextureType2DArray;
constant bool kSourceTextureType2DMS    = kSourceTextureType == kTextureType2DMultisample;
constant bool kSourceTextureTypeCube    = kSourceTextureType == kTextureTypeCube;
constant bool kSourceTextureType3D      = kSourceTextureType == kTextureType3D;

struct BlitParams
{
    // 0: lower left, 1: lower right, 2: upper left
    float2 srcTexCoords[3];
    int srcLevel;   // Source texture level. Used for color & depth blitting.
    int srcLayer;   // Source texture layer. Used for color & depth blitting.
    int srcLevel2;  // Second source level. Used for stencil blitting.
    int srcLayer2;  // Second source layer. Used for stencil blitting.
    bool dstFlipViewportX;
    bool dstFlipViewportY;
    bool dstLuminance;  // destination texture is luminance. Unused by depth & stencil blitting.
};

struct BlitVSOut
{
    float4 position [[position]];
    float2 texCoords [[user(locn1)]];
};

vertex BlitVSOut blitVS(unsigned int vid [[vertex_id]], constant BlitParams &options [[buffer(0)]])
{
    BlitVSOut output;
    output.position  = float4(gCorners[vid], 0.0, 1.0);
    output.texCoords = options.srcTexCoords[vid];

    if (options.dstFlipViewportX)
    {
        output.position.x = -output.position.x;
    }
    if (!options.dstFlipViewportY)
    {
        // If viewport is not flipped, we have to flip Y in normalized device coordinates.
        // Since NDC has Y is opposite direction of viewport coodrinates.
        output.position.y = -output.position.y;
    }

    return output;
}

template <typename T>
static inline vec<T, 4> blitSampleTextureMS(texture2d_ms<T> srcTexture, float2 texCoords)
{
    uint2 dimens(srcTexture.get_width(), srcTexture.get_height());
    uint samples = srcTexture.get_num_samples();
    uint2 coords = uint2(texCoords * float2(dimens));

    vec<T, 4> output(0);

    for (uint sample = 0; sample < samples; ++sample)
    {
        output += srcTexture.read(coords, sample);
    }

    output = output / samples;

    return output;
}

template <typename T>
static inline vec<T, 4> blitSampleTexture3D(texture3d<T> srcTexture,
                                            sampler textureSampler,
                                            float2 texCoords,
                                            constant BlitParams &options)
{
    uint depth   = srcTexture.get_depth(options.srcLevel);
    float zCoord = (float(options.srcLayer) + 0.5) / float(depth);

    return srcTexture.sample(textureSampler, float3(texCoords, zCoord), level(options.srcLevel));
}

fragment MultipleColorOutputs
blitFS(BlitVSOut input [[stage_in]],
       texture2d<float> srcTexture2d [[texture(0), function_constant(kSourceTextureType2D)]],
       texture2d_array<float> srcTexture2dArray
       [[texture(0), function_constant(kSourceTextureType2DArray)]],
       texture2d_ms<float> srcTexture2dMS [[texture(0), function_constant(kSourceTextureType2DMS)]],
       texturecube<float> srcTextureCube [[texture(0), function_constant(kSourceTextureTypeCube)]],
       texture3d<float> srcTexture3d [[texture(0), function_constant(kSourceTextureType3D)]],
       sampler textureSampler [[sampler(0)]],
       constant BlitParams &options [[buffer(0)]])
{
    float4 output;

    switch (kSourceTextureType)
    {
        case kTextureType2D:
            output = srcTexture2d.sample(textureSampler, input.texCoords, level(options.srcLevel));
            break;
        case kTextureType2DArray:
            output = srcTexture2dArray.sample(textureSampler, input.texCoords, options.srcLayer,
                                              level(options.srcLevel));
            break;
        case kTextureType2DMultisample:
            output = blitSampleTextureMS(srcTexture2dMS, input.texCoords);
            break;
        case kTextureTypeCube:
            output = srcTextureCube.sample(textureSampler,
                                           cubeTexcoords(input.texCoords, options.srcLayer),
                                           level(options.srcLevel));
            break;
        case kTextureType3D:
            output = blitSampleTexture3D(srcTexture3d, textureSampler, input.texCoords, options);
            break;
    }

    if (kPremultiplyAlpha)
    {
        output.xyz *= output.a;
    }
    else if (kUnmultiplyAlpha)
    {
        if (output.a != 0.0)
        {
            output.xyz *= 1.0 / output.a;
        }
    }

    if (options.dstLuminance)
    {
        output.g = output.b = output.r;
    }

    return toMultipleColorOutputs(output);
}

// Depth & stencil blitting.
// NOTE(hqle): MS & 3d depth/stencil texture are not supported yet.
struct FragmentDepthOut
{
    float depth [[depth(any)]];
};

float sampleDepth(texture2d<float> srcTexture2d [[function_constant(kSourceTextureType2D)]],
                  texture2d_array<float> srcTexture2dArray
                  [[function_constant(kSourceTextureType2DArray)]],
                  texturecube<float> srcTextureCube [[function_constant(kSourceTextureTypeCube)]],
                  float2 texCoords,
                  constant BlitParams &options)
{
    float4 output;

    constexpr sampler textureSampler(mag_filter::nearest, min_filter::nearest);

    switch (kSourceTextureType)
    {
        case kTextureType2D:
            output = srcTexture2d.sample(textureSampler, texCoords, level(options.srcLevel));
            break;
        case kTextureType2DArray:
            output = srcTexture2dArray.sample(textureSampler, texCoords, options.srcLayer,
                                              level(options.srcLevel));
            break;
        case kTextureTypeCube:
            output =
                srcTextureCube.sample(textureSampler, cubeTexcoords(texCoords, options.srcLayer),
                                      level(options.srcLevel));
            break;
    }

    return output.r;
}

fragment FragmentDepthOut blitDepthFS(BlitVSOut input [[stage_in]],
                                      texture2d<float> srcTexture2d
                                      [[texture(0), function_constant(kSourceTextureType2D)]],
                                      texture2d_array<float> srcTexture2dArray
                                      [[texture(0), function_constant(kSourceTextureType2DArray)]],
                                      texturecube<float> srcTextureCube
                                      [[texture(0), function_constant(kSourceTextureTypeCube)]],
                                      constant BlitParams &options [[buffer(0)]])
{
    FragmentDepthOut re;

    re.depth =
        sampleDepth(srcTexture2d, srcTexture2dArray, srcTextureCube, input.texCoords, options);

    return re;
}

#if __METAL_VERSION__ >= 210 || defined GENERATE_SOURCE_STRING

constant bool kSourceTexture2Type2D      = kSourceTexture2Type == kTextureType2D;
constant bool kSourceTexture2Type2DArray = kSourceTexture2Type == kTextureType2DArray;
constant bool kSourceTexture2TypeCube    = kSourceTexture2Type == kTextureTypeCube;

struct FragmentStencilOut
{
    uint32_t stencil [[stencil]];
};

struct FragmentDepthStencilOut
{
    float depth [[depth(any)]];
    uint32_t stencil [[stencil]];
};

uint32_t sampleStencil(texture2d<uint32_t> srcTexture2d
                       [[function_constant(kSourceTexture2Type2D)]],
                       texture2d_array<uint32_t> srcTexture2dArray
                       [[function_constant(kSourceTexture2Type2DArray)]],
                       texturecube<uint32_t> srcTextureCube
                       [[function_constant(kSourceTexture2TypeCube)]],
                       float2 texCoords,
                       constant BlitParams &options)
{
    uint4 output;
    constexpr sampler textureSampler(mag_filter::nearest, min_filter::nearest);

    switch (kSourceTexture2Type)
    {
        case kTextureType2D:
            output = srcTexture2d.sample(textureSampler, texCoords, level(options.srcLevel));
            break;
        case kTextureType2DArray:
            output = srcTexture2dArray.sample(textureSampler, texCoords, options.srcLayer,
                                              level(options.srcLevel));
            break;
        case kTextureTypeCube:
            output =
                srcTextureCube.sample(textureSampler, cubeTexcoords(texCoords, options.srcLayer),
                                      level(options.srcLevel));
            break;
    }

    return output.r;
}

fragment FragmentStencilOut blitStencilFS(
    BlitVSOut input [[stage_in]],
    texture2d<uint32_t> srcTexture2d [[texture(1), function_constant(kSourceTexture2Type2D)]],
    texture2d_array<uint32_t> srcTexture2dArray
    [[texture(1), function_constant(kSourceTexture2Type2DArray)]],
    texturecube<uint32_t> srcTextureCube [[texture(1), function_constant(kSourceTexture2TypeCube)]],
    constant BlitParams &options [[buffer(0)]])
{
    FragmentStencilOut re;

    re.stencil =
        sampleStencil(srcTexture2d, srcTexture2dArray, srcTextureCube, input.texCoords, options);

    return re;
}

fragment FragmentDepthStencilOut blitDepthStencilFS(
    BlitVSOut input [[stage_in]],
    // Source depth texture
    texture2d<float> srcDepthTexture2d [[texture(0), function_constant(kSourceTextureType2D)]],
    texture2d_array<float> srcDepthTexture2dArray
    [[texture(0), function_constant(kSourceTextureType2DArray)]],
    texturecube<float> srcDepthTextureCube
    [[texture(0), function_constant(kSourceTextureTypeCube)]],

    // Source stencil texture
    texture2d<uint32_t> srcStencilTexture2d
    [[texture(1), function_constant(kSourceTexture2Type2D)]],
    texture2d_array<uint32_t> srcStencilTexture2dArray
    [[texture(1), function_constant(kSourceTexture2Type2DArray)]],
    texturecube<uint32_t> srcStencilTextureCube
    [[texture(1), function_constant(kSourceTexture2TypeCube)]],
    constant BlitParams &options [[buffer(0)]])
{
    FragmentDepthStencilOut re;

    re.depth   = sampleDepth(srcDepthTexture2d, srcDepthTexture2dArray, srcDepthTextureCube,
                           input.texCoords, options);
    re.stencil = sampleStencil(srcStencilTexture2d, srcStencilTexture2dArray, srcStencilTextureCube,
                               input.texCoords, options);
    return re;
}
#endif
