//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// mtl_state_cache.h:
//    Defines the class interface for StateCache, RenderPipelineCache and various
//    C struct versions of Metal sampler, depth stencil, render pass, render pipeline descriptors.
//

#ifndef LIBANGLE_RENDERER_METAL_MTL_STATE_CACHE_H_
#define LIBANGLE_RENDERER_METAL_MTL_STATE_CACHE_H_

#import <Metal/Metal.h>

#include <unordered_map>

#include "common/angleutils.h"
#include "libANGLE/State.h"
#include "libANGLE/angletypes.h"
#include "libANGLE/renderer/metal/mtl_common.h"
#include "libANGLE/renderer/metal/mtl_resources.h"

static inline bool operator==(const MTLClearColor &lhs, const MTLClearColor &rhs);

namespace rx
{
class ContextMtl;

namespace mtl
{
struct alignas(1) StencilDesc
{
    bool operator==(const StencilDesc &rhs) const;

    // Set default values
    void reset();

    // Use uint8_t instead of MTLStencilOperation to compact space
    uint8_t stencilFailureOperation : 3;
    uint8_t depthFailureOperation : 3;
    uint8_t depthStencilPassOperation : 3;

    // Use uint8_t instead of MTLCompareFunction to compact space
    uint8_t stencilCompareFunction : 3;

    uint8_t readMask : 8;
    uint8_t writeMask : 8;
};

struct alignas(4) DepthStencilDesc
{
    DepthStencilDesc();
    DepthStencilDesc(const DepthStencilDesc &src);
    DepthStencilDesc(DepthStencilDesc &&src);

    DepthStencilDesc &operator=(const DepthStencilDesc &src);

    bool operator==(const DepthStencilDesc &rhs) const;

    // Set default values.
    // Default is depth/stencil test disabled. Depth/stencil write enabled.
    void reset();

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

    // Use uint8_t instead of MTLCompareFunction to compact space
    uint8_t depthCompareFunction : 3;
    bool depthWriteEnabled : 1;
};

struct alignas(4) SamplerDesc
{
    SamplerDesc();
    SamplerDesc(const SamplerDesc &src);
    SamplerDesc(SamplerDesc &&src);

    explicit SamplerDesc(const gl::SamplerState &glState);

    SamplerDesc &operator=(const SamplerDesc &src);

    // Set default values. All filters are nearest, and addresModes are clamp to edge.
    void reset();

    bool operator==(const SamplerDesc &rhs) const;

    size_t hash() const;

    // Use uint8_t instead of MTLSamplerAddressMode to compact space
    uint8_t rAddressMode : 3;
    uint8_t sAddressMode : 3;
    uint8_t tAddressMode : 3;

    // Use uint8_t instead of MTLSamplerMinMagFilter to compact space
    uint8_t minFilter : 1;
    uint8_t magFilter : 1;
    uint8_t mipFilter : 2;

    uint8_t maxAnisotropy : 5;

    // Use uint8_t instead of MTLCompareFunction to compact space
    uint8_t compareFunction : 3;
};

enum class VertexAttributeSource : uint8_t
{
    // Vertex attribute is from buffer
    Buffer,
    // Vertex attribute is from default attributes
    DefaultAttrib,
    // Vertex attribute is not used
    None,

    EnumCount,
};

struct VertexAttributeDesc
{
    bool operator==(const VertexAttributeDesc &rhs) const;
    inline bool operator!=(const VertexAttributeDesc &rhs) const { return !(*this == rhs); }

    uint32_t offset;
    uint32_t stride;
    uint32_t divisor;

    uint8_t channels;
    VertexAttributeType type : 8;
    VertexAttributeSource source : 4;
    bool isNorm : 2;     // normalized
    bool isAligned : 2;  // offset & stride's alignments are valid

    const uint8_t padding = 0;
};

static_assert(sizeof(VertexAttributeDesc) == sizeof(uint64_t) * 2,
              "Unexpected paddings in VertexAttributeDesc");

struct VertexDesc
{
    VertexAttributeDesc attributes[kMaxVertexAttribs];
};
static_assert(sizeof(VertexDesc) == sizeof(VertexAttributeDesc) * kMaxVertexAttribs,
              "Unexpected paddings in VertexDesc");

struct alignas(4) HashableVertexDesc : public VertexDesc
{
    HashableVertexDesc();
    HashableVertexDesc(const HashableVertexDesc &src);
    HashableVertexDesc(const VertexDesc &src);
    HashableVertexDesc(HashableVertexDesc &&src);

