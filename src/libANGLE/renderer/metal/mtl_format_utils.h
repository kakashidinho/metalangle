//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#ifndef LIBANGLE_RENDERER_METAL_MTL_FORMAT_UTILS_H_
#define LIBANGLE_RENDERER_METAL_MTL_FORMAT_UTILS_H_

#include "libANGLE/renderer/metal/Metal_platform.h"

#include "common/angleutils.h"
#include "libANGLE/Caps.h"
#include "libANGLE/formatutils.h"
#include "libANGLE/renderer/copyvertex.h"

namespace rx
{
class ContextMtl;

namespace mtl
{

struct FormatBase
{
    const angle::Format &actualAngleFormat() const;
    const angle::Format &intendedAngleFormat() const;

    angle::FormatID actualFormatId   = angle::FormatID::NONE;
    angle::FormatID intendedFormatId = angle::FormatID::NONE;
};

// Pixel format
struct Format : public FormatBase
{
    Format();
    Format(const gl::InternalFormat &internalFormat);
    Format(angle::FormatID intendedFormatId);

    void init(GLenum sizedInternalFormat);
    void init(const gl::InternalFormat &internalFormat);
    void init(angle::FormatID intendedFormatId);
    void initAndConvertToCompatibleFormatIfNotSupported(id<MTLDevice> metalDevice,
                                                        GLenum sizedInternalFormat);
    void initAndConvertToCompatibleFormatIfNotSupported(id<MTLDevice> metalDevice,
                                                        const gl::InternalFormat &internalFormat);
    void initAndConvertToCompatibleFormatIfNotSupported(id<MTLDevice> metalDevice,
                                                        angle::FormatID intendedFormatId);

    void convertToCompatibleFormatIfNotSupported(id<MTLDevice> metalDevice);

    const gl::InternalFormat &intendedInternalFormat() const;

    bool valid() const { return metalFormat != MTLPixelFormatInvalid; }

    static bool FormatRenderable(MTLPixelFormat format);
    static bool FormatCPUReadable(MTLPixelFormat format);
    static void GenerateTextureCapsMap(const ContextMtl *context,
                                       gl::TextureCapsMap *capsMapOut,
                                       std::vector<GLenum> *compressedFormatsOut);

    MTLPixelFormat metalFormat = MTLPixelFormatInvalid;
};

// Vertex format
struct VertexFormat : public FormatBase
{
    VertexFormat() = default;
    // forStreaming means this format is for streaming vertex data.
    // Thus, it needs to convert certain formats to float format.
    VertexFormat(angle::FormatID angleFormatId, bool forStreaming = false);

    void init(angle::FormatID angleFormatId, bool forStreaming = false);

    MTLVertexFormat metalFormat = MTLVertexFormatInvalid;

    VertexCopyFunction vertexLoadFunction = nullptr;
};

}  // namespace mtl
}  // namespace rx

#endif /* LIBANGLE_RENDERER_METAL_MTL_FORMAT_UTILS_H_ */
