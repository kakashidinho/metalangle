//
// Copyright (c) 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

// DisplayMtl.h: Metal implementation of egl::Display

#include "libANGLE/renderer/metal/DisplayMtl.h"

#include "libANGLE/AttributeMap.h"
#include "libANGLE/Context.h"
#include "libANGLE/Display.h"
#include "libANGLE/Surface.h"
#include "libANGLE/renderer/metal/ContextMtl.h"
#include "libANGLE/renderer/metal/RendererMtl.h"
#include "libANGLE/renderer/metal/SurfaceMtl.h"

#include "EGL/eglext.h"

namespace rx
{

DisplayMtl::DisplayMtl(const egl::DisplayState &state)
    : DisplayImpl(state), mRenderer(new RendererMtl())
{}

DisplayMtl::~DisplayMtl() {}

egl::Error DisplayMtl::initialize(egl::Display *display)
{
    const egl::AttributeMap &attribs = display->getAttributeMap();

    gl::Version esVersion(static_cast<EGLint>(attribs.get(EGL_CONTEXT_CLIENT_VERSION, 2)),
                          static_cast<EGLint>(attribs.get(EGL_CONTEXT_MINOR_VERSION, 0)));

    // TODO(hqle): Support ES 3.0
    if (esVersion > gl::ES_2_0)
    {
        return egl::EglBadAttribute() << "Unssuported client version";
    }

    angle::Result result = mRenderer->initialize(display);
    if (result != angle::Result::Continue)
    {
        return egl::EglNotInitialized();
    }
    return egl::NoError();
}

void DisplayMtl::terminate()
{
    mRenderer->onDestroy();
}

bool DisplayMtl::testDeviceLost()
{
    return false;
}

egl::Error DisplayMtl::restoreLostDevice(const egl::Display *display)
{
    return egl::NoError();
}

std::string DisplayMtl::getVendorString() const
{
    return mRenderer->getVendorString();
}

DeviceImpl *DisplayMtl::createDevice()
{
    UNIMPLEMENTED();
    return nullptr;
}

egl::Error DisplayMtl::waitClient(const gl::Context *context)
{
    auto contextMtl      = GetImplAs<ContextMtl>(context);
    angle::Result result = contextMtl->finishCommandBuffer();

    if (result != angle::Result::Continue)
    {
        return egl::EglBadAccess();
    }
    return egl::NoError();
}

egl::Error DisplayMtl::waitNative(const gl::Context *context, EGLint engine)
{
    UNIMPLEMENTED();
    return egl::EglBadAccess();
}

SurfaceImpl *DisplayMtl::createWindowSurface(const egl::SurfaceState &state,
                                             EGLNativeWindowType window,
                                             const egl::AttributeMap &attribs)
{
    EGLint width  = attribs.getAsInt(EGL_WIDTH, 0);
    EGLint height = attribs.getAsInt(EGL_HEIGHT, 0);

    return new SurfaceMtl(state, window, width, height);
}

SurfaceImpl *DisplayMtl::createPbufferSurface(const egl::SurfaceState &state,
                                              const egl::AttributeMap &attribs)
{
    UNIMPLEMENTED();
    return static_cast<SurfaceImpl *>(0);
}

SurfaceImpl *DisplayMtl::createPbufferFromClientBuffer(const egl::SurfaceState &state,
                                                       EGLenum buftype,
                                                       EGLClientBuffer clientBuffer,
                                                       const egl::AttributeMap &attribs)
{
    UNIMPLEMENTED();
    return static_cast<SurfaceImpl *>(0);
}

SurfaceImpl *DisplayMtl::createPixmapSurface(const egl::SurfaceState &state,
                                             NativePixmapType nativePixmap,
                                             const egl::AttributeMap &attribs)
{
    UNIMPLEMENTED();
    return static_cast<SurfaceImpl *>(0);
}

ImageImpl *DisplayMtl::createImage(const egl::ImageState &state,
                                   const gl::Context *context,
                                   EGLenum target,
                                   const egl::AttributeMap &attribs)
{
    UNIMPLEMENTED();
    return nullptr;
}

rx::ContextImpl *DisplayMtl::createContext(const gl::State &state,
                                           gl::ErrorSet *errorSet,
                                           const egl::Config *configuration,
                                           const gl::Context *shareContext,
                                           const egl::AttributeMap &attribs)
{
    return new ContextMtl(state, errorSet, mRenderer.get());
}

StreamProducerImpl *DisplayMtl::createStreamProducerD3DTexture(
    egl::Stream::ConsumerType consumerType,
    const egl::AttributeMap &attribs)
{
    UNIMPLEMENTED();
    return nullptr;
}

gl::Version DisplayMtl::getMaxSupportedESVersion() const
{
    return kMaxSupportedGLVersion;
}

gl::Version DisplayMtl::getMaxConformantESVersion() const
{
    return std::min(getMaxSupportedESVersion(), gl::Version(2, 0));
}

EGLSyncImpl *DisplayMtl::createSync(const egl::AttributeMap &attribs)
{
    // TODO(hqle)
    UNIMPLEMENTED();
    return nullptr;
}

egl::Error DisplayMtl::makeCurrent(egl::Surface *drawSurface,
                                   egl::Surface *readSurface,
                                   gl::Context *context)
{
    if (!context)
    {
        return egl::NoError();
    }

    // TODO(hqle)

    if (drawSurface == nullptr)
    {
        ANGLE_TRY(makeCurrentSurfaceless(context));
    }

    return egl::NoError();
}

void DisplayMtl::generateExtensions(egl::DisplayExtensions *outExtensions) const
{
    // TODO(hqle)
}

void DisplayMtl::generateCaps(egl::Caps *outCaps) const {}

void DisplayMtl::populateFeatureList(angle::FeatureList *features)
{
    // TODO(hqle)
}

egl::Error DisplayMtl::makeCurrentSurfaceless(gl::Context *context)
{
    UNIMPLEMENTED();
    return egl::NoError();
}

egl::ConfigSet DisplayMtl::generateConfigs()
{
    // TODO(cwallez): generate more config permutations
    egl::ConfigSet configs;

    const gl::Version &maxVersion = getMaxSupportedESVersion();
    ASSERT(maxVersion >= gl::Version(2, 0));
    bool supportsES3 = maxVersion >= gl::Version(3, 0);

    egl::Config config;

    // Native stuff
    config.nativeVisualID   = 0;
    config.nativeVisualType = 0;
    config.nativeRenderable = EGL_TRUE;

    // Buffer sizes
    config.redSize     = 8;
    config.greenSize   = 8;
    config.blueSize    = 8;
    config.alphaSize   = 8;
    config.depthSize   = 24;
    config.stencilSize = 8;

    config.colorBufferType = EGL_RGB_BUFFER;
    config.luminanceSize   = 0;
    config.alphaMaskSize   = 0;

    config.bufferSize = config.redSize + config.greenSize + config.blueSize + config.alphaSize;

    config.transparentType = EGL_NONE;

    // Pbuffer
    config.maxPBufferWidth  = 4096;
    config.maxPBufferHeight = 4096;
    config.maxPBufferPixels = 4096 * 4096;

    // Caveat
    config.configCaveat = EGL_NONE;

    // Misc
    config.sampleBuffers     = 0;
    config.samples           = 0;
    config.level             = 0;
    config.bindToTextureRGB  = EGL_FALSE;
    config.bindToTextureRGBA = EGL_FALSE;

    config.surfaceType = EGL_WINDOW_BIT | EGL_PBUFFER_BIT;

    config.minSwapInterval = 1;
    config.maxSwapInterval = 1;

    config.renderTargetFormat = GL_RGBA8;
    config.depthStencilFormat = GL_DEPTH24_STENCIL8;

    config.conformant     = EGL_OPENGL_ES2_BIT | (supportsES3 ? EGL_OPENGL_ES3_BIT_KHR : 0);
    config.renderableType = config.conformant;

    config.matchNativePixmap = EGL_NONE;

    config.colorComponentType = EGL_COLOR_COMPONENT_TYPE_FIXED_EXT;

    configs.add(config);
    return configs;
}

bool DisplayMtl::isValidNativeWindow(EGLNativeWindowType window) const
{
    NSObject *layer = (__bridge NSObject *)(window);
    return [layer isKindOfClass:[CALayer class]];
}

}  // namespace rx