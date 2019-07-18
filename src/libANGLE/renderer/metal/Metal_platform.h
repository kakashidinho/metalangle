//
// Copyright (c) 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#ifndef LIBANGLE_RENDERER_METAL_METAL_PLATFORM_H_
#define LIBANGLE_RENDERER_METAL_METAL_PLATFORM_H_

#import <Metal/Metal.h>
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CAMetalLayer.h>
#include <TargetConditionals.h>

#if TARGET_OS_IPHONE
#    if !defined(ANGLE_IOS_DEPLOY_TARGET)
#        define ANGLE_IOS_DEPLOY_TARGET __IPHONE_11_0
#    endif
#endif

// Don't allow separated depth stencil buffers
#define ANGLE_MTL_ALLOW_SEPARATED_DEPTH_STENCIL 0

#define ANGLE_MTL_OBJC_SCOPE @autoreleasepool

#if !__has_feature(objc_arc)
#    define ANGLE_MTL_WEAK
#    define ANGLE_MTL_AUTORELEASE autorelease
#else
#    define ANGLE_MTL_WEAK __weak
#    define ANGLE_MTL_AUTORELEASE self
#endif

// Xcode SDK contains FixedToFloat macro, it conflicts with FixedToFloat() function
// defined in common/mathutil.h
#ifdef FixedToFloat
#    define FixedToFloat_Backup FixedToFloat
#    undef FixedToFloat
#endif

#ifdef FloatToFixed
#    define FloatToFixed_Backup FloatToFixed
#    undef FloatToFixed
#endif

#include "common/mathutil.h"

#endif /* LIBANGLE_RENDERER_METAL_METAL_PLATFORM_H_ */
