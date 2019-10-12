//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// mtl_resources.mm:
//    Implements wrapper classes for Metal's MTLTexture and MTLBuffer.
//

#include "libANGLE/renderer/metal/mtl_resources.h"

#include <TargetConditionals.h>

#include <algorithm>

#include "common/debug.h"
#include "libANGLE/renderer/metal/ContextMtl.h"
#include "libANGLE/renderer/metal/mtl_command_buffer.h"
#include "libANGLE/renderer/metal/mtl_format_utils.h"

#define MIP_SIZE(baseSize, level) std::max<NSUInteger>(1, baseSize >> level)

namespace rx
{
namespace mtl
{

// Resource implementation
Resource::Resource() : mRef(std::make_shared<Ref>()) {}

// Share the GPU usage ref with other resource
Resource::Resource(Resource *other) : mRef(other->mRef)
{
    ASSERT(mRef);
}

bool Resource::isBeingUsedByGPU(Context *context) const
{
    return context->cmdQueue().isResourceBeingUsedByGPU(this);
}

void Resource::setUsedByCommandBufferWithQueueSerial(uint64_t serial, bool writing)
{
    auto curSerial = mRef->mCmdBufferQueueSerial.load(std::memory_order_relaxed);
    do
    {
        if (curSerial >= serial)
        {
            return;
        }
    } while (!mRef->mCmdBufferQueueSerial.compare_exchange_weak(
        curSerial, serial, std::memory_order_release, std::memory_order_relaxed));

    // TODO(hqle): This is not thread safe, if multiple command buffers on multiple threads
    // are writing to it.
    if (writing)
    {
        mRef->mCPUReadMemDirty = true;
    }
}

// Texture implemenetation
/** static */
angle::Result Texture::Make2DTexture(ContextMtl *context,
                                     MTLPixelFormat format,
                                     uint32_t width,
                                     uint32_t height,
                                     uint32_t mips,
                                     bool renderTargetOnly,
                                     TextureRef *refOut)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        MTLTextureDescriptor *desc =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format
                                                               width:width
                                                              height:height
                                                           mipmapped:mips == 0 || mips > 1];

        refOut->reset(new Texture(context, desc, mips, renderTargetOnly, false));
    }  // ANGLE_MTL_OBJC_SCOPE

    if (!refOut || !refOut->get())
    {
        ANGLE_MTL_CHECK(context, false, GL_OUT_OF_MEMORY);
    }

    return angle::Result::Continue;
}

/** static */
angle::Result Texture::MakeCubeTexture(ContextMtl *context,
                                       MTLPixelFormat format,
                                       uint32_t size,
                                       uint32_t mips,
                                       bool renderTargetOnly,
                                       TextureRef *refOut)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        MTLTextureDescriptor *desc =
            [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:format
                                                                  size:size
                                                             mipmapped:mips == 0 || mips > 1];

        refOut->reset(new Texture(context, desc, mips, renderTargetOnly, true));
    }  // ANGLE_MTL_OBJC_SCOPE

    if (!refOut || !refOut->get())
    {
        ANGLE_MTL_CHECK(context, false, GL_OUT_OF_MEMORY);
    }

    return angle::Result::Continue;
}

/** static */
TextureRef Texture::MakeFromMetal(id<MTLTexture> metalTexture)
{
    ANGLE_MTL_OBJC_SCOPE { return TextureRef(new Texture(metalTexture)); }
}

Texture::Texture(id<MTLTexture> metalTexture)
{
    set(metalTexture);
}

Texture::Texture(ContextMtl *context,
                 MTLTextureDescriptor *desc,
                 uint32_t mips,
                 bool renderTargetOnly,
                 bool supportTextureView)
{
    id<MTLDevice> metalDevice = context->getMetalDevice();

    if (mips > 1 && mips < desc.mipmapLevelCount)
    {
        desc.mipmapLevelCount = mips;
    }

    // Every texture will support being rendered for now
    desc.usage = 0;

    if (Format::FormatRenderable(desc.pixelFormat))
    {
        desc.usage |= MTLTextureUsageRenderTarget;
    }

    if (!Format::FormatCPUReadable(desc.pixelFormat))
    {
        desc.resourceOptions = MTLResourceStorageModePrivate;
    }

    if (!renderTargetOnly)
    {
        desc.usage = desc.usage | MTLTextureUsageShaderRead;
    }

    if (supportTextureView)
    {
        desc.usage = desc.usage | MTLTextureUsagePixelFormatView;
    }

    set([metalDevice newTextureWithDescriptor:desc]);
}

Texture::Texture(Texture *original, MTLTextureType type, NSRange mipmapLevelRange, uint32_t slice)
    : Resource(original)
{
    auto view = [original->get() newTextureViewWithPixelFormat:original->pixelFormat()
                                                   textureType:type
                                                        levels:mipmapLevelRange
                                                        slices:NSMakeRange(slice, 1)];

    set(view);
}

