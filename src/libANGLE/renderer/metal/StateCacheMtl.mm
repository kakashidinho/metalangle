//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "libANGLE/renderer/metal/StateCacheMtl.h"

#include <sstream>

#include "common/debug.h"
#include "common/hash_utils.h"
#include "libANGLE/renderer/metal/ContextMtl.h"
#include "libANGLE/renderer/metal/mtl_resources.h"
#include "libANGLE/renderer/metal/mtl_utils.h"

#define ANGLE_OBJC_CP_PROPERTY(DST, SRC, PROPERTY) (DST).PROPERTY = ToObjC((SRC).PROPERTY)

#define ANGLE_PROP_EQ(LHS, RHS, PROP) ((LHS).PROP == (RHS).PROP)

namespace rx
{
namespace mtl
{

namespace
{

template <class T>
inline T ToObjC(const T p)
{
    return p;
}

inline MTLStencilDescriptor *ToObjC(const StencilDesc &desc)
{
    MTLStencilDescriptor *objCDesc = [[MTLStencilDescriptor alloc] init];

    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, stencilFailureOperation);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, depthFailureOperation);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, depthStencilPassOperation);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, stencilCompareFunction);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, readMask);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, writeMask);

    return [objCDesc ANGLE_MTL_AUTORELEASE];
}

MTLDepthStencilDescriptor *ToObjC(const DepthStencilDesc &desc)
{
    MTLDepthStencilDescriptor *objCDesc = [[MTLDepthStencilDescriptor alloc] init];

    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, backFaceStencil);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, frontFaceStencil);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, depthCompareFunction);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, depthWriteEnabled);

    return objCDesc;
}

MTLSamplerDescriptor *ToObjC(const SamplerDesc &desc)
{
    MTLSamplerDescriptor *objCDesc = [[MTLSamplerDescriptor alloc] init];

    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, rAddressMode);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, sAddressMode);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, tAddressMode);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, minFilter);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, magFilter);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, mipFilter);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, maxAnisotropy);

    return [objCDesc ANGLE_MTL_AUTORELEASE];
}

MTLVertexAttributeDescriptor *ToObjC(const VertexAttributeDesc &desc)
{
    MTLVertexAttributeDescriptor *objCDesc = [[MTLVertexAttributeDescriptor alloc] init];

    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, format);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, offset);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, bufferIndex);

    ASSERT(desc.bufferIndex >= kVboBindingIndexStart);

    return [objCDesc ANGLE_MTL_AUTORELEASE];
}

MTLVertexBufferLayoutDescriptor *ToObjC(const VertexBufferLayoutDesc &desc)
{
    MTLVertexBufferLayoutDescriptor *objCDesc = [[MTLVertexBufferLayoutDescriptor alloc] init];

    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, stepFunction);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, stepRate);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, stride);

    return [objCDesc ANGLE_MTL_AUTORELEASE];
}

MTLVertexDescriptor *ToObjC(const VertexDesc &desc)
{
    MTLVertexDescriptor *objCDesc = [[MTLVertexDescriptor alloc] init];
    [objCDesc reset];

    for (uint8_t i = 0; i < desc.numAttribs; ++i)
    {
        [objCDesc.attributes setObject:ToObjC(desc.attributes[i]) atIndexedSubscript:i];
    }

    for (uint8_t i = 0; i < desc.numBufferLayouts; ++i)
    {
        [objCDesc.layouts setObject:ToObjC(desc.layouts[i]) atIndexedSubscript:i];
    }

    return [objCDesc ANGLE_MTL_AUTORELEASE];
}

MTLRenderPipelineColorAttachmentDescriptor *ToObjC(const RenderPipelineColorAttachmentDesc &desc)
{
    MTLRenderPipelineColorAttachmentDescriptor *objCDesc =
        [[MTLRenderPipelineColorAttachmentDescriptor alloc] init];

    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, pixelFormat);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, writeMask);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, alphaBlendOperation);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, rgbBlendOperation);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, destinationAlphaBlendFactor);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, destinationRGBBlendFactor);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, sourceAlphaBlendFactor);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, sourceRGBBlendFactor);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, blendingEnabled);

    return [objCDesc ANGLE_MTL_AUTORELEASE];
}

