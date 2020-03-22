//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// mtl_render_utils.h:
//    Defines the class interface for RenderUtils.
//

#ifndef LIBANGLE_RENDERER_METAL_MTL_RENDER_UTILS_H_
#define LIBANGLE_RENDERER_METAL_MTL_RENDER_UTILS_H_

#import <Metal/Metal.h>

#include "libANGLE/angletypes.h"
#include "libANGLE/renderer/metal/mtl_command_buffer.h"
#include "libANGLE/renderer/metal/mtl_state_cache.h"
#include "libANGLE/renderer/metal/shaders/constants.h"

namespace rx
{
namespace mtl
{
struct IndexConversionPipelineCacheKey
{
    gl::DrawElementsType srcType;
    bool srcBufferOffsetAligned;

    bool operator==(const IndexConversionPipelineCacheKey &other) const;

    size_t hash() const;
};

}  // namespace mtl
}  // namespace rx

namespace std
{

template <>
struct hash<rx::mtl::IndexConversionPipelineCacheKey>
{
    size_t operator()(const rx::mtl::IndexConversionPipelineCacheKey &key) const
    {
        return key.hash();
    }
};

}  // namespace std

namespace rx
{

class BufferMtl;
class ContextMtl;
class DisplayMtl;
class VisibilityBufferOffsetsMtl;

namespace mtl
{

struct ClearRectParams : public ClearOptions
{
    gl::Extents dstTextureSize;

    // Only clear enabled buffers
    gl::DrawBufferMask enabledBuffers;
    gl::Rectangle clearArea;

    bool flipY = false;
};

struct BlitParams
{
    gl::Extents dstTextureSize;
    gl::Rectangle dstRect;
    gl::Rectangle dstScissorRect;
    // Destination texture needs to have viewport Y flipped?
    // The difference between this param and unpackFlipY is that unpackFlipY is from
    // glCopyImageCHROMIUM(), and dstFlipY controls whether the final viewport needs to be
    // flipped when drawing to destination texture.
    bool dstFlipY = false;
    bool dstFlipX = false;

    TextureRef src;
    uint32_t srcLevel = 0;
    uint32_t srcLayer = 0;
    gl::Rectangle srcRect;
    bool srcYFlipped = false;  // source texture has data flipped in Y direction
    bool unpackFlipX = false;  // flip texture data copying process in X direction
    bool unpackFlipY = false;  // flip texture data copying process in Y direction
};

struct ColorBlitParams : public BlitParams
{
    MTLColorWriteMask blitColorMask = MTLColorWriteMaskAll;
    gl::DrawBufferMask enabledBuffers;
    GLenum filter               = GL_NEAREST;
    bool unpackPremultiplyAlpha = false;
    bool unpackUnmultiplyAlpha  = false;
    bool dstLuminance           = false;
};

struct DepthStencilBlitParams : public BlitParams
{
    TextureRef srcStencil;
    uint32_t srcStencilLevel = 0;
    uint32_t srcStencilLayer = 0;
};

struct TriFanFromArrayParams
{
    uint32_t firstVertex;
    uint32_t vertexCount;
    BufferRef dstBuffer;
    // Must be multiples of kIndexBufferOffsetAlignment
    uint32_t dstOffset;
};

struct IndexGenerationParams
{
    gl::DrawElementsType srcType;
    GLsizei indexCount;
    const void *indices;
    BufferRef dstBuffer;
    uint32_t dstOffset;
};

class RenderUtils : public Context, angle::NonCopyable
{
  public:
    RenderUtils(DisplayMtl *display);
    ~RenderUtils() override;

    angle::Result initialize();
    void onDestroy();

    // Clear current framebuffer
    angle::Result clearWithDraw(const gl::Context *context,
                                RenderCommandEncoder *cmdEncoder,
                                const ClearRectParams &params);
    // Blit texture data to current framebuffer
    angle::Result blitColorWithDraw(const gl::Context *context,
                                    RenderCommandEncoder *cmdEncoder,
                                    const ColorBlitParams &params);

    angle::Result blitDepthStencilWithDraw(const gl::Context *context,
                                           RenderCommandEncoder *cmdEncoder,
                                           const DepthStencilBlitParams &params);

    angle::Result convertIndexBuffer(ContextMtl *contextMtl,
                                     gl::DrawElementsType srcType,
                                     uint32_t indexCount,
                                     const BufferRef &srcBuffer,
                                     uint32_t srcOffset,
                                     const BufferRef &dstBuffer,
                                     // Must be multiples of kIndexBufferOffsetAlignment
                                     uint32_t dstOffset);
    angle::Result generateTriFanBufferFromArrays(ContextMtl *contextMtl,
                                                 const TriFanFromArrayParams &params);
    angle::Result generateTriFanBufferFromElementsArray(ContextMtl *contextMtl,
                                                        const IndexGenerationParams &params);

    angle::Result generateLineLoopLastSegment(ContextMtl *contextMtl,
                                              uint32_t firstVertex,
                                              uint32_t lastVertex,
                                              const BufferRef &dstBuffer,
                                              uint32_t dstOffset);
    angle::Result generateLineLoopLastSegmentFromElementsArray(ContextMtl *contextMtl,
                                                               const IndexGenerationParams &params);

    void combineVisibilityResult(ContextMtl *contextMtl,
                                 bool keepOldValue,
                                 const VisibilityBufferOffsetsMtl &renderPassResultBufOffsets,
                                 const BufferRef &renderPassResultBuf,
                                 const BufferRef &finalResultBuf);

    angle::Result generate3DMipmap(ContextMtl *contextMtl,
                                   const TextureRef &srcTexture,
                                   uint32_t baseLevel,
                                   gl::TexLevelArray<mtl::TextureRef> *mipmapOutputViews);

