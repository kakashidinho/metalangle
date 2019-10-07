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
    outIndices->first  = indices[0];
    outIndices->second = indices[count - 1];

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

// BufferMtl::VertexConversionBuffer implementation.
BufferMtl::VertexConversionBuffer::VertexConversionBuffer(const gl::Context *context,
                                                          angle::FormatID formatIDIn,
                                                          GLuint strideIn,
                                                          size_t offsetIn)
    : ConversionBufferMtl(context, 0, kVertexAttribBufferStrideAlignment),
      formatID(formatIDIn),
      stride(strideIn),
      offset(offsetIn)
{
    // Due to Metal's strict requirement for offset and stride, we need to always allocate new
    // buffer for every conversion.
    data.setAlwaysAllocateNewBuffer(true);
}

// BufferMtl::IndexConversionBuffer implementation.
BufferMtl::IndexConversionBuffer::IndexConversionBuffer(const gl::Context *context,
                                                        gl::DrawElementsType typeIn,
                                                        size_t offsetIn)
    : ConversionBufferMtl(context,
                          kConvertedElementArrayBufferInitialSize,
                          kBufferSettingOffsetAlignment),
      type(typeIn),
      offset(offsetIn)
{}

// BufferMtl implementation
BufferMtl::BufferMtl(const gl::BufferState &state) : BufferImpl(state), mBuffer(true) {}

BufferMtl::~BufferMtl() {}

void BufferMtl::destroy(const gl::Context *context)
{
    mBuffer.destroy();
}

angle::Result BufferMtl::setData(const gl::Context *context,
                                 gl::BufferBinding target,
                                 const void *data,
                                 size_t size,
                                 gl::BufferUsage usage)
{
    ContextMtl *contextMtl = mtl::GetImpl(context);

    if (!mBuffer.valid() || size > static_cast<size_t>(mState.getSize()) ||
        usage != mState.getUsage())
    {
        if (size == 0)
        {
            size = 1;
        }
        // Re-create the buffer
        uint32_t streamBufferQueueSize;
        switch (usage)
        {
            case gl::BufferUsage::StaticCopy:
            case gl::BufferUsage::StaticDraw:
            case gl::BufferUsage::StaticRead:
                streamBufferQueueSize = 1;  // static buffer doesn't need high speed data update
                break;
            default:
                // dynamic buffer
                streamBufferQueueSize = 2;
                break;
        }

        markConversionBuffersDirty();

        return mBuffer.initialize(contextMtl, size, streamBufferQueueSize,
                                  reinterpret_cast<const uint8_t *>(data));
    }
    else
    {
        // update data only
        return setSubData(context, target, data, size, 0);
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

    ASSERT(mBuffer.valid());

    auto srcMtl = GetAs<BufferMtl>(source);

    // TODO(hqle): use blit command?
    return setSubDataImpl(context, srcMtl->mBuffer.data() + sourceOffset, size, destOffset);
}

angle::Result BufferMtl::map(const gl::Context *context, GLenum access, void **mapPtr)
{
    ASSERT(mBuffer.valid());
    return mapRange(context, 0, mState.getSize(), 0, mapPtr);
}

angle::Result BufferMtl::mapRange(const gl::Context *context,
                                  size_t offset,
                                  size_t length,
                                  GLbitfield access,
                                  void **mapPtr)
{
    ASSERT(mBuffer.valid());

    // TODO(hqle): use access flags
    if (mapPtr)
    {
        *mapPtr = mBuffer.data() + offset;
    }

    return angle::Result::Continue;
}

angle::Result BufferMtl::unmap(const gl::Context *context, GLboolean *result)
{
    ASSERT(mBuffer.valid());

    ContextMtl *contextMtl = mtl::GetImpl(context);

    mBuffer.commit(contextMtl);

    markConversionBuffersDirty();

    return angle::Result::Continue;
}

angle::Result BufferMtl::getIndexRange(const gl::Context *context,
                                       gl::DrawElementsType type,
                                       size_t offset,
                                       size_t count,
                                       bool primitiveRestartEnabled,
                                       gl::IndexRange *outRange)
{
    ASSERT(mBuffer.valid());

    const uint8_t *indices = mBuffer.data() + offset;

    *outRange = gl::ComputeIndexRange(type, indices, count, primitiveRestartEnabled);

    return angle::Result::Continue;
}

angle::Result BufferMtl::getFirstLastIndices(const gl::Context *context,
                                             gl::DrawElementsType type,
                                             size_t offset,
                                             size_t count,
                                             std::pair<uint32_t, uint32_t> *outIndices) const
{
    ASSERT(mBuffer.valid());

    const uint8_t *indices = mBuffer.data() + offset;

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

mtl::BufferRef BufferMtl::getCurrentBuffer(const gl::Context *context)
{
    ContextMtl *contextMtl = mtl::GetImpl(context);
    return mBuffer.getCurrentBuffer(contextMtl);
}

const uint8_t *BufferMtl::getClientShadowCopyData(const gl::Context *context)
{
    // TODO(hqle): Support buffer update from GPU.
    // Which mean we have to stall the GPU by calling finish.
    return mBuffer.data();
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

ConversionBufferMtl *BufferMtl::getIndexConversionBuffer(const gl::Context *context,
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

void BufferMtl::markConversionBuffersDirty()
{
    for (VertexConversionBuffer &buffer : mVertexConversionBuffers)
    {
        buffer.dirty = true;
    }

    for (auto &buffer : mIndexConversionBuffers)
    {
        buffer.dirty = true;
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

    ASSERT(mBuffer.valid());

    ContextMtl *contextMtl = mtl::GetImpl(context);

    auto ptr = mBuffer.data() + offset;
    memcpy(ptr, data, std::min<size_t>(size, mBuffer.size()));

    mBuffer.commit(contextMtl);

    markConversionBuffersDirty();

    return angle::Result::Continue;
}

}  // namespace rx
