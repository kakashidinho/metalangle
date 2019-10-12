
//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "libANGLE/renderer/metal/TextureMtl.h"

#include "common/debug.h"
#include "common/mathutil.h"
#include "libANGLE/renderer/metal/ContextMtl.h"
#include "libANGLE/renderer/metal/FrameBufferMtl.h"
#include "libANGLE/renderer/metal/RendererMtl.h"
#include "libANGLE/renderer/metal/mtl_common.h"
#include "libANGLE/renderer/metal/mtl_format_utils.h"
#include "libANGLE/renderer/metal/mtl_utils.h"
#include "libANGLE/renderer/renderer_utils.h"

namespace rx
{

// TextureMtl implementation
TextureMtl::TextureMtl(const gl::TextureState &state) : TextureImpl(state) {}

TextureMtl::~TextureMtl() = default;

void TextureMtl::onDestroy(const gl::Context *context)
{
    mMetalSamplerState = nil;

    releaseTexture();
}

void TextureMtl::releaseTexture()
{
    mFormat  = mtl::Format();
    mTexture = nullptr;

    mLayeredRenderTargets.clear();
    mLayeredTextureViews.clear();

    mIsPow2 = false;
}

angle::Result TextureMtl::setImage(const gl::Context *context,
                                   const gl::ImageIndex &index,
                                   GLenum internalFormat,
                                   const gl::Extents &size,
                                   GLenum format,
                                   GLenum type,
                                   const gl::PixelUnpackState &unpack,
                                   const uint8_t *pixels)
{
    const gl::InternalFormat &formatInfo = gl::GetInternalFormatInfo(internalFormat, type);

    return setImageImpl(context, index, formatInfo, size, type, unpack, pixels);
}

angle::Result TextureMtl::setSubImage(const gl::Context *context,
                                      const gl::ImageIndex &index,
                                      const gl::Box &area,
                                      GLenum format,
                                      GLenum type,
                                      const gl::PixelUnpackState &unpack,
                                      gl::Buffer *unpackBuffer,
                                      const uint8_t *pixels)
{
    const gl::InternalFormat &formatInfo = gl::GetInternalFormatInfo(format, type);

    return setSubImageImpl(context, index, area, formatInfo, type, unpack, pixels);
}

angle::Result TextureMtl::setCompressedImage(const gl::Context *context,
                                             const gl::ImageIndex &index,
                                             GLenum internalFormat,
                                             const gl::Extents &size,
                                             const gl::PixelUnpackState &unpack,
                                             size_t imageSize,
                                             const uint8_t *pixels)
{
    const gl::InternalFormat &formatInfo = gl::GetSizedInternalFormatInfo(internalFormat);

    return setImageImpl(context, index, formatInfo, size, GL_UNSIGNED_BYTE, unpack, pixels);
}

angle::Result TextureMtl::setCompressedSubImage(const gl::Context *context,
                                                const gl::ImageIndex &index,
                                                const gl::Box &area,
                                                GLenum format,
                                                const gl::PixelUnpackState &unpack,
                                                size_t imageSize,
                                                const uint8_t *pixels)
{

    const gl::InternalFormat &formatInfo = gl::GetInternalFormatInfo(format, GL_UNSIGNED_BYTE);

    return setSubImageImpl(context, index, area, formatInfo, GL_UNSIGNED_BYTE, unpack, pixels);
}

angle::Result TextureMtl::copyImage(const gl::Context *context,
                                    const gl::ImageIndex &index,
                                    const gl::Rectangle &sourceArea,
                                    GLenum internalFormat,
                                    gl::Framebuffer *source)
{
    gl::Extents newImageSize(sourceArea.width, sourceArea.height, 1);
    const gl::InternalFormat &internalFormatInfo =
        gl::GetInternalFormatInfo(internalFormat, GL_UNSIGNED_BYTE);

    mtl::Format mtlFormat(internalFormatInfo);

    ANGLE_TRY(redefineImage(context, index, mtlFormat, newImageSize));

    return copySubImageImpl(context, index, gl::Offset(0, 0, 0), sourceArea, internalFormatInfo,
                            source);
}

angle::Result TextureMtl::copySubImage(const gl::Context *context,
                                       const gl::ImageIndex &index,
                                       const gl::Offset &destOffset,
                                       const gl::Rectangle &sourceArea,
                                       gl::Framebuffer *source)
{
    const gl::InternalFormat &currentFormat = *mState.getImageDesc(index).format.info;
    return copySubImageImpl(context, index, destOffset, sourceArea, currentFormat, source);
}

angle::Result TextureMtl::copyTexture(const gl::Context *context,
                                      const gl::ImageIndex &index,
                                      GLenum internalFormat,
                                      GLenum type,
                                      size_t sourceLevel,
                                      bool unpackFlipY,
                                      bool unpackPremultiplyAlpha,
                                      bool unpackUnmultiplyAlpha,
                                      const gl::Texture *source)
{
    // TODO(hqle)
    UNIMPLEMENTED();

    return angle::Result::Stop;
}

angle::Result TextureMtl::copySubTexture(const gl::Context *context,
                                         const gl::ImageIndex &index,
                                         const gl::Offset &destOffset,
                                         size_t sourceLevel,
                                         const gl::Box &sourceBox,
                                         bool unpackFlipY,
                                         bool unpackPremultiplyAlpha,
                                         bool unpackUnmultiplyAlpha,
                                         const gl::Texture *source)
{
    // TODO(hqle)
    UNIMPLEMENTED();

    return angle::Result::Stop;
}

angle::Result TextureMtl::copyCompressedTexture(const gl::Context *context,
                                                const gl::Texture *source)
{
    // TODO(hqle)
    UNIMPLEMENTED();

    return angle::Result::Stop;
}

angle::Result TextureMtl::setStorage(const gl::Context *context,
                                     gl::TextureType type,
                                     size_t mipmaps,
                                     GLenum internalFormat,
                                     const gl::Extents &size)
{
    const gl::InternalFormat &formatInfo = gl::GetSizedInternalFormatInfo(internalFormat);

    return setStorageImpl(context, type, mipmaps, mtl::Format(formatInfo), size);
}

angle::Result TextureMtl::setStorageExternalMemory(const gl::Context *context,
                                                   gl::TextureType type,
                                                   size_t levels,
                                                   GLenum internalFormat,
                                                   const gl::Extents &size,
                                                   gl::MemoryObject *memoryObject,
                                                   GLuint64 offset)
{
    // TODO(hqle)
    UNIMPLEMENTED();

    return angle::Result::Stop;
}

angle::Result TextureMtl::setStorageMultisample(const gl::Context *context,
                                                gl::TextureType type,
                                                GLsizei samples,
                                                GLint internalformat,
                                                const gl::Extents &size,
                                                bool fixedSampleLocations)
{
    // TODO(hqle)
    UNIMPLEMENTED();

    return angle::Result::Stop;
}

angle::Result TextureMtl::setEGLImageTarget(const gl::Context *context,
                                            gl::TextureType type,
                                            egl::Image *image)
{
    // TODO(hqle)
    UNIMPLEMENTED();

    return angle::Result::Stop;
}

angle::Result TextureMtl::setImageExternal(const gl::Context *context,
                                           gl::TextureType type,
                                           egl::Stream *stream,
                                           const egl::Stream::GLTextureDescription &desc)
{
    UNIMPLEMENTED();
    return angle::Result::Stop;
}

angle::Result TextureMtl::generateMipmap(const gl::Context *context)
{
    ContextMtl *contextMtl = mtl::GetImpl(context);
    if (!mTexture)
    {
        return angle::Result::Continue;
    }

    mtl::BlitCommandEncoder *blitEncoder = contextMtl->getBlitCommandEncoder();

    blitEncoder->generateMipmapsForTexture(mTexture);

    return angle::Result::Continue;
}

angle::Result TextureMtl::setBaseLevel(const gl::Context *context, GLuint baseLevel)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();

