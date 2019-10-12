//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#ifndef LIBANGLE_RENDERER_METAL_STATECACHEMTL_H_
#define LIBANGLE_RENDERER_METAL_STATECACHEMTL_H_

#include "libANGLE/renderer/metal/Metal_platform.h"

#include <unordered_map>

#include "libANGLE/State.h"
#include "libANGLE/angletypes.h"
#include "libANGLE/renderer/metal/mtl_common.h"
#include "libANGLE/renderer/metal/mtl_resources.h"

static inline bool operator==(const MTLClearColor &lhs, const MTLClearColor &rhs);

namespace rx
{
namespace mtl
{
struct StencilDesc
{
    bool operator==(const StencilDesc &rhs) const;

    // Set default values
    void set();

    MTLStencilOperation stencilFailureOperation;
    MTLStencilOperation depthFailureOperation;
    MTLStencilOperation depthStencilPassOperation;

    MTLCompareFunction stencilCompareFunction;

    uint32_t readMask;
    uint32_t writeMask;
};

struct DepthStencilDesc
{
    DepthStencilDesc() { memset(this, 0, sizeof(*this)); }

    bool operator==(const DepthStencilDesc &rhs) const;

    // Set default values.
    // Default is depth/stencil test disabled. Depth/stencil write enabled.
    void set();

    size_t hash() const;

    void updateDepthTestEnabled(const gl::DepthStencilState &dsState);
    void updateDepthWriteEnabled(const gl::DepthStencilState &dsState);
    void updateDepthCompareFunc(const gl::DepthStencilState &dsState);
    void updateStencilTestEnabled(const gl::DepthStencilState &dsState);
    void updateStencilFrontOps(const gl::DepthStencilState &dsState);
    void updateStencilBackOps(const gl::DepthStencilState &dsState);
    void updateStencilFrontFuncs(const gl::DepthStencilState &dsState);
    void updateStencilBackFuncs(const gl::DepthStencilState &dsState);
    void updateStencilFrontWriteMask(const gl::DepthStencilState &dsState);
    void updateStencilBackWriteMask(const gl::DepthStencilState &dsState);

    StencilDesc backFaceStencil;
    StencilDesc frontFaceStencil;

    MTLCompareFunction depthCompareFunction;
    bool depthWriteEnabled;
};

struct SamplerDesc
{
    SamplerDesc() { memset(this, 0, sizeof(*this)); }

    explicit SamplerDesc(const gl::SamplerState &glState);

    // Set default values. All filters are nearest, and addresModes are clamp to edge.
    void set();

    bool operator==(const SamplerDesc &rhs) const;

    size_t hash() const;

    MTLSamplerAddressMode rAddressMode;
    MTLSamplerAddressMode sAddressMode;
    MTLSamplerAddressMode tAddressMode;

    MTLSamplerMinMagFilter minFilter;
    MTLSamplerMinMagFilter magFilter;
    MTLSamplerMipFilter mipFilter;

    uint32_t maxAnisotropy;
};

struct VertexAttributeDesc
{
    inline bool operator==(const VertexAttributeDesc &rhs) const
    {
        return format == rhs.format && offset == rhs.offset && bufferIndex == rhs.bufferIndex;
    }
    inline bool operator!=(const VertexAttributeDesc &rhs) const { return !(*this == rhs); }
    MTLVertexFormat format;
    NSUInteger offset;
    NSUInteger bufferIndex;
};

struct VertexBufferLayoutDesc
{
    inline bool operator==(const VertexBufferLayoutDesc &rhs) const
    {
        return stepFunction == rhs.stepFunction && stepRate == rhs.stepRate && stride == rhs.stride;
    }
    inline bool operator!=(const VertexBufferLayoutDesc &rhs) const { return !(*this == rhs); }

    MTLVertexStepFunction stepFunction;
    NSUInteger stepRate;
    NSUInteger stride;
};

struct VertexDesc
{
    VertexAttributeDesc attributes[kMaxVertexAttribs];
    VertexBufferLayoutDesc layouts[kMaxVertexAttribs];