MTLRenderPipelineDescriptor *ToObjC(id<MTLFunction> vertexShader,
                                    id<MTLFunction> fragmentShader,
                                    const RenderPipelineDesc &desc)
{
    MTLRenderPipelineDescriptor *objCDesc = [[MTLRenderPipelineDescriptor alloc] init];
    [objCDesc reset];
    objCDesc.vertexFunction   = vertexShader;
    objCDesc.fragmentFunction = fragmentShader;

    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, vertexDescriptor);

    for (uint8_t i = 0; i < desc.outputDescriptor.numColorAttachments; ++i)
    {
        [objCDesc.colorAttachments setObject:ToObjC(desc.outputDescriptor.colorAttachments[i])
                          atIndexedSubscript:i];
    }
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc.outputDescriptor, depthAttachmentPixelFormat);
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc.outputDescriptor, stencilAttachmentPixelFormat);

#if ANGLE_MTL_PRIMITIVE_TOPOLOGY_CLASS_AVAILABLE
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, inputPrimitiveTopology);
#endif
    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, rasterizationEnabled);

    return [objCDesc ANGLE_MTL_AUTORELEASE];
}

id<MTLTexture> ToObjC(const TextureRef &texture)
{
    auto textureRef = texture;
    return textureRef ? textureRef->get() : nil;
}

void ToObjC(MTLRenderPassAttachmentDescriptor *dst, const RenderPassAttachmentDesc &src)
{
    ANGLE_OBJC_CP_PROPERTY(dst, src, texture);
    ANGLE_OBJC_CP_PROPERTY(dst, src, level);
    ANGLE_OBJC_CP_PROPERTY(dst, src, slice);

    ANGLE_OBJC_CP_PROPERTY(dst, src, loadAction);
    ANGLE_OBJC_CP_PROPERTY(dst, src, storeAction);
    ANGLE_OBJC_CP_PROPERTY(dst, src, storeActionOptions);
}

MTLRenderPassColorAttachmentDescriptor *ToObjC(const RenderPassColorAttachmentDesc &desc)
{
    MTLRenderPassColorAttachmentDescriptor *objCDesc =
        [[MTLRenderPassColorAttachmentDescriptor alloc] init];

    ToObjC(objCDesc, desc);

    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, clearColor);

    return [objCDesc ANGLE_MTL_AUTORELEASE];
}

MTLRenderPassDepthAttachmentDescriptor *ToObjC(const RenderPassDepthAttachmentDesc &desc)
{
    MTLRenderPassDepthAttachmentDescriptor *objCDesc =
        [[MTLRenderPassDepthAttachmentDescriptor alloc] init];

    ToObjC(objCDesc, desc);

    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, clearDepth);

    return [objCDesc ANGLE_MTL_AUTORELEASE];
}

MTLRenderPassStencilAttachmentDescriptor *ToObjC(const RenderPassStencilAttachmentDesc &desc)
{
    MTLRenderPassStencilAttachmentDescriptor *objCDesc =
        [[MTLRenderPassStencilAttachmentDescriptor alloc] init];

    ToObjC(objCDesc, desc);

    ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, clearStencil);

    return [objCDesc ANGLE_MTL_AUTORELEASE];
}

}  // namespace

// StencilDesc implementation
bool StencilDesc::operator==(const StencilDesc &rhs) const
{
    return ANGLE_PROP_EQ(*this, rhs, stencilFailureOperation) &&
           ANGLE_PROP_EQ(*this, rhs, depthFailureOperation) &&
           ANGLE_PROP_EQ(*this, rhs, depthStencilPassOperation) &&

           ANGLE_PROP_EQ(*this, rhs, stencilCompareFunction) &&

           ANGLE_PROP_EQ(*this, rhs, readMask) && ANGLE_PROP_EQ(*this, rhs, writeMask);
}

void StencilDesc::set()
{
    stencilFailureOperation = depthFailureOperation = depthStencilPassOperation =
        MTLStencilOperationKeep;

    stencilCompareFunction = MTLCompareFunctionAlways;
    readMask = writeMask = std::numeric_limits<uint32_t>::max();
}

