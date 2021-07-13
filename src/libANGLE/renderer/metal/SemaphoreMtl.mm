// Copyright 2021 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// SemaphoreMtl.cpp: Defines the class interface for SemaphoreMtl, implementing
// SemaphoreImpl.

#include "libANGLE/renderer/metal/SemaphoreMtl.h"

#include "common/debug.h"
#include "libANGLE/Context.h"
#include "libANGLE/renderer/metal/ContextMtl.h"

namespace rx
{

SemaphoreMtl::SemaphoreMtl() = default;

SemaphoreMtl::~SemaphoreMtl() = default;

void SemaphoreMtl::onDestroy(const gl::Context *context)
{
    mMetalSharedEvent = nil;
}

angle::Result SemaphoreMtl::importFd(gl::Context *context, gl::HandleType handleType, GLint fd)
{
    switch (handleType)
    {
        case gl::HandleType::OpaqueFd:
            return importOpaqueFd(context, fd);

        default:
            UNREACHABLE();
            return angle::Result::Stop;
    }
}

angle::Result SemaphoreMtl::wait(gl::Context *context,
                                const gl::BufferBarrierVector &bufferBarriers,
                                const gl::TextureBarrierVector &textureBarriers)
{
    // bufferBarriers & textureBarriers are unused for now because metal always end
    // current render pass when there is a wait command.

#if ANGLE_MTL_EVENT_AVAILABLE
    ContextMtl *contextMtl = mtl::GetImpl(context);
    contextMtl->serverWaitEvent(mMetalSharedEvent, mTimelineValue);
#endif // ANGLE_MTL_EVENT_AVAILABLE

    return angle::Result::Continue;
}

angle::Result SemaphoreMtl::signal(gl::Context *context,
                                  const gl::BufferBarrierVector &bufferBarriers,
                                  const gl::TextureBarrierVector &textureBarriers)
{
#if ANGLE_MTL_EVENT_AVAILABLE
    ContextMtl *contextMtl = mtl::GetImpl(context);
    contextMtl->queueEventSignal(mMetalSharedEvent, mTimelineValue);
#endif // ANGLE_MTL_EVENT_AVAILABLE

    contextMtl->flushCommandBufer();
    return angle::Result::Continue;
}

void SemaphoreMtl::parameterui64v(GLenum pname, const GLuint64 *params)
{
    switch (pname)
    {
        case GL_TIMELINE_SEMAPHORE_VALUE_MGL:
            mTimelineValue = *params;
            break;
        default:
            UNREACHABLE();
    }
}

void SemaphoreMtl::getParameterui64v(GLenum pname, GLuint64 *params)
{
    switch (pname)
    {
        case GL_TIMELINE_SEMAPHORE_VALUE_MGL:
            *params = mTimelineValue;
            break;
        default:
            UNREACHABLE();
    }
}

angle::Result SemaphoreMtl::importOpaqueFd(gl::Context *context, GLint fd)
{
#if !ANGLE_MTL_EVENT_AVAILABLE
    UNREACHABLE();
#else
    ContextMtl *contextMtl = mtl::GetImpl(context);

    // NOTE(hqle): This import assumes the address of MTLSharedEvent is stored in the file.
    void* sharedEventPtr = nullptr;
    ANGLE_MTL_TRY(contextMtl, read(fd, &sharedEventPtr, sizeof(sharedEventPtr)));
    ANGLE_MTL_TRY(contextMtl, sharedEventPtr);

    // The ownership of this fd belongs to Semaphore now, so we can close it here.
    close(fd);

    auto sharedEvent = (__bridge id<MTLSharedEvent>)sharedEventPtr;

    mMetalSharedEvent = std::move(sharedEvent);
#endif // ANGLE_MTL_EVENT_AVAILABLE

    return angle::Result::Continue;
}

}  // namespace rx
