//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#ifndef LIBANGLE_RENDERER_METAL_UTILSMTL_H_
#define LIBANGLE_RENDERER_METAL_UTILSMTL_H_

#include "libANGLE/renderer/metal/Metal_platform.h"

#include "libANGLE/angletypes.h"
#include "libANGLE/renderer/metal/StateCacheMtl.h"
#include "libANGLE/renderer/metal/mtl_command_buffer.h"

namespace rx
{

class ContextMtl;
class RendererMtl;

class UtilsMtl : public mtl::Context, angle::NonCopyable
{
  public:
    UtilsMtl(RendererMtl *renderer);
    ~UtilsMtl();

    struct ClearParams : public mtl::ClearOptions
    {
        gl::Rectangle clearArea;

        bool flipY = false;
    };

    struct BlitParams
    {
        gl::Offset dstOffset;
        bool dstFlipY = false;

        MTLColorWriteMask dstColorMask = MTLColorWriteMaskAll;

        mtl::TextureRef src;
        uint32_t srcLevel = 0;
        gl::Rectangle srcRect;
        bool srcYFlipped            = false;  // source texture has data flipped in Y direction
        bool unpackFlipY            = false;  // flip texture data copying process in Y direction
        bool unpackPremultiplyAlpha = false;
        bool unpackUnmultiplyAlpha  = false;
        bool dstLuminance           = false;
    };

    angle::Result initialize();
    void onDestroy();

    void clearWithDraw(const gl::Context *context,
                       mtl::RenderCommandEncoder *cmdEncoder,
                       const ClearParams &params);
    // Blit texture data to current framebuffer
    void blitWithDraw(const gl::Context *context,
                      mtl::RenderCommandEncoder *cmdEncoder,
                      const BlitParams &params);

  private:
    // override mtl::ErrorHandler
    void handleError(GLenum error,
                     const char *file,
                     const char *function,
                     unsigned int line) override;
    void handleError(NSError *_Nullable error,
                     const char *file,
                     const char *function,
                     unsigned int line) override;

    angle::Result initShaderLibrary();
    void initClearResources();
    void initBlitResources();

    void setupClearWithDraw(const gl::Context *context,
                            mtl::RenderCommandEncoder *cmdEncoder,
                            const ClearParams &params);
    void setupBlitWithDraw(const gl::Context *context,
                           mtl::RenderCommandEncoder *cmdEncoder,
                           const BlitParams &params);
    id<MTLDepthStencilState> getClearDepthStencilState(const gl::Context *context,
                                                       const ClearParams &params);
    id<MTLRenderPipelineState> getClearRenderPipelineState(const gl::Context *context,
                                                           mtl::RenderCommandEncoder *cmdEncoder,
                                                           const ClearParams &params);
    id<MTLRenderPipelineState> getBlitRenderPipelineState(const gl::Context *context,
                                                          mtl::RenderCommandEncoder *cmdEncoder,
                                                          const BlitParams &params);
    void setupBlitWithDrawUniformData(mtl::RenderCommandEncoder *cmdEncoder,
                                      const BlitParams &params);

    void setupDrawScreenQuadCommonStates(mtl::RenderCommandEncoder *cmdEncoder);

    mtl::AutoObjCPtr<id<MTLLibrary>> mDefaultShaders = nil;
    RenderPipelineCacheMtl mClearRenderPipelineCache;
    RenderPipelineCacheMtl mBlitRenderPipelineCache;
    RenderPipelineCacheMtl mBlitPremultiplyAlphaRenderPipelineCache;
    RenderPipelineCacheMtl mBlitUnmultiplyAlphaRenderPipelineCache;
};

}  // namespace rx

#endif /* LIBANGLE_RENDERER_METAL_UTILSMTL_H_ */