    return angle::Result::Stop;
}

angle::Result TextureMtl::bindTexImage(const gl::Context *context, egl::Surface *surface)
{
    // TODO(hqle)
    UNIMPLEMENTED();

    return angle::Result::Stop;
}

angle::Result TextureMtl::releaseTexImage(const gl::Context *context)
{
    // TODO(hqle)
    UNIMPLEMENTED();

    return angle::Result::Stop;
}

angle::Result TextureMtl::getAttachmentRenderTarget(const gl::Context *context,
                                                    GLenum binding,
                                                    const gl::ImageIndex &imageIndex,
                                                    GLsizei samples,
                                                    FramebufferAttachmentRenderTarget **rtOut)
{
    // TODO(hqle): Support MSAA.
    // Non-zero mip level attachments are an ES 3.0 feature.
    ASSERT(imageIndex.getLevelIndex() == 0);

    ContextMtl *contextMtl = mtl::GetImpl(context);
    if (!mTexture)
    {
        ANGLE_MTL_CHECK_WITH_ERR(contextMtl, false, GL_INVALID_OPERATION);
    }

    switch (imageIndex.getType())
    {
        case gl::TextureType::_2D:
            *rtOut = &mLayeredRenderTargets[0];
            break;
        case gl::TextureType::CubeMap:
            *rtOut = &mLayeredRenderTargets[imageIndex.cubeMapFaceIndex()];
            break;
        default:
            UNREACHABLE();
    }

    return angle::Result::Continue;
}

