//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// SurfaceMtl.mm:
//    Implements the class methods for SurfaceMtl.
//

#include "libANGLE/renderer/metal/SurfaceMtl.h"

#include <TargetConditionals.h>

#include "libANGLE/Display.h"
#include "libANGLE/renderer/metal/ContextMtl.h"
#include "libANGLE/renderer/metal/DisplayMtl.h"
#include "libANGLE/renderer/metal/FrameBufferMtl.h"
#include "libANGLE/renderer/metal/RendererMtl.h"
#include "libANGLE/renderer/metal/mtl_format_utils.h"

namespace rx
{

namespace
{
constexpr angle::FormatID kDefaultFrameBufferColorFormatId = angle::FormatID::B8G8R8A8_UNORM;
ANGLE_MTL_UNUSED
constexpr angle::FormatID kDefaultFrameBufferDepthFormatId = angle::FormatID::D32_FLOAT;
ANGLE_MTL_UNUSED
constexpr angle::FormatID kDefaultFrameBufferStencilFormatId = angle::FormatID::S8_UINT;
ANGLE_MTL_UNUSED
constexpr angle::FormatID kDefaultFrameBufferDepthStencilFormatId =
    angle::FormatID::D24_UNORM_S8_UINT;

ANGLE_MTL_UNUSED
bool IsFrameCaptureEnabled()
{
#if defined(NDEBUG)
    return false;
#else
    auto var                  = std::getenv("ANGLE_METAL_FRAME_CAPTURE");
    static const bool enabled = var ? (strcmp(var, "1") == 0) : false;

    return enabled;
#endif
}

ANGLE_MTL_UNUSED
size_t MaxAllowedFrameCapture()
{
#if defined(NDEBUG)
    return 0;
#else
    auto var                      = std::getenv("ANGLE_METAL_FRAME_CAPTURE_MAX");
    static const size_t maxFrames = var ? std::atoi(var) : 0;

    return maxFrames;
#endif
}

ANGLE_MTL_UNUSED
size_t MinAllowedFrameCapture()
{
#if defined(NDEBUG)
    return 0;
#else
    auto var                     = std::getenv("ANGLE_METAL_FRAME_CAPTURE_MIN");
    static const size_t minFrame = var ? std::atoi(var) : 0;

    return minFrame;
#endif
}

ANGLE_MTL_UNUSED
bool FrameCaptureDeviceScope()
{
#if defined(NDEBUG)
    return false;
#else
    auto var                      = std::getenv("ANGLE_METAL_FRAME_CAPTURE_SCOPE");
    static const bool scopeDevice = var ? (strcmp(var, "device") == 0) : false;

    return scopeDevice;
#endif
}

ANGLE_MTL_UNUSED
std::atomic<size_t> gFrameCaptured(0);

ANGLE_MTL_UNUSED
void StartFrameCapture(id<MTLDevice> metalDevice, id<MTLCommandQueue> metalCmdQueue)
{
#if !defined(NDEBUG)
    if (!IsFrameCaptureEnabled())
    {
        return;
    }

    if (gFrameCaptured >= MaxAllowedFrameCapture())
    {
        return;
    }

    MTLCaptureManager *captureManager = [MTLCaptureManager sharedCaptureManager];
    if (captureManager.isCapturing)
    {
        return;
    }

    gFrameCaptured++;

    if (gFrameCaptured < MinAllowedFrameCapture())
    {
        return;
    }

#    ifdef __MAC_10_15
    if (@available(iOS 13, macOS 10.15, *))
    {
        MTLCaptureDescriptor *captureDescriptor = [[MTLCaptureDescriptor alloc] init];
        captureDescriptor.captureObject         = metalDevice;

        NSError *error;
        if (![captureManager startCaptureWithDescriptor:captureDescriptor error:&error])
        {
            NSLog(@"Failed to start capture, error %@", error);
        }
    }
    else
#    endif  // __MAC_10_15
    {
        if (FrameCaptureDeviceScope())
        {
            [captureManager startCaptureWithDevice:metalDevice];
        }
        else
        {
            [captureManager startCaptureWithCommandQueue:metalCmdQueue];
        }
    }
#endif  // NDEBUG
}

void StartFrameCapture(ContextMtl *context)
{
    StartFrameCapture(context->getMetalDevice(), context->cmdQueue().get());
}

void StopFrameCapture()
{
#if !defined(NDEBUG)
    if (!IsFrameCaptureEnabled())
    {
        return;
    }
    MTLCaptureManager *captureManager = [MTLCaptureManager sharedCaptureManager];
    if (captureManager.isCapturing)
    {
        [captureManager stopCapture];
    }
#endif
}
}

SurfaceMtl::SurfaceMtl(const egl::SurfaceState &state,
                       EGLNativeWindowType window,
                       EGLint width,
                       EGLint height)
    : SurfaceImpl(state), mLayer((__bridge CALayer *)(window))
{}

SurfaceMtl::~SurfaceMtl() {}

void SurfaceMtl::destroy(const egl::Display *display)
{
    mDrawableTexture = nullptr;
    mDepthTexture    = nullptr;
    mStencilTexture  = nullptr;
    mCurrentDrawable = nil;
    mMetalLayer      = nil;
}

egl::Error SurfaceMtl::initialize(const egl::Display *display)
{
    DisplayMtl *displayMtl    = mtl::GetImpl(display);
    RendererMtl *renderer     = displayMtl->getRenderer();
    id<MTLDevice> metalDevice = renderer->getMetalDevice();

    mColorFormat = renderer->getPixelFormat(kDefaultFrameBufferColorFormatId);

#if ANGLE_MTL_ALLOW_SEPARATED_DEPTH_STENCIL
    mDepthFormat   = renderer->getPixelFormat(kDefaultFrameBufferDepthFormatId);
    mStencilFormat = renderer->getPixelFormat(kDefaultFrameBufferStencilFormatId);
#else
    // We must use packed depth stencil
    mUsePackedDepthStencil = true;
    mDepthFormat           = renderer->getPixelFormat(kDefaultFrameBufferDepthStencilFormatId);
    mStencilFormat         = mDepthFormat;
#endif

    StartFrameCapture(metalDevice, renderer->cmdQueue().get());

    ANGLE_MTL_OBJC_SCOPE
    {
        mMetalLayer                       = [[[CAMetalLayer alloc] init] ANGLE_MTL_AUTORELEASE];
        mMetalLayer.get().device          = metalDevice;
        mMetalLayer.get().pixelFormat     = mColorFormat.metalFormat;
        mMetalLayer.get().framebufferOnly = NO;  // This to allow readPixels
        mMetalLayer.get().frame           = mLayer.frame;

        mMetalLayer.get().contentsScale = mLayer.contentsScale;

        [mLayer addSublayer:mMetalLayer.get()];
    }

    return egl::NoError();
}

FramebufferImpl *SurfaceMtl::createDefaultFramebuffer(const gl::Context *context,
                                                      const gl::FramebufferState &state)
{
    auto fbo = new FramebufferMtl(state, /* flipY */ true, /* alwaysDiscard */ true);

    return fbo;
}

egl::Error SurfaceMtl::makeCurrent(const gl::Context *context)
{
    return egl::NoError();
}

egl::Error SurfaceMtl::unMakeCurrent(const gl::Context *context)
{
    return egl::NoError();
}

egl::Error SurfaceMtl::swap(const gl::Context *context)
{
    angle::Result result = swapImpl(context);

    if (result != angle::Result::Continue)
    {
        return egl::EglBadSurface();
    }

    return egl::NoError();
}

egl::Error SurfaceMtl::postSubBuffer(const gl::Context *context,
                                     EGLint x,
                                     EGLint y,
                                     EGLint width,
                                     EGLint height)
{
    UNIMPLEMENTED();
    return egl::EglBadAccess();
}

egl::Error SurfaceMtl::querySurfacePointerANGLE(EGLint attribute, void **value)
{
    UNIMPLEMENTED();
    return egl::EglBadAccess();
}

egl::Error SurfaceMtl::bindTexImage(const gl::Context *context, gl::Texture *texture, EGLint buffer)
{
    UNIMPLEMENTED();
    return egl::EglBadAccess();
}

egl::Error SurfaceMtl::releaseTexImage(const gl::Context *context, EGLint buffer)
{
    UNIMPLEMENTED();
    return egl::EglBadAccess();
}

egl::Error SurfaceMtl::getSyncValues(EGLuint64KHR *ust, EGLuint64KHR *msc, EGLuint64KHR *sbc)
{
    UNIMPLEMENTED();
    return egl::EglBadAccess();
}

void SurfaceMtl::setSwapInterval(EGLint interval)
{
    // TODO(hqle)
}

void SurfaceMtl::setFixedWidth(EGLint width)
{
    // TODO(hqle)
    UNIMPLEMENTED();
}

void SurfaceMtl::setFixedHeight(EGLint height)
{
    // TODO(hqle)
    UNIMPLEMENTED();
}

// width and height can change with client window resizing
EGLint SurfaceMtl::getWidth() const
{
    if (mMetalLayer)
    {
        return static_cast<EGLint>(mMetalLayer.get().drawableSize.width);
    }
    return 0;
}

EGLint SurfaceMtl::getHeight() const
{
    if (mMetalLayer)
    {
        return static_cast<EGLint>(mMetalLayer.get().drawableSize.height);
    }
    return 0;
}

EGLint SurfaceMtl::isPostSubBufferSupported() const
{
    return EGL_FALSE;
}

EGLint SurfaceMtl::getSwapBehavior() const
{
    return EGL_BUFFER_DESTROYED;
}

angle::Result SurfaceMtl::getAttachmentRenderTarget(const gl::Context *context,
                                                    GLenum binding,
                                                    const gl::ImageIndex &imageIndex,
                                                    GLsizei samples,
                                                    FramebufferAttachmentRenderTarget **rtOut)
{
    // TODO(hqle): Support MSAA.
    ANGLE_TRY(ensureRenderTargetsCreated(context));

    switch (binding)
    {
        case GL_BACK:
            *rtOut = &mColorRenderTarget;
            break;
        case GL_DEPTH:
            *rtOut = &mDepthRenderTarget;
            break;
        case GL_STENCIL:
            *rtOut = &mStencilRenderTarget;
            break;
        case GL_DEPTH_STENCIL:
            // TODO(hqle): ES 3.0 feature
            UNREACHABLE();
            break;
    }

    return angle::Result::Continue;
}

angle::Result SurfaceMtl::ensureRenderTargetsCreated(const gl::Context *context)
{
    if (!mDrawableTexture)
    {
        ANGLE_TRY(obtainNextDrawable(context));
    }

    ASSERT(mDrawableTexture && mDrawableTexture->get());

    ContextMtl *contextMtl = mtl::GetImpl(context);
    auto size              = mDrawableTexture->size();

    if (!mDepthTexture || mDepthTexture->size() != size)
    {
        ANGLE_TRY(mtl::Texture::Make2DTexture(contextMtl, mDepthFormat.metalFormat, size.width,
                                              size.height, 1, true, &mDepthTexture));

        mDepthRenderTarget.set(mDepthTexture, 0, 0, mDepthFormat);
    }

    if (!mStencilTexture || mStencilTexture->size() != size)
    {
        if (mUsePackedDepthStencil)
        {
            mStencilTexture = mDepthTexture;
        }
        else
        {
            ANGLE_TRY(mtl::Texture::Make2DTexture(contextMtl, mStencilFormat.metalFormat,
                                                  size.width, size.height, 1, true,
                                                  &mStencilTexture));
        }

        mStencilRenderTarget.set(mStencilTexture, 0, 0, mStencilFormat);
    }

    return angle::Result::Continue;
}

angle::Result SurfaceMtl::obtainNextDrawable(const gl::Context *context)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        ContextMtl *contextMtl = mtl::GetImpl(context);

