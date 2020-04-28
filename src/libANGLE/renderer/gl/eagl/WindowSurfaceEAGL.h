//
// Copyright 2020 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

// WindowSurfaceEAGL.h: EAGL implementation of egl::Surface

#ifndef LIBANGLE_RENDERER_GL_EAGL_WINDOWSURFACEEAGL_H_
#define LIBANGLE_RENDERER_GL_EAGL_WINDOWSURFACEEAGL_H_

#include "libANGLE/renderer/gl/SurfaceGL.h"

#ifdef __OBJC__
@class EAGLContext;
typedef EAGLContext *EAGLContextObj;
#else
typedef void *EAGLContextObj;
#endif
@class CALayer;
@class CAEAGLLayer;
struct __IOSurface;
typedef __IOSurface *IOSurfaceRef;

namespace rx
{

class DisplayEAGL;
class FramebufferGL;
class FunctionsGL;
class RendererGL;
class StateManagerGL;

class WindowSurfaceEAGL : public SurfaceGL
{
  public:
    WindowSurfaceEAGL(const egl::SurfaceState &state,
                      RendererGL *renderer,
                      EGLNativeWindowType layer,
                      EAGLContextObj context);
    ~WindowSurfaceEAGL() override;

    egl::Error initialize(const egl::Display *display) override;
    egl::Error makeCurrent(const gl::Context *context) override;
    egl::Error unMakeCurrent(const gl::Context *context) override;

    egl::Error swap(const gl::Context *context) override;
    egl::Error postSubBuffer(const gl::Context *context,
                             EGLint x,
                             EGLint y,
                             EGLint width,
                             EGLint height) override;
    egl::Error querySurfacePointerANGLE(EGLint attribute, void **value) override;
    egl::Error bindTexImage(const gl::Context *context,
                            gl::Texture *texture,
                            EGLint buffer) override;
    egl::Error releaseTexImage(const gl::Context *context, EGLint buffer) override;
    void setSwapInterval(EGLint interval) override;

    EGLint getWidth() const override;
    EGLint getHeight() const override;

    EGLint isPostSubBufferSupported() const override;
    EGLint getSwapBehavior() const override;

    FramebufferImpl *createDefaultFramebuffer(const gl::Context *context,
                                              const gl::FramebufferState &state) override;

  private:
    CAEAGLLayer *mSwapLayer;
    CALayer *mLayer;
    EAGLContextObj mContext;
    const FunctionsGL *mFunctions;
    StateManagerGL *mStateManager;

    GLuint mColorRenderbuffer;
    GLuint mDSRenderbuffer;
    EGLint mDSBufferWidth;
    EGLint mDSBufferHeight;
};

}  // namespace rx

#endif  // LIBANGLE_RENDERER_GL_EAGL_WINDOWSURFACEEAGL_H_