angle::Result TextureMtl::syncState(const gl::Context *context,
                                    const gl::Texture::DirtyBits &dirtyBits)
{
    ContextMtl *contextMtl = mtl::GetImpl(context);

    if (dirtyBits.none() && mMetalSamplerState)
    {
        return angle::Result::Continue;
    }

    RendererMtl *renderer = contextMtl->getRenderer();

    if (dirtyBits.test(gl::Texture::DIRTY_BIT_SWIZZLE_RED) ||
        dirtyBits.test(gl::Texture::DIRTY_BIT_SWIZZLE_GREEN) ||
        dirtyBits.test(gl::Texture::DIRTY_BIT_SWIZZLE_BLUE) ||
        dirtyBits.test(gl::Texture::DIRTY_BIT_SWIZZLE_ALPHA))
    {
        // TODO(hqle): Metal doesn't support swizzle on many devices. Skip for now.
    }

    mMetalSamplerState = renderer->getStateCache().getSamplerState(
        renderer->getMetalDevice(), mtl::SamplerDesc(mState.getSamplerState()));

    return angle::Result::Continue;
}

void TextureMtl::bindVertexShader(const gl::Context *context,
                                  mtl::RenderCommandEncoder *cmdEncoder,
                                  int textureSlotIndex,
                                  int samplerSlotIndex)
{
    // ES 2.0: non power of two texture won't have any mipmap.
    // We don't support OES_texture_npot atm.
    float maxLodClamp = FLT_MAX;
    if (!mIsPow2)
    {
        maxLodClamp = 0;
    }

    cmdEncoder->setVertexTexture(mTexture, textureSlotIndex);
    cmdEncoder->setVertexSamplerState(mMetalSamplerState, 0, maxLodClamp, samplerSlotIndex);
}

void TextureMtl::bindFragmentShader(const gl::Context *context,
                                    mtl::RenderCommandEncoder *cmdEncoder,
                                    int textureSlotIndex,
                                    int samplerSlotIndex)
{
    // ES 2.0: non power of two texture won't have any mipmap.
    // We don't support OES_texture_npot atm.
    float maxLodClamp = FLT_MAX;
    if (!mIsPow2)
    {
        maxLodClamp = 0;
    }

    cmdEncoder->setFragmentTexture(mTexture, textureSlotIndex);
    cmdEncoder->setFragmentSamplerState(mMetalSamplerState, 0, maxLodClamp, samplerSlotIndex);
}

