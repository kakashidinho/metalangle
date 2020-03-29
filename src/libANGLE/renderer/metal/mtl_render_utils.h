//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// mtl_render_utils.h:
//    Defines the class interface for RenderUtils, which contains many utility functions and shaders
//    for converting, blitting, copying as well as generating data, and many more.
// NOTE(hqle): Consider splitting this class into multiple classes each doing different utilities.
// This class has become too big.
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

class BufferMtl;
class ContextMtl;
class DisplayMtl;
class VisibilityBufferOffsetsMtl;

namespace mtl
{

struct ClearRectParams
{
    Optional<ClearColorValue> clearColor;
    Optional<float> clearDepth;
    Optional<uint32_t> clearStencil;

    const mtl::Format *colorFormat = nullptr;
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

struct CopyPixelsCommonParams
{
    BufferRef buffer;
    uint32_t bufferStartOffset = 0;
    uint32_t bufferRowPitch    = 0;

    TextureRef texture;
};

struct CopyPixelsFromBufferParams : CopyPixelsCommonParams
{
    uint32_t bufferDepthPitch = 0;

    gl::Box textureArea;
};

struct CopyPixelsToBufferParams : CopyPixelsCommonParams
{
    gl::Rectangle textureArea;
    uint32_t textureLevel       = 0;
    uint32_t textureSliceOrDeph = 0;
    bool reverseTextureRowOrder;
};

struct VertexFormatConvertParams
{
    BufferRef srcBuffer;
    uint32_t srcBufferStartOffset = 0;
    uint32_t srcStride            = 0;
    uint32_t srcDefaultAlphaData  = 0;  // casted as uint

    BufferRef dstBuffer;
    uint32_t dstBufferStartOffset = 0;
    uint32_t dstStride            = 0;
    uint32_t dstComponents        = 0;

    uint32_t vertexCount = 0;
};

class ComputeBasedUtils
{
  public:
    virtual ~ComputeBasedUtils() = default;

    void dispatchCompute(ContextMtl *contextMtl,
                         ComputeCommandEncoder *encoder,
                         id<MTLComputePipelineState> pipelineState,
                         size_t numThreads);

    void dispatchCompute(ContextMtl *contextMtl,
                         ComputeCommandEncoder *encoder,
                         bool allowNonUniform,
                         const MTLSize &numThreads,
                         const MTLSize &threadsPerThreadGroup);
};

// Utils class for clear & blitting
class DrawBasedUtils
{
  protected:
    void setupDrawCommonStates(RenderCommandEncoder *cmdEncoder);
};

class BaseBlitUtils : public DrawBasedUtils
{
  protected:
    void setupCommonBlitWithDraw(const gl::Context *context,
                                 RenderCommandEncoder *cmdEncoder,
                                 const BlitParams &params,
                                 bool isColorBlit);
    void setupBlitWithDrawUniformData(RenderCommandEncoder *cmdEncoder,
                                      const BlitParams &params,
                                      bool isColorBlit);
};

class ClearUtils : DrawBasedUtils
{
  public:
    ClearUtils() = default;
    ClearUtils(const std::string &fragmentShaderName);
    ClearUtils(const ClearUtils &src);

    angle::Result initialize(Context *ctx);
    void onDestroy();

    // Clear current framebuffer
    angle::Result clearWithDraw(const gl::Context *context,
                                RenderCommandEncoder *cmdEncoder,
                                const ClearRectParams &params);

  private:
    void initClearResources(Context *ctx);

    void setupClearWithDraw(const gl::Context *context,
                            RenderCommandEncoder *cmdEncoder,
                            const ClearRectParams &params);
    id<MTLDepthStencilState> getClearDepthStencilState(const gl::Context *context,
                                                       const ClearRectParams &params);
    id<MTLRenderPipelineState> getClearRenderPipelineState(const gl::Context *context,
                                                           RenderCommandEncoder *cmdEncoder,
                                                           const ClearRectParams &params);

    const std::string mFragmentShaderName;

    // Render pipeline cache for clear with draw:
    std::array<RenderPipelineCache, kMaxRenderTargets + 1> mClearRenderPipelineCache;
};

class ColorBlitUtils : BaseBlitUtils
{
  public:
    ColorBlitUtils() = default;
    ColorBlitUtils(const std::string &fragmentShaderName);
    ColorBlitUtils(const ColorBlitUtils &src);

    angle::Result initialize(Context *ctx);
    void onDestroy();

    // Blit texture data to current framebuffer
    angle::Result blitColorWithDraw(const gl::Context *context,
                                    RenderCommandEncoder *cmdEncoder,
                                    const ColorBlitParams &params);

  private:
    void initBlitResources(Context *ctx);

    void setupColorBlitWithDraw(const gl::Context *context,
                                RenderCommandEncoder *cmdEncoder,
                                const ColorBlitParams &params);

    id<MTLRenderPipelineState> getColorBlitRenderPipelineState(const gl::Context *context,
                                                               RenderCommandEncoder *cmdEncoder,
                                                               const ColorBlitParams &params);