    HashableVertexDesc &operator=(const HashableVertexDesc &src);
    HashableVertexDesc &operator=(const VertexDesc &src);

    bool operator==(const HashableVertexDesc &rhs) const;

    size_t hash() const;
};

static_assert(sizeof(HashableVertexDesc) == sizeof(VertexDesc),
              "Unexpected paddings in HashableVertexDesc");

struct BlendDesc
{
    bool operator==(const BlendDesc &rhs) const;
    BlendDesc &operator=(const BlendDesc &src) = default;

    // Set default values
    void reset();
    void reset(MTLColorWriteMask writeMask);

    void updateWriteMask(const uint8_t angleMask);

    // Use uint8_t instead of MTLColorWriteMask to compact space
    uint8_t writeMask : 4;

    // Use uint8_t instead of MTLBlendOperation to compact space
    uint8_t alphaBlendOperation : 3;
    uint8_t rgbBlendOperation : 3;

    // Use uint8_t instead of MTLBlendFactor to compact space
    // NOTE(hqle): enum MTLBlendFactorSource1Color and above are unused.
    uint8_t destinationAlphaBlendFactor : 4;
    uint8_t destinationRGBBlendFactor : 4;
    uint8_t sourceAlphaBlendFactor : 4;
    uint8_t sourceRGBBlendFactor : 4;

    bool blendingEnabled : 1;
};

using BlendDescArray = std::array<BlendDesc, kMaxRenderTargets>;
using WriteMaskArray = std::array<uint8_t, kMaxRenderTargets>;

struct alignas(2) RenderPipelineColorAttachmentDesc : public BlendDesc
{
    bool operator==(const RenderPipelineColorAttachmentDesc &rhs) const;
    inline bool operator!=(const RenderPipelineColorAttachmentDesc &rhs) const
    {
        return !(*this == rhs);
    }

    // Set default values
    void reset();
    void reset(MTLPixelFormat format);
    void reset(MTLPixelFormat format, MTLColorWriteMask writeMask);
    void reset(MTLPixelFormat format, const BlendDesc &blendDesc);

    void update(const BlendDesc &blendDesc);

    // Use uint16_t instead of MTLPixelFormat to compact space
    uint16_t pixelFormat : 16;
};

struct RenderPipelineOutputDesc
{
    bool operator==(const RenderPipelineOutputDesc &rhs) const;

    void updateEnabledDrawBuffers(gl::DrawBufferMask enabledBuffers);

    RenderPipelineColorAttachmentDesc colorAttachments[kMaxRenderTargets];

    // Use uint16_t instead of MTLPixelFormat to compact space
    uint16_t depthAttachmentPixelFormat : 16;
    uint16_t stencilAttachmentPixelFormat : 16;

    static_assert(kMaxRenderTargets <= 4, "kMaxRenderTargets must be <= 4");
    uint8_t numColorAttachments : 3;
    uint8_t sampleCount : 5;
};

// Some SDK levels don't declare MTLPrimitiveTopologyClass. Needs to do compile time check here:
#if !(TARGET_OS_OSX || TARGET_OS_MACCATALYST) && ANGLE_IOS_DEPLOY_TARGET < __IPHONE_12_0
#    define ANGLE_MTL_PRIMITIVE_TOPOLOGY_CLASS_AVAILABLE 0
using PrimitiveTopologyClass                                     = uint32_t;
constexpr PrimitiveTopologyClass kPrimitiveTopologyClassTriangle = 0;
constexpr PrimitiveTopologyClass kPrimitiveTopologyClassPoint    = 0;
#else
#    define ANGLE_MTL_PRIMITIVE_TOPOLOGY_CLASS_AVAILABLE 1
using PrimitiveTopologyClass = MTLPrimitiveTopologyClass;
constexpr PrimitiveTopologyClass kPrimitiveTopologyClassTriangle =
    MTLPrimitiveTopologyClassTriangle;
constexpr PrimitiveTopologyClass kPrimitiveTopologyClassPoint = MTLPrimitiveTopologyClassPoint;
#endif

enum class RenderPipelineRasterization : uint32_t
{
    // This flag is used for vertex shader not writing any stage output (e.g gl_Position).
    // This will disable fragment shader stage. This is useful for transform feedback ouput vertex
    // shader.
    Disabled,