angle::Result TextureMtl::redefineImage(const gl::Context *context,
                                        const gl::ImageIndex &index,
                                        const mtl::Format &mtlFormat,
                                        const gl::Extents &size)
{
    if (mTexture)
    {
        if (mTexture->valid())
        {
            // Calculate the expected size for the index we are defining. If the size is different
            // from the given size, or the format is different, we are redefining the image so we
            // must release it.
            if (mTexture->pixelFormat() != mtlFormat.metalFormat || size != mTexture->size(index) ||
                mTexture->textureType() != mtl::GetTextureType(index.getType()))
            {
                releaseTexture();
            }
        }
    }

    // Early-out on empty textures, don't create a zero-sized storage.
    if (size.empty())
    {
        return angle::Result::Continue;
    }

    if (!mTexture)
    {
        gl::Extents baseSize;
        baseSize.width  = size.width << index.getLevelIndex();
        baseSize.height = size.height << index.getLevelIndex();

        mIsPow2 = gl::isPow2(size.width) && gl::isPow2(size.height);
        // ES 2.0: don't support mip map filtering with non power of two textures
        size_t mipmaps = mIsPow2 ? 0 : 1;

        ANGLE_TRY(setStorageImpl(context, index.getType(), mipmaps, mtlFormat, baseSize));
    }

    return angle::Result::Continue;
}

// If levels = 0, this function will create full mipmaps texture.
angle::Result TextureMtl::setStorageImpl(const gl::Context *context,
                                         gl::TextureType type,
                                         size_t mipmaps,
                                         const mtl::Format &mtlFormat,
                                         const gl::Extents &size)
{
    ContextMtl *contextMtl = mtl::GetImpl(context);

    if (mTexture)
    {
        releaseTexture();
    }

    MTLTextureType mtlType = mtl::GetTextureType(type);

    auto convertedFormat = mtlFormat;
    convertedFormat.convertToCompatibleFormatIfNotSupported(contextMtl->getMetalDevice());

    switch (mtlType)
    {
        case MTLTextureType2D:
            ANGLE_TRY(mtl::Texture::Make2DTexture(
                contextMtl, convertedFormat.metalFormat, size.width, size.height,
                static_cast<uint32_t>(mipmaps), false, &mTexture));

            mLayeredRenderTargets.resize(1);
            mLayeredRenderTargets[0].set(mTexture, 0, 0, mFormat);
            break;
        case MTLTextureTypeCube:
            ANGLE_TRY(mtl::Texture::MakeCubeTexture(contextMtl, convertedFormat.metalFormat,
                                                    size.width, static_cast<uint32_t>(mipmaps),
                                                    false, &mTexture));

            mLayeredRenderTargets.resize(gl::kCubeFaceCount);
            mLayeredTextureViews.resize(gl::kCubeFaceCount);
            for (uint32_t f = 0; f < gl::kCubeFaceCount; ++f)
            {
                mLayeredTextureViews[f] = mTexture->createFaceView(f);
                mLayeredRenderTargets[f].set(mLayeredTextureViews[f], 0, 0, mFormat);
            }
            break;
        default:
        {
            ANGLE_MTL_CHECK_WITH_ERR(contextMtl, false, GL_INVALID_ENUM);
        }
    }

    mFormat                             = convertedFormat;
    MTLColorWriteMask colorWritableMask = MTLColorWriteMaskAll;
    const angle::Format &intendedFormat = angle::Format::Get(mFormat.intendedFormatId);
    bool emulatedAlpha                  = false;
    if (intendedFormat.alphaBits == 0)
    {
        emulatedAlpha = true;
        // Disable alpha write to this texture
        colorWritableMask = colorWritableMask & (~MTLColorWriteMaskAlpha);
    }
    mTexture->setColorWritableMask(colorWritableMask);

    // For emulated alpha texture, we need to initialize its alpha channel to one.
    if (emulatedAlpha)
    {
        int layers = mtlType == MTLTextureTypeCube ? 6 : 1;
        for (int layer = 0; layer < layers; ++layer)
        {
            auto cubeFace = static_cast<gl::TextureTarget>(
                static_cast<int>(gl::TextureTarget::CubeMapPositiveX) + layer);
            for (uint32_t mip = 0; mip < mipmaps; ++mip)
            {
                gl::ImageIndex index;
                if (layers > 1)
                {
                    index = gl::ImageIndex::MakeCubeMapFace(cubeFace, mip);
                }
                else
                {
                    index = gl::ImageIndex::Make2D(mip);
                }

                ANGLE_TRY(mtl::InitializeTextureContents(context, mTexture, mFormat, index));
            }
        }
    }

    return angle::Result::Continue;
}