    const std::string mFragmentShaderName;

    // Blit with draw pipeline caches:
    // First array dimension: number of outputs.
    // Second array dimension: source texture type (2d, ms, array, 3d, etc)
    using ColorBlitRenderPipelineCacheArray =
        std::array<std::array<RenderPipelineCache, mtl_shader::kTextureTypeCount>,
                   kMaxRenderTargets>;
    ColorBlitRenderPipelineCacheArray mBlitRenderPipelineCache;
    ColorBlitRenderPipelineCacheArray mBlitPremultiplyAlphaRenderPipelineCache;
    ColorBlitRenderPipelineCacheArray mBlitUnmultiplyAlphaRenderPipelineCache;
};

class DepthStencilBlitUtils : BaseBlitUtils
{
  public:
    angle::Result initialize(Context *ctx);
    void onDestroy();

    angle::Result blitDepthStencilWithDraw(const gl::Context *context,
                                           RenderCommandEncoder *cmdEncoder,
                                           const DepthStencilBlitParams &params);

  private:
    void initBlitResources(Context *ctx);

    void setupDepthStencilBlitWithDraw(const gl::Context *context,
                                       RenderCommandEncoder *cmdEncoder,
                                       const DepthStencilBlitParams &params);
    id<MTLRenderPipelineState> getDepthStencilBlitRenderPipelineState(
        const gl::Context *context,
        RenderCommandEncoder *cmdEncoder,
        const DepthStencilBlitParams &params);

    std::array<RenderPipelineCache, mtl_shader::kTextureTypeCount> mDepthBlitRenderPipelineCache;
    std::array<RenderPipelineCache, mtl_shader::kTextureTypeCount> mStencilBlitRenderPipelineCache;
    std::array<std::array<RenderPipelineCache, mtl_shader::kTextureTypeCount>,
               mtl_shader::kTextureTypeCount>
        mDepthStencilBlitRenderPipelineCache;
};

// util class for generating index buffer
class IndexGeneratorUtils : public ComputeBasedUtils
{
  public:
    void onDestroy();

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

  private:
    AutoObjCPtr<id<MTLComputePipelineState>> getIndexConversionPipeline(
        ContextMtl *contextMtl,
        gl::DrawElementsType srcType,
        uint32_t srcOffset);
    AutoObjCPtr<id<MTLComputePipelineState>> getTriFanFromElemArrayGeneratorPipeline(
        ContextMtl *contextMtl,
        gl::DrawElementsType srcType,
        uint32_t srcOffset);
    void ensureTriFanFromArrayGeneratorInitialized(ContextMtl *contextMtl);

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

    // Index generator compute pipelines:
    //  - First dimension: index type.
    //  - second dimension: source buffer's offset is aligned or not.
    using IndexConversionPipelineArray =
        std::array<std::array<AutoObjCPtr<id<MTLComputePipelineState>>, 2>,
                   angle::EnumSize<gl::DrawElementsType>()>;
    IndexConversionPipelineArray mIndexConversionPipelineCaches;
    IndexConversionPipelineArray mTriFanFromElemArrayGeneratorPipelineCaches;
    AutoObjCPtr<id<MTLComputePipelineState>> mTriFanFromArraysGeneratorPipeline;
};

// Util class for handling visibility query result
class VisibilityResultUtils : public ComputeBasedUtils
{
  public:
    void onDestroy();

    void combineVisibilityResult(ContextMtl *contextMtl,
                                 bool keepOldValue,
                                 const VisibilityBufferOffsetsMtl &renderPassResultBufOffsets,
                                 const BufferRef &renderPassResultBuf,
                                 const BufferRef &finalResultBuf);

  private:
    void ensureVisibilityResultCombPipelineInitialized(ContextMtl *contextMtl);
    // Visibility combination compute pipeline:
    AutoObjCPtr<id<MTLComputePipelineState>> mVisibilityResultCombPipeline;
};

// Util class for handling mipmap generation
class MipmapUtils : public ComputeBasedUtils
{
  public:
    void onDestroy();

    // Compute based mipmap generation
    angle::Result generateMipmapCS(ContextMtl *contextMtl,
                                   const TextureRef &srcTexture,
                                   gl::TexLevelArray<mtl::TextureRef> *mipmapOutputViews);

  private:
    void ensure3DMipGeneratorPipelineInitialized(ContextMtl *contextMtl);
    void ensure2DMipGeneratorPipelineInitialized(ContextMtl *contextMtl);
    void ensure2DArrayMipGeneratorPipelineInitialized(ContextMtl *contextMtl);
    void ensureCubeMipGeneratorPipelineInitialized(ContextMtl *contextMtl);

