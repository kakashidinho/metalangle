//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// mtl_command_buffer.mm:
//      Implementations of Metal framework's MTLCommandBuffer, MTLCommandQueue,
//      MTLCommandEncoder's wrappers.
//

#include "libANGLE/renderer/metal/mtl_command_buffer.h"

#include <cassert>
#if ANGLE_MTL_SIMULATE_DISCARD_FRAMEBUFFER
#    include <random>
#endif

#include "common/debug.h"
#include "libANGLE/renderer/metal/mtl_resources.h"

namespace rx
{
namespace mtl
{

namespace
{

#define ANGLE_MTL_CMD_X(PROC)            \
    PROC(SetRenderPipelineState)         \
    PROC(SetTriangleFillMode)            \
    PROC(SetFrontFacingWinding)          \
    PROC(SetCullMode)                    \
    PROC(SetDepthStencilState)           \
    PROC(SetDepthBias)                   \
    PROC(SetStencilRefVals)              \
    PROC(SetViewport)                    \
    PROC(SetScissorRect)                 \
    PROC(SetBlendColor)                  \
    PROC(SetVertexBuffer)                \
    PROC(SetVertexBytes)                 \
    PROC(SetVertexSamplerState)          \
    PROC(SetVertexTexture)               \
    PROC(SetFragmentBuffer)              \
    PROC(SetFragmentBytes)               \
    PROC(SetFragmentSamplerState)        \
    PROC(SetFragmentTexture)             \
    PROC(Draw)                           \
    PROC(DrawInstanced)                  \
    PROC(DrawIndexed)                    \
    PROC(DrawIndexedInstanced)           \
    PROC(DrawIndexedInstancedBaseVertex) \
    PROC(InsertDebugsign)

#define ANGLE_MTL_TYPE_DECL(CMD) CMD,

// Command types
enum class CmdType : uint8_t
{
    ANGLE_MTL_CMD_X(ANGLE_MTL_TYPE_DECL)
};

// Commands decoder
void SetRenderPipelineStateCmd(id<MTLRenderCommandEncoder> encoder,
                               IntermediateCommandStream *stream)
{
    auto state = stream->fetch<id<MTLRenderPipelineState>>();
    [encoder setRenderPipelineState:state];
    [state ANGLE_MTL_RELEASE];
}

void SetTriangleFillModeCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto mode = stream->fetch<MTLTriangleFillMode>();
    [encoder setTriangleFillMode:mode];
}

void SetFrontFacingWindingCmd(id<MTLRenderCommandEncoder> encoder,
                              IntermediateCommandStream *stream)
{
    auto winding = stream->fetch<MTLWinding>();
    [encoder setFrontFacingWinding:winding];
}

void SetCullModeCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto mode = stream->fetch<MTLCullMode>();
    [encoder setCullMode:mode];
}

void SetDepthStencilStateCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto state = stream->fetch<id<MTLDepthStencilState>>();
    [encoder setDepthStencilState:state];
    [state ANGLE_MTL_RELEASE];
}

void SetDepthBiasCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto depthBias  = stream->fetch<float>();
    auto slopeScale = stream->fetch<float>();
    auto clamp      = stream->fetch<float>();
    [encoder setDepthBias:depthBias slopeScale:slopeScale clamp:clamp];
}

void SetStencilRefValsCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    // Metal has some bugs when reference values are larger than 0xff
    uint32_t frontRef = stream->fetch<uint32_t>();
    uint32_t backRef  = stream->fetch<uint32_t>();
    [encoder setStencilFrontReferenceValue:frontRef backReferenceValue:backRef];
}

void SetViewportCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto viewport = stream->fetch<MTLViewport>();
    [encoder setViewport:viewport];
}

void SetScissorRectCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto rect = stream->fetch<MTLScissorRect>();
    [encoder setScissorRect:rect];
}

void SetBlendColorCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    float r = stream->fetch<float>();
    float g = stream->fetch<float>();
    float b = stream->fetch<float>();
    float a = stream->fetch<float>();
    [encoder setBlendColorRed:r green:g blue:b alpha:a];
}

void SetVertexBufferCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto buffer = stream->fetch<id<MTLBuffer>>();
    auto offset = stream->fetch<uint32_t>();
    auto index  = stream->fetch<uint32_t>();
    [encoder setVertexBuffer:buffer offset:offset atIndex:index];
    [buffer ANGLE_MTL_RELEASE];
}

void SetVertexBytesCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto size  = stream->fetch<size_t>();
    auto bytes = stream->fetch(size);
    auto index = stream->fetch<uint32_t>();
    [encoder setVertexBytes:bytes length:size atIndex:index];
}

void SetVertexSamplerStateCmd(id<MTLRenderCommandEncoder> encoder,
                              IntermediateCommandStream *stream)
{
    auto state        = stream->fetch<id<MTLSamplerState>>();
    float lodMinClamp = stream->fetch<float>();
    float lodMaxClamp = stream->fetch<float>();
    auto index        = stream->fetch<uint32_t>();
    [encoder setVertexSamplerState:state
                       lodMinClamp:lodMinClamp
                       lodMaxClamp:lodMaxClamp
                           atIndex:index];

    [state ANGLE_MTL_RELEASE];
}

void SetVertexTextureCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto texture = stream->fetch<id<MTLTexture>>();
    auto index   = stream->fetch<uint32_t>();
    [encoder setVertexTexture:texture atIndex:index];
    [texture ANGLE_MTL_RELEASE];
}

void SetFragmentBufferCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto buffer = stream->fetch<id<MTLBuffer>>();
    auto offset = stream->fetch<uint32_t>();
    auto index  = stream->fetch<uint32_t>();
    [encoder setFragmentBuffer:buffer offset:offset atIndex:index];
    [buffer ANGLE_MTL_RELEASE];
}

void SetFragmentBytesCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto size  = stream->fetch<size_t>();
    auto bytes = stream->fetch(size);
    auto index = stream->fetch<uint32_t>();
    [encoder setFragmentBytes:bytes length:size atIndex:index];
}

void SetFragmentSamplerStateCmd(id<MTLRenderCommandEncoder> encoder,
                                IntermediateCommandStream *stream)
{
    auto state        = stream->fetch<id<MTLSamplerState>>();
    float lodMinClamp = stream->fetch<float>();
    float lodMaxClamp = stream->fetch<float>();
    auto index        = stream->fetch<uint32_t>();
    [encoder setFragmentSamplerState:state
                         lodMinClamp:lodMinClamp
                         lodMaxClamp:lodMaxClamp
                             atIndex:index];
    [state ANGLE_MTL_RELEASE];
}

void SetFragmentTextureCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto texture = stream->fetch<id<MTLTexture>>();
    auto index   = stream->fetch<uint32_t>();
    [encoder setFragmentTexture:texture atIndex:index];
    [texture ANGLE_MTL_RELEASE];
}

void DrawCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto primitiveType = stream->fetch<MTLPrimitiveType>();
    auto vertexStart   = stream->fetch<uint32_t>();
    auto vertexCount   = stream->fetch<uint32_t>();
    [encoder drawPrimitives:primitiveType vertexStart:vertexStart vertexCount:vertexCount];
}

void DrawInstancedCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto primitiveType = stream->fetch<MTLPrimitiveType>();
    auto vertexStart   = stream->fetch<uint32_t>();
    auto vertexCount   = stream->fetch<uint32_t>();
    auto instances     = stream->fetch<uint32_t>();
    [encoder drawPrimitives:primitiveType
                vertexStart:vertexStart
                vertexCount:vertexCount
              instanceCount:instances];
}

void DrawIndexedCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto primitiveType = stream->fetch<MTLPrimitiveType>();
    auto indexCount    = stream->fetch<uint32_t>();
    auto indexType     = stream->fetch<MTLIndexType>();
    auto indexBuffer   = stream->fetch<id<MTLBuffer>>();
    auto bufferOffset  = stream->fetch<size_t>();
    [encoder drawIndexedPrimitives:primitiveType
                        indexCount:indexCount
                         indexType:indexType
                       indexBuffer:indexBuffer
                 indexBufferOffset:bufferOffset];
    [indexBuffer ANGLE_MTL_RELEASE];
}

void DrawIndexedInstancedCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto primitiveType = stream->fetch<MTLPrimitiveType>();
    auto indexCount    = stream->fetch<uint32_t>();
    auto indexType     = stream->fetch<MTLIndexType>();
    auto indexBuffer   = stream->fetch<id<MTLBuffer>>();
    auto bufferOffset  = stream->fetch<size_t>();
    auto instances     = stream->fetch<uint32_t>();
    [encoder drawIndexedPrimitives:primitiveType
                        indexCount:indexCount
                         indexType:indexType
                       indexBuffer:indexBuffer
                 indexBufferOffset:bufferOffset
                     instanceCount:instances];
    [indexBuffer ANGLE_MTL_RELEASE];
}

void DrawIndexedInstancedBaseVertexCmd(id<MTLRenderCommandEncoder> encoder,
                                       IntermediateCommandStream *stream)
{
    auto primitiveType = stream->fetch<MTLPrimitiveType>();
    auto indexCount    = stream->fetch<uint32_t>();
    auto indexType     = stream->fetch<MTLIndexType>();
    auto indexBuffer   = stream->fetch<id<MTLBuffer>>();
    auto bufferOffset  = stream->fetch<size_t>();
    auto instances     = stream->fetch<uint32_t>();
    auto baseVertex    = stream->fetch<uint32_t>();
    [encoder drawIndexedPrimitives:primitiveType
                        indexCount:indexCount
                         indexType:indexType
                       indexBuffer:indexBuffer
                 indexBufferOffset:bufferOffset
                     instanceCount:instances
                        baseVertex:baseVertex
                      baseInstance:0];
    [indexBuffer ANGLE_MTL_RELEASE];
}

void InsertDebugsignCmd(id<MTLRenderCommandEncoder> encoder, IntermediateCommandStream *stream)
{
    auto label = stream->fetch<NSString *>();
    [encoder insertDebugSignpost:label];
    [label ANGLE_MTL_RELEASE];
}

// Command decoder mapping
#define ANGLE_MTL_CMD_MAP(CMD) CMD##Cmd,

using CommandEncoderFunc = void (*)(id<MTLRenderCommandEncoder>, IntermediateCommandStream *);
constexpr CommandEncoderFunc gCommandEncoders[] = {ANGLE_MTL_CMD_X(ANGLE_MTL_CMD_MAP)};

}

// CommandQueue implementation
void CommandQueue::reset()
{
    finishAllCommands();
    ParentClass::reset();
}

void CommandQueue::set(id<MTLCommandQueue> metalQueue)
{
    finishAllCommands();

    ParentClass::set(metalQueue);
}

