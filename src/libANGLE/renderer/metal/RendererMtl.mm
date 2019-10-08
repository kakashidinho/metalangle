//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "libANGLE/renderer/metal/RendererMtl.h"

#include "libANGLE/renderer/metal/ContextMtl.h"
#include "libANGLE/renderer/metal/GlslangWrapper.h"
#include "libANGLE/renderer/metal/mtl_common.h"

namespace rx
{
RendererMtl::RendererMtl() : mUtils(this) {}

RendererMtl::~RendererMtl() {}

angle::Result RendererMtl::initialize(egl::Display *display)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        mMetalDevice = MTLCreateSystemDefaultDevice();
        if (!mMetalDevice)
        {
            return angle::Result::Stop;
        }

        mCmdQueue.set([mMetalDevice.get() newCommandQueue]);

        mCapsInitialized = false;

        GlslangWrapperMtl::Initialize();

        return mUtils.initialize();
    }
}
void RendererMtl::onDestroy()
{
    for (auto &nullTex : mNullTextures)
    {
        nullTex.reset();
    }
    mUtils.onDestroy();
    mCmdQueue.reset();
    mMetalDevice     = nil;
    mCapsInitialized = false;

    GlslangWrapperMtl::Release();
}

std::string RendererMtl::getVendorString() const
{
    std::string vendorString = "Google Inc.";
    if (mMetalDevice)
    {
        vendorString += " ";
        vendorString += mMetalDevice.get().name.UTF8String;
    }

    return vendorString;
}

std::string RendererMtl::getRendererDescription() const
{
    std::string desc = "Metal Renderer";

    if (mMetalDevice)
    {
        desc += ": ";
        desc += mMetalDevice.get().name.UTF8String;
    }

    return desc;
}

const gl::Limitations &RendererMtl::getNativeLimitations() const
{
    ensureCapsInitialized();
    return mNativeLimitations;
}

mtl::TextureRef RendererMtl::getNullTexture(const gl::Context *context, gl::TextureType typeEnum)
{
    ContextMtl *contextMtl = mtl::GetImpl(context);
    int type               = static_cast<int>(typeEnum);
    if (!mNullTextures[type])
    {
        // initialize content with zeros
        MTLRegion region           = MTLRegionMake2D(0, 0, 1, 1);
        const uint8_t zeroPixel[4] = {0, 0, 0, 255};

        switch (typeEnum)
        {
            case gl::TextureType::_2D:
                (void)(mtl::Texture::Make2DTexture(contextMtl, MTLPixelFormatRGBA8Unorm, 1, 1, 1,
                                                   false, &mNullTextures[type]));
                mNullTextures[type]->replaceRegion(contextMtl, region, 0, 0, zeroPixel,
                                                   sizeof(zeroPixel));
                break;
            case gl::TextureType::CubeMap:
                (void)(mtl::Texture::MakeCubeTexture(contextMtl, MTLPixelFormatRGBA8Unorm, 1, 1,
                                                     false, &mNullTextures[type]));
                for (int f = 0; f < 6; ++f)
                {
                    mNullTextures[type]->replaceRegion(contextMtl, region, 0, f, zeroPixel,
                                                       sizeof(zeroPixel));
                }
                break;
            default:
                UNREACHABLE();
                // TODO(hqle): Support more texture types.
                return nullptr;
        }
        ASSERT(mNullTextures[type]);
    }

    return mNullTextures[type];
}

void RendererMtl::ensureCapsInitialized() const
{
    if (mCapsInitialized)
        return;
    mCapsInitialized = true;

    // TODO(hqle): Fill gl::Limitations
}
}
