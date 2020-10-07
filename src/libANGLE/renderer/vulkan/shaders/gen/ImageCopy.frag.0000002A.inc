// GENERATED FILE - DO NOT EDIT.
// Generated by gen_vk_internal_shaders.py.
//
// Copyright 2020 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// shaders/gen/ImageCopy.frag.0000002A.inc:
//   Pre-generated shader for the ANGLE Vulkan back-end.

#pragma once
constexpr uint8_t kImageCopy_frag_0000002A[] = {
    0x1f,0x8b,0x08,0x00,0x00,0x00,0x00,0x00,0x02,0xff,0x85,0x96,0x8d,0x53,0x94,0x55,
    0x14,0x87,0x5f,0x76,0x61,0x17,0x41,0x04,0x01,0x25,0x54,0x2c,0x51,0xfa,0x10,0x43,
    0x2c,0x30,0x12,0x50,0xc9,0x48,0x32,0x4a,0x41,0xb3,0x12,0xcb,0x48,0x12,0x2d,0xa4,
    0x12,0x33,0x4d,0xcb,0x0f,0x4c,0x49,0x4b,0x2b,0x29,0x3f,0xfa,0x12,0x2b,0xd1,0x54,
    0xd4,0xfa,0x23,0xfa,0x8b,0x9a,0x3e,0x66,0x9a,0xe9,0x9e,0x77,0x9f,0xc3,0xfc,0xda,
    0xb1,0xda,0x99,0x3b,0xfb,0xde,0xe7,0x9c,0x7b,0xee,0xef,0x9c,0x7b,0xdf,0xb3,0x9b,
    0x4c,0xcc,0x4f,0x47,0x51,0x4e,0x54,0x10,0xe5,0x47,0x3f,0x47,0x99,0xcf,0xf4,0x28,
    0x11,0x48,0x14,0x15,0x46,0xa9,0xf8,0x7b,0x75,0xe7,0xfa,0xce,0xba,0xa1,0xdd,0x7d,
    0x75,0x0d,0x8d,0xf5,0x66,0x9f,0x16,0x25,0x63,0x3f,0xb3,0x15,0x47,0xe9,0x28,0x37,
    0x7c,0xdb,0xd8,0xd9,0xbb,0x63,0xd0,0x78,0x51,0x18,0xb7,0xc3,0x28,0x09,0x7e,0xc6,
    0xd3,0x16,0x23,0x3c,0x15,0xc5,0x31,0x6d,0x4d,0x14,0x75,0x44,0x79,0x51,0x19,0xfb,
    0xcd,0xe7,0xdb,0x59,0x0e,0x2c,0x5f,0x58,0x02,0x56,0x22,0x2c,0x09,0x2b,0x17,0x96,
    0x0b,0xbb,0x4b,0x58,0x1e,0x6c,0x8e,0xb0,0x14,0xec,0x1e,0x61,0x69,0xd8,0x02,0x61,
    0xf9,0xb0,0xfb,0x85,0x4d,0x81,0x2d,0x12,0x56,0x00,0xab,0x17,0x56,0x08,0x6b,0x10,
    0x36,0x15,0xd6,0x24,0xac,0x08,0xd6,0x12,0xd7,0x29,0x39,0x99,0xaf,0xd5,0x6c,0x55,
    0xf8,0xae,0xa6,0x3e,0x3e,0x9f,0x27,0x73,0xab,0xf3,0x5c,0xe6,0x65,0x61,0x55,0x22,
    0xb6,0x27,0xe3,0xda,0xd8,0xf3,0x8c,0xe0,0x93,0x22,0x4f,0xab,0x6b,0x45,0x98,0xa7,
    0xc9,0x3f,0x11,0xf3,0xdc,0x38,0xc7,0x34,0x63,0x66,0x58,0x59,0x80,0xbf,0xf9,0x16,
    0x92,0x5b,0x2e,0xbe,0x53,0x89,0x63,0xbc,0x99,0x79,0x91,0xc4,0x9e,0x86,0xbf,0xef,
    0x5d,0x4a,0xac,0x28,0xd6,0x59,0x32,0x59,0x67,0xd7,0x60,0xa3,0xf4,0x7f,0x86,0xfb,
    0xd8,0xfe,0xe5,0xd4,0xbf,0x8c,0xfd,0xcb,0xe3,0x7d,0x32,0xac,0x96,0x5c,0x67,0xa2,
    0xc7,0xfc,0x2b,0xb0,0xa5,0xc5,0x5e,0x25,0xf9,0xcc,0xc5,0x5e,0x1a,0xdf,0xa3,0x44,
    0x5c,0xdb,0x5a,0x74,0x7b,0xdd,0xcd,0xef,0x5e,0xd1,0xec,0x71,0x6a,0xb9,0x5b,0xee,
    0xbf,0x84,0x7d,0xdd,0xbe,0x94,0xda,0x58,0x5d,0x96,0xb3,0x87,0xef,0xbb,0x82,0x78,
    0xc6,0x2b,0x83,0x82,0x36,0xec,0x89,0xe8,0x9f,0x9f,0x1c,0xd1,0xf0,0x18,0xcf,0x6d,
    0xe4,0x6e,0xf3,0x55,0x30,0xdf,0xb3,0x3d,0x6b,0xbe,0x86,0xf7,0xc4,0xd6,0x3f,0x45,
    0xae,0x29,0x34,0x3d,0xc3,0x73,0x52,0xfc,0xbb,0xd1,0xe0,0xf3,0x8d,0x92,0xb3,0xe9,
    0xdb,0x2c,0xf1,0x5e,0x24,0x87,0x52,0xe2,0xbd,0xcc,0xb3,0xc6,0xdb,0x9e,0x55,0xfb,
    0x61,0xde,0x29,0xf3,0xff,0x50,0x72,0x76,0xfb,0xe9,0xac,0xb3,0xbc,0xc0,0x3b,0xe3,
    0xfb,0x5f,0x91,0x7b,0x7b,0x8b,0xbd,0x96,0x53,0x8f,0x5b,0xf4,0x9d,0x64,0x5c,0xfb,
    0xbc,0xd8,0x2f,0x97,0x7a,0x18,0xfb,0x3d,0x90,0x3c,0x7c,0xf3,0xe5,0x5e,0xf8,0x7c,
    0xb6,0xcc,0xed,0x7c,0x56,0x66,0xcd,0x0f,0xc8,0xdc,0xee,0xc3,0x79,0xe6,0xad,0xbc,
    0x27,0xc5,0x9c,0xf7,0xda,0x40,0xa7,0xd1,0xab,0x8a,0x19,0x7e,0x96,0x83,0xbc,0x7f,
    0xd3,0xb1,0xb7,0x05,0x45,0x15,0xf4,0xab,0x19,0xdc,0xdd,0x56,0x7c,0x2a,0xe1,0x47,
    0x82,0x8f,0xcd,0x67,0xb1,0xae,0x32,0xce,0x39,0x19,0xeb,0x9f,0x25,0xfe,0x73,0xc8,
    0xc9,0x6c,0xb3,0x99,0x5b,0x7c,0xbb,0xe3,0x77,0x13,0xbf,0x0a,0x7f,0x7f,0x2f,0x8d,
    0x5f,0x0b,0x3e,0xf3,0xa4,0x1f,0xda,0xbd,0xff,0x2d,0xc4,0xa8,0x41,0xf7,0x9f,0xc1,
    0xdf,0xfb,0x62,0x0d,0x75,0x5c,0x40,0x6c,0xab,0xc3,0x7d,0xd4,0xae,0x9a,0xd8,0x29,
    0xfa,0xa5,0xf1,0xf7,0x99,0x3f,0x00,0xf3,0x35,0x0b,0x65,0x8d,0xe9,0x5d,0x88,0xcf,
    0x1f,0x21,0xb6,0xef,0x51,0x23,0xfa,0x17,0xa1,0xbf,0x56,0xf4,0x3f,0x08,0x77,0xfd,
    0x75,0x30,0xd7,0x5f,0x2f,0xfa,0xcd,0xb6,0x98,0xfe,0x6c,0xb1,0x17,0x8b,0x96,0x87,
    0xd0,0xb2,0x44,0xf4,0x3f,0x0c,0x77,0xfd,0x0d,0x30,0x5f,0xd3,0x28,0x6b,0x4c,0x7f,
    0x23,0x3e,0xa6,0xdf,0xf7,0xa8,0x17,0xfd,0x8f,0xa0,0x7f,0xa9,0xe8,0x6f,0x82,0xbb,
    0xfe,0x47,0x61,0xae,0xbf,0x59,0xf4,0x9b,0x6d,0x59,0x7c,0xf7,0x32,0xb1,0x97,0xc9,
    0xb9,0xb7,0xa0,0xc5,0xee,0x5d,0xe6,0x3e,0x66,0x58,0x8b,0xf4,0x0f,0xbf,0x13,0xad,
    0x68,0xf4,0x38,0xcd,0xc4,0xb1,0x9e,0xf2,0x38,0xfd,0xc4,0xef,0xe4,0x13,0x68,0x6e,
    0x97,0xbd,0x56,0xc3,0x7d,0xde,0xc1,0xde,0x87,0xb8,0xa3,0x4f,0xe2,0xd3,0x41,0x1c,
    0xeb,0x39,0x9d,0xc4,0x59,0x23,0xf5,0x7d,0x1a,0xde,0x15,0x7c,0x52,0xb1,0xf6,0xcc,
    0xda,0x48,0xd8,0x3a,0x58,0x4e,0xfc,0x9c,0x8a,0xfb,0x55,0x17,0xbe,0xeb,0x88,0xe1,
    0x7b,0xac,0x67,0x8f,0x6e,0xd9,0x63,0x03,0x7c,0x4b,0x50,0x66,0x3d,0xe2,0x59,0x72,
    0xec,0xa2,0x87,0x6c,0xa0,0x2e,0x2b,0xb1,0xf9,0x59,0x3d,0x47,0xac,0x8d,0x72,0x56,
    0xcf,0xc3,0xfd,0xac,0x5e,0x80,0xf9,0x59,0xf5,0xc8,0x59,0x99,0x6d,0x53,0x18,0xfd,
    0xd4,0x78,0x13,0xb1,0xad,0x5f,0xbe,0x44,0x5f,0xd9,0x2c,0xb1,0xb7,0xc0,0x5b,0xf9,
    0x9d,0xe8,0xc5,0x67,0x6d,0xe8,0x4a,0xd6,0x53,0x5f,0x81,0xf5,0x4a,0x1f,0x49,0x50,
    0x13,0xb3,0x6f,0x25,0x86,0x8f,0xa3,0x61,0x2f,0xe3,0x7d,0xac,0xdd,0x2a,0xb1,0x5f,
    0x9d,0x8c,0x3d,0x25,0x9e,0x6f,0x83,0xf5,0xd1,0x2b,0xf3,0xe4,0x37,0xc1,0x6b,0xb3,
    0x8d,0x3b,0xd3,0x43,0x3e,0xfd,0x52,0xab,0x1d,0xd4,0x6a,0xbb,0xe4,0xf3,0x1a,0xdc,
    0x6b,0xf5,0x3a,0xcc,0x6b,0xb5,0x53,0x6a,0x65,0xb6,0x01,0xfb,0xef,0x48,0xec,0x01,
    0xa9,0xd5,0xe0,0x1d,0x6a,0xf5,0x06,0xfc,0x3a,0xb1,0xdf,0x84,0x55,0xa3,0xd1,0xe3,
    0xd8,0xf7,0xaf,0xe1,0xdc,0xcd,0xe7,0x2d,0x34,0xf4,0xe3,0x3f,0x80,0x8e,0x21,0xd1,
    0x61,0x3e,0xbb,0xc2,0x18,0x62,0xfd,0x2e,0xd1,0xb1,0xfb,0x0e,0x3a,0xde,0x86,0x7b,
    0x5d,0xf7,0x64,0x9d,0xd9,0x3b,0xb0,0x3d,0xff,0x72,0x66,0x7b,0x89,0xe1,0xe3,0x18,
    0x67,0xb6,0x8f,0xb5,0x7b,0x25,0xf6,0xbb,0x59,0x67,0xb6,0x1f,0xb6,0xef,0x3f,0xce,
    0x6c,0x3f,0xf5,0xf0,0x7c,0x86,0xb2,0xce,0xb0,0x47,0xe2,0xbf,0x47,0x7c,0x7b,0xef,
    0x4a,0xe3,0x9e,0x97,0x61,0x91,0xb0,0x83,0xb0,0x1c,0x61,0x87,0x60,0x09,0x61,0x87,
    0x61,0xc9,0x38,0xd7,0xcc,0x7b,0x77,0x84,0x98,0x07,0x59,0x73,0x18,0x9d,0x07,0xb0,
    0xf9,0x5d,0x3a,0xca,0x5d,0x1a,0x96,0x3a,0x7f,0x00,0xf7,0xbb,0x74,0x0c,0xe6,0x77,
    0x69,0x44,0xce,0xd0,0x6c,0xc7,0xc3,0x38,0x45,0x8e,0xc7,0x25,0xc7,0x13,0xfc,0x7e,
    0x5b,0x8f,0xb4,0xff,0x1d,0x27,0x61,0x27,0xe4,0xff,0x81,0xfb,0x7e,0x34,0xe9,0x9b,
    0xa9,0xf7,0xc7,0xb0,0x93,0x52,0xef,0x84,0xd4,0xfb,0x00,0x3e,0x56,0xdf,0x11,0xf6,
    0x3e,0x25,0x79,0x7d,0x42,0x5e,0xa7,0x25,0xaf,0x4f,0xe1,0x9e,0xd7,0x67,0x30,0xcf,
    0x6b,0x54,0xf2,0x32,0xdb,0x99,0x30,0xce,0x11,0xfb,0x8c,0xdc,0xcd,0xcf,0xd1,0xaa,
    0x77,0xf3,0x0b,0xb8,0xfb,0x9c,0xc5,0xc7,0x7f,0x6b,0xcf,0xe2,0x63,0x7a,0x47,0x89,
    0x79,0x4e,0x7a,0xe9,0x97,0xe8,0xbd,0x20,0xbd,0xf4,0x2b,0xb8,0xad,0x3f,0xcf,0xdc,
    0x6d,0x5f,0xf3,0x5f,0xe8,0x17,0xfa,0xf6,0x37,0xb0,0x6e,0xc9,0xef,0x5b,0x78,0x3b,
    0xf9,0x8d,0x49,0x7e,0x66,0xbb,0x18,0xc6,0x18,0x5a,0x2e,0x8a,0xf6,0x4b,0x68,0xf7,
    0xdf,0xd9,0x4b,0xf2,0xae,0xbb,0xff,0x98,0x68,0xf9,0x2e,0x4b,0xcb,0xf7,0xb0,0x2a,
    0xd1,0xf2,0x03,0xdc,0xb5,0x8c,0x8b,0x16,0xb3,0x5d,0x0e,0x63,0x9c,0xd8,0x97,0x45,
    0xcb,0x55,0xb4,0x5c,0x41,0xcb,0x55,0xd1,0xe2,0xfe,0xe3,0xa2,0xe5,0xc7,0x2c,0x2d,
    0xd7,0x60,0xc3,0xa2,0xe5,0x3a,0xdc,0xb5,0x4c,0x88,0x16,0xb3,0xdd,0x08,0x63,0x82,
    0xd8,0x37,0x44,0xcb,0x4d,0x39,0x77,0xd3,0x72,0x93,0x1a,0x99,0x16,0xf7,0x9f,0xc8,
    0x3a,0xe3,0xd1,0xac,0x3b,0x3a,0x22,0x77,0xfe,0x27,0xe2,0x59,0xac,0xdb,0xcc,0xff,
    0x0a,0x6f,0x7b,0x53,0x18,0x7f,0x03,0x25,0xa8,0xb0,0xba,0x24,0x10,0x00,0x00
};

