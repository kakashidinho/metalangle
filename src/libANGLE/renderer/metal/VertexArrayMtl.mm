//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "libANGLE/renderer/metal/VertexArrayMtl.h"
#include "libANGLE/renderer/metal/BufferMtl.h"
#include "libANGLE/renderer/metal/ContextMtl.h"
#include "libANGLE/renderer/metal/RendererMtl.h"
#include "libANGLE/renderer/metal/mtl_format_utils.h"

#include "common/debug.h"

#define ANGLE_MTL_CONVERT_INDEX_GPU 1

namespace rx
{
namespace
{
constexpr size_t kDynamicIndexDataSize = 1024 * 8;

angle::Result StreamVertexData(ContextMtl *contextMtl,
                               mtl::BufferPool *dynamicBuffer,
                               const uint8_t *sourceData,
                               size_t bytesToAllocate,
                               size_t destOffset,
                               size_t vertexCount,
                               size_t stride,
                               VertexCopyFunction vertexLoadFunction,
                               SimpleWeakBufferHolderMtl *bufferHolder,
                               size_t *bufferOffsetOut)
{
    ANGLE_CHECK(contextMtl, vertexLoadFunction, "Unsupported format conversion", GL_INVALID_ENUM);
    uint8_t *dst = nullptr;
    mtl::BufferRef newBuffer;
    ANGLE_TRY(dynamicBuffer->allocate(contextMtl, bytesToAllocate, &dst, &newBuffer,
                                      bufferOffsetOut, nullptr));
    bufferHolder->set(newBuffer);
    dst += destOffset;
    vertexLoadFunction(sourceData, stride, vertexCount, dst);

    ANGLE_TRY(dynamicBuffer->commit(contextMtl));
    return angle::Result::Continue;
}

size_t GetIndexConvertedBufferSize(gl::DrawElementsType indexType, size_t indexCount)
{
    size_t elementSize = gl::GetDrawElementsTypeSize(indexType);
    if (indexType == gl::DrawElementsType::UnsignedByte)
    {
        // 8-bit indices are not supported by Metal, so they are promoted to
        // 16-bit indices below
        elementSize = sizeof(GLushort);
    }

    const size_t amount = elementSize * indexCount;

    return amount;
}

angle::Result StreamIndexData(ContextMtl *contextMtl,
                              mtl::BufferPool *dynamicBuffer,
                              const uint8_t *sourcePointer,
                              gl::DrawElementsType indexType,
                              size_t indexCount,
                              SimpleWeakBufferHolderMtl *bufferHolder,
                              size_t *bufferOffsetOut)
{
    // TODO(hqle): This piece of code is copied from Vulkan backend. Consider move it
    // to a common source file?
    dynamicBuffer->releaseInFlightBuffers(contextMtl);

    const size_t amount = GetIndexConvertedBufferSize(indexType, indexCount);
    GLubyte *dst        = nullptr;

    mtl::BufferRef newBuffer;
    ANGLE_TRY(
        dynamicBuffer->allocate(contextMtl, amount, &dst, &newBuffer, bufferOffsetOut, nullptr));
    bufferHolder->set(newBuffer);
    if (indexType == gl::DrawElementsType::UnsignedByte)
    {
        // Unsigned bytes don't have direct support in Metal so we have to expand the
        // memory to a GLushort.
        const GLubyte *in     = static_cast<const GLubyte *>(sourcePointer);
        GLushort *expandedDst = reinterpret_cast<GLushort *>(dst);

        // TODO(hqle): May need to handle primitive restart index in future when ES 3.0
        // is supported.
        // Fast path for common case.
        for (size_t index = 0; index < indexCount; index++)
        {
            expandedDst[index] = static_cast<GLushort>(in[index]);
        }
    }
    else
    {
        // The primitive restart value is the same for OpenGL and Vulkan,
        // so there's no need to perform any conversion.
        memcpy(dst, sourcePointer, amount);
    }
    ANGLE_TRY(dynamicBuffer->commit(contextMtl));

    return angle::Result::Continue;
}

// TODO(hqle): This code is copied from Vulkan backend. Consider moving it to a common header.
size_t GetVertexCount(BufferMtl *srcBuffer,
                      const gl::VertexBinding &binding,
                      uint32_t srcFormatSize)
{
    // Bytes usable for vertex data.
    GLint64 bytes = srcBuffer->size() - binding.getOffset();
    if (bytes < srcFormatSize)
        return 0;

    // Count the last vertex.  It may occupy less than a full stride.
    size_t numVertices = 1;
    bytes -= srcFormatSize;

    // Count how many strides fit remaining space.
    if (bytes > 0)
        numVertices += static_cast<size_t>(bytes) / binding.getStride();

    return numVertices;
}

inline size_t GetIndexCount(BufferMtl *srcBuffer, size_t offset, gl::DrawElementsType indexType)
{
    size_t elementSize = gl::GetDrawElementsTypeSize(indexType);
    return (srcBuffer->size() - offset) / elementSize;
}

}  // namespace

// VertexArrayMtl implementation
VertexArrayMtl::VertexArrayMtl(const gl::VertexArrayState &state, ContextMtl *context)
    : VertexArrayImpl(state)
{
    for (auto &offset : mCurrentArrayBufferOffsets)
    {
        offset = 0;
    }
    for (auto &stride : mCurrentArrayBufferStrides)
    {
        stride = 0;
    }
    for (auto &format : mCurrentArrayBufferFormats)
    {
        format = MTLVertexFormatFloat4;
    }

    mDynamicVertexData.initialize(context, 0, kVertexAttribBufferStrideAlignment,
                                  kMaxVertexAttribs);
    // Due to Metal's strict requirement for offset and stride, we need to always allocate new
    // buffer for every conversion.
    mDynamicVertexData.setAlwaysAllocateNewBuffer(true);

    mDynamicIndexData.initialize(context, kDynamicIndexDataSize, kIndexBufferOffsetAlignment);
}
VertexArrayMtl::~VertexArrayMtl() {}

void VertexArrayMtl::destroy(const gl::Context *context)
{
    ContextMtl *contextMtl = mtl::GetImpl(context);

    for (auto &buffer : mCurrentArrayBuffers)
    {
        buffer = nullptr;
    }
    for (auto &offset : mCurrentArrayBufferOffsets)
    {
        offset = 0;
    }
    for (auto &stride : mCurrentArrayBufferStrides)
    {
        stride = 0;
    }
    for (auto &format : mCurrentArrayBufferFormats)
    {
        format = MTLVertexFormatInvalid;
    }

    mCurrentElementArrayBuffer = nullptr;

    mVertexArrayDirty = true;

    mDynamicVertexData.destroy(contextMtl);
    mDynamicIndexData.destroy(contextMtl);
}

angle::Result VertexArrayMtl::syncState(const gl::Context *context,
                                        const gl::VertexArray::DirtyBits &dirtyBits,
                                        gl::VertexArray::DirtyAttribBitsArray *attribBits,
                                        gl::VertexArray::DirtyBindingBitsArray *bindingBits)
{
    const std::vector<gl::VertexAttribute> &attribs = mState.getVertexAttributes();
    const std::vector<gl::VertexBinding> &bindings  = mState.getVertexBindings();

    for (size_t dirtyBit : dirtyBits)
    {
        switch (dirtyBit)
        {
            case gl::VertexArray::DIRTY_BIT_ELEMENT_ARRAY_BUFFER:
            case gl::VertexArray::DIRTY_BIT_ELEMENT_ARRAY_BUFFER_DATA:
            {
                gl::Buffer *bufferGL = mState.getElementArrayBuffer();
                if (bufferGL)
                {
                    BufferMtl *bufferMtl             = mtl::GetImpl(bufferGL);
                    mCurrentElementArrayBuffer       = bufferMtl;
                    mCurrentElementArrayBufferOffset = 0;
                }
                else
                {
                    mCurrentElementArrayBuffer       = nullptr;
                    mCurrentElementArrayBufferOffset = 0;
                }

                // TODO(hqle): line loop handle

                break;
            }

#define ANGLE_VERTEX_DIRTY_ATTRIB_FUNC(INDEX)                                                     \
    case gl::VertexArray::DIRTY_BIT_ATTRIB_0 + INDEX:                                             \
        ANGLE_TRY(syncDirtyAttrib(context, attribs[INDEX], bindings[attribs[INDEX].bindingIndex], \
                                  INDEX));                                                        \
        mVertexArrayDirty = true;                                                                 \
        (*attribBits)[INDEX].reset();                                                             \
        break;

                ANGLE_VERTEX_INDEX_CASES(ANGLE_VERTEX_DIRTY_ATTRIB_FUNC)

#define ANGLE_VERTEX_DIRTY_BINDING_FUNC(INDEX)                                                    \
    case gl::VertexArray::DIRTY_BIT_BINDING_0 + INDEX:                                            \
        ANGLE_TRY(syncDirtyAttrib(context, attribs[INDEX], bindings[attribs[INDEX].bindingIndex], \
                                  INDEX));                                                        \
        mVertexArrayDirty = true;                                                                 \
        (*bindingBits)[INDEX].reset();                                                            \
        break;

                ANGLE_VERTEX_INDEX_CASES(ANGLE_VERTEX_DIRTY_BINDING_FUNC)

#define ANGLE_VERTEX_DIRTY_BUFFER_DATA_FUNC(INDEX)                                                \
    case gl::VertexArray::DIRTY_BIT_BUFFER_DATA_0 + INDEX:                                        \
        ANGLE_TRY(syncDirtyAttrib(context, attribs[INDEX], bindings[attribs[INDEX].bindingIndex], \
                                  INDEX));                                                        \
        mVertexArrayDirty = true;                                                                 \
        break;

                ANGLE_VERTEX_INDEX_CASES(ANGLE_VERTEX_DIRTY_BUFFER_DATA_FUNC)

            default:
                UNREACHABLE();
                break;
        }
    }

    return angle::Result::Continue;
}

// vertexDescChanged is both input and output, the input value if is true, will force new
// mtl::VertexDesc to be returned via vertexDescOut. Otherwise, it is only returned when the
// vertex array is dirty
angle::Result VertexArrayMtl::setupDraw(const gl::Context *glContext,
                                        mtl::RenderCommandEncoder *cmdEncoder,
                                        bool *vertexDescChanged,
                                        mtl::VertexDesc *vertexDescOut)
{
    bool dirty = mVertexArrayDirty || *vertexDescChanged;

    if (dirty)
    {
        mVertexArrayDirty         = false;
        uint32_t currentBufferIdx = kVboBindingIndexStart;

        const std::vector<gl::VertexAttribute> &attribs = mState.getVertexAttributes();
        const std::vector<gl::VertexBinding> &bindings  = mState.getVertexBindings();

        auto &desc = *vertexDescOut;

        desc.numAttribs       = kMaxVertexAttribs;
        desc.numBufferLayouts = kMaxVertexAttribs;

#define ANGLE_MTL_SET_DEFAULT_ATTRIB_BUFFER_LAYOUT(DESC, INDEX)           \
    do                                                                    \
    {                                                                     \
        DESC.layouts[INDEX].stepFunction = MTLVertexStepFunctionConstant; \
        DESC.layouts[INDEX].stepRate     = 0;                             \
        DESC.layouts[INDEX].stride       = 0;                             \
    } while (0)

        // Initialize the buffer layouts with constant step rate
        for (uint32_t b = 0; b < kMaxVertexAttribs; ++b)
        {
            ANGLE_MTL_SET_DEFAULT_ATTRIB_BUFFER_LAYOUT(desc, b);
        }

        for (uint32_t v = 0; v < kMaxVertexAttribs; ++v)
        {
            __attribute__((unused)) const auto &attrib  = attribs[v];
            __attribute__((unused)) const auto &binding = bindings[v];

            desc.attributes[v].offset = mCurrentArrayBufferOffsets[v];
            desc.attributes[v].format = mCurrentArrayBufferFormats[v];

            bool attribEnabled = attrib.enabled;
            if (attribEnabled && !mCurrentArrayBuffers[v])
            {
                // Disable it to avoid crash.
                attribEnabled = false;
            }

            if (attribEnabled)
            {
                auto bufferIdx = currentBufferIdx++;

                desc.attributes[v].bufferIndex = bufferIdx;

                desc.layouts[v].stepFunction = MTLVertexStepFunctionPerVertex;
                desc.layouts[v].stepRate     = 1;
                desc.layouts[v].stride       = mCurrentArrayBufferStrides[v];

                cmdEncoder->setVertexBuffer(mCurrentArrayBuffers[v]->getCurrentBuffer(glContext), 0,
                                            bufferIdx);
            }
            else
            {
                desc.attributes[v].bufferIndex = kDefaultAttribsBindingIndex;
                desc.attributes[v].offset      = v * kDefaultAttributeSize;
            }
        }
    }

    *vertexDescChanged = dirty;

    return angle::Result::Continue;
}

angle::Result VertexArrayMtl::updateClientAttribs(const gl::Context *context,
                                                  GLint firstVertex,
                                                  GLsizei vertexOrIndexCount,
                                                  GLsizei instanceCount,
                                                  gl::DrawElementsType indexTypeOrInvalid,
                                                  const void *indices)
{
    ContextMtl *contextMtl                  = mtl::GetImpl(context);
    const gl::AttributesMask &clientAttribs = context->getStateCache().getActiveClientAttribsMask();

    ASSERT(clientAttribs.any());

    GLint startVertex;
    size_t vertexCount;
    ANGLE_TRY(GetVertexRangeInfo(context, firstVertex, vertexOrIndexCount, indexTypeOrInvalid,
                                 indices, 0, &startVertex, &vertexCount));

    mDynamicVertexData.releaseInFlightBuffers(contextMtl);

    const auto &attribs  = mState.getVertexAttributes();
    const auto &bindings = mState.getVertexBindings();

    // TODO(fjhenigman): When we have a bunch of interleaved attributes, they end up
    // un-interleaved, wasting space and copying time.  Consider improving on that.
    for (size_t attribIndex : clientAttribs)
    {
        const gl::VertexAttribute &attrib = attribs[attribIndex];
        const gl::VertexBinding &binding  = bindings[attrib.bindingIndex];
        ASSERT(attrib.enabled && binding.getBuffer().get() == nullptr);

        mtl::VertexFormat vertexFormat(attrib.format->id, true);
        GLuint stride = vertexFormat.actualAngleFormat().pixelBytes;

        const uint8_t *src = static_cast<const uint8_t *>(attrib.pointer);
        if (src == nullptr)
        {
            // Is this an error?
            return angle::Result::Continue;
        }

        if (binding.getDivisor() > 0)
        {
            (void)instanceCount;
            // TODO(hqle): ES 3.0.
            // instanced attrib
            UNREACHABLE();
        }
        else
        {
            // Allocate space for startVertex + vertexCount so indexing will work.  If we don't
            // start at zero all the indices will be off.
            // Only vertexCount vertices will be used by the upcoming draw so that is all we copy.
            size_t bytesToAllocate = (startVertex + vertexCount) * stride;
            src += startVertex * binding.getStride();
            size_t destOffset = startVertex * stride;

            ANGLE_TRY(StreamVertexData(contextMtl, &mDynamicVertexData, src, bytesToAllocate,
                                       destOffset, vertexCount, binding.getStride(),
                                       vertexFormat.vertexLoadFunction,
                                       &mDynamicArrayBufferHolders[attribIndex],
                                       &mCurrentArrayBufferOffsets[attribIndex]));

            mCurrentArrayBuffers[attribIndex]       = &mDynamicArrayBufferHolders[attribIndex];
            mCurrentArrayBufferFormats[attribIndex] = vertexFormat.metalFormat;
            mCurrentArrayBufferStrides[attribIndex] = stride;
        }
    }

    mVertexArrayDirty = true;

    return angle::Result::Continue;
}

angle::Result VertexArrayMtl::syncDirtyAttrib(const gl::Context *glContext,
                                              const gl::VertexAttribute &attrib,
                                              const gl::VertexBinding &binding,
                                              size_t attribIndex)
{
    ContextMtl *contextMtl = mtl::GetImpl(glContext);
    ASSERT(kMaxVertexAttribs > attribIndex);

    if (attrib.enabled)
    {
        gl::Buffer *bufferGL = binding.getBuffer().get();
        mtl::VertexFormat format(attrib.format->id);

        if (bufferGL)
        {
            BufferMtl *bufferMtl = mtl::GetImpl(bufferGL);
            bool needConversion =
                format.actualFormatId != format.intendedFormatId ||
                (binding.getOffset() % kVertexAttribBufferOffsetAlignment) != 0 ||
                (binding.getStride() % kVertexAttribBufferStrideAlignment) != 0 ||
                // This is Metal requirement:
                (format.actualAngleFormat().pixelBytes + binding.getOffset() > binding.getStride());

            if (needConversion)
            {
                ANGLE_TRY(convertVertexBuffer(glContext, bufferMtl, binding, attribIndex, format));
            }
            else
            {
                mCurrentArrayBuffers[attribIndex]       = bufferMtl;
                mCurrentArrayBufferOffsets[attribIndex] = binding.getOffset();
                mCurrentArrayBufferStrides[attribIndex] = binding.getStride();

                mCurrentArrayBufferFormats[attribIndex] = format.metalFormat;
            }
        }
        else
        {
            // ContextMtl must feed the client data using updateClientAttribs()
        }
    }
    else
    {
        // Tell ContextMtl to update default attribute value
        contextMtl->invalidateDefaultAttribute(attribIndex);

        mCurrentArrayBuffers[attribIndex]       = nullptr;
        mCurrentArrayBufferOffsets[attribIndex] = 0;
        mCurrentArrayBufferStrides[attribIndex] = 0;
        // TODO(hqle): We only support ES 2.0 atm. So default attribute type should always
        // be float.
        mCurrentArrayBufferFormats[attribIndex] = MTLVertexFormatFloat4;
    }

    return angle::Result::Continue;
}

angle::Result VertexArrayMtl::convertIndexBuffer(const gl::Context *glContext,
                                                 gl::DrawElementsType indexType,
                                                 BufferMtl *idxBuffer,
                                                 size_t offset)
{
    ASSERT(idxBuffer);
    ASSERT((offset % kIndexBufferOffsetAlignment) != 0 ||
           indexType == gl::DrawElementsType::UnsignedByte);

    ConversionBufferMtl *conversion =
        idxBuffer->getIndexConversionBuffer(glContext, indexType, offset);

    // Has the content of the buffer has changed since last conversion?
    if (!conversion->dirty)
    {
        return angle::Result::Continue;
    }

    size_t indexCount = GetIndexCount(idxBuffer, offset, indexType);

#if ANGLE_MTL_CONVERT_INDEX_GPU
    ANGLE_TRY(
        convertIndexBufferGPU(glContext, indexType, idxBuffer, offset, indexCount, conversion));
#else
    ANGLE_TRY(
        convertIndexBufferCPU(glContext, indexType, idxBuffer, offset, indexCount, conversion));
#endif

    return angle::Result::Continue;
}

angle::Result VertexArrayMtl::convertIndexBufferGPU(const gl::Context *glContext,
                                                    gl::DrawElementsType indexType,
                                                    BufferMtl *idxBuffer,
                                                    size_t offset,
                                                    size_t indexCount,
                                                    ConversionBufferMtl *conversion)
{
    ContextMtl *contextMtl = mtl::GetImpl(glContext);
    RendererMtl *renderer  = contextMtl->getRenderer();

    const size_t amount = GetIndexConvertedBufferSize(indexType, indexCount);

    // Allocate new buffer
    mtl::BufferRef newBuffer;
    conversion->data.releaseInFlightBuffers(contextMtl);
    ANGLE_TRY(conversion->data.allocate(contextMtl, amount, nullptr, &newBuffer,
                                        &mCurrentElementArrayBufferOffset));
    mDynamicElementArrayBufferHolder.set(newBuffer);

    // Do the conversion on GPU.
    ANGLE_TRY(renderer->getUtils().convertIndexBuffer(
        glContext, indexType, static_cast<uint32_t>(indexCount),
        idxBuffer->getCurrentBuffer(glContext), static_cast<uint32_t>(offset), newBuffer,
        static_cast<uint32_t>(mCurrentElementArrayBufferOffset)));

    ANGLE_TRY(conversion->data.commit(contextMtl));

    mCurrentElementArrayBuffer = &mDynamicElementArrayBufferHolder;
    ASSERT(conversion->dirty);
    conversion->dirty = false;

    return angle::Result::Continue;
}

angle::Result VertexArrayMtl::convertIndexBufferCPU(const gl::Context *glContext,
                                                    gl::DrawElementsType indexType,
                                                    BufferMtl *idxBuffer,
                                                    size_t offset,
                                                    size_t indexCount,
                                                    ConversionBufferMtl *conversion)
{
    ContextMtl *contextMtl = mtl::GetImpl(glContext);

    const auto srcData = idxBuffer->getClientShadowCopyData(glContext) + offset;
    ANGLE_TRY(StreamIndexData(contextMtl, &conversion->data, srcData, indexType, indexCount,
                              &mDynamicElementArrayBufferHolder,
                              &mCurrentElementArrayBufferOffset));

    mCurrentElementArrayBuffer = &mDynamicElementArrayBufferHolder;
    ASSERT(conversion->dirty);
    conversion->dirty = false;

    return angle::Result::Continue;
}

angle::Result VertexArrayMtl::streamIndexBufferFromClient(const gl::Context *context,
                                                          gl::DrawElementsType indexType,
                                                          size_t indexCount,
                                                          const void *sourcePointer)
{
    ASSERT(getState().getElementArrayBuffer() == nullptr);
    ContextMtl *contextMtl = mtl::GetImpl(context);

    auto srcData = static_cast<const uint8_t *>(sourcePointer);
    ANGLE_TRY(StreamIndexData(contextMtl, &mDynamicIndexData, srcData, indexType, indexCount,
                              &mDynamicElementArrayBufferHolder,
                              &mCurrentElementArrayBufferOffset));

    mCurrentElementArrayBuffer = &mDynamicElementArrayBufferHolder;

    return angle::Result::Continue;
}

angle::Result VertexArrayMtl::convertVertexBuffer(const gl::Context *glContext,
                                                  BufferMtl *srcBuffer,
                                                  const gl::VertexBinding &binding,
                                                  size_t attribIndex,
                                                  const mtl::VertexFormat &vertexFormat)
{
    const angle::Format &intendedAngleFormat = vertexFormat.intendedAngleFormat();

    ConversionBufferMtl *conversion = srcBuffer->getVertexConversionBuffer(
        glContext, intendedAngleFormat.id, binding.getStride(), binding.getOffset());

    // Has the content of the buffer has changed since last conversion?
    if (!conversion->dirty)
    {
        return angle::Result::Continue;
    }

    // TODO(hqle): Do the conversion on GPU.
    return convertVertexBufferCPU(glContext, srcBuffer, binding, attribIndex, vertexFormat,
                                  conversion);
}

angle::Result VertexArrayMtl::convertVertexBufferCPU(const gl::Context *glContext,
                                                     BufferMtl *srcBuffer,
                                                     const gl::VertexBinding &binding,
                                                     size_t attribIndex,
                                                     const mtl::VertexFormat &srcVertexFormat,
                                                     ConversionBufferMtl *conversion)
{
    ContextMtl *contextMtl = mtl::GetImpl(glContext);

    // Convert to streaming format
    mtl::VertexFormat vertexFormat(srcVertexFormat.intendedFormatId, true);
    unsigned srcFormatSize = vertexFormat.intendedAngleFormat().pixelBytes;
    unsigned dstFormatSize = vertexFormat.actualAngleFormat().pixelBytes;

    conversion->data.releaseInFlightBuffers(contextMtl);

    size_t numVertices = GetVertexCount(srcBuffer, binding, srcFormatSize);
    if (numVertices == 0)
    {
        return angle::Result::Continue;
    }

    const uint8_t *srcBytes = srcBuffer->getClientShadowCopyData(glContext);
    ANGLE_CHECK_GL_ALLOC(contextMtl, srcBytes);

    srcBytes += binding.getOffset();

    ANGLE_TRY(StreamVertexData(contextMtl, &conversion->data, srcBytes, numVertices * dstFormatSize,
                               0, numVertices, binding.getStride(), vertexFormat.vertexLoadFunction,
                               &mDynamicArrayBufferHolders[attribIndex],
                               &mCurrentArrayBufferOffsets[attribIndex]));

    mCurrentArrayBuffers[attribIndex]       = &mDynamicArrayBufferHolders[attribIndex];
    mCurrentArrayBufferFormats[attribIndex] = vertexFormat.metalFormat;
    mCurrentArrayBufferStrides[attribIndex] = dstFormatSize;

    ASSERT(conversion->dirty);
    conversion->dirty = false;

    return angle::Result::Continue;
}
}