    // Fragment shader is enabled.
    Enabled,

    // This flag is for rasterization discard emulation when vertex shader still writes to stage
    // output. Disabled flag cannot be used in this case since Metal doesn't allow that. The
    // emulation would insert a code snippet to move gl_Position out of clip space's visible area to
    // simulate the discard.
    EmulatedDiscard,

    EnumCount,
};

template <typename T>
using RenderPipelineRasterStateMap = angle::PackedEnumMap<RenderPipelineRasterization, T>;

struct alignas(4) RenderPipelineDesc
{
    RenderPipelineDesc();
    RenderPipelineDesc(const RenderPipelineDesc &src);
    RenderPipelineDesc(RenderPipelineDesc &&src);

    RenderPipelineDesc &operator=(const RenderPipelineDesc &src);

    bool operator==(const RenderPipelineDesc &rhs) const;

    size_t hash() const;

    bool rasterizationEnabled() const;

    VertexDesc vertexDescriptor;

    RenderPipelineOutputDesc outputDescriptor;

    // Use uint8_t instead of PrimitiveTopologyClass to compact space.
    uint8_t inputPrimitiveTopology : 2;

    bool alphaToCoverageEnabled : 1;

    // These flags are for emulation and do not correspond to any flags in
    // MTLRenderPipelineDescriptor descriptor. These flags should be used by
    // RenderPipelineCacheSpecializeShaderFactory.
    RenderPipelineRasterization rasterizationType : 2;
    bool emulateCoverageMask : 1;
};

struct RenderPassAttachmentDesc
{
    RenderPassAttachmentDesc();
    // Set default values
    void reset();

    bool equalIgnoreLoadStoreOptions(const RenderPassAttachmentDesc &other) const;
    bool operator==(const RenderPassAttachmentDesc &other) const;

    ANGLE_INLINE bool hasImplicitMSTexture() const { return implicitMSTexture.get(); }

    TextureRef texture;
    // Implicit multisample texture that will be rendered into and discarded at the end of
    // a render pass. Its result will be resolved into normal texture above.
    TextureRef implicitMSTexture;
    MipmapNativeLevel level;
    uint32_t sliceOrDepth;

    // This attachment is blendable or not.
    bool blendable;

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
    MTLClearColor clearColor = {0, 0, 0, 0};
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

    void convertToMetalDesc(MTLRenderPassDescriptor *objCDesc) const;

    // This will populate the RenderPipelineOutputDesc with default blend state and
    // MTLColorWriteMaskAll
    void populateRenderPipelineOutputDesc(RenderPipelineOutputDesc *outDesc) const;
    // This will populate the RenderPipelineOutputDesc with default blend state and the specified
    // MTLColorWriteMask
    void populateRenderPipelineOutputDesc(const WriteMaskArray &writeMaskArray,
                                          RenderPipelineOutputDesc *outDesc) const;
    // This will populate the RenderPipelineOutputDesc with the specified blend state
    void populateRenderPipelineOutputDesc(const BlendDescArray &blendDescArray,
                                          RenderPipelineOutputDesc *outDesc) const;

    bool equalIgnoreLoadStoreOptions(const RenderPassDesc &other) const;
    bool operator==(const RenderPassDesc &other) const;
    inline bool operator!=(const RenderPassDesc &other) const { return !(*this == other); }

    uint32_t numColorAttachments = 0;
    uint32_t sampleCount         = 1;
};

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
struct hash<rx::mtl::HashableVertexDesc>
{
    size_t operator()(const rx::mtl::HashableVertexDesc &key) const { return key.hash(); }
};

template <>
struct hash<rx::mtl::RenderPipelineDesc>
{
    size_t operator()(const rx::mtl::RenderPipelineDesc &key) const { return key.hash(); }
};

}  // namespace std

namespace rx
{
namespace mtl
{

// Abstract factory to create specialized vertex & fragment shaders based on RenderPipelineDesc.
class RenderPipelineCacheSpecializeShaderFactory
{
  public:
    virtual ~RenderPipelineCacheSpecializeShaderFactory() = default;

