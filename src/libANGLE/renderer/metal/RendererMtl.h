//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// RendererMtl.h:
//    Defines class interface for RendererMtl.

#ifndef LIBANGLE_RENDERER_METAL_RENDERERMTL_H_
#define LIBANGLE_RENDERER_METAL_RENDERERMTL_H_

#import <Metal/Metal.h>

#include "common/PackedEnums.h"
#include "libANGLE/angletypes.h"
#include "libANGLE/renderer/metal/StateCacheMtl.h"
#include "libANGLE/renderer/metal/UtilsMtl.h"
#include "libANGLE/renderer/metal/mtl_command_buffer.h"
#include "libANGLE/renderer/metal/mtl_format_utils.h"
#include "libANGLE/renderer/metal/mtl_utils.h"

namespace egl
{
class Display;
}

namespace rx
{

class ContextMtl;

class RendererMtl final : angle::NonCopyable
{
  public:
    RendererMtl();
    ~RendererMtl();

    angle::Result initialize(egl::Display *display);
    void onDestroy();

    std::string getVendorString() const;
    std::string getRendererDescription() const;
    gl::Caps getNativeCaps() const;
    const gl::TextureCapsMap &getNativeTextureCaps() const;
    const gl::Extensions &getNativeExtensions() const;
    const gl::Limitations &getNativeLimitations() const;

    id<MTLDevice> getMetalDevice() const { return mMetalDevice; }

    mtl::CommandQueue &cmdQueue() { return mCmdQueue; }
    const mtl::FormatTable &getFormatTable() const { return mFormatTable; }
    UtilsMtl &getUtils() { return mUtils; }
    StateCacheMtl &getStateCache() { return mStateCache; }

    id<MTLDepthStencilState> getDepthStencilState(const mtl::DepthStencilDesc &desc)
    {
        return mStateCache.getDepthStencilState(getMetalDevice(), desc);
    }
    id<MTLSamplerState> getSamplerState(const mtl::SamplerDesc &desc)
    {
        return mStateCache.getSamplerState(getMetalDevice(), desc);
    }

    mtl::TextureRef getNullTexture(const gl::Context *context, gl::TextureType type);

    const mtl::Format &getPixelFormat(angle::FormatID angleFormatId) const
    {
        return mFormatTable.getPixelFormat(angleFormatId);
    }

    // See mtl::FormatTable::getVertexFormat()
    const mtl::VertexFormat &getVertexFormat(angle::FormatID angleFormatId,
                                             bool tightlyPacked) const
    {
        return mFormatTable.getVertexFormat(angleFormatId, tightlyPacked);
    }

  private:
    void ensureCapsInitialized() const;
    void initializeCaps() const;
    void initializeExtensions() const;
    void initializeTextureCaps() const;

    mtl::AutoObjCPtr<id<MTLDevice>> mMetalDevice = nil;

    mtl::CommandQueue mCmdQueue;

    mtl::FormatTable mFormatTable;
    StateCacheMtl mStateCache;
    UtilsMtl mUtils;

    static const size_t kNumTexturesType = static_cast<size_t>(gl::TextureType::EnumCount);
    mtl::TextureRef mNullTextures[kNumTexturesType];

    mutable bool mCapsInitialized;
    mutable gl::TextureCapsMap mNativeTextureCaps;
    mutable gl::Extensions mNativeExtensions;
    mutable gl::Caps mNativeCaps;
    mutable gl::Limitations mNativeLimitations;
};
}  // namespace rx

#endif /* LIBANGLE_RENDERER_METAL_RENDERERMTL_H_ */
