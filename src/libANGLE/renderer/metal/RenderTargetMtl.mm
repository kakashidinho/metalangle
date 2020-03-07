//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// RenderTargetMtl.mm:
//    Implements the class methods for RenderTargetMtl.
//

#include "libANGLE/renderer/metal/RenderTargetMtl.h"

#include "libANGLE/renderer/metal/mtl_state_cache.h"

namespace rx
{
RenderTargetMtl::RenderTargetMtl()
    : mTextureRenderTargetInfo(std::make_shared<mtl::RenderPassAttachmentTextureTargetDesc>())
{}

RenderTargetMtl::~RenderTargetMtl()
{
    reset();
}

RenderTargetMtl::RenderTargetMtl(RenderTargetMtl &&other)
    : mTextureRenderTargetInfo(std::move(other.mTextureRenderTargetInfo))
{}

void RenderTargetMtl::set(const mtl::TextureRef &texture,
                          uint32_t level,
                          uint32_t layer,
                          const mtl::Format &format)
{
    mTextureRenderTargetInfo->texture = texture;
    mTextureRenderTargetInfo->level   = level;
    mTextureRenderTargetInfo->slice   = layer;
    mFormat                           = &format;
}

void RenderTargetMtl::set(const mtl::TextureRef &texture)
{
    mTextureRenderTargetInfo->texture = texture;
}

void RenderTargetMtl::reset()
{
    mTextureRenderTargetInfo->texture.reset();
    mTextureRenderTargetInfo->level = 0;
    mTextureRenderTargetInfo->slice = 0;
    mFormat                         = nullptr;
}

void RenderTargetMtl::toRenderPassAttachmentDesc(mtl::RenderPassAttachmentDesc *rpaDescOut) const
{
    rpaDescOut->renderTarget = mTextureRenderTargetInfo;
}
}
