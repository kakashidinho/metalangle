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
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#import "MGLDisplay.h"

@interface MGLLayer () {
    MGLDisplay *_display;
    // The context that owns the offscreen FBO
    MGLContext *_offscreenFBOCreatorContext;
    EGLSurface _eglSurface;
    CAMetalLayer *_metalLayer;

    // Textures used to retain the content of framebuffer.
    GLuint _offscreenTexture;
    GLuint _offscreenDepthStencilBuffer;
    GLuint _offscreenBlitProgram;
    GLuint _offscreenBlitVBO;
    GLuint _offscreenBlitVAO;
    CGSize _offscreenFBOSize;
}

@property(nonatomic, readonly) EGLSurface eglSurface;

- (BOOL)setCurrentContext:(MGLContext *)context;

@end

#endif /* MGLLayer_Private_h */