angle::Result TextureMtl::setImageImpl(const gl::Context *context,
                                       const gl::ImageIndex &index,
                                       const gl::InternalFormat &formatInfo,
                                       const gl::Extents &size,
                                       GLenum type,
                                       const gl::PixelUnpackState &unpack,
                                       const uint8_t *pixels)
{
    mtl::Format mtlFormat(formatInfo);

    ANGLE_TRY(redefineImage(context, index, mtlFormat, size));

    // Early-out on empty textures, don't create a zero-sized storage.
    if (size.empty())
    {
        return angle::Result::Continue;
    }

    return setSubImageImpl(context, index, gl::Box(0, 0, 0, size.width, size.height, size.depth),
                           formatInfo, type, unpack, pixels);
}

angle::Result TextureMtl::setSubImageImpl(const gl::Context *context,
                                          const gl::ImageIndex &index,
                                          const gl::Box &area,
                                          const gl::InternalFormat &formatInfo,
                                          GLenum type,
                                          const gl::PixelUnpackState &unpack,
                                          const uint8_t *pixels)
{
    if (!pixels)
    {
        return angle::Result::Continue;
    }
    ASSERT(mTexture && mTexture->valid());
    ASSERT(unpack.skipRows == 0 && unpack.skipPixels == 0 && unpack.skipImages == 0);

    ContextMtl *contextMtl = mtl::GetImpl(context);

    mtl::Format mtlFormat(formatInfo);

    if (mFormat.metalFormat != mtlFormat.metalFormat)
    {
        ANGLE_MTL_CHECK_WITH_ERR(contextMtl, false, GL_INVALID_OPERATION);
    }

    GLuint sourceRowPitch = 0;
    ANGLE_CHECK_GL_MATH(contextMtl, formatInfo.computeRowPitch(type, area.width, unpack.alignment,
                                                               unpack.rowLength, &sourceRowPitch));
    // Check if partial image update is supported for this format
    if (!formatInfo.supportSubImage())
    {
        // area must be the whole mip level
        sourceRowPitch   = 0;
        gl::Extents size = mTexture->size(index);
        if (area.x != 0 || area.y != 0 || area.width != size.width || area.height != size.height)
        {
            ANGLE_MTL_CHECK_WITH_ERR(contextMtl, false, GL_INVALID_OPERATION);
        }
    }

    // Only 2D/cube texture is supported atm
    auto mtlRegion = MTLRegionMake2D(area.x, area.y, area.width, area.height);

    const angle::Format &srcAngleFormat =
        angle::Format::Get(angle::Format::InternalFormatToID(formatInfo.sizedInternalFormat));

    // If source pixels are luminance or RGB8, we need to convert them to RGBA
    if (mFormat.actualFormatId != srcAngleFormat.id)
    {
        return convertAndSetSubImage(context, index, mtlRegion, formatInfo, srcAngleFormat,
                                     sourceRowPitch, pixels);
    }

    // Upload to texture
    mTexture->replaceRegion(contextMtl, mtlRegion, index.getLevelIndex(),
                            index.hasLayer() ? index.cubeMapFaceIndex() : 0, pixels,
                            sourceRowPitch);

    return angle::Result::Continue;
}