    // Get specialized shader for the render pipeline cache.
    virtual angle::Result getSpecializedShader(Context *context,
                                               gl::ShaderType shaderType,
                                               const RenderPipelineDesc &renderPipelineDesc,
                                               id<MTLFunction> *shaderOut) = 0;
    // Check whether specialized shaders is required for the specified RenderPipelineDesc.
    // If not, the render pipeline cache will use the supplied non-specialized shaders.
    virtual bool hasSpecializedShader(gl::ShaderType shaderType,
                                      const RenderPipelineDesc &renderPipelineDesc) = 0;
};

// Render pipeline state cache per shader program.
class RenderPipelineCache final : angle::NonCopyable
{
  public:
    RenderPipelineCache();
    RenderPipelineCache(RenderPipelineCacheSpecializeShaderFactory *specializedShaderFactory);
    ~RenderPipelineCache();

    // Set non-specialized vertex/fragment shader to be used by render pipeline cache to create
    // render pipeline state. If the internal
    // RenderPipelineCacheSpecializeShaderFactory.hasSpecializedShader() returns false for a
    // particular RenderPipelineDesc, the render pipeline cache will use the non-specialized
    // shaders.
    void setVertexShader(Context *context, id<MTLFunction> shader);
    void setFragmentShader(Context *context, id<MTLFunction> shader);

    // Get non-specialized shaders supplied via set*Shader().
    id<MTLFunction> getVertexShader() { return mVertexShader; }
    id<MTLFunction> getFragmentShader() { return mFragmentShader; }

    AutoObjCPtr<id<MTLRenderPipelineState>> getRenderPipelineState(ContextMtl *context,
                                                                   const RenderPipelineDesc &desc);

    void clear();

  protected:
    // Non-specialized vertex shader
    AutoObjCPtr<id<MTLFunction>> mVertexShader;
    // Non-specialized fragment shader
    AutoObjCPtr<id<MTLFunction>> mFragmentShader;

  private:
    void clearPipelineStates();
    void recreatePipelineStates(Context *context);
    AutoObjCPtr<id<MTLRenderPipelineState>> insertRenderPipelineState(
        Context *context,
        const RenderPipelineDesc &desc);
    AutoObjCPtr<id<MTLRenderPipelineState>> createRenderPipelineState(
        Context *context,
        const RenderPipelineDesc &desc);

    // One table with default attrib and one table without.
    angle::HashMap<RenderPipelineDesc, AutoObjCPtr<id<MTLRenderPipelineState>>>
        mRenderPipelineStates;

    RenderPipelineCacheSpecializeShaderFactory *mSpecializedShaderFactory;
};

class StateCache final : angle::NonCopyable
{
  public:
    StateCache();
    ~StateCache();

    // Null depth stencil state has depth/stecil read & write disabled.
    inline AutoObjCPtr<id<MTLDepthStencilState>> getNullDepthStencilState(Context *context)
    {
        return getNullDepthStencilState(context->getMetalDevice());
    }
    AutoObjCPtr<id<MTLDepthStencilState>> getNullDepthStencilState(id<MTLDevice> device);
    AutoObjCPtr<id<MTLDepthStencilState>> getDepthStencilState(id<MTLDevice> device,
                                                               const DepthStencilDesc &desc);
    AutoObjCPtr<id<MTLSamplerState>> getSamplerState(id<MTLDevice> device, const SamplerDesc &desc);
    // Null sampler state uses default SamplerDesc
    AutoObjCPtr<id<MTLSamplerState>> getNullSamplerState(Context *context);
    AutoObjCPtr<id<MTLSamplerState>> getNullSamplerState(id<MTLDevice> device);
    void clear();

  private:
    AutoObjCPtr<id<MTLDepthStencilState>> mNullDepthStencilState = nil;
    angle::HashMap<DepthStencilDesc, AutoObjCPtr<id<MTLDepthStencilState>>> mDepthStencilStates;
    angle::HashMap<SamplerDesc, AutoObjCPtr<id<MTLSamplerState>>> mSamplerStates;
};

}  // namespace mtl
}  // namespace rx

static inline bool operator==(const rx::mtl::VertexDesc &lhs, const rx::mtl::VertexDesc &rhs)
{
    for (uint8_t i = 0; i < ArraySize(lhs.attributes); ++i)
    {
        if (lhs.attributes[i] != rhs.attributes[i])
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

#endif /* LIBANGLE_RENDERER_METAL_MTL_STATE_CACHE_H_ */