    uint8_t numAttribs;
    uint8_t numBufferLayouts;
};

struct BlendDesc
{
    bool operator==(const BlendDesc &rhs) const;
    BlendDesc &operator=(const BlendDesc &src) = default;

    // Set default values
    void set();
    void set(MTLColorWriteMask writeMask);

    void updateWriteMask(const gl::BlendState &blendState);
    void updateBlendFactors(const gl::BlendState &blendState);
    void updateBlendOps(const gl::BlendState &blendState);
    void updateBlendEnabled(const gl::BlendState &blendState);

    MTLColorWriteMask writeMask;

    MTLBlendOperation alphaBlendOperation;
    MTLBlendOperation rgbBlendOperation;

    MTLBlendFactor destinationAlphaBlendFactor;
    MTLBlendFactor destinationRGBBlendFactor;
    MTLBlendFactor sourceAlphaBlendFactor;
    MTLBlendFactor sourceRGBBlendFactor;

    bool blendingEnabled;
};

struct RenderPipelineColorAttachmentDesc : public BlendDesc
{
    bool operator==(const RenderPipelineColorAttachmentDesc &rhs) const;
    inline bool operator!=(const RenderPipelineColorAttachmentDesc &rhs) const
    {
        return !(*this == rhs);
    }

    // Set default values
    void set();
    void set(MTLPixelFormat format);
    void set(MTLPixelFormat format, MTLColorWriteMask writeMask);
    void set(MTLPixelFormat format, const BlendDesc &blendState);

    void update(const BlendDesc &blendState);

    MTLPixelFormat pixelFormat;
};

struct RenderPipelineOutputDesc
{
    bool operator==(const RenderPipelineOutputDesc &rhs) const;

    RenderPipelineColorAttachmentDesc colorAttachments[kMaxRenderTargets];
    MTLPixelFormat depthAttachmentPixelFormat;
    MTLPixelFormat stencilAttachmentPixelFormat;

    uint8_t numColorAttachments;
};

#if !TARGET_OS_OSX && ANGLE_IOS_DEPLOY_TARGET < __IPHONE_12_0
#    define ANGLE_MTL_PRIMITIVE_TOPOLOGY_CLASS_AVAILABLE 0
typedef uint32_t PrimitiveTopologyClass;
constexpr PrimitiveTopologyClass kPrimitiveTopologyClassTriangle = 0;
constexpr PrimitiveTopologyClass kPrimitiveTopologyClassPoint    = 0;
#else
#    define ANGLE_MTL_PRIMITIVE_TOPOLOGY_CLASS_AVAILABLE 1
typedef MTLPrimitiveTopologyClass PrimitiveTopologyClass;
constexpr PrimitiveTopologyClass kPrimitiveTopologyClassTriangle =
    MTLPrimitiveTopologyClassTriangle;
constexpr PrimitiveTopologyClass kPrimitiveTopologyClassPoint = MTLPrimitiveTopologyClassPoint;
#endif

struct RenderPipelineDesc
{
    RenderPipelineDesc()
    {
        memset(this, 0, sizeof(*this));
        rasterizationEnabled = true;
    }

    bool operator==(const RenderPipelineDesc &rhs) const;

    size_t hash() const;

    VertexDesc vertexDescriptor;

    RenderPipelineOutputDesc outputDescriptor;

    PrimitiveTopologyClass inputPrimitiveTopology;

    bool rasterizationEnabled;
};

struct RenderPassAttachmentDesc
{
    RenderPassAttachmentDesc() { set(); }
    // Set default values
    void set();

    bool equalIgnoreLoadStoreOptions(const RenderPassAttachmentDesc &other) const;
    bool operator==(const RenderPassAttachmentDesc &other) const;

