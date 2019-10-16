//
// Copyright 2019 Le Hoang Quyen. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#ifndef MGLLayer_Private_h
#define MGLLayer_Private_h

#import "MGLLayer.h"

#import <QuartzCore/CAMetalLayer.h>

#include <EGL/egl.h>
#import "MGLDisplay.h"

@interface MGLLayer () {
    MGLDisplay *_display;
    EGLSurface _eglSurface;
    CAMetalLayer *_metalLayer;
}

@property(nonatomic, readonly) EGLSurface eglSurface;

@end

#endif /* MGLLayer_Private_h */