// Generated from:
//
// #version 450 core
//
// #extension GL_EXT_samplerless_texture_functions : require
//
// layout(set = 0, binding = 0)uniform utexture3D src;
// layout(location = 0)out uvec4 dest;
//
// layout(push_constant)uniform PushConstants {
//
//     ivec2 srcOffset;
//     ivec2 destOffset;
//     int srcMip;
//     int srcLayer;
//
//     bool flipX;
//     bool flipY;
//
//     bool premultiplyAlpha;
//     bool unmultiplyAlpha;
//
//     bool destHasLuminance;
//     bool destIsAlpha;
//
//     bool srcIsSRGB;
//     bool destIsSRGB;
//
//     int destDefaultChannelsMask;
//     bool rotateXY;
// } params;
//
// void main()
// {
//     ivec2 destSubImageCoords = ivec2(gl_FragCoord . xy)- params . destOffset;
//
//     ivec2 srcSubImageCoords = destSubImageCoords;
//
//     if(params . flipX)
//     {
//         srcSubImageCoords . x = - srcSubImageCoords . x;
//     }
//     if(params . flipY)
//     {
//         srcSubImageCoords . y = - srcSubImageCoords . y;
//     }
//     if(params . rotateXY)
//     {
//         srcSubImageCoords . xy = srcSubImageCoords . yx;
//     }
//
//           uvec4 srcValue = texelFetch(src, ivec3(params . srcOffset + srcSubImageCoords, params . srcLayer), params . srcMip);
//
//     if(params . premultiplyAlpha)
//     {
//         srcValue . rgb *= srcValue . a;
//     }
//     else if(params . unmultiplyAlpha && srcValue . a > 0)
//     {
//         srcValue . rgb /= srcValue . a;
//     }
//
//            uvec4 destValue = uvec4(srcValue);
//
//     if(params . destHasLuminance)
//     {
//         destValue . rg = destValue . ra;
//     }
//     else if(params . destIsAlpha)
//     {
//         destValue . r = destValue . a;
//     }
//     else
//     {
//         int defaultChannelsMask = params . destDefaultChannelsMask;
//         if((defaultChannelsMask & 2)!= 0)
//         {
//             destValue . g = 0;
//         }
//         if((defaultChannelsMask & 4)!= 0)
//         {
//             destValue . b = 0;
//         }
//         if((defaultChannelsMask & 8)!= 0)
//         {
//             destValue . a = 1;
//         }
//     }
//
//     dest = destValue;
// }