        StartFrameCapture(contextMtl);

        ANGLE_MTL_TRY(contextMtl, mMetalLayer);

        if (mDrawableTexture)
        {
            mDrawableTexture->set(nil);
        }

        mCurrentDrawable = nil;
        mCurrentDrawable.retainAssign([mMetalLayer nextDrawable]);
        if (!mCurrentDrawable)
        {
            // The GPU might be taking too long finishing its rendering to the previous frame.
            // Try again, indefinitely wait until the previous frame render finishes.
            // TODO: this may wait forever here
            mMetalLayer.get().allowsNextDrawableTimeout = NO;
            mCurrentDrawable.retainAssign([mMetalLayer nextDrawable]);
            mMetalLayer.get().allowsNextDrawableTimeout = YES;
        }

        if (!mDrawableTexture)
        {
            mDrawableTexture = mtl::Texture::MakeFromMetal(mCurrentDrawable.get().texture);
            mColorRenderTarget.set(mDrawableTexture, 0, 0, mColorFormat);
        }
        else
        {
            mDrawableTexture->set(mCurrentDrawable.get().texture);
        }

#if defined(ANGLE_MTL_ENABLE_TRACE)
        [mCurrentDrawable.get() addPresentedHandler:^(id<MTLDrawable> drawable) {
          NSLog(@"Drawable %@ has been presented", drawable);
        }];
#endif

        return angle::Result::Continue;
    }
}

angle::Result SurfaceMtl::swapImpl(const gl::Context *context)
{
    ANGLE_TRY(ensureRenderTargetsCreated(context));

    ContextMtl *contextMtl = mtl::GetImpl(context);

    contextMtl->present(context, mCurrentDrawable);

    StopFrameCapture();

    ANGLE_TRY(obtainNextDrawable(context));

    return angle::Result::Continue;
}
}
