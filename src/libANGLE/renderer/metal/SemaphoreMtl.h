// Copyright 2021 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// SemaphoreMtl.h: Defines the class interface for SemaphoreMtl,
// implementing SemaphoreImpl.

#ifndef LIBANGLE_RENDERER_METAL_SEMAPHOREMTL_H_
#define LIBANGLE_RENDERER_METAL_SEMAPHOREMTL_H_

#include "libANGLE/renderer/SemaphoreImpl.h"
#include "libANGLE/renderer/metal/mtl_common.h"

namespace rx
{

class SemaphoreMtl : public SemaphoreImpl
{
  public:
    SemaphoreMtl();
    ~SemaphoreMtl() override;

    void onDestroy(const gl::Context *context) override;

    angle::Result importFd(gl::Context *context, gl::HandleType handleType, GLint fd) override;

    angle::Result wait(gl::Context *context,
                       const gl::BufferBarrierVector &bufferBarriers,
                       const gl::TextureBarrierVector &textureBarriers) override;

    angle::Result signal(gl::Context *context,
                         const gl::BufferBarrierVector &bufferBarriers,
                         const gl::TextureBarrierVector &textureBarriers) override;

    void parameterui64v(GLenum pname, const GLuint64 *params) override;
    void getParameterui64v(GLenum pname, GLuint64 *params) override;
  private:
    angle::Result importOpaqueFd(gl::Context *context, GLint fd);

    mtl::SharedEventRef mMetalSharedEvent;
    GLuint64 mTimelineValue = 0;
};

}  // namespace rx

#endif  // LIBANGLE_RENDERER_METAL_SEMAPHOREMTL_H_
