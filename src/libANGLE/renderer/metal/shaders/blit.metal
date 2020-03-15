//
// Copyright 2019 The ANGLE Project. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// blit.metal: Implements blitting texture content to current frame buffer.

#include "common.h"

struct BlitParams
{
    // 0: lower left, 1: lower right, 2: upper left, 3: upper right
    float2 srcTexCoords[4];
    int srcLevel;
    bool srcLuminance;  // source texture is luminance texture. Unused by depth & stencil blitting.
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
    output.texCoords = options.srcTexCoords[gTexcoordsIndices[vid]];

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

float4 blitSampleTexture(texture2d<float> srcTexture,
                         sampler textureSampler,
                         float2 texCoords,
                         constant BlitParams &options)
{
    float4 output = srcTexture.sample(textureSampler, texCoords, level(options.srcLevel));

    if (options.srcLuminance)
    {
        output.gb = float2(output.r, output.r);
    }

    return output;
}

float4 blitSampleTextureMS(texture2d_ms<float> srcTexture,
                           float2 texCoords,
                           constant BlitParams &options)
{
    uint2 dimens(srcTexture.get_width(), srcTexture.get_height());
    uint samples = srcTexture.get_num_samples();
    uint2 coords = uint2(texCoords * float2(dimens));

    float4 output(0);

    for (uint sample = 0; sample < samples; ++sample)
    {
        output += srcTexture.read(coords, sample);
    }

    output *= 1.0 / samples;

    return output;
}

MultipleColorOutputs blitOutput(float4 color, constant BlitParams &options)
{
    float4 ret = color;

    if (options.dstLuminance)
    {
        ret.r = ret.g = ret.b = color.r;
    }

    return toMultipleColorOutputs(ret);
}

fragment MultipleColorOutputs blitFS(BlitVSOut input [[stage_in]],
                                     texture2d<float> srcTexture [[texture(0)]],
                                     sampler textureSampler [[sampler(0)]],
                                     constant BlitParams &options [[buffer(0)]])
{
    return blitOutput(blitSampleTexture(srcTexture, textureSampler, input.texCoords, options),
                      options);
}

fragment MultipleColorOutputs blitMultisampleFS(BlitVSOut input [[stage_in]],
                                                texture2d_ms<float> srcTexture [[texture(0)]],
                                                constant BlitParams &options [[buffer(0)]])
{
    return blitOutput(blitSampleTextureMS(srcTexture, input.texCoords, options), options);
}

fragment MultipleColorOutputs blitPremultiplyAlphaFS(BlitVSOut input [[stage_in]],
                                                     texture2d<float> srcTexture [[texture(0)]],
                                                     sampler textureSampler [[sampler(0)]],
                                                     constant BlitParams &options [[buffer(0)]])
{
    float4 output = blitSampleTexture(srcTexture, textureSampler, input.texCoords, options);
    output.xyz *= output.a;
    return blitOutput(output, options);
}

fragment MultipleColorOutputs blitMultisamplePremultiplyAlphaFS(BlitVSOut input [[stage_in]],
                                                                texture2d_ms<float> srcTexture
                                                                [[texture(0)]],
                                                                constant BlitParams &options
                                                                [[buffer(0)]])
{
    float4 output = blitSampleTextureMS(srcTexture, input.texCoords, options);
    output.xyz *= output.a;
    return blitOutput(output, options);
}

fragment MultipleColorOutputs blitUnmultiplyAlphaFS(BlitVSOut input [[stage_in]],
                                                    texture2d<float> srcTexture [[texture(0)]],
                                                    sampler textureSampler [[sampler(0)]],
                                                    constant BlitParams &options [[buffer(0)]])
{
    float4 output = blitSampleTexture(srcTexture, textureSampler, input.texCoords, options);
    if (output.a != 0.0)
    {
        output.xyz *= 1.0 / output.a;
    }
    return blitOutput(output, options);
}

fragment MultipleColorOutputs blitMultisampleUnmultiplyAlphaFS(BlitVSOut input [[stage_in]],
                                                               texture2d_ms<float> srcTexture
                                                               [[texture(0)]],
                                                               constant BlitParams &options
                                                               [[buffer(0)]])
{
    float4 output = blitSampleTextureMS(srcTexture, input.texCoords, options);
    if (output.a != 0.0)
    {
        output.xyz *= 1.0 / output.a;
    }
    return blitOutput(output, options);
}

// Depth & stencil blitting
template <typename T>
T blitSampleDepthOrStencil(texture2d<T> srcTexture, float2 texCoords, constant BlitParams &options)
{
    constexpr sampler textureSampler(mag_filter::nearest, min_filter::nearest);
    T output = srcTexture.sample(textureSampler, texCoords, level(options.srcLevel)).r;

    return output;
}

struct FragmentDepthOut
{
    float depth [[depth(any)]];
};

fragment FragmentDepthOut blitDepthFS(BlitVSOut input [[stage_in]],
                                      texture2d<float> srcTexture [[texture(0)]],
                                      constant BlitParams &options [[buffer(0)]])
{
    FragmentDepthOut re;
    re.depth = blitSampleDepthOrStencil(srcTexture, input.texCoords, options);
    return re;
}

#if __METAL_VERSION__ >= 210 || defined GENERATE_SOURCE_STRING
struct FragmentStencilOut
{
    uint32_t stencil [[stencil]];
};

struct FragmentDepthStencilOut
{
    float depth [[depth(any)]];
    uint32_t stencil [[stencil]];
};

fragment FragmentStencilOut blitStencilFS(BlitVSOut input [[stage_in]],
                                          texture2d<uint32_t> srcTexture [[texture(1)]],
                                          constant BlitParams &options [[buffer(0)]])
{
    FragmentStencilOut re;
    re.stencil = blitSampleDepthOrStencil(srcTexture, input.texCoords, options);
    return re;
}
fragment FragmentDepthStencilOut blitDepthDepthFS(BlitVSOut input [[stage_in]],
                                                  texture2d<float> srcDepthTexture [[texture(0)]],
                                                  texture2d<uint32_t> srcStencilTexture
                                                  [[texture(1)]],
                                                  constant BlitParams &options [[buffer(0)]])
{
    FragmentDepthStencilOut re;
    re.depth   = blitSampleDepthOrStencil(srcDepthTexture, input.texCoords, options);
    re.stencil = blitSampleDepthOrStencil(srcStencilTexture, input.texCoords, options);
    return re;
}
#endif