    // Mipmaps generating compute pipeline:
    AutoObjCPtr<id<MTLComputePipelineState>> m3DMipGeneratorPipeline;
    AutoObjCPtr<id<MTLComputePipelineState>> m2DMipGeneratorPipeline;
    AutoObjCPtr<id<MTLComputePipelineState>> m2DArrayMipGeneratorPipeline;
    AutoObjCPtr<id<MTLComputePipelineState>> mCubeMipGeneratorPipeline;
};

// Util class for handling pixels copy between buffers and textures
class CopyPixelsUtils : public ComputeBasedUtils
{
  public:
    CopyPixelsUtils() = default;
    CopyPixelsUtils(const std::string &readShaderName, const std::string &writeShaderName);
    CopyPixelsUtils(const CopyPixelsUtils &src);

    void onDestroy();

    angle::Result unpackPixelsFromBufferToTexture(ContextMtl *contextMtl,
                                                  const angle::Format &srcAngleFormat,
                                                  const CopyPixelsFromBufferParams &params);
    angle::Result packPixelsFromTextureToBuffer(ContextMtl *contextMtl,
                                                const angle::Format &dstAngleFormat,
                                                const CopyPixelsToBufferParams &params);

  private:
    AutoObjCPtr<id<MTLComputePipelineState>> getPixelsCopyPipeline(ContextMtl *contextMtl,
                                                                   const angle::Format &angleFormat,
                                                                   const TextureRef &texture,
                                                                   bool bufferWrite);
    // Copy pixels between buffer and texture compute pipelines:
    // - First dimension: pixel format.
    // - Second dimension: texture type * (buffer read/write flag)
    using PixelsCopyPipelineArray = std::array<
        std::array<AutoObjCPtr<id<MTLComputePipelineState>>, mtl_shader::kTextureTypeCount * 2>,
        angle::kNumANGLEFormats>;
    PixelsCopyPipelineArray mPixelsCopyPipelineCaches;

    const std::string mReadShaderName;
    const std::string mWriteShaderName;
};

// Util class for handling vertex format conversion on GPU
class VertexFormatConversionUtils : public ComputeBasedUtils
{
  public:
    void onDestroy();

    // Convert vertex format to float
    angle::Result convertVertexFormatToFloat(ContextMtl *contextMtl,
                                             const angle::Format &srcAngleFormat,
                                             const VertexFormatConvertParams &params);
    // Expand number of components per vertex's attribute (or just simply copy components between
    // buffers with different stride and offset)
    angle::Result expandVertexFormatComponents(ContextMtl *contextMtl,
                                               const angle::Format &srcAngleFormat,
                                               const VertexFormatConvertParams &params);

  private:
    void ensureComponentsExpandPipelineCreated(ContextMtl *contextMtl);
    AutoObjCPtr<id<MTLComputePipelineState>> getFloatConverstionPipeline(
        ContextMtl *contextMtl,
        const angle::Format &srcAngleFormat);
    using ConvertToFloatPipelineArray =
        std::array<AutoObjCPtr<id<MTLComputePipelineState>>, angle::kNumANGLEFormats>;
    ConvertToFloatPipelineArray mConvertToFloatPipelineCaches;
    AutoObjCPtr<id<MTLComputePipelineState>> mComponentsExpandPipeline;
};

// RenderUtils: container class of variable util classes above
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
                                    const angle::Format &srcAngleFormat,
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

    // Compute based mipmap generation
    angle::Result generateMipmapCS(ContextMtl *contextMtl,
                                   const TextureRef &srcTexture,
                                   gl::TexLevelArray<mtl::TextureRef> *mipmapOutputViews);

    angle::Result unpackPixelsFromBufferToTexture(ContextMtl *contextMtl,
                                                  const angle::Format &srcAngleFormat,
                                                  const CopyPixelsFromBufferParams &params);
    angle::Result packPixelsFromTextureToBuffer(ContextMtl *contextMtl,
                                                const angle::Format &dstAngleFormat,
                                                const CopyPixelsToBufferParams &params);

    // Convert vertex format to float (or normalized) on GPU
    angle::Result convertVertexFormatToFloat(ContextMtl *contextMtl,
                                             const angle::Format &srcAngleFormat,
                                             const VertexFormatConvertParams &params);
    // Expand number of components per vertex's attribute (or just simply copy components between
    // buffers with different stride and offset) on GPU
    angle::Result expandVertexFormatComponents(ContextMtl *contextMtl,
                                               const angle::Format &srcAngleFormat,
                                               const VertexFormatConvertParams &params);

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

    std::array<ClearUtils, angle::EnumSize<PixelType>()> mClearUtils;

    std::array<ColorBlitUtils, angle::EnumSize<PixelType>()> mColorBlitUtils;

    DepthStencilBlitUtils mDepthStencilBlitUtils;

    IndexGeneratorUtils mIndexUtils;

    VisibilityResultUtils mVisibilityResultUtils;

    MipmapUtils mMipmapUtils;

    std::array<CopyPixelsUtils, angle::EnumSize<PixelType>()> mCopyPixelsUtils;

    VertexFormatConversionUtils mVertexFormatUtils;
};

}  // namespace mtl
}  // namespace rx

#endif /* LIBANGLE_RENDERER_METAL_MTL_RENDER_UTILS_H_ */