angle::Result TextureMtl::convertAndSetSubImage(const gl::Context *context,
                                                const gl::ImageIndex &index,
                                                const MTLRegion &mtlArea,
                                                const gl::InternalFormat &internalFormat,
                                                const angle::Format &pixelsFormat,
                                                size_t pixelsRowPitch,
                                                const uint8_t *pixels)
{
    ASSERT(mTexture && mTexture->valid());
    ASSERT(mTexture->textureType() == MTLTextureType2D ||
           mTexture->textureType() == MTLTextureTypeCube);

    ContextMtl *contextMtl = mtl::GetImpl(context);

    // Create scratch buffer
    const angle::Format &dstFormat = angle::Format::Get(mFormat.actualFormatId);
    uint8_t *conversionRow;
    const size_t dstRowPitch = dstFormat.pixelBytes * mtlArea.size.width;
    ANGLE_CHECK_GL_ALLOC(contextMtl,
                         (conversionRow = new (std::nothrow) uint8_t[dstRowPitch]) != nullptr);

    MTLRegion mtlRow    = mtlArea;
    mtlRow.size.height  = 1;
    const uint8_t *psrc = pixels;
    for (NSUInteger r = 0; r < mtlArea.size.height; ++r, psrc += pixelsRowPitch)
    {
        mtlRow.origin.y = mtlArea.origin.y + r;

        // Convert pixels
        CopyImageCHROMIUM(psrc, pixelsRowPitch, pixelsFormat.pixelBytes, 0,
                          pixelsFormat.pixelReadFunction, conversionRow, dstRowPitch,
                          dstFormat.pixelBytes, 0, dstFormat.pixelWriteFunction,
                          internalFormat.format, dstFormat.componentType, mtlRow.size.width, 1, 1,
                          false, false, false);

        // Upload to texture
        mTexture->replaceRegion(contextMtl, mtlRow, index.getLevelIndex(),
                                index.hasLayer() ? index.cubeMapFaceIndex() : 0, conversionRow,
                                dstRowPitch);
    }

    delete[] conversionRow;

    return angle::Result::Continue;
}

angle::Result TextureMtl::initializeContents(const gl::Context *context,
                                             const gl::ImageIndex &imageIndex)
{
    return mtl::InitializeTextureContents(context, mTexture, mFormat, imageIndex);
}

angle::Result TextureMtl::copySubImageImpl(const gl::Context *context,
                                           const gl::ImageIndex &index,
                                           const gl::Offset &destOffset,
                                           const gl::Rectangle &sourceArea,
                                           const gl::InternalFormat &internalFormat,
                                           gl::Framebuffer *source)
{
    ASSERT(mTexture && mTexture->valid());

    gl::Extents fbSize = source->getReadColorAttachment()->getSize();
    gl::Rectangle clippedSourceArea;
    if (!ClipRectangle(sourceArea, gl::Rectangle(0, 0, fbSize.width, fbSize.height),
                       &clippedSourceArea))
    {
        return angle::Result::Continue;
    }

    // If negative offsets are given, clippedSourceArea ensures we don't read from those offsets.
    // However, that changes the sourceOffset->destOffset mapping.  Here, destOffset is shifted by
    // the same amount as clipped to correct the error.
    const gl::Offset modifiedDestOffset(destOffset.x + clippedSourceArea.x - sourceArea.x,
                                        destOffset.y + clippedSourceArea.y - sourceArea.y, 0);

    if (!mtl::Format::FormatRenderable(mFormat.metalFormat))
    {
        return copySubImageCPU(context, index, modifiedDestOffset, clippedSourceArea,
                               internalFormat, source);
    }

    // TODO(hqle): Use compute shader.
    return copySubImageWithDraw(context, index, modifiedDestOffset, clippedSourceArea,
                                internalFormat, source);
}