// DepthStencilDesc implementation
bool DepthStencilDesc::operator==(const DepthStencilDesc &rhs) const
{
    return ANGLE_PROP_EQ(*this, rhs, backFaceStencil) &&
           ANGLE_PROP_EQ(*this, rhs, frontFaceStencil) &&

           ANGLE_PROP_EQ(*this, rhs, depthCompareFunction) &&

           ANGLE_PROP_EQ(*this, rhs, depthWriteEnabled);
}

void DepthStencilDesc::set()
{
    frontFaceStencil.set();
    backFaceStencil.set();

    depthCompareFunction = MTLCompareFunctionAlways;
    depthWriteEnabled    = true;
}

void DepthStencilDesc::updateDepthTestEnabled(const gl::DepthStencilState &dsState)
{
    if (!dsState.depthTest)
    {
        depthCompareFunction = MTLCompareFunctionAlways;
    }
    else
    {
        updateDepthCompareFunc(dsState);
    }
}

void DepthStencilDesc::updateDepthWriteEnabled(const gl::DepthStencilState &dsState)
{
    depthWriteEnabled = dsState.depthMask;
}

void DepthStencilDesc::updateDepthCompareFunc(const gl::DepthStencilState &dsState)
{
    if (!dsState.depthTest)
    {
        return;
    }
    depthCompareFunction = mtl::GetCompareFunc(dsState.depthFunc);
}

void DepthStencilDesc::updateStencilTestEnabled(const gl::DepthStencilState &dsState)
{
    if (!dsState.stencilTest)
    {
        frontFaceStencil.stencilCompareFunction    = MTLCompareFunctionAlways;
        frontFaceStencil.depthFailureOperation     = MTLStencilOperationKeep;
        frontFaceStencil.depthStencilPassOperation = MTLStencilOperationKeep;
        frontFaceStencil.writeMask                 = 0;

        backFaceStencil.stencilCompareFunction    = MTLCompareFunctionAlways;
        backFaceStencil.depthFailureOperation     = MTLStencilOperationKeep;
        backFaceStencil.depthStencilPassOperation = MTLStencilOperationKeep;
        backFaceStencil.writeMask                 = 0;
    }
    else
    {
        updateStencilFrontFuncs(dsState);
        updateStencilFrontOps(dsState);
        updateStencilFrontWriteMask(dsState);
        updateStencilBackFuncs(dsState);
        updateStencilBackOps(dsState);
        updateStencilBackWriteMask(dsState);
    }
}

void DepthStencilDesc::updateStencilFrontOps(const gl::DepthStencilState &dsState)
{
    if (!dsState.stencilTest)
    {
        return;
    }
    frontFaceStencil.stencilFailureOperation   = mtl::GetStencilOp(dsState.stencilFail);
    frontFaceStencil.depthFailureOperation     = mtl::GetStencilOp(dsState.stencilPassDepthFail);
    frontFaceStencil.depthStencilPassOperation = mtl::GetStencilOp(dsState.stencilPassDepthPass);
}

void DepthStencilDesc::updateStencilBackOps(const gl::DepthStencilState &dsState)
{
    if (!dsState.stencilTest)
    {
        return;
    }
    backFaceStencil.stencilFailureOperation   = mtl::GetStencilOp(dsState.stencilBackFail);
    backFaceStencil.depthFailureOperation     = mtl::GetStencilOp(dsState.stencilBackPassDepthFail);
    backFaceStencil.depthStencilPassOperation = mtl::GetStencilOp(dsState.stencilBackPassDepthPass);
}

void DepthStencilDesc::updateStencilFrontFuncs(const gl::DepthStencilState &dsState)
{
    if (!dsState.stencilTest)
    {
        return;
    }
    frontFaceStencil.stencilCompareFunction = mtl::GetCompareFunc(dsState.stencilFunc);
    frontFaceStencil.readMask               = dsState.stencilMask;
}

