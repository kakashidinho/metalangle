//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "libANGLE/renderer/metal/RendererMtl.h"

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

void RendererMtl::ensureCapsInitialized() const
{
    if (mCapsInitialized)
        return;
    mCapsInitialized = true;

    // TODO(hqle): Fill gl::Limitations
}
}
