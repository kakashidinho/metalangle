//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// mtl_command_buffer.h:
//    Defines the wrapper classes for MTLCommandEncoder and MTLCommandBuffer.
// TODO: define the wrapper class such that it can be changed to proxy class
// so that in future the command encoder can be reordered in a similar way
// to what Vulkan backend's Command Graph mechanism does
//

#ifndef LIBANGLE_RENDERER_METAL_COMMANDENBUFFERMTL_H_
#define LIBANGLE_RENDERER_METAL_COMMANDENBUFFERMTL_H_

#include "libANGLE/renderer/metal/Metal_platform.h"

#include <deque>
#include <memory>
#include <mutex>
#include <thread>
#include <unordered_set>
#include <vector>

#include "common/FixedVector.h"
#include "common/angleutils.h"
#include "libANGLE/renderer/metal/StateCacheMtl.h"
#include "libANGLE/renderer/metal/mtl_common.h"
#include "libANGLE/renderer/metal/mtl_resources.h"

namespace rx
{
namespace mtl
{

class CommandBuffer;
class CommandEncoder;
class RenderCommandEncoder;

class CommandQueue final : public WrappedObject<id<MTLCommandQueue>>, angle::NonCopyable
{
  public:
    void reset();
    void set(id<MTLCommandQueue> metalQueue);

    void finishAllCommands();

    void ensureResourceReadyForCPU(const ResourceRef &resource);
    void ensureResourceReadyForCPU(Resource *resource);
    bool isResourceBeingUsedByGPU(const ResourceRef &resource) const
    {
        return isResourceBeingUsedByGPU(resource.get());
    }
    bool isResourceBeingUsedByGPU(const Resource *resource) const;

    CommandQueue &operator=(id<MTLCommandQueue> metalQueue)
    {
        set(metalQueue);
        return *this;
    }

    AutoObjCPtr<id<MTLCommandBuffer>> makeMetalCommandBuffer(uint64_t *queueSerialOut);

  private:
    void onCommandBufferCompleted(id<MTLCommandBuffer> buf, uint64_t serial);
    typedef WrappedObject<id<MTLCommandQueue>> ParentClass;

    struct CmdBufferQueueEntry
    {
        AutoObjCPtr<id<MTLCommandBuffer>> buffer;
        uint64_t serial;
    };
    std::deque<CmdBufferQueueEntry> mQueuedMetalCmdBuffers;
    std::deque<CmdBufferQueueEntry> mQueuedMetalCmdBuffersTmp;

    uint64_t mQueueSerialCounter = 1;
    std::atomic<uint64_t> mCompletedBufferSerial{0};

    mutable std::mutex mLock;
};

class CommandBuffer final : public WrappedObject<id<MTLCommandBuffer>>, angle::NonCopyable
{
  public:
    CommandBuffer(CommandQueue *cmdQueue);
    ~CommandBuffer();

    void restart();

    bool valid() const;
    void commit();
    void finish();

    void present(id<CAMetalDrawable> presentationDrawable);

    void setWriteDependency(const ResourceRef &resource);
    void setReadDependency(const ResourceRef &resource);

    CommandQueue &cmdQueue() { return mCmdQueue; }

    void setActiveCommandEncoder(CommandEncoder *encoder);
    void invalidateActiveCommandEncoder(CommandEncoder *encoder);

  private:
    void set(id<MTLCommandBuffer> metalBuffer);
    void cleanup();

    bool validImpl() const;
    void commitImpl();

    typedef WrappedObject<id<MTLCommandBuffer>> ParentClass;

    CommandQueue &mCmdQueue;

    std::atomic<CommandEncoder *> mActiveCommandEncoder{nullptr};

    uint64_t mQueueSerial = 0;

    mutable std::mutex mLock;

    bool mCommitted = false;
};

class CommandEncoder : public WrappedObject<id<MTLCommandEncoder>>, angle::NonCopyable
{
  public:
    enum Type
    {
        RENDER,
        BLIT,
        COMPUTE,
    };

    virtual ~CommandEncoder();

    virtual void endEncoding();

    void reset();
    Type getType() const { return mType; }

    CommandEncoder &markResourceBeingWrittenByGPU(BufferRef buffer);
    CommandEncoder &markResourceBeingWrittenByGPU(TextureRef texture);

  protected:
    typedef WrappedObject<id<MTLCommandEncoder>> ParentClass;

    CommandEncoder(CommandBuffer *cmdBuffer, Type type);