void DepthStencilDesc::updateStencilBackFuncs(const gl::DepthStencilState &dsState)
{
    if (!dsState.stencilTest)
    {
        return;
    }
    backFaceStencil.stencilCompareFunction = mtl::GetCompareFunc(dsState.stencilBackFunc);
    backFaceStencil.readMask               = dsState.stencilBackMask;
}

void DepthStencilDesc::updateStencilFrontWriteMask(const gl::DepthStencilState &dsState)
{
    if (!dsState.stencilTest)
    {
        return;
    }
    frontFaceStencil.writeMask = dsState.stencilWritemask;
}

void DepthStencilDesc::updateStencilBackWriteMask(const gl::DepthStencilState &dsState)
{
    if (!dsState.stencilTest)
    {
        return;
    }
    backFaceStencil.writeMask = dsState.stencilBackWritemask;
}

size_t DepthStencilDesc::hash() const
{
    return angle::ComputeGenericHash(*this);
}

// SamplerDesc implementation
SamplerDesc::SamplerDesc(const gl::SamplerState &glState) : SamplerDesc()
{
    rAddressMode = GetSamplerAddressMode(glState.getWrapR());
    sAddressMode = GetSamplerAddressMode(glState.getWrapS());
    tAddressMode = GetSamplerAddressMode(glState.getWrapT());

    minFilter = GetFilter(glState.getMinFilter());
    magFilter = GetFilter(glState.getMagFilter());
    mipFilter = GetMipmapFilter(glState.getMinFilter());

    maxAnisotropy = static_cast<uint32_t>(glState.getMaxAnisotropy());
}

void SamplerDesc::set()
{
    rAddressMode = MTLSamplerAddressModeClampToEdge;
    sAddressMode = MTLSamplerAddressModeClampToEdge;
    tAddressMode = MTLSamplerAddressModeClampToEdge;

    minFilter = MTLSamplerMinMagFilterNearest;
    magFilter = MTLSamplerMinMagFilterNearest;
    mipFilter = MTLSamplerMipFilterNearest;

    maxAnisotropy = 1;
}

bool SamplerDesc::operator==(const SamplerDesc &rhs) const
{
    return ANGLE_PROP_EQ(*this, rhs, rAddressMode) && ANGLE_PROP_EQ(*this, rhs, sAddressMode) &&
           ANGLE_PROP_EQ(*this, rhs, tAddressMode) &&

           ANGLE_PROP_EQ(*this, rhs, minFilter) && ANGLE_PROP_EQ(*this, rhs, magFilter) &&
           ANGLE_PROP_EQ(*this, rhs, mipFilter) &&

           ANGLE_PROP_EQ(*this, rhs, maxAnisotropy);
}

size_t SamplerDesc::hash() const
{
    return angle::ComputeGenericHash(*this);
}

// BlendDesc implementation
bool BlendDesc::operator==(const BlendDesc &rhs) const
{
    return ANGLE_PROP_EQ(*this, rhs, writeMask) &&

           ANGLE_PROP_EQ(*this, rhs, alphaBlendOperation) &&
           ANGLE_PROP_EQ(*this, rhs, rgbBlendOperation) &&

           ANGLE_PROP_EQ(*this, rhs, destinationAlphaBlendFactor) &&
           ANGLE_PROP_EQ(*this, rhs, destinationRGBBlendFactor) &&
           ANGLE_PROP_EQ(*this, rhs, sourceAlphaBlendFactor) &&
           ANGLE_PROP_EQ(*this, rhs, sourceRGBBlendFactor) &&

           ANGLE_PROP_EQ(*this, rhs, blendingEnabled);
}

void BlendDesc::set()
{
    set(MTLColorWriteMaskAll);
}

void BlendDesc::set(MTLColorWriteMask writeMask)
{
    this->writeMask = writeMask;

    blendingEnabled     = false;
    alphaBlendOperation = rgbBlendOperation = MTLBlendOperationAdd;

    destinationAlphaBlendFactor = destinationRGBBlendFactor = MTLBlendFactorZero;
    sourceAlphaBlendFactor = sourceRGBBlendFactor = MTLBlendFactorOne;
}