angle::Result TextureMtl::copySubImageWithDraw(const gl::Context *context,
                                               const gl::ImageIndex &index,
                                               const gl::Offset &modifiedDestOffset,
                                               const gl::Rectangle &clippedSourceArea,
                                               const gl::InternalFormat &internalFormat,
                                               gl::Framebuffer *source)
{
    ContextMtl *contextMtl         = mtl::GetImpl(context);
    RendererMtl *rendererMtl       = contextMtl->getRenderer();
    FramebufferMtl *framebufferMtl = mtl::GetImpl(source);

    RenderTargetMtl *colorReadRT = framebufferMtl->getColorReadRenderTarget();

    if (!colorReadRT || !colorReadRT->getTexture())
    {
        // Is this an error?
        return angle::Result::Continue;
    }

    const gl::InternalFormat &intendedInternalFormat = *mState.getImageDesc(index).format.info;
    mtl::RenderCommandEncoder *cmdEncoder = contextMtl->getRenderCommandEncoder(mTexture, index);
    UtilsMtl::BlitParams blitParams;

    blitParams.dstOffset    = modifiedDestOffset;
    blitParams.dstColorMask = mTexture->getColorWritableMask();

    blitParams.src          = colorReadRT->getTexture();
    blitParams.srcRect      = clippedSourceArea;
    blitParams.srcYFlipped  = framebufferMtl->flipY();
    blitParams.dstLuminance = intendedInternalFormat.isLUMA();

    rendererMtl->getUtils().blitWithDraw(context, cmdEncoder, blitParams);

    return angle::Result::Continue;
}

angle::Result TextureMtl::copySubImageCPU(const gl::Context *context,
                                          const gl::ImageIndex &index,
                                          const gl::Offset &modifiedDestOffset,
                                          const gl::Rectangle &clippedSourceArea,
                                          const gl::InternalFormat &internalFormat,
                                          gl::Framebuffer *source)
{
    ContextMtl *contextMtl         = mtl::GetImpl(context);
    FramebufferMtl *framebufferMtl = mtl::GetImpl(source);

    const angle::Format &dstFormat = angle::Format::Get(mFormat.actualFormatId);
    const int dstRowPitch          = dstFormat.pixelBytes * clippedSourceArea.width;
    std::unique_ptr<uint8_t[]> conversionRow(new (std::nothrow) uint8_t[dstRowPitch]);
    ANGLE_CHECK_GL_ALLOC(contextMtl, conversionRow);

    MTLRegion mtlDstRowArea  = MTLRegionMake2D(clippedSourceArea.x, 0, clippedSourceArea.width, 1);
    gl::Rectangle srcRowArea = gl::Rectangle(clippedSourceArea.x, 0, clippedSourceArea.width, 1);

    for (int r = 0; r < clippedSourceArea.height; ++r)
    {
        mtlDstRowArea.origin.y = modifiedDestOffset.y + r;
        srcRowArea.y           = clippedSourceArea.y + r;

        PackPixelsParams packParams(srcRowArea, dstFormat, dstRowPitch, false, nullptr, 0);

        // Read pixels from framebuffer to memory:
        ANGLE_TRY(framebufferMtl->readPixelsImpl(context, srcRowArea, packParams,
                                                 framebufferMtl->getColorReadRenderTarget(),
                                                 conversionRow.get()));

        // Upload to texture
        mTexture->replaceRegion(contextMtl, mtlDstRowArea, index.getLevelIndex(),
                                index.hasLayer() ? index.cubeMapFaceIndex() : 0,
                                conversionRow.get(), dstRowPitch);
    }

    return angle::Result::Continue;
}
}
