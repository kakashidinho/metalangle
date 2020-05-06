//
// Copyright 2020 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// ImageMtl.cpp:
//    Implements the class methods for ImageMtl.
//

#include "libANGLE/renderer/metal/ImageMtl.h"

#include "common/debug.h"
#include "libANGLE/Context.h"
#include "libANGLE/Display.h"
#include "libANGLE/renderer/metal/ContextMtl.h"
#include "libANGLE/renderer/metal/DisplayMtl.h"
#include "libANGLE/renderer/metal/RenderBufferMtl.h"
#include "libANGLE/renderer/metal/TextureMtl.h"

namespace rx
{

ImageMtl::ImageMtl(const egl::ImageState &state, const gl::Context *context)
    : ImageImpl(state), mContext(context)
{}

ImageMtl::~ImageMtl() {}

void ImageMtl::onDestroy(const egl::Display *display)
{
    mNativeTexture = nullptr;
}

egl::Error ImageMtl::initialize(const egl::Display *display)
{
    if (egl::IsTextureTarget(mState.target))
    {
        TextureMtl *textureMtl = GetImplAs<TextureMtl>(GetAs<gl::Texture>(mState.source));

        // Make sure the texture has created its backing storage
        ASSERT(mContext != nullptr);
        ANGLE_TRY(ResultToEGL(textureMtl->ensureTextureCreated(mContext)));

        mNativeTexture = textureMtl->getNativeTexture();
        mImageTextureType = mState.imageIndex.getType();
        mImageLevel       = mState.imageIndex.getLevelIndex();
        mImageLayer       = mState.imageIndex.hasLayer() ? mState.imageIndex.getLayerIndex() : 0;
    }
    else
    {
        if (egl::IsRenderbufferTarget(mState.target))
        {
            RenderbufferMtl *renderbufferMtl =
                GetImplAs<RenderbufferMtl>(GetAs<gl::Renderbuffer>(mState.source));
            mNativeTexture = renderbufferMtl->getTexture();
        }
        else
        {
            UNREACHABLE();
            return egl::EglBadAccess();
        }

        mImageTextureType = gl::TextureType::_2D;
        mImageLevel       = 0;
        mImageLayer       = 0;
    }

    return egl::NoError();
}

angle::Result ImageMtl::orphan(const gl::Context *context, egl::ImageSibling *sibling)
{
    if (sibling == mState.source)
    {
        mNativeTexture = nullptr;
    }

    return angle::Result::Continue;
}

}  // namespace rx