void CommandQueue::finishAllCommands()
{
    {
        // Copy to temp list
        std::lock_guard<std::mutex> lg(mLock);

        for (CmdBufferQueueEntry &metalBufferEntry : mMetalCmdBuffers)
        {
            mMetalCmdBuffersTmp.push_back(metalBufferEntry);
        }

        mMetalCmdBuffers.clear();
    }

    // Wait for command buffers to finish
    for (CmdBufferQueueEntry &metalBufferEntry : mMetalCmdBuffersTmp)
    {
        [metalBufferEntry.buffer waitUntilCompleted];
    }
    mMetalCmdBuffersTmp.clear();
}

void CommandQueue::ensureResourceReadyForCPU(const ResourceRef &resource)
{
    if (!resource)
    {
        return;
    }

    ensureResourceReadyForCPU(resource.get());
}

void CommandQueue::ensureResourceReadyForCPU(Resource *resource)
{
    mLock.lock();
    while (isResourceBeingUsedByGPU(resource) && !mMetalCmdBuffers.empty())
    {
        CmdBufferQueueEntry metalBufferEntry = mMetalCmdBuffers.front();
        mMetalCmdBuffers.pop_front();
        mLock.unlock();

        ANGLE_MTL_LOG("Waiting for MTLCommandBuffer %llu:%p", metalBufferEntry.serial,
                      metalBufferEntry.buffer.get());
        [metalBufferEntry.buffer waitUntilCompleted];

        mLock.lock();
    }
    mLock.unlock();

    // This can happen if the resource is read then write in the same command buffer.
    // So it is the responsitibily of outer code to ensure the command buffer is commit before
    // the resource can be read or written again
    ASSERT(!isResourceBeingUsedByGPU(resource));
}

bool CommandQueue::isResourceBeingUsedByGPU(const Resource *resource) const
{
    if (!resource)
    {
        return false;
    }

    return mCompletedBufferSerial.load(std::memory_order_relaxed) <
           resource->getCommandBufferQueueSerial().load(std::memory_order_relaxed);
}

AutoObjCPtr<id<MTLCommandBuffer>> CommandQueue::makeMetalCommandBuffer(uint64_t *queueSerialOut)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        AutoObjCPtr<id<MTLCommandBuffer>> metalCmdBuffer = [get() commandBuffer];

        std::lock_guard<std::mutex> lg(mLock);

        uint64_t serial = mQueueSerialCounter++;

        mMetalCmdBuffers.push_back({metalCmdBuffer, serial});

        ANGLE_MTL_LOG("Created MTLCommandBuffer %llu:%p", serial, metalCmdBuffer.get());

        [metalCmdBuffer addCompletedHandler:^(id<MTLCommandBuffer> buf) {
          onCommandBufferCompleted(buf, serial);
        }];

        [metalCmdBuffer enqueue];

        ASSERT(metalCmdBuffer);

        *queueSerialOut = serial;

        return metalCmdBuffer;
    }
}

void CommandQueue::onCommandBufferCompleted(id<MTLCommandBuffer> buf, uint64_t serial)
{
    std::lock_guard<std::mutex> lg(mLock);

    ANGLE_MTL_LOG("Completed MTLCommandBuffer %llu:%p", serial, buf);

    if (mCompletedBufferSerial >= serial)
    {
        // Already handled.
        return;
    }

    while (!mMetalCmdBuffers.empty() && mMetalCmdBuffers.front().serial <= serial)
    {
        CmdBufferQueueEntry metalBufferEntry = mMetalCmdBuffers.front();
        ANGLE_UNUSED_VARIABLE(metalBufferEntry);
        ANGLE_MTL_LOG("Popped MTLCommandBuffer %llu:%p", metalBufferEntry.serial,
                      metalBufferEntry.buffer.get());

        mMetalCmdBuffers.pop_front();
    }

    mCompletedBufferSerial.store(
        std::max(mCompletedBufferSerial.load(std::memory_order_relaxed), serial),
        std::memory_order_relaxed);
}

// CommandBuffer implementation
CommandBuffer::CommandBuffer(CommandQueue *cmdQueue) : mCmdQueue(*cmdQueue) {}

CommandBuffer::~CommandBuffer()
{
    finish();
    cleanup();
}

bool CommandBuffer::valid() const
{
    std::lock_guard<std::mutex> lg(mLock);

    return validImpl();
}

void CommandBuffer::commit()
{
    std::lock_guard<std::mutex> lg(mLock);
    commitImpl();
}

void CommandBuffer::finish()
{
    commit();
    [get() waitUntilCompleted];
}

void CommandBuffer::present(id<CAMetalDrawable> presentationDrawable)
{
    [get() presentDrawable:presentationDrawable];
}

void CommandBuffer::setWriteDependency(const ResourceRef &resource)
{
    if (!resource)
    {
        return;
    }

    std::lock_guard<std::mutex> lg(mLock);

    if (!validImpl())
    {
        return;
    }

    resource->setUsedByCommandBufferWithQueueSerial(mQueueSerial, true);
}

void CommandBuffer::setReadDependency(const ResourceRef &resource)
{
    if (!resource)
    {
        return;
    }

    std::lock_guard<std::mutex> lg(mLock);

    if (!validImpl())
    {
        return;
    }

    resource->setUsedByCommandBufferWithQueueSerial(mQueueSerial, false);
}

void CommandBuffer::restart()
{
    uint64_t serial     = 0;
    auto metalCmdBuffer = mCmdQueue.makeMetalCommandBuffer(&serial);

    std::lock_guard<std::mutex> lg(mLock);

    set(metalCmdBuffer);
    mQueueSerial = serial;
    mCommitted   = false;

    ASSERT(metalCmdBuffer);
}

