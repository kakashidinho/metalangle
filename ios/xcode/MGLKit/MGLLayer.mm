//
// Copyright 2019 Le Hoang Quyen. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#import "MGLLayer+Private.h"

#include <vector>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <EGL/eglext_angle.h>
#include <EGL/eglplatform.h>
#include <common/debug.h>
#import "MGLContext+Private.h"
#import "MGLDisplay.h"

namespace
{
void Throw(NSString *msg)
{
    [NSException raise:@"MGLSurfaceException" format:@"%@", msg];
}
}

@implementation MGLLayer

- (id)init
{
    if (self = [super init])
    {
        [self constructor];
    }
    return self;
}

- (id)initWithLayer:(id)layer
{
    if (self = [super initWithLayer:layer])
    {
        [self constructor];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder])
    {
        [self constructor];
    }
    return self;
}

- (void)constructor
{
    _drawableColorFormat   = MGLDrawableColorFormatRGBA8888;
    _drawableDepthFormat   = MGLDrawableDepthFormatNone;
    _drawableStencilFormat = MGLDrawableStencilFormatNone;

    _display = [MGLDisplay defaultDisplay];

    _eglSurface = EGL_NO_SURFACE;

    _metalLayer       = [[CAMetalLayer alloc] init];
    _metalLayer.frame = self.bounds;
    [self addSublayer:_metalLayer];
}

- (void)dealloc
{
    [self releaseSurface];

    _display = nil;
}

- (void)setContentsScale:(CGFloat)contentsScale
{
    [super setContentsScale:contentsScale];
    _metalLayer.contentsScale = contentsScale;
}

- (CGSize)drawableSize
{
    return _metalLayer.drawableSize;
}

- (BOOL)setCurrentContext:(MGLContext *)context
{
    if (eglGetCurrentContext() != context.eglContext ||
        eglGetCurrentSurface(EGL_READ) != self.eglSurface ||
        eglGetCurrentSurface(EGL_DRAW) != self.eglSurface)
    {
        if (!eglMakeCurrent(_display.eglDisplay, self.eglSurface, self.eglSurface,
                            context.eglContext))
        {
            return NO;
        }
    }
    return YES;
}

- (BOOL)present
{
    if (!eglSwapBuffers(_display.eglDisplay, self.eglSurface))
    {
        return NO;
    }

    [self checkLayerSize];

    return YES;
}

- (EGLSurface)eglSurface
{
    [self ensureSurfaceCreated];

    return _eglSurface;
}

- (void)setDrawableColorFormat:(MGLDrawableColorFormat)drawableColorFormat
{
    _drawableColorFormat = drawableColorFormat;
    [self releaseSurface];
}

- (void)setDrawableDepthFormat:(MGLDrawableDepthFormat)drawableDepthFormat
{
    _drawableDepthFormat = drawableDepthFormat;
    [self releaseSurface];
}

- (void)setDrawableStencilFormat:(MGLDrawableStencilFormat)drawableStencilFormat
{
    _drawableStencilFormat = drawableStencilFormat;
    [self releaseSurface];
}

- (void)releaseSurface
{
    if (_eglSurface == eglGetCurrentSurface(EGL_READ) ||
        _eglSurface == eglGetCurrentSurface(EGL_DRAW))
    {
        eglMakeCurrent(_display.eglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    }
    if (_eglSurface != EGL_NO_SURFACE)
    {
        eglDestroySurface(_display.eglDisplay, _eglSurface);
        _eglSurface = EGL_NO_SURFACE;
    }
}

- (void)checkLayerSize
{
    // Resize the metal layer
    _metalLayer.frame = self.bounds;
    _metalLayer.drawableSize =
        CGSizeMake(_metalLayer.bounds.size.width * _metalLayer.contentsScale,
                   _metalLayer.bounds.size.height * _metalLayer.contentsScale);
}

- (void)ensureSurfaceCreated
{
    if (_eglSurface != EGL_NO_SURFACE)
    {
        return;
    }

    [self checkLayerSize];

    int red = 8, green = 8, blue = 8, alpha = 8;
    switch (_drawableColorFormat)
    {
        case MGLDrawableColorFormatRGBA8888:
            red = green = blue = alpha = 8;
            break;
        case MGLDrawableColorFormatRGB565:
            red = blue = 5;
            green      = 6;
            alpha      = 0;
            break;
        default:
            UNREACHABLE();
            break;
    }

    // Init surface
    std::vector<EGLint> surfaceAttribs = {
        EGL_RED_SIZE,       red,
        EGL_GREEN_SIZE,     green,
        EGL_BLUE_SIZE,      blue,
        EGL_ALPHA_SIZE,     alpha,
        EGL_DEPTH_SIZE,     _drawableDepthFormat,
        EGL_STENCIL_SIZE,   _drawableStencilFormat,
        EGL_SAMPLE_BUFFERS, 0,
        EGL_SAMPLES,        EGL_DONT_CARE,
    };
    surfaceAttribs.push_back(EGL_NONE);
    EGLConfig config;
    EGLint numConfigs;
    if (!eglChooseConfig(_display.eglDisplay, surfaceAttribs.data(), &config, 1, &numConfigs) ||
        numConfigs < 1)
    {
        Throw(@"Failed to call eglChooseConfig()");
    }

    EGLint creationAttribs[] = {EGL_FLEXIBLE_SURFACE_COMPATIBILITY_SUPPORTED_ANGLE, EGL_TRUE,
                                EGL_NONE};

    _eglSurface = eglCreateWindowSurface(
        _display.eglDisplay, config, (__bridge EGLNativeWindowType)_metalLayer, creationAttribs);
    if (_eglSurface == EGL_NO_SURFACE)
    {
        Throw(@"Failed to call eglCreateWindowSurface()");
    }
}

@end
