//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "libANGLE/renderer/metal/mtl_command_buffer.h"

#include <cassert>

#include "common/debug.h"
#include "libANGLE/renderer/metal/mtl_resources.h"

#if 0 && !defined(NDEBUG)
#    define ANGLE_MTL_CMD_LOG(...) NSLog(@__VA_ARGS__)
#else
#    define ANGLE_MTL_CMD_LOG(...) (void)0
#endif

namespace rx
{
namespace mtl
{

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

        for (auto metalBufferEntry : mQueuedMetalCmdBuffers)
        {
            mQueuedMetalCmdBuffersTmp.push_back(metalBufferEntry);
        }

        mQueuedMetalCmdBuffers.clear();
    }

    // Wait for command buffers to finish
    for (auto metalBufferEntry : mQueuedMetalCmdBuffersTmp)
    {
        [metalBufferEntry.buffer waitUntilCompleted];
    }
    mQueuedMetalCmdBuffersTmp.clear();
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
    while (isResourceBeingUsedByGPU(resource) && mQueuedMetalCmdBuffers.size())
    {
        CmdBufferQueueEntry metalBufferEntry = mQueuedMetalCmdBuffers.front();
        mQueuedMetalCmdBuffers.pop_front();
        mLock.unlock();

        ANGLE_MTL_CMD_LOG("Waiting for MTLCommandBuffer %llu:%p", metalBufferEntry.serial,
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

        mQueuedMetalCmdBuffers.push_back({metalCmdBuffer, serial});

        ANGLE_MTL_CMD_LOG("Created MTLCommandBuffer %llu:%p", serial, metalCmdBuffer.get());

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

    ANGLE_MTL_CMD_LOG("Completed MTLCommandBuffer %llu:%p", serial, buf);

    if (mCompletedBufferSerial >= serial)
    {
        // Already handled.
        return;
    }

    while (mQueuedMetalCmdBuffers.size() && mQueuedMetalCmdBuffers.front().serial <= serial)
    {
        auto metalBufferEntry = mQueuedMetalCmdBuffers.front();
        (void)metalBufferEntry;
        ANGLE_MTL_CMD_LOG("Popped MTLCommandBuffer %llu:%p", metalBufferEntry.serial,
                          metalBufferEntry.buffer.get());

        mQueuedMetalCmdBuffers.pop_front();
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

/** private use only */
void CommandBuffer::set(id<MTLCommandBuffer> metalBuffer)
{
    ParentClass::set(metalBuffer);
}

void CommandBuffer::setActiveCommandEncoder(CommandEncoder *encoder)
{
    mActiveCommandEncoder = encoder;
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

    ANGLE_MTL_CMD_LOG("Committed MTLCommandBuffer %llu:%p", mQueueSerial, get());

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

CommandEncoder &CommandEncoder::markResourceBeingWrittenByGPU(BufferRef buffer)
{
    cmdBuffer().setWriteDependency(buffer);
    return *this;
}

CommandEncoder &CommandEncoder::markResourceBeingWrittenByGPU(TextureRef texture)
{
    cmdBuffer().setWriteDependency(texture);
    return *this;
}

// RenderCommandEncoder implemtation
RenderCommandEncoder::RenderCommandEncoder(CommandBuffer *cmdBuffer)
    : CommandEncoder(cmdBuffer, RENDER)
{}
RenderCommandEncoder::~RenderCommandEncoder() {}

void RenderCommandEncoder::endEncoding()
{
    if (!valid())
        return;

    // Now is the time to do the actual store option setting.
    auto metalEncoder = get();
    for (uint32_t i = 0; i < mRenderPassDesc.numColorAttachments; ++i)
    {
        if (mRenderPassDesc.colorAttachments[i].storeAction == MTLStoreActionUnknown)
        {
            // If storeAction hasn't been set for this attachment, we set to dontcare.
            mRenderPassDesc.colorAttachments[i].storeAction = MTLStoreActionDontCare;
        }

        // Only initial unknown store action can change the value now.
        if (mColorInitialStoreActions[i] == MTLStoreActionUnknown)
        {
            [metalEncoder setColorStoreAction:mRenderPassDesc.colorAttachments[i].storeAction
                                      atIndex:i];
        }
    }

    if (mRenderPassDesc.depthAttachment.storeAction == MTLStoreActionUnknown)
    {
        // If storeAction hasn't been set for this attachment, we set to dontcare.
        mRenderPassDesc.depthAttachment.storeAction = MTLStoreActionDontCare;
    }
    if (mDepthInitialStoreAction == MTLStoreActionUnknown)
    {
        [metalEncoder setDepthStoreAction:mRenderPassDesc.depthAttachment.storeAction];
    }

    if (mRenderPassDesc.stencilAttachment.storeAction == MTLStoreActionUnknown)
    {
        // If storeAction hasn't been set for this attachment, we set to dontcare.
        mRenderPassDesc.stencilAttachment.storeAction = MTLStoreActionDontCare;
    }
    if (mStencilInitialStoreAction == MTLStoreActionUnknown)
    {
        [metalEncoder setStencilStoreAction:mRenderPassDesc.stencilAttachment.storeAction];
    }

    CommandEncoder::endEncoding();

    // reset state
    mStateCache     = StateCache();
    mRenderPassDesc = RenderPassDesc();
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

    ANGLE_MTL_OBJC_SCOPE
    {

#define ANGLE_MTL_SET_DEP_AND_STORE_ACTION(TEXTURE_EXPR, STOREACTION)        \
    do                                                                       \
    {                                                                        \
        auto TEXTURE = TEXTURE_EXPR;                                         \
        if (TEXTURE)                                                         \
        {                                                                    \
            cmdBuffer().setWriteDependency(TEXTURE);                         \
            /* Set store action to unknown so that we can change it later */ \
            STOREACTION = MTLStoreActionUnknown;                             \
        }                                                                    \
        else                                                                 \
        {                                                                    \
            STOREACTION = MTLStoreActionDontCare;                            \
        }                                                                    \
    } while (0)

        // mask writing dependency
        for (uint32_t i = 0; i < mRenderPassDesc.numColorAttachments; ++i)
        {
            ANGLE_MTL_SET_DEP_AND_STORE_ACTION(mRenderPassDesc.colorAttachments[i].texture,
                                               mRenderPassDesc.colorAttachments[i].storeAction);
            mColorInitialStoreActions[i] = mRenderPassDesc.colorAttachments[i].storeAction;
        }

        ANGLE_MTL_SET_DEP_AND_STORE_ACTION(mRenderPassDesc.depthAttachment.texture,
                                           mRenderPassDesc.depthAttachment.storeAction);
        mDepthInitialStoreAction = mRenderPassDesc.depthAttachment.storeAction;

        ANGLE_MTL_SET_DEP_AND_STORE_ACTION(mRenderPassDesc.stencilAttachment.texture,
                                           mRenderPassDesc.stencilAttachment.storeAction);
        mStencilInitialStoreAction = mRenderPassDesc.stencilAttachment.storeAction;

        // Create objective C object
        mtl::AutoObjCObj<MTLRenderPassDescriptor> objCDesc = ToMetalObj(mRenderPassDesc);

        ANGLE_MTL_CMD_LOG("Creating new render command encoder with desc: %@", objCDesc.get());

        id<MTLRenderCommandEncoder> metalCmdEncoder =
            [cmdBuffer().get() renderCommandEncoderWithDescriptor:objCDesc];

        set(metalCmdEncoder);

        // Set the actual store action
        for (uint32_t i = 0; i < desc.numColorAttachments; ++i)
        {
            setColorStoreAction(desc.colorAttachments[i].storeAction, i);
        }

        setDepthStencilStoreAction(desc.depthAttachment.storeAction,
                                   desc.stencilAttachment.storeAction);

        // Verify that it was created successfully
        ASSERT(get());
    }  // ANGLE_MTL_OBJC_SCOPE

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::restart(const RenderPassDesc &desc,
                                                    const StateCache &retainedState)
{
    restart(desc);

    // sync the state
    setRenderPipelineState(retainedState.renderPipelineState);
    setTriangleFillMode(retainedState.triangleFillMode);
    setFrontFacingWinding(retainedState.frontFace);
    setCullMode(retainedState.cullMode);
    setDepthStencilState(retainedState.depthStencilState);
    setDepthBias(retainedState.depthBias, retainedState.slopeScale, retainedState.clamp);
    setStencilRefVals(retainedState.frontStencilRef, retainedState.backStencilRef);
    setBlendColor(retainedState.blendR, retainedState.blendG, retainedState.blendB,
                  retainedState.blendA);

    for (uint32_t i = 0; i < kMaxShaderBuffers; ++i)
    {
        if (retainedState.vertexBuffers[i].buffer)
        {
            setVertexBuffer(retainedState.vertexBuffers[i].buffer,
                            retainedState.vertexBuffers[i].offset, i);
        }

        if (retainedState.fragmentBuffers[i].buffer)
        {
            setFragmentBuffer(retainedState.fragmentBuffers[i].buffer,
                              retainedState.fragmentBuffers[i].offset, i);
        }
    }

    for (uint32_t i = 0; i < kMaxShaderSamplers; ++i)
    {
        if (retainedState.vertexTextures[i])
        {
            setVertexTexture(retainedState.vertexTextures[i], i);
        }
        if (retainedState.vertexSamplers[i].stateObject)
        {
            setVertexSamplerState(retainedState.vertexSamplers[i].stateObject,
                                  retainedState.vertexSamplers[i].lodMinClamp,
                                  retainedState.vertexSamplers[i].lodMaxClamp, i);
        }

        if (retainedState.fragmentTextures[i])
        {
            setFragmentTexture(retainedState.fragmentTextures[i], i);
        }
        if (retainedState.fragmentSamplers[i].stateObject)
        {
            setFragmentSamplerState(retainedState.fragmentSamplers[i].stateObject,
                                    retainedState.fragmentSamplers[i].lodMinClamp,
                                    retainedState.fragmentSamplers[i].lodMaxClamp, i);
        }
    }

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setRenderPipelineState(id<MTLRenderPipelineState> state)
{
    [get() setRenderPipelineState:state];

    mStateCache.renderPipelineState = state;

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setTriangleFillMode(MTLTriangleFillMode mode)
{
    [get() setTriangleFillMode:mode];

    mStateCache.triangleFillMode = mode;

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setFrontFacingWinding(MTLWinding winding)
{
    [get() setFrontFacingWinding:winding];

    mStateCache.frontFace = winding;

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setCullMode(MTLCullMode mode)
{
    [get() setCullMode:mode];

    mStateCache.cullMode = mode;

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setDepthStencilState(id<MTLDepthStencilState> state)
{
    [get() setDepthStencilState:state];

    mStateCache.depthStencilState = state;

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setDepthBias(float depthBias,
                                                         float slopeScale,
                                                         float clamp)
{
    [get() setDepthBias:depthBias slopeScale:slopeScale clamp:clamp];

    mStateCache.depthBias  = depthBias;
    mStateCache.slopeScale = slopeScale;
    mStateCache.clamp      = clamp;

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setStencilRefVals(uint32_t frontRef, uint32_t backRef)
{
    [get() setStencilFrontReferenceValue:frontRef backReferenceValue:backRef];

    mStateCache.frontStencilRef = frontRef;
    mStateCache.backStencilRef  = backRef;

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setStencilRefVal(uint32_t ref)
{
    return setStencilRefVals(ref, ref);
}

RenderCommandEncoder &RenderCommandEncoder::setViewport(const MTLViewport &viewport)
{
    [get() setViewport:viewport];

    mStateCache.viewports[0] = viewport;
    mStateCache.numViewports = 1;

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setScissorRect(const MTLScissorRect &rect)
{
    [get() setScissorRect:rect];

    mStateCache.scissorRects[0] = rect;
    mStateCache.numScissorRects = 1;

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setBlendColor(float r, float g, float b, float a)
{
    [get() setBlendColorRed:r green:g blue:b alpha:a];

    mStateCache.blendR = r;
    mStateCache.blendG = g;
    mStateCache.blendB = b;
    mStateCache.blendA = a;

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setVertexBuffer(BufferRef buffer,
                                                            uint32_t offset,
                                                            uint32_t index)
{
    if (index >= kMaxShaderBuffers)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(buffer);

    [get() setVertexBuffer:(buffer ? buffer->get() : nil) offset:offset atIndex:index];

    mStateCache.vertexBuffers[index].offset = offset;
    mStateCache.vertexBuffers[index].buffer = buffer;

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

    [get() setVertexBytes:bytes length:size atIndex:index];

    mStateCache.vertexBuffers[index].offset = 0;
    mStateCache.vertexBuffers[index].buffer = nullptr;

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

    [get() setVertexSamplerState:state
                     lodMinClamp:lodMinClamp
                     lodMaxClamp:lodMaxClamp
                         atIndex:index];

    mStateCache.vertexSamplers[index].lodMinClamp = lodMinClamp;
    mStateCache.vertexSamplers[index].lodMaxClamp = lodMaxClamp;
    mStateCache.vertexSamplers[index].stateObject = state;

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setVertexTexture(TextureRef texture, uint32_t index)
{
    if (index >= kMaxShaderSamplers)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(texture);
    [get() setVertexTexture:(texture ? texture->get() : nil) atIndex:index];

    mStateCache.vertexTextures[index] = texture;

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::setFragmentBuffer(BufferRef buffer,
                                                              uint32_t offset,
                                                              uint32_t index)
{
    if (index >= kMaxShaderBuffers)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(buffer);

    [get() setFragmentBuffer:(buffer ? buffer->get() : nil) offset:offset atIndex:index];

    mStateCache.fragmentBuffers[index].offset = offset;
    mStateCache.fragmentBuffers[index].buffer = buffer;

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

    [get() setFragmentBytes:bytes length:size atIndex:index];

    mStateCache.fragmentBuffers[index].offset = 0;
    mStateCache.fragmentBuffers[index].buffer = nullptr;

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

    [get() setFragmentSamplerState:state
                       lodMinClamp:lodMinClamp
                       lodMaxClamp:lodMaxClamp
                           atIndex:index];

    mStateCache.fragmentSamplers[index].lodMinClamp = lodMinClamp;
    mStateCache.fragmentSamplers[index].lodMaxClamp = lodMaxClamp;
    mStateCache.fragmentSamplers[index].stateObject = state;

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::setFragmentTexture(TextureRef texture, uint32_t index)
{
    if (index >= kMaxShaderSamplers)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(texture);
    [get() setFragmentTexture:(texture ? texture->get() : nil) atIndex:index];

    mStateCache.fragmentTextures[index] = texture;

    return *this;
}

RenderCommandEncoder &RenderCommandEncoder::draw(MTLPrimitiveType primitiveType,
                                                 uint32_t vertexStart,
                                                 uint32_t vertexCount)
{
    [get() drawPrimitives:primitiveType vertexStart:vertexStart vertexCount:vertexCount];

    return *this;
}
RenderCommandEncoder &RenderCommandEncoder::drawIndexed(MTLPrimitiveType primitiveType,
                                                        uint32_t indexCount,
                                                        MTLIndexType indexType,
                                                        BufferRef indexBuffer,
                                                        size_t bufferOffset)
{
    if (!indexBuffer)
    {
        return *this;
    }

    cmdBuffer().setReadDependency(indexBuffer);
    [get() drawIndexedPrimitives:primitiveType
                      indexCount:indexCount
                       indexType:indexType
                     indexBuffer:indexBuffer->get()
               indexBufferOffset:bufferOffset];

    return *this;
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

BlitCommandEncoder &BlitCommandEncoder::copyTexture(TextureRef dst,
                                                    uint32_t dstSlice,
                                                    uint32_t dstLevel,
                                                    MTLOrigin dstOrigin,
                                                    MTLSize dstSize,
                                                    TextureRef src,
                                                    uint32_t srcSlice,
                                                    uint32_t srcLevel,
                                                    MTLOrigin srcOrigin)
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
                sourceSize:dstSize
                 toTexture:dst->get()
          destinationSlice:dstSlice
          destinationLevel:dstLevel
         destinationOrigin:dstOrigin];

    return *this;
}

BlitCommandEncoder &BlitCommandEncoder::generateMipmapsForTexture(TextureRef texture)
{
    if (!texture)
    {
        return *this;
    }

    cmdBuffer().setWriteDependency(texture);
    [get() generateMipmapsForTexture:texture->get()];

    return *this;
}
BlitCommandEncoder &BlitCommandEncoder::synchronizeResource(TextureRef texture)
{
    if (!texture)
    {
        return *this;
    }

#if TARGET_OS_OSX
    cmdBuffer().setWriteDependency(texture);
    [get() synchronizeResource:texture->get()];
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

ComputeCommandEncoder &ComputeCommandEncoder::setBuffer(BufferRef buffer,
                                                        uint32_t offset,
                                                        uint32_t index)
{
    if (index >= kMaxShaderBuffers)
    {
        return *this;
    }

    // TODO(hqle): Assume compute shader both reads and writes to this buffer for now.
    cmdBuffer().setReadDependency(buffer);
    cmdBuffer().setWriteDependency(buffer);

    [get() setBuffer:(buffer ? buffer->get() : nil) offset:offset atIndex:index];

    return *this;
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
ComputeCommandEncoder &ComputeCommandEncoder::setTexture(TextureRef texture, uint32_t index)
{
    if (index >= kMaxShaderSamplers)
    {
        return *this;
    }

    // TODO(hqle): Assume compute shader both reads and writes to this texture for now.
    cmdBuffer().setReadDependency(texture);
    cmdBuffer().setWriteDependency(texture);
    [get() setTexture:(texture ? texture->get() : nil) atIndex:index];

    return *this;
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