void CommandBuffer::insertDebugSign(const std::string &marker)
{
    mtl::CommandEncoder *currentEncoder = mActiveCommandEncoder.load(std::memory_order_relaxed);
    if (currentEncoder)
    {
        currentEncoder->insertDebugSign(marker);
    }
    else
    {
        mPendingDebugSigns.push_back(marker);
    }
}

void CommandBuffer::pushDebugGroup(const std::string &marker)
{
    // NOTE(hqle): to implement this
}

void CommandBuffer::popDebugGroup()
{
    // NOTE(hqle): to implement this
}

/** private use only */
void CommandBuffer::set(id<MTLCommandBuffer> metalBuffer)
{
    ParentClass::set(metalBuffer);
}

void CommandBuffer::setActiveCommandEncoder(CommandEncoder *encoder)
{
    mActiveCommandEncoder = encoder;
    for (auto &marker : mPendingDebugSigns)
    {
        encoder->insertDebugSign(marker);
    }
    mPendingDebugSigns.clear();
}

void CommandBuffer::invalidateActiveCommandEncoder(CommandEncoder *encoder)
{
    mActiveCommandEncoder.compare_exchange_strong(encoder, nullptr);
}

void CommandBuffer::cleanup()
{
    mActiveCommandEncoder = nullptr;

    ParentClass::set(nil);
}

bool CommandBuffer::validImpl() const
{
    if (!ParentClass::valid())
    {
        return false;
    }

    return !mCommitted;
}

void CommandBuffer::commitImpl()
{
    if (!validImpl())
    {
        return;
    }

    // End the current encoder
    if (mActiveCommandEncoder.load(std::memory_order_relaxed))
    {
        mActiveCommandEncoder.load(std::memory_order_relaxed)->endEncoding();
        mActiveCommandEncoder = nullptr;
    }

    // Do the actual commit
    [get() commit];

    ANGLE_MTL_LOG("Committed MTLCommandBuffer %llu:%p", mQueueSerial, get());

    mCommitted = true;
}

// CommandEncoder implementation
CommandEncoder::CommandEncoder(CommandBuffer *cmdBuffer, Type type)
    : mType(type), mCmdBuffer(*cmdBuffer)
{}

CommandEncoder::~CommandEncoder()
{
    reset();
}

void CommandEncoder::endEncoding()
{
    [get() endEncoding];
    reset();
}

void CommandEncoder::reset()
{
    ParentClass::reset();

    mCmdBuffer.invalidateActiveCommandEncoder(this);
}

void CommandEncoder::set(id<MTLCommandEncoder> metalCmdEncoder)
{
    ParentClass::set(metalCmdEncoder);

    // Set this as active encoder
    cmdBuffer().setActiveCommandEncoder(this);
}

CommandEncoder &CommandEncoder::markResourceBeingWrittenByGPU(const BufferRef &buffer)
{
    cmdBuffer().setWriteDependency(buffer);
    return *this;
}

CommandEncoder &CommandEncoder::markResourceBeingWrittenByGPU(const TextureRef &texture)
{
    cmdBuffer().setWriteDependency(texture);
    return *this;
}

void CommandEncoder::insertDebugSign(const std::string &marker)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        auto label = [NSString stringWithUTF8String:marker.c_str()];
        insertDebugSignImpl(label);
    }
}

void CommandEncoder::insertDebugSignImpl(NSString *label)
{
    // Default implementation
    [get() insertDebugSignpost:label];
}

// RenderCommandEncoder implemtation
RenderCommandEncoder::RenderCommandEncoder(CommandBuffer *cmdBuffer)
    : CommandEncoder(cmdBuffer, RENDER)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        mCachedRenderPassDescObjC = [MTLRenderPassDescriptor renderPassDescriptor];
    }
}
RenderCommandEncoder::~RenderCommandEncoder() {}

void RenderCommandEncoder::reset()
{
    CommandEncoder::reset();
    mRecording = false;
    mCommands.clear();
}

void RenderCommandEncoder::endEncoding()
{
    endEncodingImpl(true);
}

void RenderCommandEncoder::endEncodingImpl(bool considerDiscardSimulation)
{
    if (!valid())
        return;

    // Last minute correcting the store options.
    MTLRenderPassDescriptor *rpDesc = mCachedRenderPassDescObjC.get();
    for (uint32_t i = 0; i < mRenderPassDesc.numColorAttachments; ++i)
    {
        if (rpDesc.colorAttachments[i].storeAction == MTLStoreActionUnknown)
        {
            // If storeAction hasn't been set for this attachment, we set to dontcare.
            rpDesc.colorAttachments[i].storeAction = MTLStoreActionDontCare;
        }
    }

    if (rpDesc.depthAttachment.storeAction == MTLStoreActionUnknown)
    {
        // If storeAction hasn't been set for this attachment, we set to dontcare.
        rpDesc.depthAttachment.storeAction = MTLStoreActionDontCare;
    }

    if (rpDesc.stencilAttachment.storeAction == MTLStoreActionUnknown)
    {
        // If storeAction hasn't been set for this attachment, we set to dontcare.
        rpDesc.stencilAttachment.storeAction = MTLStoreActionDontCare;
    }

    // Encode the actual encoder
    encodeMetalEncoder();

    CommandEncoder::endEncoding();

#if ANGLE_MTL_SIMULATE_DISCARD_FRAMEBUFFER
    if (considerDiscardSimulation)
    {
        simulateDiscardFramebuffer();
    }
#endif

    // reset state
    mRenderPassDesc = RenderPassDesc();
}