void Texture::replaceRegion(ContextMtl *context,
                            MTLRegion region,
                            uint32_t mipmapLevel,
                            uint32_t slice,
                            const uint8_t *data,
                            size_t bytesPerRow)
{
    CommandQueue &cmdQueue = context->cmdQueue();

    // TODO(hqle): what if multiple contexts on multiple threads are using this texture?
    if (this->isBeingUsedByGPU(context))
    {
        context->flushCommandBufer();
    }

    cmdQueue.ensureResourceReadyForCPU(this);

    [get() replaceRegion:region
             mipmapLevel:mipmapLevel
                   slice:slice
               withBytes:data
             bytesPerRow:bytesPerRow
           bytesPerImage:0];
}

void Texture::getBytes(ContextMtl *context,
                       size_t bytesPerRow,
                       MTLRegion region,
                       uint32_t mipmapLevel,
                       uint8_t *dataOut)
{
    CommandQueue &cmdQueue = context->cmdQueue();

    // TODO(hqle): what if multiple contexts on multiple threads are using this texture?
    if (this->isBeingUsedByGPU(context))
    {
        context->flushCommandBufer();
    }

    cmdQueue.ensureResourceReadyForCPU(this);

    [get() getBytes:dataOut bytesPerRow:bytesPerRow fromRegion:region mipmapLevel:mipmapLevel];
}

TextureRef Texture::createFaceView(uint32_t face)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        switch (textureType())
        {
            case MTLTextureTypeCube:
                return TextureRef(
                    new Texture(this, MTLTextureType2D, NSMakeRange(0, mipmapLevels()), face));
            default:
                return nullptr;
        }
    }
}

MTLPixelFormat Texture::pixelFormat() const
{
    return get().pixelFormat;
}

MTLTextureType Texture::textureType() const
{
    return get().textureType;
}

uint32_t Texture::mipmapLevels() const
{
    return static_cast<uint32_t>(get().mipmapLevelCount);
}

uint32_t Texture::width(uint32_t level) const
{
    return static_cast<uint32_t>(MIP_SIZE(get().width, level));
}

uint32_t Texture::height(uint32_t level) const
{
    return static_cast<uint32_t>(MIP_SIZE(get().height, level));
}

gl::Extents Texture::size(uint32_t level) const
{
    gl::Extents re;

    re.width  = width(level);
    re.height = height(level);
    re.depth  = static_cast<uint32_t>(MIP_SIZE(get().depth, level));

    return re;
}

gl::Extents Texture::size(const gl::ImageIndex &index) const
{
    // Only support these texture types for now
    ASSERT(!get() || textureType() == MTLTextureType2D || textureType() == MTLTextureTypeCube);

    return size(index.getLevelIndex());
}

void Texture::set(id<MTLTexture> metalTexture)
{
    ParentClass::set(metalTexture);
}

// Buffer implementation
angle::Result Buffer::MakeBuffer(ContextMtl *context,
                                 size_t size,
                                 const uint8_t *data,
                                 BufferRef *bufferOut)
{
    bufferOut->reset(new Buffer(context, size, data));

    if (!bufferOut || !bufferOut->get())
    {
        ANGLE_MTL_CHECK(context, false, GL_OUT_OF_MEMORY);
    }

    return angle::Result::Continue;
}

Buffer::Buffer(ContextMtl *context, size_t size, const uint8_t *data)
{
    (void)reset(context, size, data);
}

angle::Result Buffer::reset(ContextMtl *context, size_t size, const uint8_t *data)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        MTLResourceOptions options;

        id<MTLBuffer> newBuffer;
        id<MTLDevice> metalDevice = context->getMetalDevice();

        options = 0;

        if (data)
        {
            newBuffer = [metalDevice newBufferWithBytes:data length:size options:options];
        }
        else
        {
            newBuffer = [metalDevice newBufferWithLength:size options:options];
        }

        set(newBuffer);

        return angle::Result::Continue;
    }
}

uint8_t *Buffer::map(ContextMtl *context)
{
    CommandQueue &cmdQueue = context->cmdQueue();

    // TODO(hqle): what if multiple contexts on multiple threads are using this buffer?
    if (this->isBeingUsedByGPU(context))
    {
        context->flushCommandBufer();
    }

    // TODO(hqle): currently not support reading data written by GPU
    cmdQueue.ensureResourceReadyForCPU(this);

    return reinterpret_cast<uint8_t *>([get() contents]);
}

void Buffer::unmap(ContextMtl *context) {}

size_t Buffer::size() const
{
    return get().length;
}
}
}
