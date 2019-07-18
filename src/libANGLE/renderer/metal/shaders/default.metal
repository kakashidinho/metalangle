//
// Copyright (c) 2019 The ANGLE Project. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

constant float2 gCorners[6] =
{
    float2(-1.0f,  1.0f),
    float2( 1.0f, -1.0f),
    float2(-1.0f, -1.0f),
    float2(-1.0f,  1.0f),
    float2( 1.0f,  1.0f),
    float2( 1.0f, -1.0f),
};

constant int gTexcoordsIndices[6] =
{
    2,
    1,
    0,
    2,
    3,
    1
};

struct ClearParams
{
    float4 clearColor;
    float clearDepth;
};

struct BlitParams
{
    // 0: lower left, 1: lower right, 2: upper left, 3: upper right
    float2 srcTexCoords[4];
    int srcLevel;
    bool srcLuminance; // source texture is luminance texture
    bool dstFlipY;
    bool dstLuminance; // destination texture is luminance;
};

struct BlitVSOut
{
    float4 position [[position]];
    float2 texCoords [[user(locn1)]];
};

vertex float4 clearVS(unsigned int vid [[ vertex_id ]],
                      constant ClearParams &clearParams [[buffer(0)]])
{
    return float4(gCorners[vid], clearParams.clearDepth, 1.0);
}

fragment float4 clearFS(constant ClearParams &clearParams [[buffer(0)]])
{
    return clearParams.clearColor;
}

vertex BlitVSOut blitVS(unsigned int vid [[ vertex_id ]],
                         constant BlitParams &options [[buffer(0)]])
{
    BlitVSOut output;
    output.position = float4(gCorners[vid], 0.0, 1.0);
    output.texCoords = options.srcTexCoords[gTexcoordsIndices[vid]];

    if (options.dstFlipY)
    {
        output.position = -output.position;
    }

    return output;
}

float4 sampleTexture(texture2d<float> srcTexture,
                     float2 texCoords,
                     constant BlitParams &options)
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    float4 output = srcTexture.sample(textureSampler, texCoords, level(options.srcLevel));

    if (options.srcLuminance)
    {
        output.gb = float2(output.r, output.r);
    }

    return output;
}

float4 blitOutput(float4 color, constant BlitParams &options)
{
    float4 ret = color;

    if (options.dstLuminance)
    {
        ret.r = ret.g = ret.b = (color.r * 0.3) + (color.g * 0.59) + (color.b * 0.11);
    }

    return ret;
}

fragment float4 blitFS(BlitVSOut input [[stage_in]],
                       texture2d<float> srcTexture [[texture(0)]],
                       constant BlitParams &options [[buffer(0)]])
{
    return blitOutput(sampleTexture(srcTexture, input.texCoords, options), options);
}

fragment float4 blitPremultiplyAlphaFS(BlitVSOut input [[stage_in]],
                                       texture2d<float> srcTexture [[texture(0)]],
                                       constant BlitParams &options [[buffer(0)]])
{
    float4 output = sampleTexture(srcTexture, input.texCoords, options);
    output.xyz *= output.a;
    return blitOutput(output, options);
}

fragment float4 blitUnmultiplyAlphaFS(BlitVSOut input [[stage_in]],
                                      texture2d<float> srcTexture [[texture(0)]],
                                      constant BlitParams &options [[buffer(0)]])
{
    float4 output = sampleTexture(srcTexture, input.texCoords, options);
    if (output.a != 0.0)
    {
        output.xyz *= 1.0 / output.a;
    }
    return blitOutput(output, options);
}