inline void RenderCommandEncoder::initWriteDependencyAndStoreAction(const TextureRef &texture,
                                                                    MTLStoreAction *storeActionOut)
{
    if (texture)
    {
        cmdBuffer().setWriteDependency(texture);
    }
    else
    {
        // Texture is invalid, use don'tcare store action
        *storeActionOut = MTLStoreActionDontCare;
    }
}

void RenderCommandEncoder::simulateDiscardFramebuffer()
{
    // Simulate true framebuffer discard operation by clearing the framebuffer
#if ANGLE_MTL_SIMULATE_DISCARD_FRAMEBUFFER
    std::random_device rd;   // Will be used to obtain a seed for the random number engine
    std::mt19937 gen(rd());  // Standard mersenne_twister_engine seeded with rd()
    std::uniform_real_distribution<float> dis(0.0, 1.0f);
    bool hasDiscard = false;
    for (uint32_t i = 0; i < mRenderPassDesc.numColorAttachments; ++i)
    {
        if (mRenderPassDesc.colorAttachments[i].storeAction == MTLStoreActionDontCare)
        {
            hasDiscard                                     = true;
            mRenderPassDesc.colorAttachments[i].loadAction = MTLLoadActionClear;
            mRenderPassDesc.colorAttachments[i].clearColor =
                MTLClearColorMake(dis(gen), dis(gen), dis(gen), dis(gen));
        }
        else
        {
            mRenderPassDesc.colorAttachments[i].loadAction = MTLLoadActionLoad;
        }
    }

    if (mRenderPassDesc.depthAttachment.storeAction == MTLStoreActionDontCare)
    {
        hasDiscard                                 = true;
        mRenderPassDesc.depthAttachment.loadAction = MTLLoadActionClear;
        mRenderPassDesc.depthAttachment.clearDepth = dis(gen);
    }
    else
    {
        mRenderPassDesc.depthAttachment.loadAction = MTLLoadActionLoad;
    }

    if (mRenderPassDesc.stencilAttachment.storeAction == MTLStoreActionDontCare)
    {
        hasDiscard                                     = true;
        mRenderPassDesc.stencilAttachment.loadAction   = MTLLoadActionClear;
        mRenderPassDesc.stencilAttachment.clearStencil = rand();
    }
    else
    {
        mRenderPassDesc.stencilAttachment.loadAction = MTLLoadActionLoad;
    }

    if (hasDiscard)
    {
        auto tmpDesc = mRenderPassDesc;
        restart(tmpDesc);
        endEncodingImpl(false);
    }
#endif  // ANGLE_MTL_SIMULATE_DISCARD_FRAMEBUFFER
}

void RenderCommandEncoder::encodeMetalEncoder()
{
    ANGLE_MTL_OBJC_SCOPE
    {
        ANGLE_MTL_LOG("Creating new render command encoder with desc: %@",
                      mCachedRenderPassDescObjC);

        id<MTLRenderCommandEncoder> metalCmdEncoder =
            [cmdBuffer().get() renderCommandEncoderWithDescriptor:mCachedRenderPassDescObjC];

        set(metalCmdEncoder);

        // Verify that it was created successfully
        ASSERT(get());

        while (mCommands.good())
        {
            auto cmdType               = mCommands.fetch<CmdType>();
            CommandEncoderFunc encoder = gCommandEncoders[static_cast<int>(cmdType)];
            encoder(metalCmdEncoder, &mCommands);
        }

        mCommands.clear();
    }
}

