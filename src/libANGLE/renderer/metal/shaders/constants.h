//
// Copyright 2020 The ANGLE Project. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// constants.h: Declare some constant values to be used by metal defaultshaders.

#ifndef LIBANGLE_RENDERER_METAL_SHADERS_ENUM_H_
#define LIBANGLE_RENDERER_METAL_SHADERS_ENUM_H_

#if !defined(__METAL_VERSION__)
#    define constant constexpr
#endif

namespace rx
{
namespace mtl_shader
{

constant int kTextureType2D            = 0;
constant int kTextureType2DMultisample = 1;
constant int kTextureType2DArray       = 2;
constant int kTextureTypeCube          = 3;
constant int kTextureType3D            = 4;
constant int kTextureTypeCount         = 5;

// Metal doesn't support constexpr to be used as array size, so we need to use macro here
#define kGenerateMipThreadGroupSizePerDim 8

}  // namespace mtl_shader
}  // namespace rx

#endif