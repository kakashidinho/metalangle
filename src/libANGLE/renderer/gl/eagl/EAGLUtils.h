//
// Copyright 2021 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#ifndef LIBANGLE_RENDERER_GL_EAGL_EAGLUTILS_H_
#define LIBANGLE_RENDERER_GL_EAGL_EAGLUTILS_H_

struct CGRect;

#ifndef __OBJC__

typedef void *EAGLContextObj;
typedef void *CAEAGLLayerObj;

#else  // __OBJC__

#import <Foundation/Foundation.h>

typedef id EAGLContextObj;
typedef id CAEAGLLayerObj;

struct __IOSurface;
typedef __IOSurface *IOSurfaceRef;

namespace eagl
{

enum class RenderingAPI : NSUInteger
{
    GLES1 = 1,
    GLES2,
    GLES3,
};

EAGLContextObj createWithAPI(RenderingAPI api);
EAGLContextObj createWithAPIAndSharedContext(RenderingAPI api, EAGLContextObj sharedContext);
BOOL setCurrentContext(EAGLContextObj ctx);
BOOL texImageIOSurface(EAGLContextObj ctx,
                       IOSurfaceRef iosurface,
                       NSUInteger target,
                       NSUInteger internalFormat,
                       uint32_t width,
                       uint32_t height,
                       NSUInteger format,
                       NSUInteger type,
                       uint32_t plane);
void presentRenderbuffer(EAGLContextObj ctx, NSUInteger target);
void renderbufferStorage(EAGLContextObj ctx, NSUInteger target, CAEAGLLayerObj drawable);

CAEAGLLayerObj createCAEAGLLayer();
void setCAEAGLLayerFrame(CAEAGLLayerObj layer, const CGRect &frame);
void setCAEAGLContentsScale(CAEAGLLayerObj layer, const double scale);

}

#endif  // __OBJC__

#endif