RenderCommandEncoder &RenderCommandEncoder::restart(const RenderPassDesc &desc)
{
    if (valid())
    {
        if (mRenderPassDesc == desc)
        {
            // no change, skip
            return *this;
        }

        // finish current encoder
        endEncoding();
    }

    if (!cmdBuffer().valid())
    {
        reset();
        return *this;
    }

    mRenderPassDesc = desc;
    mRecording      = true;

    // mask writing dependency & set appropriate store options
    for (uint32_t i = 0; i < mRenderPassDesc.numColorAttachments; ++i)
    {
        initWriteDependencyAndStoreAction(mRenderPassDesc.colorAttachments[i].texture(),
                                          &mRenderPassDesc.colorAttachments[i].storeAction);
    }

    initWriteDependencyAndStoreAction(mRenderPassDesc.depthAttachment.texture(),
                                      &mRenderPassDesc.depthAttachment.storeAction);

    initWriteDependencyAndStoreAction(mRenderPassDesc.stencilAttachment.texture(),
                                      &mRenderPassDesc.stencilAttachment.storeAction);

    // Convert to Objective-C descriptor
    mRenderPassDesc.convertToMetalDesc(mCachedRenderPassDescObjC);

    // The actual Objective-C encoder will be created later in endEncoding(), we do so in order
    // to be able to sort the commands or do the preprocessing before the actual encoding.

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setRenderPipelineState(id<MTLRenderPipelineState> state)
{
    mCommands.push(CmdType::SetRenderPipelineState).push([state ANGLE_MTL_RETAIN]);

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setTriangleFillMode(MTLTriangleFillMode mode)
{
    mCommands.push(CmdType::SetTriangleFillMode).push(mode);

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setFrontFacingWinding(MTLWinding winding)
{
    mCommands.push(CmdType::SetFrontFacingWinding).push(winding);

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setCullMode(MTLCullMode mode)
{
    mCommands.push(CmdType::SetCullMode).push(mode);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setDepthStencilState(id<MTLDepthStencilState> state)
{
    mCommands.push(CmdType::SetDepthStencilState).push([state ANGLE_MTL_RETAIN]);

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setDepthBias(float depthBias,
                                                         float slopeScale,
                                                         float clamp)
{
    mCommands.push(CmdType::SetDepthBias).push(depthBias).push(slopeScale).push(clamp);

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setStencilRefVals(uint32_t frontRef, uint32_t backRef)
{
    // Metal has some bugs when reference values are larger than 0xff
    ASSERT(frontRef == (frontRef & kStencilMaskAll));
    ASSERT(backRef == (backRef & kStencilMaskAll));

    mCommands.push(CmdType::SetStencilRefVals).push(frontRef).push(backRef);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setStencilRefVal(uint32_t ref)
{
    return setStencilRefVals(ref, ref);
}

RenderCommandEncoder &RenderCommandEncoder::setViewport(const MTLViewport &viewport)
{
    mCommands.push(CmdType::SetViewport).push(viewport);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setScissorRect(const MTLScissorRect &rect)
{
    mCommands.push(CmdType::SetScissorRect).push(rect);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setBlendColor(float r, float g, float b, float a)
{
    mCommands.push(CmdType::SetBlendColor).push(r).push(g).push(b).push(a);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setVertexBuffer(const BufferRef &buffer,
                                                            uint32_t offset,
                                                            uint32_t index)
{
    if (index >= kMaxShaderBuffers)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(buffer);

    id<MTLBuffer> mtlBuffer = (buffer ? buffer->get() : nil);
    mCommands.push(CmdType::SetVertexBuffer)
        .push([mtlBuffer ANGLE_MTL_RETAIN])
        .push(offset)
        .push(index);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setVertexBytes(const uint8_t *bytes,
                                                           size_t size,
                                                           uint32_t index)
{
    if (index >= kMaxShaderBuffers)
    {
        return *this;
    }

    mCommands.push(CmdType::SetVertexBytes).push(size).push(bytes, size).push(index);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setVertexSamplerState(id<MTLSamplerState> state,
                                                                  float lodMinClamp,
                                                                  float lodMaxClamp,
                                                                  uint32_t index)
{
    if (index >= kMaxShaderSamplers)
    {
        return *this;
    }

    mCommands.push(CmdType::SetVertexSamplerState)
        .push([state ANGLE_MTL_RETAIN])
        .push(lodMinClamp)
        .push(lodMaxClamp)
        .push(index);

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setVertexTexture(const TextureRef &texture,
                                                             uint32_t index)
{
    if (index >= kMaxShaderSamplers)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(texture);

    id<MTLTexture> mtlTexture = (texture ? texture->get() : nil);

    mCommands.push(CmdType::SetVertexTexture).push([mtlTexture ANGLE_MTL_RETAIN]).push(index);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setFragmentBuffer(const BufferRef &buffer,
                                                              uint32_t offset,
                                                              uint32_t index)
{
    if (index >= kMaxShaderBuffers)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(buffer);

    id<MTLBuffer> mtlBuffer = (buffer ? buffer->get() : nil);
    mCommands.push(CmdType::SetFragmentBuffer)
        .push([mtlBuffer ANGLE_MTL_RETAIN])
        .push(offset)
        .push(index);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setFragmentBytes(const uint8_t *bytes,
                                                             size_t size,
                                                             uint32_t index)
{
    if (index >= kMaxShaderBuffers)
    {
        return *this;
    }

    mCommands.push(CmdType::SetFragmentBytes).push(size).push(bytes, size).push(index);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setFragmentSamplerState(id<MTLSamplerState> state,
                                                                    float lodMinClamp,
                                                                    float lodMaxClamp,
                                                                    uint32_t index)
{
    if (index >= kMaxShaderSamplers)
    {
        return *this;
    }

    mCommands.push(CmdType::SetFragmentSamplerState)
        .push([state ANGLE_MTL_RETAIN])
        .push(lodMinClamp)
        .push(lodMaxClamp)
        .push(index);

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setFragmentTexture(const TextureRef &texture,
                                                               uint32_t index)
{
    if (index >= kMaxShaderSamplers)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(texture);

    id<MTLTexture> mtlTexture = (texture ? texture->get() : nil);

    mCommands.push(CmdType::SetFragmentTexture).push([mtlTexture ANGLE_MTL_RETAIN]).push(index);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::draw(MTLPrimitiveType primitiveType,
                                                 uint32_t vertexStart,
                                                 uint32_t vertexCount)
{
    mCommands.push(CmdType::Draw).push(primitiveType).push(vertexStart).push(vertexCount);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::drawInstanced(MTLPrimitiveType primitiveType,
                                                          uint32_t vertexStart,
                                                          uint32_t vertexCount,
                                                          uint32_t instances)
{
    mCommands.push(CmdType::DrawInstanced)
        .push(primitiveType)
        .push(vertexStart)
        .push(vertexCount)
        .push(instances);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::drawIndexed(MTLPrimitiveType primitiveType,
                                                        uint32_t indexCount,
                                                        MTLIndexType indexType,
                                                        const BufferRef &indexBuffer,
                                                        size_t bufferOffset)
{
    if (!indexBuffer)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(indexBuffer);

    mCommands.push(CmdType::DrawIndexed)
        .push(primitiveType)
        .push(indexCount)
        .push(indexType)
        .push([indexBuffer->get() ANGLE_MTL_RETAIN])
        .push(bufferOffset);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::drawIndexedInstanced(MTLPrimitiveType primitiveType,
                                                                 uint32_t indexCount,
                                                                 MTLIndexType indexType,
                                                                 const BufferRef &indexBuffer,
                                                                 size_t bufferOffset,
                                                                 uint32_t instances)
{
    if (!indexBuffer)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(indexBuffer);

    mCommands.push(CmdType::DrawIndexedInstanced)
        .push(primitiveType)
        .push(indexCount)
        .push(indexType)
        .push([indexBuffer->get() ANGLE_MTL_RETAIN])
        .push(bufferOffset)
        .push(instances);

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::drawIndexedInstancedBaseVertex(
    MTLPrimitiveType primitiveType,
    uint32_t indexCount,
    MTLIndexType indexType,
    const BufferRef &indexBuffer,
    size_t bufferOffset,
    uint32_t instances,
    uint32_t baseVertex)
{
    if (!indexBuffer)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(indexBuffer);

    mCommands.push(CmdType::DrawIndexedInstancedBaseVertex)
        .push(primitiveType)
        .push(indexCount)
        .push(indexType)
        .push([indexBuffer->get() ANGLE_MTL_RETAIN])
        .push(bufferOffset)
        .push(instances)
        .push(baseVertex);

    return *this;
}

void RenderCommandEncoder::insertDebugSignImpl(NSString *label)
{
    // Defer the insertion until endEncoding()
    mCommands.push(CmdType::InsertDebugsign).push([label ANGLE_MTL_RETAIN]);
}

RenderCommandEncoder &RenderCommandEncoder::setColorStoreAction(MTLStoreAction action,
                                                                uint32_t colorAttachmentIndex)
{
    if (colorAttachmentIndex >= mRenderPassDesc.numColorAttachments)
    {
        return *this;
    }

    // We only store the options, will defer the actual setting until the encoder finishes
    mRenderPassDesc.colorAttachments[colorAttachmentIndex].storeAction = action;

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setColorStoreAction(MTLStoreAction action)
{
    for (uint32_t i = 0; i < mRenderPassDesc.numColorAttachments; ++i)
    {
        setColorStoreAction(action, i);
    }
    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setDepthStencilStoreAction(
    MTLStoreAction depthStoreAction,
    MTLStoreAction stencilStoreAction)
{
    // We only store the options, will defer the actual setting until the encoder finishes
    mRenderPassDesc.depthAttachment.storeAction   = depthStoreAction;
    mRenderPassDesc.stencilAttachment.storeAction = stencilStoreAction;

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setDepthStoreAction(MTLStoreAction action)
{
    // We only store the options, will defer the actual setting until the encoder finishes
    mRenderPassDesc.depthAttachment.storeAction = action;

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setStencilStoreAction(MTLStoreAction action)
{
    // We only store the options, will defer the actual setting until the encoder finishes
    mRenderPassDesc.stencilAttachment.storeAction = action;

    return *this;
}

// BlitCommandEncoder
BlitCommandEncoder::BlitCommandEncoder(CommandBuffer *cmdBuffer) : CommandEncoder(cmdBuffer, BLIT)
{}

BlitCommandEncoder::~BlitCommandEncoder() {}

BlitCommandEncoder &BlitCommandEncoder::restart()
{
    ANGLE_MTL_OBJC_SCOPE
    {
        if (valid())
        {
            // no change, skip
            return *this;
        }

        if (!cmdBuffer().valid())
        {
            reset();
            return *this;
        }

        // Create objective C object
        set([cmdBuffer().get() blitCommandEncoder]);

        // Verify that it was created successfully
        ASSERT(get());

        return *this;
    }
}

BlitCommandEncoder &BlitCommandEncoder::copyBufferToTexture(const BufferRef &src,
                                                            size_t srcOffset,
                                                            size_t srcBytesPerRow,
                                                            size_t srcBytesPerImage,
                                                            MTLSize srcSize,
                                                            const TextureRef &dst,
                                                            uint32_t dstSlice,
                                                            uint32_t dstLevel,
                                                            MTLOrigin dstOrigin,
                                                            MTLBlitOption blitOption)
{
    if (!src || !dst)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(src);
    cmdBuffer().setWriteDependency(dst);

    [get() copyFromBuffer:src->get()
               sourceOffset:srcOffset
          sourceBytesPerRow:srcBytesPerRow
        sourceBytesPerImage:srcBytesPerImage
                 sourceSize:srcSize
                  toTexture:dst->get()
           destinationSlice:dstSlice
           destinationLevel:dstLevel
          destinationOrigin:dstOrigin
                    options:blitOption];

    return *this;
}

BlitCommandEncoder &BlitCommandEncoder::copyTextureToBuffer(const TextureRef &src,
                                                            uint32_t srcSlice,
                                                            uint32_t srcLevel,
                                                            MTLOrigin srcOrigin,
                                                            MTLSize srcSize,
                                                            const BufferRef &dst,
                                                            size_t dstOffset,
                                                            size_t dstBytesPerRow,
                                                            size_t dstBytesPerImage,
                                                            MTLBlitOption blitOption)
{

    if (!src || !dst)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(src);
    cmdBuffer().setWriteDependency(dst);

    [get() copyFromTexture:src->get()
                     sourceSlice:srcSlice
                     sourceLevel:srcLevel
                    sourceOrigin:srcOrigin
                      sourceSize:srcSize
                        toBuffer:dst->get()
               destinationOffset:dstOffset
          destinationBytesPerRow:dstBytesPerRow
        destinationBytesPerImage:dstBytesPerImage
                         options:blitOption];

    return *this;
}

BlitCommandEncoder &BlitCommandEncoder::copyTexture(const TextureRef &src,
                                                    uint32_t srcSlice,
                                                    uint32_t srcLevel,
                                                    MTLOrigin srcOrigin,
                                                    MTLSize srcSize,
                                                    const TextureRef &dst,
                                                    uint32_t dstSlice,
                                                    uint32_t dstLevel,
                                                    MTLOrigin dstOrigin)
{
    if (!src || !dst)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(src);
    cmdBuffer().setWriteDependency(dst);
    [get() copyFromTexture:src->get()
               sourceSlice:srcSlice
               sourceLevel:srcLevel
              sourceOrigin:srcOrigin
                sourceSize:srcSize
                 toTexture:dst->get()
          destinationSlice:dstSlice
          destinationLevel:dstLevel
         destinationOrigin:dstOrigin];

    return *this;
}

BlitCommandEncoder &BlitCommandEncoder::generateMipmapsForTexture(const TextureRef &texture)
{
    if (!texture)
    {
        return *this;
    }

    cmdBuffer().setWriteDependency(texture);
    [get() generateMipmapsForTexture:texture->get()];

    return *this;
}
BlitCommandEncoder &BlitCommandEncoder::synchronizeResource(const BufferRef &buffer)
{
    if (!buffer)
    {
        return *this;
    }

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    // Only MacOS has separated storage for resource on CPU and GPU and needs explicit
    // synchronization
    cmdBuffer().setReadDependency(buffer);
    [get() synchronizeResource:buffer->get()];
#endif
    return *this;
}
BlitCommandEncoder &BlitCommandEncoder::synchronizeResource(const TextureRef &texture)
{
    if (!texture)
    {
        return *this;
    }

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    // Only MacOS has separated storage for resource on CPU and GPU and needs explicit
    // synchronization
    cmdBuffer().setReadDependency(texture);
    if (texture->get().parentTexture)
    {
        [get() synchronizeResource:texture->get().parentTexture];
    }
    else
    {
        [get() synchronizeResource:texture->get()];
    }
#endif
    return *this;
}

// ComputeCommandEncoder implementation
ComputeCommandEncoder::ComputeCommandEncoder(CommandBuffer *cmdBuffer)
    : CommandEncoder(cmdBuffer, COMPUTE)
{}
ComputeCommandEncoder::~ComputeCommandEncoder() {}

ComputeCommandEncoder &ComputeCommandEncoder::restart()
{
    ANGLE_MTL_OBJC_SCOPE
    {
        if (valid())
        {
            // no change, skip
            return *this;
        }

        if (!cmdBuffer().valid())
        {
            reset();
            return *this;
        }

        // Create objective C object
        set([cmdBuffer().get() computeCommandEncoder]);

        // Verify that it was created successfully
        ASSERT(get());

        return *this;
    }
}

ComputeCommandEncoder &ComputeCommandEncoder::setComputePipelineState(
    id<MTLComputePipelineState> state)
{
    [get() setComputePipelineState:state];
    return *this;
}

ComputeCommandEncoder &ComputeCommandEncoder::setBuffer(const BufferRef &buffer,
                                                        uint32_t offset,
                                                        uint32_t index)
{
    if (index >= kMaxShaderBuffers)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(buffer);

    [get() setBuffer:(buffer ? buffer->get() : nil) offset:offset atIndex:index];

    return *this;
}

ComputeCommandEncoder &ComputeCommandEncoder::setBufferForWrite(const BufferRef &buffer,
                                                                uint32_t offset,
                                                                uint32_t index)
{
    if (index >= kMaxShaderBuffers)
    {
        return *this;
    }

    cmdBuffer().setWriteDependency(buffer);
    return setBuffer(buffer, offset, index);
}

ComputeCommandEncoder &ComputeCommandEncoder::setBytes(const uint8_t *bytes,
                                                       size_t size,
                                                       uint32_t index)
{
    if (index >= kMaxShaderBuffers)
    {
        return *this;
    }

    [get() setBytes:bytes length:size atIndex:index];

    return *this;
}

ComputeCommandEncoder &ComputeCommandEncoder::setSamplerState(id<MTLSamplerState> state,
                                                              float lodMinClamp,
                                                              float lodMaxClamp,
                                                              uint32_t index)
{
    if (index >= kMaxShaderSamplers)
    {
        return *this;
    }

    [get() setSamplerState:state lodMinClamp:lodMinClamp lodMaxClamp:lodMaxClamp atIndex:index];

    return *this;
}
ComputeCommandEncoder &ComputeCommandEncoder::setTexture(const TextureRef &texture, uint32_t index)
{
    if (index >= kMaxShaderSamplers)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(texture);
    [get() setTexture:(texture ? texture->get() : nil) atIndex:index];

    return *this;
}
ComputeCommandEncoder &ComputeCommandEncoder::setTextureForWrite(const TextureRef &texture,
                                                                 uint32_t index)
{
    if (index >= kMaxShaderSamplers)
    {
        return *this;
    }

    cmdBuffer().setWriteDependency(texture);
    return setTexture(texture, index);
}

ComputeCommandEncoder &ComputeCommandEncoder::dispatch(MTLSize threadGroupsPerGrid,
                                                       MTLSize threadsPerGroup)
{
    [get() dispatchThreadgroups:threadGroupsPerGrid threadsPerThreadgroup:threadsPerGroup];
    return *this;
}

ComputeCommandEncoder &ComputeCommandEncoder::dispatchNonUniform(MTLSize threadsPerGrid,
                                                                 MTLSize threadsPerGroup)
{
    [get() dispatchThreads:threadsPerGrid threadsPerThreadgroup:threadsPerGroup];
    return *this;
}

}
}
