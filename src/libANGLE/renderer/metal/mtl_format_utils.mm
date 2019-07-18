//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "libANGLE/renderer/metal/mtl_format_utils.h"

#include "common/debug.h"
#include "libANGLE/renderer/Format.h"
#include "libANGLE/renderer/metal/ContextMtl.h"

namespace rx
{
namespace mtl
{

namespace
{

bool OverrideTextureCaps(const ContextMtl *context, angle::FormatID formatId, gl::TextureCaps *caps)
{
    // TODO(hqle): Auto generate this?
    switch (formatId)
    {
        case angle::FormatID::R8G8_UNORM:
        case angle::FormatID::R8G8B8_UNORM:
        case angle::FormatID::R8G8B8_UNORM_SRGB:
        case angle::FormatID::R8G8B8A8_UNORM:
        case angle::FormatID::R8G8B8A8_UNORM_SRGB:
        case angle::FormatID::B8G8R8A8_UNORM:
        case angle::FormatID::B8G8R8A8_UNORM_SRGB:
            caps->texturable = caps->filterable = caps->textureAttachment = caps->renderbuffer =
                true;
            return true;
        default:
            // TODO(hqle): Handle more cases
            return false;
    }
}

}  // namespace

// Format implementation
/** static */
bool Format::FormatRenderable(MTLPixelFormat format)
{
    switch (format)
    {
        case MTLPixelFormatR8Unorm:
        case MTLPixelFormatRG8Unorm:
        case MTLPixelFormatR16Float:
        case MTLPixelFormatRG16Float:
        case MTLPixelFormatRGBA16Float:
        case MTLPixelFormatR32Float:
        case MTLPixelFormatRG32Float:
        case MTLPixelFormatRGBA32Float:
        case MTLPixelFormatBGRA8Unorm:
        case MTLPixelFormatBGRA8Unorm_sRGB:
        case MTLPixelFormatRGBA8Unorm:
        case MTLPixelFormatRGBA8Unorm_sRGB:
        case MTLPixelFormatDepth32Float:
        case MTLPixelFormatStencil8:
        case MTLPixelFormatDepth32Float_Stencil8:
#if TARGET_OS_OSX
        case MTLPixelFormatDepth16Unorm:
        case MTLPixelFormatDepth24Unorm_Stencil8:
#else
        case MTLPixelFormatR8Unorm_sRGB:
        case MTLPixelFormatRG8Unorm_sRGB:
        case MTLPixelFormatB5G6R5Unorm:
        case MTLPixelFormatA1BGR5Unorm:
        case MTLPixelFormatABGR4Unorm:
        case MTLPixelFormatBGR5A1Unorm:
#endif
            // TODO(hqle): we may add more formats support here in future.
            return true;
        default:
            return false;
    }
    return false;
}

/** static */
bool Format::FormatCPUReadable(MTLPixelFormat format)
{
    switch (format)
    {
        case MTLPixelFormatDepth32Float:
        case MTLPixelFormatStencil8:
        case MTLPixelFormatDepth32Float_Stencil8:
#if TARGET_OS_OSX
        case MTLPixelFormatDepth16Unorm:
        case MTLPixelFormatDepth24Unorm_Stencil8:
#endif
            // TODO(hqle): we may add more formats support here in future.
            return false;
        default:
            return true;
    }
}

/** static */
void Format::GenerateTextureCapsMap(const ContextMtl *context,
                                    gl::TextureCapsMap *capsMapOut,
                                    std::vector<GLenum> *compressedFormatsOut)
{
    auto &textureCapsMap    = *capsMapOut;
    auto &compressedFormats = *compressedFormatsOut;

    compressedFormats.clear();

    // Metal doesn't have programmatical way to determine texture format support.
    // What is available is the online documents from Apple. What we can do here
    // is manually set certain extension flag to true then let angle decide the supported formats.
    gl::Extensions tmpTextureExtensions;

#if TARGET_OS_OSX
    // https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf
    // Requires depth24Stencil8PixelFormatSupported=YES for these extensions
    bool packedDepthStencil24Support =
        context->getMetalDevice().depth24Stencil8PixelFormatSupported;
    tmpTextureExtensions.packedDepthStencil         = true;  // We support this reguardless
    tmpTextureExtensions.colorBufferHalfFloat       = packedDepthStencil24Support;
    tmpTextureExtensions.colorBufferFloat           = packedDepthStencil24Support;
    tmpTextureExtensions.colorBufferFloatRGB        = packedDepthStencil24Support;
    tmpTextureExtensions.colorBufferFloatRGBA       = packedDepthStencil24Support;
    tmpTextureExtensions.textureHalfFloat           = packedDepthStencil24Support;
    tmpTextureExtensions.textureFloat               = packedDepthStencil24Support;
    tmpTextureExtensions.textureHalfFloatLinear     = packedDepthStencil24Support;
    tmpTextureExtensions.textureFloatLinear         = packedDepthStencil24Support;
    tmpTextureExtensions.textureRG                  = packedDepthStencil24Support;
    tmpTextureExtensions.textureCompressionDXT1     = true;
    tmpTextureExtensions.textureCompressionDXT3     = true;
    tmpTextureExtensions.textureCompressionDXT5     = true;
    tmpTextureExtensions.textureCompressionS3TCsRGB = true;
#else
    tmpTextureExtensions.packedDepthStencil = true;  // override to D32_FLOAT_S8X24_UINT
    tmpTextureExtensions.colorBufferHalfFloat = true;
    tmpTextureExtensions.colorBufferFloat = true;
    tmpTextureExtensions.colorBufferFloatRGB = true;
    tmpTextureExtensions.colorBufferFloatRGBA = true;
    tmpTextureExtensions.textureHalfFloat = true;
    tmpTextureExtensions.textureHalfFloatLinear = true;
    tmpTextureExtensions.textureFloat = true;
    tmpTextureExtensions.textureRG = true;
    if ([context->getMetalDevice() supportsFeatureSet:MTLFeatureSet_iOS_GPUFamily1_v1])
    {
        tmpTextureExtensions.compressedETC1RGB8Texture = true;
        tmpTextureExtensions.compressedETC2RGB8Texture = true;
        tmpTextureExtensions.compressedETC2sRGB8Texture = true;
        tmpTextureExtensions.compressedETC2RGBA8Texture = true;
        tmpTextureExtensions.compressedETC2sRGB8Alpha8Texture = true;
        tmpTextureExtensions.compressedEACR11UnsignedTexture = true;
        tmpTextureExtensions.compressedEACR11SignedTexture = true;
        tmpTextureExtensions.compressedEACRG11UnsignedTexture = true;
        tmpTextureExtensions.compressedEACRG11SignedTexture = true;
        tmpTextureExtensions.compressedTexturePVRTC = true;
        tmpTextureExtensions.compressedTexturePVRTCsRGB = true;
    }
#endif
    tmpTextureExtensions.sRGB                  = true;
    tmpTextureExtensions.depth32               = true;
    tmpTextureExtensions.depth24OES            = true;
    tmpTextureExtensions.rgb8rgba8             = true;
    tmpTextureExtensions.textureFormatBGRA8888 = true;
    tmpTextureExtensions.textureStorage        = true;

    auto formatVerifier = [&](const gl::InternalFormat &internalFormatInfo) {
        mtl::Format mtlFormat(internalFormatInfo);

        if (!mtlFormat.valid())
        {
            return;
        }

        const angle::Format &intendedAngleFormat = mtlFormat.intendedAngleFormat();
        gl::TextureCaps textureCaps;

        const auto &clientVersion = kMaxSupportedGLVersion;

        // First let check whether we can determine programmatically.
        if (!OverrideTextureCaps(context, mtlFormat.intendedFormatId, &textureCaps))
        {
            // Let angle decide based on extensions we enabled above.
            textureCaps = gl::GenerateMinimumTextureCaps(internalFormatInfo.sizedInternalFormat,
                                                         clientVersion, tmpTextureExtensions);
        }

        // TODO(hqle): Support MSAA.
        textureCaps.sampleCounts.clear();
        textureCaps.sampleCounts.insert(0);
        textureCaps.sampleCounts.insert(1);

        if (textureCaps.filterable && mtlFormat.actualFormatId == angle::FormatID::D32_FLOAT)
        {
            // Only MacOS support filterable for D32_FLOAT texture
#if !TARGET_OS_OSX
            textureCaps.filterable = false;
#endif
        }

        textureCapsMap.set(mtlFormat.intendedFormatId, textureCaps);

        if (intendedAngleFormat.isBlock)
        {
            compressedFormats.push_back(intendedAngleFormat.glInternalFormat);
        }

        // Verify implementation mismatch
        ASSERT(!textureCaps.renderbuffer || mtl::Format::FormatRenderable(mtlFormat.metalFormat));
        ASSERT(!textureCaps.textureAttachment ||
               mtl::Format::FormatRenderable(mtlFormat.metalFormat));
    };

    // Texture caps map.
    const gl::FormatSet &internalFormats = gl::GetAllSizedInternalFormats();
    for (const auto internalFormat : internalFormats)
    {
        const gl::InternalFormat &internalFormatInfo =
            gl::GetSizedInternalFormatInfo(internalFormat);

        formatVerifier(internalFormatInfo);
    }
}

// FormatBase implementation
const angle::Format &FormatBase::actualAngleFormat() const
{
    return angle::Format::Get(actualFormatId);
}

const angle::Format &FormatBase::intendedAngleFormat() const
{
    return angle::Format::Get(intendedFormatId);
}

// Format implementation
Format::Format() {}

Format::Format(const gl::InternalFormat &internalFormat)
{
    init(internalFormat);
}

Format::Format(angle::FormatID angleFormatId)
{
    // auto generated function
    init(angleFormatId);
}

void Format::init(GLenum sizedInternalFormat)
{
    const auto &internalFormat = gl::GetSizedInternalFormatInfo(sizedInternalFormat);
    init(internalFormat);
}

void Format::init(const gl::InternalFormat &internalFormat)
{
    angle::FormatID formatId =
        angle::Format::InternalFormatToID(internalFormat.sizedInternalFormat);

    // auto generated function
    init(formatId);
}

void Format::initAndConvertToCompatibleFormatIfNotSupported(id<MTLDevice> metalDevice,
                                                            GLenum sizedInternalFormat)
{
    init(sizedInternalFormat);
    convertToCompatibleFormatIfNotSupported(metalDevice);
}

void Format::initAndConvertToCompatibleFormatIfNotSupported(
    id<MTLDevice> metalDevice,
    const gl::InternalFormat &internalFormat)
{
    init(internalFormat);
    convertToCompatibleFormatIfNotSupported(metalDevice);
}

void Format::initAndConvertToCompatibleFormatIfNotSupported(id<MTLDevice> metalDevice,
                                                            angle::FormatID intendedFormatId)
{
    init(intendedFormatId);
    convertToCompatibleFormatIfNotSupported(metalDevice);
}

void Format::convertToCompatibleFormatIfNotSupported(id<MTLDevice> metalDevice)
{
    if (!valid())
    {
        return;
    }
#if TARGET_OS_OSX
    // Fallback format
    if (actualFormatId == angle::FormatID::D24_UNORM_S8_UINT &&
        !metalDevice.depth24Stencil8PixelFormatSupported)
    {
        init(angle::FormatID::D32_FLOAT_S8X24_UINT);
    }
#else
    (void)metalDevice;
#endif
}

const gl::InternalFormat &Format::intendedInternalFormat() const
{
    return gl::GetSizedInternalFormatInfo(intendedAngleFormat().glInternalFormat);
}

// VertexFormat implementation
VertexFormat::VertexFormat(angle::FormatID angleFormatId, bool forStreaming)
{
    // auto generated function
    init(angleFormatId, forStreaming);
}

}  // namespace mtl
}  // namespace rx