    TextureRef texture;
    uint32_t level;
    uint32_t slice;
    MTLLoadAction loadAction;
    MTLStoreAction storeAction;
    MTLStoreActionOptions storeActionOptions;
};

struct RenderPassColorAttachmentDesc : public RenderPassAttachmentDesc
{
    inline bool operator==(const RenderPassColorAttachmentDesc &other) const
    {
        return RenderPassAttachmentDesc::operator==(other) && clearColor == other.clearColor;
    }
    inline bool operator!=(const RenderPassColorAttachmentDesc &other) const
    {
        return !(*this == other);
    }
    MTLClearColor clearColor = {0};
};

struct RenderPassDepthAttachmentDesc : public RenderPassAttachmentDesc
{
    inline bool operator==(const RenderPassDepthAttachmentDesc &other) const
    {
        return RenderPassAttachmentDesc::operator==(other) && clearDepth == other.clearDepth;
    }
    inline bool operator!=(const RenderPassDepthAttachmentDesc &other) const
    {
        return !(*this == other);
    }

    double clearDepth = 0;
};

struct RenderPassStencilAttachmentDesc : public RenderPassAttachmentDesc
{
    inline bool operator==(const RenderPassStencilAttachmentDesc &other) const
    {
        return RenderPassAttachmentDesc::operator==(other) && clearStencil == other.clearStencil;
    }
    inline bool operator!=(const RenderPassStencilAttachmentDesc &other) const
    {
        return !(*this == other);
    }
    uint32_t clearStencil = 0;
};

struct RenderPassDesc
{
    RenderPassColorAttachmentDesc colorAttachments[kMaxRenderTargets];
    RenderPassDepthAttachmentDesc depthAttachment;
    RenderPassStencilAttachmentDesc stencilAttachment;

    // This will populate the RenderPipelineOutputDesc with default blend state and
    // MTLColorWriteMaskAll
    void populateRenderPipelineOutputDesc(RenderPipelineOutputDesc *outDesc) const;
    // This will populate the RenderPipelineOutputDesc with default blend state and the specified
    // MTLColorWriteMask
    void populateRenderPipelineOutputDesc(MTLColorWriteMask colorWriteMask,
                                          RenderPipelineOutputDesc *outDesc) const;
    // This will populate the RenderPipelineOutputDesc with the specified blend state
    void populateRenderPipelineOutputDesc(const BlendDesc &blendState,
                                          RenderPipelineOutputDesc *outDesc) const;

    bool equalIgnoreLoadStoreOptions(const RenderPassDesc &other) const;
    bool operator==(const RenderPassDesc &other) const;
    inline bool operator!=(const RenderPassDesc &other) const { return !(*this == other); }

    uint32_t numColorAttachments = 0;
};

// convert to Metal object
AutoObjCObj<MTLRenderPassDescriptor> ToMetalObj(const RenderPassDesc &desc);

}  // namespace mtl
}  // namespace rx

namespace std
{

template <>
struct hash<rx::mtl::DepthStencilDesc>
{
    size_t operator()(const rx::mtl::DepthStencilDesc &key) const { return key.hash(); }
};

template <>
struct hash<rx::mtl::SamplerDesc>
{
    size_t operator()(const rx::mtl::SamplerDesc &key) const { return key.hash(); }
};

template <>
struct hash<rx::mtl::RenderPipelineDesc>
{
    size_t operator()(const rx::mtl::RenderPipelineDesc &key) const { return key.hash(); }
};

}  // namespace std

namespace rx
{
class ContextMtl;

// render pipeline state cache per shader program
class RenderPipelineCacheMtl final : angle::NonCopyable
{
  public:
    RenderPipelineCacheMtl();
    ~RenderPipelineCacheMtl();

    void setVertexShader(mtl::Context *context, id<MTLFunction> shader);
    void setFragmentShader(mtl::Context *context, id<MTLFunction> shader);

    id<MTLFunction> getVertexShader() { return mVertexShader.get(); }
    id<MTLFunction> getFragmentShader() { return mFragmentShader.get(); }

