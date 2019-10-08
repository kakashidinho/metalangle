//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#ifndef LIBANGLE_RENDERER_METAL_MTL_RESOURCES_H_
#define LIBANGLE_RENDERER_METAL_MTL_RESOURCES_H_

#include "libANGLE/renderer/metal/Metal_platform.h"

#include <atomic>
#include <memory>

#include "common/FastVector.h"
#include "common/MemoryBuffer.h"
#include "common/angleutils.h"
#include "libANGLE/Error.h"
#include "libANGLE/ImageIndex.h"
#include "libANGLE/angletypes.h"
#include "libANGLE/renderer/metal/mtl_common.h"

namespace rx
{

class ContextMtl;

namespace mtl
{

class CommandQueue;
class Resource;
class Texture;
class Buffer;

typedef std::shared_ptr<Resource> ResourceRef;
typedef std::shared_ptr<Texture> TextureRef;
typedef std::weak_ptr<Texture> TextureWeakRef;
typedef std::shared_ptr<Buffer> BufferRef;
typedef std::weak_ptr<Buffer> BufferWeakRef;

class Resource : angle::NonCopyable
{
  public:
    virtual ~Resource() {}

    bool isBeingUsedByGPU(Context *context) const;

    void setUsedByCommandBufferWithQueueSerial(uint64_t serial, bool writing);

    const std::atomic<uint64_t> &getCommandBufferQueueSerial() const
    {
        return mRef->mCmdBufferQueueSerial;
    }

    // Flag indicate whether we should synchornize the content to CPU after GPU changed this
    // resource's content.
    bool isCPUReadMemDirty() const { return mRef->mCPUReadMemDirty; }
    void resetCPUReadMemDirty() { mRef->mCPUReadMemDirty = false; }

  protected:
    Resource();
    // Share the GPU usage ref with other resource
    Resource(Resource *other);

  private:
    struct Ref
    {
        // The command buffer's writing ref count
        std::atomic<uint64_t> mCmdBufferQueueSerial{0};

        // TODO(hqle): resource dirty handle is not threadsafe.
        bool mCPUReadMemDirty = false;
    };

    std::shared_ptr<Ref> mRef;
};

class Texture final : public Resource, public WrappedObject<id<MTLTexture>>
{
  public:
    static angle::Result Make2DTexture(ContextMtl *context,
                                       MTLPixelFormat format,
                                       uint32_t width,
                                       uint32_t height,
                                       uint32_t mips /** use zero to create full mipmaps chain */,
                                       bool renderTargetOnly,
                                       TextureRef *refOut);

    static angle::Result MakeCubeTexture(ContextMtl *context,
                                         MTLPixelFormat format,
                                         uint32_t size,
                                         uint32_t mips /** use zero to create full mipmaps chain */,
                                         bool renderTargetOnly,
                                         TextureRef *refOut);

    static TextureRef MakeFromMetal(id<MTLTexture> metalTexture);

    void replaceRegion(ContextMtl *context,
                       MTLRegion region,
                       uint32_t mipmapLevel,
                       uint32_t slice,
                       const uint8_t *data,
                       size_t bytesPerRow);

    // read pixel data from slice 0
    void getBytes(ContextMtl *context,
                  size_t bytesPerRow,
                  MTLRegion region,
                  uint32_t mipmapLevel,
                  uint8_t *dataOut);

    // Create 2d view of a cube face
    TextureRef createFaceView(uint32_t face);

    MTLTextureType textureType() const;
    MTLPixelFormat pixelFormat() const;

    uint32_t mipmapLevels() const;

    uint32_t width(uint32_t level = 0) const;
    uint32_t height(uint32_t level = 0) const;

    gl::Extents size(uint32_t level = 0) const;
    gl::Extents size(const gl::ImageIndex &index) const;

    // For render target
    MTLColorWriteMask getColorWritableMask() const { return mColorWritableMask; }
    void setColorWritableMask(MTLColorWriteMask mask) { mColorWritableMask = mask; }

    // Change the wrapped metal object. Special case for swapchain image
    void set(id<MTLTexture> metalTexture);

  private:
    typedef WrappedObject<id<MTLTexture>> ParentClass;

    Texture(id<MTLTexture> metalTexture);
    Texture(ContextMtl *context,
            MTLTextureDescriptor *desc,
            uint32_t mips,
            bool renderTargetOnly,
            bool supportTextureView);

    // Create a texture view
    Texture(Texture *original, MTLTextureType type, NSRange mipmapLevelRange, uint32_t slice);

    MTLColorWriteMask mColorWritableMask = MTLColorWriteMaskAll;
};

class Buffer final : public Resource, public WrappedObject<id<MTLBuffer>>
{
  public:
    static angle::Result MakeBuffer(ContextMtl *context,
                                    size_t size,
                                    const uint8_t *data,
                                    BufferRef *bufferOut);

    angle::Result reset(ContextMtl *context, size_t size, const uint8_t *data);

    uint8_t *map(ContextMtl *context);
    void unmap(ContextMtl *context);

    size_t size() const;

  private:
    Buffer(ContextMtl *context, size_t size, const uint8_t *data);
};

// This buffer allow the content to be updated n times within single
// command buffer usage without flushing it. Where n=internal queue size.
class StreamBuffer final : angle::NonCopyable
{
  public:
    StreamBuffer(bool allocateShadowBuffer);
    ~StreamBuffer();

    angle::Result initialize(ContextMtl *context,
                             size_t bufferSize,
                             size_t queueSize    = 2,
                             const uint8_t *data = nullptr);
    void destroy();

    bool valid() const { return mValid; }
    size_t size() const { return mBufferSize; }

    // Returns pointer to client side shadow buffer. Call commit() to submit the data
    // modified in this buffer to GPU buffer
    uint8_t *data();
    const uint8_t *data() const;
    // After finish, a ready to be used buffer is returned with most up to date
    // data from shadow buffer
    BufferRef commit(ContextMtl *context);
    // Instead of commiting data from shadow buffer, commit provided data in argument
    BufferRef commit(ContextMtl *context, const uint8_t *data);

    BufferRef getCurrentBuffer(ContextMtl *context);

  private:
    angle::Result initializeImpl(ContextMtl *context,
                                 size_t bufferSize,
                                 size_t queueSize,
                                 const uint8_t *data);

    BufferRef prepareBuffer(ContextMtl *context);

    angle::FastVector<BufferRef, 2> mBuffersQueue;
    // Client side shadow buffer
    angle::MemoryBuffer mShadowCopy;
    size_t mBufferSize       = 0;
    size_t mCurrentBufferIdx = 0;
    bool mUseShadowCopy;
    bool mValid = false;
};

}  // namespace mtl
}  // namespace rx

#endif /* LIBANGLE_RENDERER_METAL_MTL_RESOURCES_H_ */