void BlendDesc::updateWriteMask(const gl::BlendState &blendState)
{
    writeMask = MTLColorWriteMaskNone;
    if (blendState.colorMaskRed)
    {
        writeMask |= MTLColorWriteMaskRed;
    }
    if (blendState.colorMaskGreen)
    {
        writeMask |= MTLColorWriteMaskGreen;
    }
    if (blendState.colorMaskBlue)
    {
        writeMask |= MTLColorWriteMaskBlue;
    }
    if (blendState.colorMaskAlpha)
    {
        writeMask |= MTLColorWriteMaskAlpha;
    }
}

void BlendDesc::updateBlendFactors(const gl::BlendState &blendState)
{
    sourceRGBBlendFactor        = GetBlendFactor(blendState.sourceBlendRGB);
    sourceAlphaBlendFactor      = GetBlendFactor(blendState.sourceBlendAlpha);
    destinationRGBBlendFactor   = GetBlendFactor(blendState.destBlendRGB);
    destinationAlphaBlendFactor = GetBlendFactor(blendState.destBlendAlpha);
}

void BlendDesc::updateBlendOps(const gl::BlendState &blendState)
{
    rgbBlendOperation   = GetBlendOp(blendState.blendEquationRGB);
    alphaBlendOperation = GetBlendOp(blendState.blendEquationAlpha);
}

void BlendDesc::updateBlendEnabled(const gl::BlendState &blendState)
{
    blendingEnabled = blendState.blend;
}

// RenderPipelineColorAttachmentDesc implementation
bool RenderPipelineColorAttachmentDesc::operator==(
    const RenderPipelineColorAttachmentDesc &rhs) const
{
    if (!BlendDesc::operator==(rhs))
    {
        return false;
    }
    return ANGLE_PROP_EQ(*this, rhs, pixelFormat);
}

void RenderPipelineColorAttachmentDesc::set()
{
    set(MTLPixelFormatInvalid);
}

void RenderPipelineColorAttachmentDesc::set(MTLPixelFormat format)
{
    set(format, MTLColorWriteMaskAll);
}

void RenderPipelineColorAttachmentDesc::set(MTLPixelFormat format, MTLColorWriteMask writeMask)
{
    this->pixelFormat = format;

    BlendDesc::set(writeMask);
}

void RenderPipelineColorAttachmentDesc::set(MTLPixelFormat format, const BlendDesc &blendState)
{
    this->pixelFormat = format;

    BlendDesc::operator=(blendState);
}

void RenderPipelineColorAttachmentDesc::update(const BlendDesc &blendState)
{
    BlendDesc::operator=(blendState);
}

// RenderPipelineOutputDesc implementation
bool RenderPipelineOutputDesc::operator==(const RenderPipelineOutputDesc &rhs) const
{
    if (numColorAttachments != rhs.numColorAttachments)
    {
        return false;
    }

    for (uint8_t i = 0; i < numColorAttachments; ++i)
    {
        if (colorAttachments[i] != rhs.colorAttachments[i])
        {
            return false;
        }
    }

    return ANGLE_PROP_EQ(*this, rhs, depthAttachmentPixelFormat) &&
           ANGLE_PROP_EQ(*this, rhs, stencilAttachmentPixelFormat);
}

// RenderPipelineDesc implementation
bool RenderPipelineDesc::operator==(const RenderPipelineDesc &rhs) const
{
    return ANGLE_PROP_EQ(*this, rhs, vertexDescriptor) &&
           ANGLE_PROP_EQ(*this, rhs, outputDescriptor) &&

           ANGLE_PROP_EQ(*this, rhs, inputPrimitiveTopology);
}

size_t RenderPipelineDesc::hash() const
{
    return angle::ComputeGenericHash(*this);
}

// RenderPassDesc implementation
void RenderPassAttachmentDesc::set()
{
    texture.reset();
    level              = 0;
    slice              = 0;
    loadAction         = MTLLoadActionLoad;
    storeAction        = MTLStoreActionStore;
    storeActionOptions = MTLStoreActionOptionNone;
}