    mtl::AutoObjCPtr<id<MTLRenderPipelineState>> getRenderPipelineState(
        ContextMtl *context,
        const mtl::RenderPipelineDesc &desc);

    void clear();

  protected:
    mtl::AutoObjCPtr<id<MTLFunction>> mVertexShader   = nil;
    mtl::AutoObjCPtr<id<MTLFunction>> mFragmentShader = nil;

  private:
    void clearPipelineStates();
    void recreatePipelineStates(mtl::Context *context);
    mtl::AutoObjCPtr<id<MTLRenderPipelineState>> insertRenderPipelineState(
        mtl::Context *context,
        const mtl::RenderPipelineDesc &desc,
        bool insertDefaultAttribLayout);
    mtl::AutoObjCPtr<id<MTLRenderPipelineState>> createRenderPipelineState(
        mtl::Context *context,
        const mtl::RenderPipelineDesc &desc,
        bool insertDefaultAttribLayout);

    bool hasDefaultAttribs(const mtl::RenderPipelineDesc &desc) const;

    // One table with default attrib and one table without.
    std::unordered_map<mtl::RenderPipelineDesc, mtl::AutoObjCPtr<id<MTLRenderPipelineState>>>
        mRenderPipelineStates[2];
};

class StateCacheMtl final : angle::NonCopyable
{
  public:
    StateCacheMtl();
    ~StateCacheMtl();

    // Null depth stencil state has depth/stecil read & write disabled.
    inline mtl::AutoObjCPtr<id<MTLDepthStencilState>> getNullDepthStencilState(
        mtl::Context *context)
    {
        return getNullDepthStencilState(context->getMetalDevice());
    }
    mtl::AutoObjCPtr<id<MTLDepthStencilState>> getNullDepthStencilState(id<MTLDevice> device);
    mtl::AutoObjCPtr<id<MTLDepthStencilState>> getDepthStencilState(
        id<MTLDevice> device,
        const mtl::DepthStencilDesc &desc);
    mtl::AutoObjCPtr<id<MTLSamplerState>> getSamplerState(id<MTLDevice> device,
                                                          const mtl::SamplerDesc &desc);
    // Null sampler state uses default SamplerDesc
    mtl::AutoObjCPtr<id<MTLSamplerState>> getNullSamplerState(mtl::Context *context);
    mtl::AutoObjCPtr<id<MTLSamplerState>> getNullSamplerState(id<MTLDevice> device);
    void clear();

  private:
    mtl::AutoObjCPtr<id<MTLDepthStencilState>> mNullDepthStencilState = nil;
    std::unordered_map<mtl::DepthStencilDesc, mtl::AutoObjCPtr<id<MTLDepthStencilState>>>
        mDepthStencilStates;
    std::unordered_map<mtl::SamplerDesc, mtl::AutoObjCPtr<id<MTLSamplerState>>> mSamplerStates;
};
}  // namespace rx

static inline bool operator==(const rx::mtl::VertexDesc &lhs, const rx::mtl::VertexDesc &rhs)
{
    if (lhs.numAttribs != rhs.numAttribs || lhs.numBufferLayouts != rhs.numBufferLayouts)
    {
        return false;
    }
    for (uint8_t i = 0; i < lhs.numAttribs; ++i)
    {
        if (lhs.attributes[i] != rhs.attributes[i])
        {
            return false;
        }
    }
    for (uint8_t i = 0; i < lhs.numBufferLayouts; ++i)
    {
        if (lhs.layouts[i] != rhs.layouts[i])
        {
            return false;
        }
    }
    return true;
}

static inline bool operator==(const MTLClearColor &lhs, const MTLClearColor &rhs)
{
    return lhs.red == rhs.red && lhs.green == rhs.green && lhs.blue == rhs.blue &&
           lhs.alpha == rhs.alpha;
}

#endif /* LIBANGLE_RENDERER_METAL_STATECACHEMTL_H_ */
