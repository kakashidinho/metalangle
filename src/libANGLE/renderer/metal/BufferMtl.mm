//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// BufferMtl.mm:
//    Implements the class methods for BufferMtl.
//

#include "libANGLE/renderer/metal/BufferMtl.h"

#include "common/debug.h"
#include "common/utilities.h"
#include "libANGLE/renderer/metal/ContextMtl.h"

namespace rx
{

namespace
{

// Start with a fairly small buffer size. We can increase this dynamically as we convert more data.
constexpr size_t kConvertedElementArrayBufferInitialSize = 1024 * 8;

template <typename IndexType>
angle::Result GetFirstLastIndices(const IndexType *indices,
                                  size_t count,
                                  std::pair<uint32_t, uint32_t> *outIndices)
{
    IndexType first, last;
    // Use memcpy to avoid unaligned memory access crash:
    memcpy(&first, &indices[0], sizeof(first));
    memcpy(&last, &indices[count - 1], sizeof(last));

    outIndices->first  = first;
    outIndices->second = last;

    return angle::Result::Continue;
}

}  // namespace

// ConversionBufferMtl implementation.
ConversionBufferMtl::ConversionBufferMtl(const gl::Context *context,
                                         size_t initialSize,
                                         size_t alignment)
    : dirty(true)
{
    ContextMtl *contextMtl = mtl::GetImpl(context);
    data.initialize(contextMtl, initialSize, alignment);
}

ConversionBufferMtl::~ConversionBufferMtl() = default;

// IndexConversionBufferMtl implementation.
IndexConversionBufferMtl::IndexConversionBufferMtl(const gl::Context *context,
                                                   gl::DrawElementsType typeIn,
                                                   size_t offsetIn)
    : ConversionBufferMtl(context,
                          kConvertedElementArrayBufferInitialSize,
                          mtl::kBufferSettingOffsetAlignment),
      type(typeIn),
      offset(offsetIn),
      convertedBuffer(nullptr),
      convertedOffset(0)
{}

// BufferMtl::VertexConversionBuffer implementation.
BufferMtl::VertexConversionBuffer::VertexConversionBuffer(const gl::Context *context,
                                                          angle::FormatID formatIDIn,
                                                          GLuint strideIn,
                                                          size_t offsetIn)
    : ConversionBufferMtl(context, 0, mtl::kVertexAttribBufferStrideAlignment),
      formatID(formatIDIn),
      stride(strideIn),
      offset(offsetIn)
{
    // Due to Metal's strict requirement for offset and stride, we need to always allocate new
    // buffer for every conversion.
    data.setAlwaysAllocateNewBuffer(true);
}

// BufferMtl implementation
BufferMtl::BufferMtl(const gl::BufferState &state)
    : BufferImpl(state), mBufferPool(/** alwaysAllocNewBuffer */ true)
{}

BufferMtl::~BufferMtl() {}

void BufferMtl::destroy(const gl::Context *context)
{
    ContextMtl *contextMtl = mtl::GetImpl(context);
    mShadowCopy.resize(0);
    mBufferPool.destroy(contextMtl);
    mBuffer = nullptr;
}

angle::Result BufferMtl::setData(const gl::Context *context,
                                 gl::BufferBinding target,
                                 const void *data,
                                 size_t originalSize,
                                 gl::BufferUsage usage)
{
    ContextMtl *contextMtl = mtl::GetImpl(context);

    mFirstBufferUpdate = true;

    if (!mShadowCopy.size() || originalSize > static_cast<size_t>(mState.getSize()) ||
        usage != mState.getUsage())
    {
        size_t size = originalSize;
        if (size == 0)
        {
            size = 1;
        }
        // Re-create the buffer
        markDataDirty();

        // Allocate shadow copy
        ANGLE_MTL_CHECK(contextMtl, mShadowCopy.resize(size), GL_OUT_OF_MEMORY);

        // Allocate GPU buffers pool
        size_t maxBuffers;
        switch (usage)
        {
            case gl::BufferUsage::StaticCopy:
            case gl::BufferUsage::StaticDraw:
            case gl::BufferUsage::StaticRead:
                maxBuffers = 1;  // static buffer doesn't need high speed data update
                break;
            default:
                // dynamic buffer, allow up to 2 update per frame/encoding without
                // waiting for GPU.
                maxBuffers = 2;
                break;
        }

        mBufferPool.initialize(contextMtl, size, 1, maxBuffers);
        if (data)
        {
            // Transfer data to GPU buffer
            return commitData(context, static_cast<const uint8_t *>(data), 0, originalSize);
        }
        else
        {
            // Allocate the very first buffer
            ANGLE_TRY(mBufferPool.allocate(contextMtl, mShadowCopy.size(), nullptr, &mBuffer, nullptr,
                                           nullptr));
        }

        return angle::Result::Continue;
    }
    else
    {
        // update data only
        return setSubData(context, target, data, originalSize, 0);
    }
}

angle::Result BufferMtl::setSubData(const gl::Context *context,
                                    gl::BufferBinding target,
                                    const void *data,
                                    size_t size,
                                    size_t offset)
{
    return setSubDataImpl(context, data, size, offset);
}

angle::Result BufferMtl::copySubData(const gl::Context *context,
                                     BufferImpl *source,
                                     GLintptr sourceOffset,
                                     GLintptr destOffset,
                                     GLsizeiptr size)
{
    if (!source)
    {
        return angle::Result::Continue;
    }

    ASSERT(mShadowCopy.size());

    auto srcMtl = GetAs<BufferMtl>(source);

    // NOTE(hqle): use blit command.
    return setSubDataImpl(context, srcMtl->getClientShadowCopyData(context) + sourceOffset, size,
                          destOffset);
}

angle::Result BufferMtl::map(const gl::Context *context, GLenum access, void **mapPtr)
{
    ASSERT(mShadowCopy.size());
    return mapRange(context, 0, mState.getSize(), 0, mapPtr);
}

angle::Result BufferMtl::mapRange(const gl::Context *context,
                                  size_t offset,
                                  size_t length,
                                  GLbitfield access,
                                  void **mapPtr)
{
    ASSERT(mShadowCopy.size());

    // NOTE(hqle): use access flags
    uint8_t *ptr;
    ANGLE_TRY(mapImpl(context, &ptr));
    if (mapPtr)
    {
        *mapPtr = ptr + offset;
    }

    return angle::Result::Continue;
}

angle::Result BufferMtl::unmap(const gl::Context *context, GLboolean *result)
{
    ASSERT(mShadowCopy.size());

    markDataDirty();

    ANGLE_TRY(unmapImpl(context));

    return angle::Result::Continue;
}

angle::Result BufferMtl::getIndexRange(const gl::Context *context,
                                       gl::DrawElementsType type,
                                       size_t offset,
                                       size_t count,
                                       bool primitiveRestartEnabled,
                                       gl::IndexRange *outRange)
{
    ASSERT(mShadowCopy.size());

    const uint8_t *indices = getClientShadowCopyData(context) + offset;

    *outRange = gl::ComputeIndexRange(type, indices, count, primitiveRestartEnabled);

    return angle::Result::Continue;
}

angle::Result BufferMtl::getFirstLastIndices(const gl::Context *context,
                                             gl::DrawElementsType type,
                                             size_t offset,
                                             size_t count,
                                             std::pair<uint32_t, uint32_t> *outIndices) const
{
    ASSERT(mShadowCopy.size());

    const uint8_t *indices = getClientShadowCopyData(context) + offset;

    switch (type)
    {
        case gl::DrawElementsType::UnsignedByte:
            return GetFirstLastIndices(static_cast<const GLubyte *>(indices), count, outIndices);
        case gl::DrawElementsType::UnsignedShort:
            return GetFirstLastIndices(reinterpret_cast<const GLushort *>(indices), count,
                                       outIndices);
        case gl::DrawElementsType::UnsignedInt:
            return GetFirstLastIndices(reinterpret_cast<const GLuint *>(indices), count,
                                       outIndices);
        default:
            UNREACHABLE();
            return angle::Result::Stop;
    }

    return angle::Result::Continue;
}

const uint8_t *BufferMtl::getClientShadowCopyData(const gl::Context *context) const
{
    if (mShadowCopyDirty)
    {
        // Current buffer=null means the buffer's data hasn't been updated yet.
        // In that case, ignore the copy step.
        if (mBuffer)
        {
            copyToShadowCopy(context);
        }
    }
    return mShadowCopy.data();
}

void BufferMtl::copyToShadowCopy(const gl::Context *context) const
{
    ASSERT(mBuffer);
    ContextMtl *contextMtl = mtl::GetImpl(context);

    // Copy from GPU buffer to shadow copy buffer.
    ASSERT(mBuffer->size() == mShadowCopy.size());
    const uint8_t *bufferData = mBuffer->contents(contextMtl);
    std::copy(bufferData, bufferData + mShadowCopy.size(), mShadowCopy.data());

    mShadowCopyDirty = false;
}

ConversionBufferMtl *BufferMtl::getVertexConversionBuffer(const gl::Context *context,
                                                          angle::FormatID formatID,
                                                          GLuint stride,
                                                          size_t offset)
{
    for (VertexConversionBuffer &buffer : mVertexConversionBuffers)
    {
        if (buffer.formatID == formatID && buffer.stride == stride && buffer.offset == offset)
        {
            return &buffer;
        }
    }

    mVertexConversionBuffers.emplace_back(context, formatID, stride, offset);
    return &mVertexConversionBuffers.back();
}

IndexConversionBufferMtl *BufferMtl::getIndexConversionBuffer(const gl::Context *context,
                                                              gl::DrawElementsType type,
                                                              size_t offset)
{
    for (auto &buffer : mIndexConversionBuffers)
    {
        if (buffer.type == type && buffer.offset == offset)
        {
            return &buffer;
        }
    }

    mIndexConversionBuffers.emplace_back(context, type, offset);
    return &mIndexConversionBuffers.back();
}

void BufferMtl::markDataDirty()
{
    mShadowCopyDirty = true;

    for (VertexConversionBuffer &buffer : mVertexConversionBuffers)
    {
        buffer.dirty = true;
    }

    for (auto &buffer : mIndexConversionBuffers)
    {
        buffer.dirty           = true;
        buffer.convertedBuffer = nullptr;
        buffer.convertedOffset = 0;
    }
}

angle::Result BufferMtl::setSubDataImpl(const gl::Context *context,
                                        const void *data,
                                        size_t size,
                                        size_t offset)
{
    if (!data)
    {
        return angle::Result::Continue;
    }

    ASSERT(mShadowCopy.size());

    markDataDirty();

    auto srcPtr = static_cast<const uint8_t *>(data);

    ANGLE_TRY(commitData(context, srcPtr, offset, size));

    return angle::Result::Continue;
}

angle::Result BufferMtl::commitData(const gl::Context *context,
                                    const uint8_t *data,
                                    size_t offset,
                                    size_t size)
{
    ContextMtl *contextMtl = mtl::GetImpl(context);
    ANGLE_MTL_TRY(contextMtl, offset <= this->size());

    size = std::min(size, mShadowCopy.size() - offset);

    uint8_t *ptr = nullptr;
    ANGLE_TRY(mapImpl(context, &ptr));

    std::copy(data, data + size, ptr + offset);

    ANGLE_TRY(unmapImpl(context));

    return angle::Result::Continue;
}

angle::Result BufferMtl::mapImpl(const gl::Context *context, uint8_t **mapPtr)
{
    if (mMappedPtr)
    {
        // If already mapped, return the mapped pointer.
        *mapPtr = mMappedPtr;
        return angle::Result::Continue;
    }

    mtl::BufferRef previousBuffer = mBuffer;

    ContextMtl *contextMtl = mtl::GetImpl(context);
    ANGLE_TRY(mBufferPool.allocate(contextMtl, mShadowCopy.size(), &mMappedPtr, &mBuffer, nullptr,
                                   nullptr));

    *mapPtr = mMappedPtr;

    if (!mFirstBufferUpdate && previousBuffer && previousBuffer != mBuffer)
    {
        ASSERT(previousBuffer->size() == mBuffer->size());
        // If this is not first update, transfer previous buffer data to the newly allocated buffer.
        const uint8_t *oldBufferData = previousBuffer->contents(contextMtl);
        std::copy(oldBufferData, oldBufferData + mShadowCopy.size(), mMappedPtr);
    }

    // The subsequent update is not first update anymore.
    mFirstBufferUpdate = false;

    return angle::Result::Continue;
}

angle::Result BufferMtl::unmapImpl(const gl::Context *context)
{
    if (!mMappedPtr)
    {
        return angle::Result::Continue;
    }

    mMappedPtr = nullptr;

    ContextMtl *contextMtl = mtl::GetImpl(context);
    return mBufferPool.commit(contextMtl);
}

// SimpleWeakBufferHolderMtl implementation
SimpleWeakBufferHolderMtl::SimpleWeakBufferHolderMtl()
{
    mIsWeak = true;
}

}  // namespace rx