bool RenderPassAttachmentDesc::equalIgnoreLoadStoreOptions(
    const RenderPassAttachmentDesc &other) const
{
    return texture == other.texture && level == other.level && slice == other.slice;
}

bool RenderPassAttachmentDesc::operator==(const RenderPassAttachmentDesc &other) const
{
    if (!equalIgnoreLoadStoreOptions(other))
    {
        return false;
    }

    return loadAction == other.loadAction && storeAction == other.storeAction &&
           storeActionOptions == other.storeActionOptions;
}

void RenderPassDesc::populateRenderPipelineOutputDesc(RenderPipelineOutputDesc *outDesc) const
{
    populateRenderPipelineOutputDesc(MTLColorWriteMaskAll, outDesc);
}

void RenderPassDesc::populateRenderPipelineOutputDesc(MTLColorWriteMask colorWriteMask,
                                                      RenderPipelineOutputDesc *outDesc) const
{
    // Default blend state.
    BlendDesc blendState;
    blendState.set(colorWriteMask);

    populateRenderPipelineOutputDesc(blendState, outDesc);
}

void RenderPassDesc::populateRenderPipelineOutputDesc(const BlendDesc &blendState,
                                                      RenderPipelineOutputDesc *outDesc) const
{
    auto &outputDescriptor               = *outDesc;
    outputDescriptor.numColorAttachments = this->numColorAttachments;
    for (uint32_t i = 0; i < this->numColorAttachments; ++i)
    {
        auto &renderPassColorAttachment = this->colorAttachments[i];
        auto texture                    = renderPassColorAttachment.texture;

        // Copy parameters from blend state
        outputDescriptor.colorAttachments[i].update(blendState);

        if (texture)
        {

            outputDescriptor.colorAttachments[i].pixelFormat = texture->pixelFormat();

            // Combine the masks. This is useful when the texture is not supposed to have alpha
            // channel such as GL_RGB8, however, Metal doesn't natively support 24 bit RGB, so
            // we need to use RGBA texture, and then disable alpha write to this texture
            outputDescriptor.colorAttachments[i].writeMask &= texture->getColorWritableMask();
        }
        else
        {
            outputDescriptor.colorAttachments[i].pixelFormat = MTLPixelFormatInvalid;
        }
    }

    auto depthTexture = this->depthAttachment.texture;
    outputDescriptor.depthAttachmentPixelFormat =
        depthTexture ? depthTexture->pixelFormat() : MTLPixelFormatInvalid;

    auto stencilTexture = this->stencilAttachment.texture;
    outputDescriptor.stencilAttachmentPixelFormat =
        stencilTexture ? stencilTexture->pixelFormat() : MTLPixelFormatInvalid;
}

bool RenderPassDesc::equalIgnoreLoadStoreOptions(const RenderPassDesc &other) const
{
    if (numColorAttachments != other.numColorAttachments)
    {
        return false;
    }

    for (uint32_t i = 0; i < numColorAttachments; ++i)
    {
        auto &renderPassColorAttachment = colorAttachments[i];
        auto &otherRPAttachment         = other.colorAttachments[i];
        if (!renderPassColorAttachment.equalIgnoreLoadStoreOptions(otherRPAttachment))
        {
            return false;
        }
    }

    return depthAttachment.equalIgnoreLoadStoreOptions(other.depthAttachment) &&
           stencilAttachment.equalIgnoreLoadStoreOptions(other.stencilAttachment);
}

bool RenderPassDesc::operator==(const RenderPassDesc &other) const
{
    if (numColorAttachments != other.numColorAttachments)
    {
        return false;
    }

    for (uint32_t i = 0; i < numColorAttachments; ++i)
    {
        auto &renderPassColorAttachment = colorAttachments[i];
        auto &otherRPAttachment         = other.colorAttachments[i];
        if (renderPassColorAttachment != (otherRPAttachment))
        {
            return false;
        }
    }

    return depthAttachment == other.depthAttachment && stencilAttachment == other.stencilAttachment;
}

