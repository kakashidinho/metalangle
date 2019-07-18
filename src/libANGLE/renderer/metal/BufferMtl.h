//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// BufferMtl.h:
//    Defines the class interface for BufferMtl, implementing BufferImpl.
//

#ifndef LIBANGLE_RENDERER_METAL_BUFFERMTL_H_
#define LIBANGLE_RENDERER_METAL_BUFFERMTL_H_

#include "libANGLE/renderer/metal/Metal_platform.h"

#include <utility>

#include "libANGLE/Buffer.h"
#include "libANGLE/Observer.h"
#include "libANGLE/angletypes.h"
#include "libANGLE/renderer/BufferImpl.h"
#include "libANGLE/renderer/Format.h"
#include "libANGLE/renderer/metal/mtl_buffer_pool.h"
#include "libANGLE/renderer/metal/mtl_resources.h"

namespace rx
{

// Conversion buffers hold translated index and vertex data.
struct ConversionBufferMtl
{
    ConversionBufferMtl(const gl::Context *context, size_t initialSize, size_t alignment);
    ~ConversionBufferMtl();

    // One state value determines if we need to re-stream vertex data.
    bool dirty;

    // The conversion is stored in a dynamic buffer.
    mtl::BufferPool data;
};

class BufferHolderMtl
{
  public:
    virtual ~BufferHolderMtl() = default;

    // Due to the complication of synchronizing accesses between CPU and GPU,
    // a mtl::Buffer might be under used by GPU but CPU wants to modify its content through
    // map() method, this could lead to GPU stalling. The more efficient method is maintain
    // a queue of mtl::Buffer and only let CPU modifies a free mtl::Buffer.
    // So, in order to let GPU use the most recent modified content, one must call this method
    // right before the draw call to retrieved the most up-to-date mtl::Buffer.
    virtual mtl::BufferRef getCurrentBuffer(const gl::Context *context) = 0;
};

class BufferMtl : public BufferImpl, public BufferHolderMtl
{
  public:
    BufferMtl(const gl::BufferState &state);
    ~BufferMtl() override;
    void destroy(const gl::Context *context) override;

    angle::Result setData(const gl::Context *context,
                          gl::BufferBinding target,
                          const void *data,
                          size_t size,
                          gl::BufferUsage usage) override;
    angle::Result setSubData(const gl::Context *context,
                             gl::BufferBinding target,
                             const void *data,
                             size_t size,
                             size_t offset) override;
    angle::Result copySubData(const gl::Context *context,
                              BufferImpl *source,
                              GLintptr sourceOffset,
                              GLintptr destOffset,
                              GLsizeiptr size) override;
    angle::Result map(const gl::Context *context, GLenum access, void **mapPtr) override;
    angle::Result mapRange(const gl::Context *context,
                           size_t offset,
                           size_t length,
                           GLbitfield access,
                           void **mapPtr) override;
    angle::Result unmap(const gl::Context *context, GLboolean *result) override;

    angle::Result getIndexRange(const gl::Context *context,
                                gl::DrawElementsType type,
                                size_t offset,
                                size_t count,
                                bool primitiveRestartEnabled,
                                gl::IndexRange *outRange) override;

    angle::Result getFirstLastIndices(const gl::Context *context,
                                      gl::DrawElementsType type,
                                      size_t offset,
                                      size_t count,
                                      std::pair<uint32_t, uint32_t> *outIndices) const;

    // BufferMtl actually manages a queue of mtl::Buffer internally to avoid
    // stalling the rendering GPU whenever the CPU wants to modify this buffer's content.
    // So in order to submit the modified content to GPU. One needs to call this method
    // to retrieve the most recent up-to-date mtl::Buffer. So it's important to only
    // call this method right before the draw call. Because if you get a mtl::Buffer too early,
    // and the application calls map() and unmap() to modify the content of BufferMtl right after
    // that, the earlier mtl::Buffer may not contain that modified data.
    mtl::BufferRef getCurrentBuffer(const gl::Context *context) override;

    const uint8_t *getClientShadowCopyData(const gl::Context *context);

    ConversionBufferMtl *getVertexConversionBuffer(const gl::Context *context,
                                                   angle::FormatID formatID,
                                                   GLuint stride,
                                                   size_t offset);

    ConversionBufferMtl *getIndexConversionBuffer(const gl::Context *context,
                                                  gl::DrawElementsType type,
                                                  size_t offset);

    size_t size() const { return mBuffer.size(); }

  private:
    angle::Result setSubDataImpl(const gl::Context *context,
                                 const void *data,
                                 size_t size,
                                 size_t offset);

    void markConversionBuffersDirty();

    mtl::StreamBuffer mBuffer;

    struct VertexConversionBuffer : public ConversionBufferMtl
    {
        VertexConversionBuffer(const gl::Context *context,
                               angle::FormatID formatIDIn,
                               GLuint strideIn,
                               size_t offsetIn);

        // The conversion is identified by the triple of {format, stride, offset}.
        angle::FormatID formatID;
        GLuint stride;
        size_t offset;
    };

    struct IndexConversionBuffer : public ConversionBufferMtl
    {
        IndexConversionBuffer(const gl::Context *context,
                              gl::DrawElementsType type,
                              size_t offsetIn);
        gl::DrawElementsType type;
        size_t offset;
    };

    // A cache of converted vertex data.
    std::vector<VertexConversionBuffer> mVertexConversionBuffers;

    std::vector<IndexConversionBuffer> mIndexConversionBuffers;
};

class SimpleWeakBufferHolderMtl : public BufferHolderMtl
{
  public:
    void set(mtl::BufferRef buffer) { mBuffer = buffer; }

    mtl::BufferRef getCurrentBuffer(const gl::Context *context) override { return mBuffer.lock(); }

  private:
    mtl::BufferWeakRef mBuffer;
};

}  // namespace rx

#endif /* LIBANGLE_RENDERER_METAL_BUFFERMTL_H_ */