    CommandBuffer &cmdBuffer() { return mCmdBuffer; }
    CommandQueue &cmdQueue() { return mCmdBuffer.cmdQueue(); }

    void set(id<MTLCommandEncoder> metalCmdEncoder);

  private:
    const Type mType;
    CommandBuffer &mCmdBuffer;
};

class RenderCommandEncoder final : public CommandEncoder
{
  public:
    struct StateCache
    {
        id<MTLRenderPipelineState> renderPipelineState                 = nil;
        MTLTriangleFillMode triangleFillMode                           = MTLTriangleFillModeFill;
        MTLWinding frontFace                                           = MTLWindingClockwise;
        MTLCullMode cullMode                                           = MTLCullModeNone;
        id<MTLDepthStencilState> depthStencilState                     = nil;
        float depthBias                                                = 0;
        float slopeScale                                               = 0;
        float clamp                                                    = 0;
        uint32_t frontStencilRef                                       = 0;
        uint32_t backStencilRef                                        = 0;
        angle::FixedVector<MTLViewport, kMaxViewports> viewports       = {};
        angle::FixedVector<MTLScissorRect, kMaxViewports> scissorRects = {};
        uint32_t numViewports                                          = 0;
        uint32_t numScissorRects                                       = 0;

        float blendR = 0;
        float blendG = 0;
        float blendB = 0;
        float blendA = 0;

        struct BufferBinding
        {
            BufferRef buffer;
            uint32_t offset = 0;
        };

        struct SamplerState
        {
            id<MTLSamplerState> stateObject;
            float lodMinClamp = 0;
            float lodMaxClamp = FLT_MAX;
        };

        angle::FixedVector<BufferBinding, kMaxShaderBuffers> vertexBuffers    = {};
        angle::FixedVector<TextureRef, kMaxShaderSamplers> vertexTextures     = {};
        angle::FixedVector<SamplerState, kMaxShaderSamplers> vertexSamplers   = {};
        angle::FixedVector<BufferBinding, kMaxShaderBuffers> fragmentBuffers  = {};
        angle::FixedVector<TextureRef, kMaxShaderSamplers> fragmentTextures   = {};
        angle::FixedVector<SamplerState, kMaxShaderSamplers> fragmentSamplers = {};
    };

    RenderCommandEncoder(CommandBuffer *cmdBuffer);
    ~RenderCommandEncoder();

    void endEncoding() override;

    RenderCommandEncoder &restart(const RenderPassDesc &desc);
    RenderCommandEncoder &restart(const RenderPassDesc &desc, const StateCache &retainedState);

    RenderCommandEncoder &setRenderPipelineState(id<MTLRenderPipelineState> state);
    RenderCommandEncoder &setTriangleFillMode(MTLTriangleFillMode mode);
    RenderCommandEncoder &setFrontFacingWinding(MTLWinding winding);
    RenderCommandEncoder &setCullMode(MTLCullMode mode);

    RenderCommandEncoder &setDepthStencilState(id<MTLDepthStencilState> state);
    RenderCommandEncoder &setDepthBias(float depthBias, float slopeScale, float clamp);
    RenderCommandEncoder &setStencilRefVals(uint32_t frontRef, uint32_t backRef);
    RenderCommandEncoder &setStencilRefVal(uint32_t ref);

    RenderCommandEncoder &setViewport(const MTLViewport &viewport);
    RenderCommandEncoder &setScissorRect(const MTLScissorRect &rect);

    RenderCommandEncoder &setBlendColor(float r, float g, float b, float a);

    RenderCommandEncoder &setVertexBuffer(BufferRef buffer, uint32_t offset, uint32_t index);
    RenderCommandEncoder &setVertexBytes(const uint8_t *bytes, size_t size, uint32_t index);
    template <typename T>
    RenderCommandEncoder &setVertexData(const T &data, uint32_t index)
    {
        return setVertexBytes(reinterpret_cast<const uint8_t *>(&data), sizeof(T), index);
    }
    RenderCommandEncoder &setVertexSamplerState(id<MTLSamplerState> state,
                                                float lodMinClamp,
                                                float lodMaxClamp,
                                                uint32_t index);
    RenderCommandEncoder &setVertexTexture(TextureRef texture, uint32_t index);