    void dispatchCompute(ContextMtl *contextMtl,
                         ComputeCommandEncoder *encoder,
                         id<MTLComputePipelineState> pipelineState,
                         size_t numThreads);

    void dispatchCompute(ContextMtl *contextMtl,
                         ComputeCommandEncoder *encoder,
                         bool allowNonUniform,
                         const MTLSize &numThreads,
                         const MTLSize &threadsPerThreadGroup);

  private:
    // override ErrorHandler
    void handleError(GLenum error,
                     const char *file,
                     const char *function,
                     unsigned int line) override;
    void handleError(NSError *_Nullable error,
                     const char *file,
                     const char *function,
                     unsigned int line) override;

    void initClearResources();
    void initBlitResources();

    void setupClearWithDraw(const gl::Context *context,
                            RenderCommandEncoder *cmdEncoder,
                            const ClearRectParams &params);
    void setupCommonBlitWithDraw(const gl::Context *context,
                                 RenderCommandEncoder *cmdEncoder,
                                 const BlitParams &params,
                                 bool isColorBlit);
    void setupColorBlitWithDraw(const gl::Context *context,
                                RenderCommandEncoder *cmdEncoder,
                                const ColorBlitParams &params);
    void setupDepthStencilBlitWithDraw(const gl::Context *context,
                                       RenderCommandEncoder *cmdEncoder,
                                       const DepthStencilBlitParams &params);
    id<MTLDepthStencilState> getClearDepthStencilState(const gl::Context *context,
                                                       const ClearRectParams &params);
    id<MTLRenderPipelineState> getClearRenderPipelineState(const gl::Context *context,
                                                           RenderCommandEncoder *cmdEncoder,
                                                           const ClearRectParams &params);
    id<MTLRenderPipelineState> getColorBlitRenderPipelineState(const gl::Context *context,
                                                               RenderCommandEncoder *cmdEncoder,
                                                               const ColorBlitParams &params);
    id<MTLRenderPipelineState> getDepthStencilBlitRenderPipelineState(
        const gl::Context *context,
        RenderCommandEncoder *cmdEncoder,
        const DepthStencilBlitParams &params);
    void setupBlitWithDrawUniformData(RenderCommandEncoder *cmdEncoder,
                                      const BlitParams &params,
                                      bool isColorBlit);

    void setupDrawCommonStates(RenderCommandEncoder *cmdEncoder);

    AutoObjCPtr<id<MTLComputePipelineState>> getIndexConversionPipeline(
        gl::DrawElementsType srcType,
        uint32_t srcOffset);
    AutoObjCPtr<id<MTLComputePipelineState>> getTriFanFromElemArrayGeneratorPipeline(
        gl::DrawElementsType srcType,
        uint32_t srcOffset);
    void ensureTriFanFromArrayGeneratorInitialized();
    void ensureVisibilityResultCombPipelineInitialized();
    void ensure3DMipGeneratorPipelineInitialized();
    angle::Result generateTriFanBufferFromElementsArrayGPU(
        ContextMtl *contextMtl,
        gl::DrawElementsType srcType,
        uint32_t indexCount,
        const BufferRef &srcBuffer,
        uint32_t srcOffset,
        const BufferRef &dstBuffer,
        // Must be multiples of kIndexBufferOffsetAlignment
        uint32_t dstOffset);
    angle::Result generateTriFanBufferFromElementsArrayCPU(ContextMtl *contextMtl,
                                                           const IndexGenerationParams &params);
    angle::Result generateLineLoopLastSegmentFromElementsArrayCPU(
        ContextMtl *contextMtl,
        const IndexGenerationParams &params);

    RenderPipelineCache mClearRenderPipelineCache[kMaxRenderTargets + 1];
    // First array dimension: number of outputs.
    // Second array dimension: source texture type (2d, ms, array, 3d, etc)
    using ColorBlitRenderPipelineCacheArray =
        std::array<std::array<RenderPipelineCache, mtl_shader::kTextureTypeCount>,
                   kMaxRenderTargets>;
    ColorBlitRenderPipelineCacheArray mBlitRenderPipelineCache;
    ColorBlitRenderPipelineCacheArray mBlitPremultiplyAlphaRenderPipelineCache;
    ColorBlitRenderPipelineCacheArray mBlitUnmultiplyAlphaRenderPipelineCache;

    std::array<RenderPipelineCache, mtl_shader::kTextureTypeCount> mDepthBlitRenderPipelineCache;
    std::array<RenderPipelineCache, mtl_shader::kTextureTypeCount> mStencilBlitRenderPipelineCache;
    std::array<std::array<RenderPipelineCache, mtl_shader::kTextureTypeCount>,
               mtl_shader::kTextureTypeCount>
        mDepthStencilBlitRenderPipelineCache;

    std::unordered_map<IndexConversionPipelineCacheKey, AutoObjCPtr<id<MTLComputePipelineState>>>
        mIndexConversionPipelineCaches;
    std::unordered_map<IndexConversionPipelineCacheKey, AutoObjCPtr<id<MTLComputePipelineState>>>
        mTriFanFromElemArrayGeneratorPipelineCaches;
    AutoObjCPtr<id<MTLComputePipelineState>> mTriFanFromArraysGeneratorPipeline;
    AutoObjCPtr<id<MTLComputePipelineState>> mVisibilityResultCombPipeline;
    AutoObjCPtr<id<MTLComputePipelineState>> m3DMipGeneratorPipeline;
};

}  // namespace mtl
}  // namespace rx

#endif /* LIBANGLE_RENDERER_METAL_MTL_RENDER_UTILS_H_ */
