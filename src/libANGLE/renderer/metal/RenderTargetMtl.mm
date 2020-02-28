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

RenderTargetMtl::~RenderTargetMtl() {}

RenderTargetMtl::RenderTargetMtl(RenderTargetMtl &&other)
    : mTextureRenderTargetInfo(std::move(other.mTextureRenderTargetInfo))
{}

void RenderTargetMtl::reset(const mtl::TextureRef &texture,
                            uint32_t level,
                            uint32_t layer,
                            const mtl::Format &format)
{
    // Recreate render target info to invalidate any old references stored in mtl::RenderPassDesc.
    // This to ensure that new render pass would be started with new texture attachment.
    mTextureRenderTargetInfo.reset(new mtl::RenderPassAttachmentTextureTargetDesc());

    mTextureRenderTargetInfo->texture = texture;
    mTextureRenderTargetInfo->level   = level;
    mTextureRenderTargetInfo->slice   = layer;
    mFormat                           = &format;
}

void RenderTargetMtl::reset(const mtl::TextureRef &texture)
{
    // Recreate render target info to invalidate any old references stored in mtl::RenderPassDesc.
    // This to ensure that new render pass would be started with new texture attachment.
    auto oldInfo = mTextureRenderTargetInfo;
    mTextureRenderTargetInfo.reset(new mtl::RenderPassAttachmentTextureTargetDesc(*oldInfo));
    mTextureRenderTargetInfo->texture = texture;
}

void RenderTargetMtl::reset()
{
    mTextureRenderTargetInfo.reset(new mtl::RenderPassAttachmentTextureTargetDesc());
    mFormat = nullptr;
}

void RenderTargetMtl::toRenderPassAttachmentDesc(mtl::RenderPassAttachmentDesc *rpaDescOut) const
{
    rpaDescOut->renderTarget = mTextureRenderTargetInfo;
}
}