    RenderCommandEncoder &setFragmentBuffer(BufferRef buffer, uint32_t offset, uint32_t index);
    RenderCommandEncoder &setFragmentBytes(const uint8_t *bytes, size_t size, uint32_t index);
    template <typename T>
    RenderCommandEncoder &setFragmentData(const T &data, uint32_t index)
    {
        return setFragmentBytes(reinterpret_cast<const uint8_t *>(&data), sizeof(T), index);
    }
    RenderCommandEncoder &setFragmentSamplerState(id<MTLSamplerState> state,
                                                  float lodMinClamp,
                                                  float lodMaxClamp,
                                                  uint32_t index);
    RenderCommandEncoder &setFragmentTexture(TextureRef texture, uint32_t index);

    RenderCommandEncoder &draw(MTLPrimitiveType primitiveType,
                               uint32_t vertexStart,
                               uint32_t vertexCount);
    RenderCommandEncoder &drawIndexed(MTLPrimitiveType primitiveType,
                                      uint32_t indexCount,
                                      MTLIndexType indexType,
                                      BufferRef indexBuffer,
                                      size_t bufferOffset);

    RenderCommandEncoder &setColorStoreAction(MTLStoreAction action, uint32_t colorAttachmentIndex);
    // Set store action for every color attachment.
    RenderCommandEncoder &setColorStoreAction(MTLStoreAction action);

    RenderCommandEncoder &setDepthStencilStoreAction(MTLStoreAction depthStoreAction,
                                                     MTLStoreAction stencilStoreAction);

    const RenderPassDesc &renderPassDesc() const { return mRenderPassDesc; }
    const StateCache &getStateCache() const { return mStateCache; }

  private:
    id<MTLRenderCommandEncoder> get()
    {
        return static_cast<id<MTLRenderCommandEncoder>>(CommandEncoder::get());
    }

    RenderPassDesc mRenderPassDesc;
    MTLStoreAction mColorInitialStoreActions[kMaxRenderTargets];
    MTLStoreAction mDepthInitialStoreAction;
    MTLStoreAction mStencilInitialStoreAction;

    StateCache mStateCache;
};

class BlitCommandEncoder final : public CommandEncoder
{
  public:
    BlitCommandEncoder(CommandBuffer *cmdBuffer);
    ~BlitCommandEncoder();

    BlitCommandEncoder &restart();

    BlitCommandEncoder &copyTexture(TextureRef dst,
                                    uint32_t dstSlice,
                                    uint32_t dstLevel,
                                    MTLOrigin dstOrigin,
                                    MTLSize dstSize,
                                    TextureRef src,
                                    uint32_t srcSlice,
                                    uint32_t srcLevel,
                                    MTLOrigin srcOrigin);

    BlitCommandEncoder &generateMipmapsForTexture(TextureRef texture);
    BlitCommandEncoder &synchronizeResource(TextureRef texture);

  private:
    id<MTLBlitCommandEncoder> get()
    {
        return static_cast<id<MTLBlitCommandEncoder>>(CommandEncoder::get());
    }
};

class ComputeCommandEncoder final : public CommandEncoder
{
  public:
    ComputeCommandEncoder(CommandBuffer *cmdBuffer);
    ~ComputeCommandEncoder();

    ComputeCommandEncoder &restart();

    ComputeCommandEncoder &setComputePipelineState(id<MTLComputePipelineState> state);

    ComputeCommandEncoder &setBuffer(BufferRef buffer, uint32_t offset, uint32_t index);
    ComputeCommandEncoder &setBytes(const uint8_t *bytes, size_t size, uint32_t index);
    template <typename T>
    ComputeCommandEncoder &setData(const T &data, uint32_t index)
    {
        return setBytes(reinterpret_cast<const uint8_t *>(&data), sizeof(T), index);
    }
    ComputeCommandEncoder &setSamplerState(id<MTLSamplerState> state,
                                           float lodMinClamp,
                                           float lodMaxClamp,
                                           uint32_t index);
    ComputeCommandEncoder &setTexture(TextureRef texture, uint32_t index);

    ComputeCommandEncoder &dispatch(MTLSize threadGroupsPerGrid, MTLSize threadsPerGroup);

    ComputeCommandEncoder &dispatchNonUniform(MTLSize threadsPerGrid, MTLSize threadsPerGroup);

  private:
    id<MTLComputeCommandEncoder> get()
    {
        return static_cast<id<MTLComputeCommandEncoder>>(CommandEncoder::get());
    }
};

}  // namespace mtl
}  // namespace rx

#endif /* LIBANGLE_RENDERER_METAL_COMMANDENBUFFERMTL_H_ */
