//
//  MGLContext.m
//  OpenGLES
//
//  Created by Le Quyen on 16/10/19.
//  Copyright © 2019 Google. All rights reserved.
//

#import "MGLContext.h"
#import "MGLContext+Private.h"

#import <QuartzCore/CAMetalLayer.h>

#include <vector>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <EGL/eglext_angle.h>
#include <EGL/eglplatform.h>
#include <common/debug.h>

namespace
{
thread_local void *gCurrentContext;

void Throw(NSString *msg)
{
    [NSException raise:@"MGLSurfaceException" format:@"%@", msg];
}
}

// MGLContext implementation

@implementation MGLContext

- (id)initWithAPI:(MGLRenderingAPI)api
{
    if (self = [super init])
    {
        _renderingApi = api;
        _display      = [MGLDisplay defaultDisplay];
        [self initContext];
    }
    return self;
}

- (void)dealloc
{
    [self releaseContext];

    _display = nil;
}

- (void)releaseContext
{
    if (eglGetCurrentContext() == _eglContext)
    {
        eglMakeCurrent(_display.eglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    }

    if (_dummySurface != EGL_NO_SURFACE)
    {
        eglDestroySurface(_display.eglDisplay, _dummySurface);
        _dummySurface = EGL_NO_SURFACE;
    }

    if (_eglContext != EGL_NO_CONTEXT)
    {
        eglDestroyContext(_display.eglDisplay, _eglContext);
        _eglContext = EGL_NO_CONTEXT;
    }
}

- (void)initContext
{
    // Init config
    std::vector<EGLint> surfaceAttribs = {
        EGL_RED_SIZE,       EGL_DONT_CARE, EGL_GREEN_SIZE,   EGL_DONT_CARE,
        EGL_BLUE_SIZE,      EGL_DONT_CARE, EGL_ALPHA_SIZE,   EGL_DONT_CARE,
        EGL_DEPTH_SIZE,     EGL_DONT_CARE, EGL_STENCIL_SIZE, EGL_DONT_CARE,
        EGL_SAMPLE_BUFFERS, EGL_DONT_CARE, EGL_SAMPLES,      EGL_DONT_CARE,
    };
    surfaceAttribs.push_back(EGL_NONE);
    EGLConfig config;
    EGLint numConfigs;
    if (!eglChooseConfig(_display.eglDisplay, surfaceAttribs.data(), &config, 1, &numConfigs) ||
        numConfigs < 1)
    {
        Throw(@"Failed to call eglChooseConfig()");
    }

    // Init context
    int ctxMajorVersion = 2;
    int ctxMinorVersion = 0;
    switch (_renderingApi)
    {
        case kMGLRenderingAPIOpenGLES1:
            ctxMajorVersion = 1;
            ctxMinorVersion = 0;
            break;
        case kMGLRenderingAPIOpenGLES2:
            ctxMajorVersion = 2;
            ctxMinorVersion = 0;
            break;
        default:
            UNREACHABLE();
    }
    EGLint ctxAttribs[] = {EGL_CONTEXT_MAJOR_VERSION, ctxMajorVersion, EGL_CONTEXT_MINOR_VERSION,
                           ctxMinorVersion, EGL_NONE};

    _eglContext = eglCreateContext(_display.eglDisplay, config, EGL_NO_CONTEXT, ctxAttribs);
    if (_eglContext == EGL_NO_CONTEXT)
    {
        Throw(@"Failed to call eglCreateContext()");
    }

    // Create dummy surface
    _dummyLayer       = [[CAMetalLayer alloc] init];
    _dummyLayer.frame = CGRectMake(0, 0, 1, 1);

    _dummySurface = eglCreateWindowSurface(_display.eglDisplay, config,
                                           (__bridge EGLNativeWindowType)_dummyLayer, nullptr);
    if (_dummySurface == EGL_NO_SURFACE)
    {
        Throw(@"Failed to call eglCreateWindowSurface()");
    }
}

- (BOOL)present:(MGLLayer *)layer
{
    return [layer present];
}

+ (MGLContext *)currentContext
{
    return (__bridge MGLContext *)gCurrentContext;
}

+ (BOOL)setCurrentContext:(MGLContext *)context
{
    if (context)
    {
        return [context setCurrentContextForLayer:nil];
    }

    return eglMakeCurrent([MGLDisplay defaultDisplay].eglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE,
                          EGL_NO_CONTEXT);
}

+ (BOOL)setCurrentContext:(MGLContext *)context forLayer:(MGLLayer *)layer
{
    if (context)
    {
        return [context setCurrentContextForLayer:layer];
    }
    return [self setCurrentContext:nil];
}

- (BOOL)setCurrentContextForLayer:(MGLLayer *_Nullable)layer
{
    if (!layer)
    {
        if (eglGetCurrentContext() != _eglContext ||
            eglGetCurrentSurface(EGL_READ) != _dummySurface ||
            eglGetCurrentSurface(EGL_DRAW) != _dummySurface)
        {
            if (!eglMakeCurrent(_display.eglDisplay, _dummySurface, _dummySurface, _eglContext))
            {
                return NO;
            }
        }
    }
    else
    {
        if (![layer setCurrentContext:self])
        {
            return NO;
        }
    }

    gCurrentContext = (__bridge void *)self;

    return YES;
}

@end
