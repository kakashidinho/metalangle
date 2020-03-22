//
// Copyright 2019 The ANGLE Project. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// common.h: Common header for other metal source code.

#ifndef LIBANGLE_RENDERER_METAL_SHADERS_COMMON_H_
#define LIBANGLE_RENDERER_METAL_SHADERS_COMMON_H_

#ifndef GENERATE_SOURCE_STRING
#    include <simd/simd.h>
#    include <metal_stdlib>
#endif

#include "constants.h"

#define ANGLE_KERNEL_GUARD(IDX, MAX_COUNT) \
    if (IDX >= MAX_COUNT)                  \
    {                                      \
        return;                            \
    }

using namespace metal;

// Full screen triangle's vertices
constant float2 gCorners[3] = {float2(-1.0f, -1.0f), float2(3.0f, -1.0f), float2(-1.0f, 3.0f)};

// Common constant defined number of color outputs
constant uint32_t kNumColorOutputs [[function_constant(0)]];
constant bool kColorOutputAvailable0 = kNumColorOutputs > 0;
constant bool kColorOutputAvailable1 = kNumColorOutputs > 1;
constant bool kColorOutputAvailable2 = kNumColorOutputs > 2;
constant bool kColorOutputAvailable3 = kNumColorOutputs > 3;
constant bool kColorOutputAvailable4 = kNumColorOutputs > 4;
constant bool kColorOutputAvailable5 = kNumColorOutputs > 5;
constant bool kColorOutputAvailable6 = kNumColorOutputs > 6;
constant bool kColorOutputAvailable7 = kNumColorOutputs > 7;

struct MultipleColorOutputs
{
    float4 color0 [[color(0), function_constant(kColorOutputAvailable0)]];
    float4 color1 [[color(1), function_constant(kColorOutputAvailable1)]];
    float4 color2 [[color(2), function_constant(kColorOutputAvailable2)]];
    float4 color3 [[color(3), function_constant(kColorOutputAvailable3)]];
    float4 color4 [[color(4), function_constant(kColorOutputAvailable4)]];
    float4 color5 [[color(5), function_constant(kColorOutputAvailable5)]];
    float4 color6 [[color(6), function_constant(kColorOutputAvailable6)]];
    float4 color7 [[color(7), function_constant(kColorOutputAvailable7)]];
};

#define ANGLE_ASSIGN_COLOR_OUPUT(STRUCT_VARIABLE, COLOR_INDEX, VALUE) \
    do                                                                \
    {                                                                 \
        if (kColorOutputAvailable##COLOR_INDEX)                       \
        {                                                             \
            STRUCT_VARIABLE.color##COLOR_INDEX = VALUE;               \
        }                                                             \
    } while (0)

static inline MultipleColorOutputs toMultipleColorOutputs(float4 color)
{
    MultipleColorOutputs re;

    ANGLE_ASSIGN_COLOR_OUPUT(re, 0, color);
    ANGLE_ASSIGN_COLOR_OUPUT(re, 1, color);
    ANGLE_ASSIGN_COLOR_OUPUT(re, 2, color);
    ANGLE_ASSIGN_COLOR_OUPUT(re, 3, color);
    ANGLE_ASSIGN_COLOR_OUPUT(re, 4, color);
    ANGLE_ASSIGN_COLOR_OUPUT(re, 5, color);
    ANGLE_ASSIGN_COLOR_OUPUT(re, 6, color);
    ANGLE_ASSIGN_COLOR_OUPUT(re, 7, color);

    return re;
}

static inline float3 cubeTexcoords(float2 texcoords, int face)
{
    texcoords = 2.0 * texcoords - 1.0;
    switch (face)
    {
        case 0:
            return float3(1.0, -texcoords.y, -texcoords.x);
        case 1:
            return float3(-1.0, -texcoords.y, texcoords.x);
        case 2:
            return float3(texcoords.x, 1.0, texcoords.y);
        case 3:
            return float3(texcoords.x, -1.0, -texcoords.y);
        case 4:
            return float3(texcoords.x, -texcoords.y, 1.0);
        case 5:
            return float3(-texcoords.x, -texcoords.y, -1.0);
    }
    return float3(texcoords, 0);
}

#endif /* LIBANGLE_RENDERER_METAL_SHADERS_COMMON_H_ */