// Convert to Metal object
AutoObjCObj<MTLRenderPassDescriptor> ToMetalObj(const RenderPassDesc &desc)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        MTLRenderPassDescriptor *objCDesc = [MTLRenderPassDescriptor renderPassDescriptor];

        for (uint32_t i = 0; i < desc.numColorAttachments; ++i)
        {
            [objCDesc.colorAttachments setObject:ToObjC(desc.colorAttachments[i])
                              atIndexedSubscript:i];
        }

        ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, depthAttachment);
        ANGLE_OBJC_CP_PROPERTY(objCDesc, desc, stencilAttachment);

        return objCDesc;
    }
}

}  // namespace mtl

// RenderPipelineCacheMtl implementation
RenderPipelineCacheMtl::RenderPipelineCacheMtl() {}

RenderPipelineCacheMtl::~RenderPipelineCacheMtl() {}

void RenderPipelineCacheMtl::setVertexShader(mtl::Context *context, id<MTLFunction> shader)
{
    mVertexShader.retainAssign(shader);

    if (!shader)
    {
        clearPipelineStates();
        return;
    }

    recreatePipelineStates(context);
}

void RenderPipelineCacheMtl::setFragmentShader(mtl::Context *context, id<MTLFunction> shader)
{
    mFragmentShader.retainAssign(shader);

    if (!shader)
    {
        clearPipelineStates();
        return;
    }

    recreatePipelineStates(context);
}

bool RenderPipelineCacheMtl::hasDefaultAttribs(const mtl::RenderPipelineDesc &rpdesc) const
{
    const mtl::VertexDesc &desc = rpdesc.vertexDescriptor;
    for (uint8_t i = 0; i < desc.numAttribs; ++i)
    {
        if (desc.attributes[i].bufferIndex == kDefaultAttribsBindingIndex)
        {
            return true;
        }
    }

    return false;
}

mtl::AutoObjCPtr<id<MTLRenderPipelineState>> RenderPipelineCacheMtl::getRenderPipelineState(
    ContextMtl *context,
    const mtl::RenderPipelineDesc &desc)
{
    auto insertDefaultAttribLayout = hasDefaultAttribs(desc);
    int tableIdx                   = insertDefaultAttribLayout ? 1 : 0;
    auto &table                    = mRenderPipelineStates[tableIdx];
    auto ite                       = table.find(desc);
    if (ite == table.end())
    {
        return insertRenderPipelineState(context, desc, insertDefaultAttribLayout);
    }

    return ite->second;
}

mtl::AutoObjCPtr<id<MTLRenderPipelineState>> RenderPipelineCacheMtl::insertRenderPipelineState(
    mtl::Context *context,
    const mtl::RenderPipelineDesc &desc,
    bool insertDefaultAttribLayout)
{
    mtl::AutoObjCPtr<id<MTLRenderPipelineState>> newState =
        createRenderPipelineState(context, desc, insertDefaultAttribLayout);

    int tableIdx = insertDefaultAttribLayout ? 1 : 0;
    auto re      = mRenderPipelineStates[tableIdx].insert(std::make_pair(desc, newState));
    if (!re.second)
    {
        return nil;
    }

    return re.first->second;
}

mtl::AutoObjCPtr<id<MTLRenderPipelineState>> RenderPipelineCacheMtl::createRenderPipelineState(
    mtl::Context *context,
    const mtl::RenderPipelineDesc &desc,
    bool insertDefaultAttribLayout)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        auto metalDevice = context->getMetalDevice();
        mtl::AutoObjCObj<MTLRenderPipelineDescriptor> objCDesc =
            mtl::ToObjC(mVertexShader, mFragmentShader, desc);

        // special attribute slot for default attribute
        if (insertDefaultAttribLayout)
        {
            MTLVertexBufferLayoutDescriptor *defaultAttribLayoutObjCDesc =
                [[MTLVertexBufferLayoutDescriptor alloc] init];
            defaultAttribLayoutObjCDesc.stepFunction = MTLVertexStepFunctionConstant;
            defaultAttribLayoutObjCDesc.stepRate     = 0;
            defaultAttribLayoutObjCDesc.stride       = kDefaultAttributeSize * kMaxVertexAttribs;

            [objCDesc.get().vertexDescriptor.layouts
                         setObject:[defaultAttribLayoutObjCDesc ANGLE_MTL_AUTORELEASE]
                atIndexedSubscript:kDefaultAttribsBindingIndex];
        }
        // Create pipeline state
        NSError *err  = nil;
        auto newState = [metalDevice newRenderPipelineStateWithDescriptor:objCDesc error:&err];
        if (err)
        {
            context->handleError(err, __FILE__, ANGLE_FUNCTION, __LINE__);
            return nil;
        }

        return newState;
    }
}

void RenderPipelineCacheMtl::recreatePipelineStates(mtl::Context *context)
{
    for (int hasDefaultAttrib = 0; hasDefaultAttrib <= 1; ++hasDefaultAttrib)
    {
        for (auto &ite : mRenderPipelineStates[hasDefaultAttrib])
        {
            if (ite.second == nil)
            {
                continue;
            }

            ite.second = createRenderPipelineState(context, ite.first, hasDefaultAttrib);
        }
    }
}

void RenderPipelineCacheMtl::clear()
{
    mVertexShader   = nil;
    mFragmentShader = nil;
    clearPipelineStates();
}

void RenderPipelineCacheMtl::clearPipelineStates()
{
    mRenderPipelineStates[0].clear();
    mRenderPipelineStates[1].clear();
}

// StateCacheMtl implementation
StateCacheMtl::StateCacheMtl() {}

StateCacheMtl::~StateCacheMtl() {}

mtl::AutoObjCPtr<id<MTLDepthStencilState>> StateCacheMtl::getNullDepthStencilState(
    id<MTLDevice> device)
{
    if (!mNullDepthStencilState)
    {
        mtl::DepthStencilDesc desc;
        desc.set();
        ASSERT(desc.frontFaceStencil.stencilCompareFunction == MTLCompareFunctionAlways);
        desc.depthWriteEnabled = false;
        mNullDepthStencilState = getDepthStencilState(device, desc);
    }
    return mNullDepthStencilState;
}

mtl::AutoObjCPtr<id<MTLDepthStencilState>> StateCacheMtl::getDepthStencilState(
    id<MTLDevice> metalDevice,
    const mtl::DepthStencilDesc &desc)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        auto ite = mDepthStencilStates.find(desc);
        if (ite == mDepthStencilStates.end())
        {
            mtl::AutoObjCObj<MTLDepthStencilDescriptor> objCDesc = mtl::ToObjC(desc);
            mtl::AutoObjCPtr<id<MTLDepthStencilState>> newState =
                [metalDevice newDepthStencilStateWithDescriptor:objCDesc];

            auto re = mDepthStencilStates.insert(std::make_pair(desc, newState));
            if (!re.second)
            {
                return nil;
            }

            ite = re.first;
        }

        return ite->second;
    }
}

mtl::AutoObjCPtr<id<MTLSamplerState>> StateCacheMtl::getSamplerState(id<MTLDevice> metalDevice,
                                                                     const mtl::SamplerDesc &desc)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        auto ite = mSamplerStates.find(desc);
        if (ite == mSamplerStates.end())
        {
            mtl::AutoObjCObj<MTLSamplerDescriptor> objCDesc = mtl::ToObjC(desc);
            mtl::AutoObjCPtr<id<MTLSamplerState>> newState =
                [metalDevice newSamplerStateWithDescriptor:objCDesc];

            auto re = mSamplerStates.insert(std::make_pair(desc, newState));
            if (!re.second)
                return nil;

            ite = re.first;
        }

        return ite->second;
    }
}

mtl::AutoObjCPtr<id<MTLSamplerState>> StateCacheMtl::getNullSamplerState(mtl::Context *context)
{
    return getNullSamplerState(context->getMetalDevice());
}

mtl::AutoObjCPtr<id<MTLSamplerState>> StateCacheMtl::getNullSamplerState(id<MTLDevice> device)
{
    mtl::SamplerDesc desc;
    desc.set();

    return getSamplerState(device, desc);
}

void StateCacheMtl::clear()
{
    mNullDepthStencilState = nil;
    mDepthStencilStates.clear();
    mSamplerStates.clear();
}
}
