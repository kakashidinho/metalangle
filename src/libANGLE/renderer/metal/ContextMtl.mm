//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "libANGLE/renderer/metal/ContextMtl.h"

#include <TargetConditionals.h>

#include "common/debug.h"
#include "libANGLE/renderer/metal/BufferMtl.h"
#include "libANGLE/renderer/metal/CompilerMtl.h"
#include "libANGLE/renderer/metal/FrameBufferMtl.h"
#include "libANGLE/renderer/metal/ProgramMtl.h"
#include "libANGLE/renderer/metal/RenderBufferMtl.h"
#include "libANGLE/renderer/metal/RendererMtl.h"
#include "libANGLE/renderer/metal/ShaderMtl.h"
#include "libANGLE/renderer/metal/TextureMtl.h"
#include "libANGLE/renderer/metal/VertexArrayMtl.h"
#include "libANGLE/renderer/metal/mtl_command_buffer.h"
#include "libANGLE/renderer/metal/mtl_format_utils.h"
#include "libANGLE/renderer/metal/mtl_utils.h"

namespace rx
{

ContextMtl::ContextMtl(const gl::State &state, gl::ErrorSet *errorSet, RendererMtl *renderer)
    : ContextImpl(state, errorSet),
      mtl::Context(renderer),
      mCmdBuffer(&renderer->cmdQueue()),
      mRenderEncoder(&mCmdBuffer),
      mBlitEncoder(&mCmdBuffer),
      mComputeEncoder(&mCmdBuffer)
{}

ContextMtl::~ContextMtl() {}

angle::Result ContextMtl::initialize()
{
    initializeCaps();

    mBlendDesc.set();
    mDepthStencilDesc.set();

    return angle::Result::Continue;
}

void ContextMtl::onDestroy(const gl::Context *context) {}

// Flush and finish.
angle::Result ContextMtl::flush(const gl::Context *context)
{
    flushCommandBufer();
    return angle::Result::Continue;
}
angle::Result ContextMtl::finish(const gl::Context *context)
{
    ANGLE_TRY(finishCommandBuffer());
    return angle::Result::Continue;
}

// Drawing methods.
angle::Result ContextMtl::drawArrays(const gl::Context *context,
                                     gl::PrimitiveMode mode,
                                     GLint first,
                                     GLsizei count)
{
    if (mCullAllPolygons && mtl::IsPolygonPrimitiveType(mode))
    {
        return angle::Result::Continue;
    }

    MTLPrimitiveType mtlType = mtl::GetPrimitiveType(mode);

    ANGLE_TRY(
        setupDraw(context, mode, first, count, 1, gl::DrawElementsType::InvalidEnum, nullptr));

    mRenderEncoder.draw(mtlType, first, count);

    return angle::Result::Continue;
}
angle::Result ContextMtl::drawArraysInstanced(const gl::Context *context,
                                              gl::PrimitiveMode mode,
                                              GLint first,
                                              GLsizei count,
                                              GLsizei instanceCount)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return angle::Result::Stop;
}

angle::Result ContextMtl::drawArraysInstancedBaseInstance(const gl::Context *context,
                                                          gl::PrimitiveMode mode,
                                                          GLint first,
                                                          GLsizei count,
                                                          GLsizei instanceCount,
                                                          GLuint baseInstance)
{
    // TODO(hqle)
    UNIMPLEMENTED();
    return angle::Result::Stop;
}

angle::Result ContextMtl::drawElements(const gl::Context *context,
                                       gl::PrimitiveMode mode,
                                       GLsizei count,
                                       gl::DrawElementsType type,
                                       const void *indices)
{
    if (mCullAllPolygons && mtl::IsPolygonPrimitiveType(mode))
    {
        return angle::Result::Continue;
    }

    const gl::Buffer *glElementArrayBuffer = mVertexArray->getState().getElementArrayBuffer();

    size_t convertedOffset = reinterpret_cast<size_t>(indices);
    if (!glElementArrayBuffer)
    {
        ANGLE_TRY(mVertexArray->streamIndexBufferFromClient(context, type, count, indices));
        convertedOffset = mVertexArray->getElementArrayBufferOffset();
    }
    else
    {
        bool needConversion = type == gl::DrawElementsType::UnsignedByte ||
                              (convertedOffset % kIndexBufferOffsetAlignment) != 0;
        if (needConversion)
        {
            BufferMtl *acualBuffer = mtl::GetImpl(glElementArrayBuffer);
            ANGLE_TRY(
                mVertexArray->convertIndexBuffer(context, type, acualBuffer, convertedOffset));
            convertedOffset = mVertexArray->getElementArrayBufferOffset();
        }
    }

    BufferHolderMtl *idxBuffer = mVertexArray->getElementArrayBuffer();
    ASSERT(idxBuffer);
    ASSERT((convertedOffset % kIndexBufferOffsetAlignment) == 0);

    ANGLE_TRY(setupDraw(context, mode, 0, count, 1, type, indices));

    MTLPrimitiveType mtlType = mtl::GetPrimitiveType(mode);

    gl::DrawElementsType convertedType = type;
    if (type == gl::DrawElementsType::UnsignedByte)
    {
        // This buffer is already converted to ushort indices above
        convertedType = gl::DrawElementsType::UnsignedShort;
    }

    MTLIndexType mtlIdxType = mtl::GetIndexType(convertedType);

    mRenderEncoder.drawIndexed(mtlType, count, mtlIdxType, idxBuffer->getCurrentBuffer(context),
                               convertedOffset);

    return angle::Result::Continue;
}
angle::Result ContextMtl::drawElementsInstanced(const gl::Context *context,
                                                gl::PrimitiveMode mode,
                                                GLsizei count,
                                                gl::DrawElementsType type,
                                                const void *indices,
                                                GLsizei instanceCount)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return angle::Result::Stop;
}
angle::Result ContextMtl::drawElementsInstancedBaseVertexBaseInstance(const gl::Context *context,
                                                                      gl::PrimitiveMode mode,
                                                                      GLsizei count,
                                                                      gl::DrawElementsType type,
                                                                      const void *indices,
                                                                      GLsizei instances,
                                                                      GLint baseVertex,
                                                                      GLuint baseInstance)
{
    // TODO(hqle)
    UNIMPLEMENTED();
    return angle::Result::Stop;
}
angle::Result ContextMtl::drawRangeElements(const gl::Context *context,
                                            gl::PrimitiveMode mode,
                                            GLuint start,
                                            GLuint end,
                                            GLsizei count,
                                            gl::DrawElementsType type,
                                            const void *indices)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return angle::Result::Stop;
}
angle::Result ContextMtl::drawArraysIndirect(const gl::Context *context,
                                             gl::PrimitiveMode mode,
                                             const void *indirect)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return angle::Result::Stop;
}
angle::Result ContextMtl::drawElementsIndirect(const gl::Context *context,
                                               gl::PrimitiveMode mode,
                                               gl::DrawElementsType type,
                                               const void *indirect)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return angle::Result::Stop;
}

// Device loss
gl::GraphicsResetStatus ContextMtl::getResetStatus()
{
    return gl::GraphicsResetStatus::NoError;
}

// Vendor and description strings.
std::string ContextMtl::getVendorString() const
{
    return getRenderer()->getVendorString();
}
std::string ContextMtl::getRendererDescription() const
{
    return getRenderer()->getRendererDescription();
}

// EXT_debug_marker
void ContextMtl::insertEventMarker(GLsizei length, const char *marker)
{
    // TODO(hqle)
}
void ContextMtl::pushGroupMarker(GLsizei length, const char *marker)
{
    // TODO(hqle)
}
void ContextMtl::popGroupMarker()
{
    // TODO(hqle
}

// KHR_debug
void ContextMtl::pushDebugGroup(GLenum source, GLuint id, const std::string &message)
{
    // TODO(hqle)
}
void ContextMtl::popDebugGroup()
{
    // TODO(hqle)
}

// State sync with dirty bits.
angle::Result ContextMtl::syncState(const gl::Context *context,
                                    const gl::State::DirtyBits &dirtyBits,
                                    const gl::State::DirtyBits &bitMask)
{
    const gl::State &glState = context->getState();

    for (size_t dirtyBit : dirtyBits)
    {
        switch (dirtyBit)
        {
            case gl::State::DIRTY_BIT_SCISSOR_TEST_ENABLED:
            case gl::State::DIRTY_BIT_SCISSOR:
                updateScissor(glState);
                break;
            case gl::State::DIRTY_BIT_VIEWPORT:
            {
                FramebufferMtl *framebufferMtl = mtl::GetImpl(glState.getDrawFramebuffer());
                updateViewport(framebufferMtl, glState.getViewport(), glState.getNearPlane(),
                               glState.getFarPlane());
                // Update the scissor, which will be constrained to the viewport
                updateScissor(glState);
                break;
            }
            case gl::State::DIRTY_BIT_DEPTH_RANGE:
                updateDepthRange(glState.getNearPlane(), glState.getFarPlane());
                break;
            case gl::State::DIRTY_BIT_BLEND_COLOR:
                mDirtyBits.set(DIRTY_BIT_BLEND_COLOR);
                break;
            case gl::State::DIRTY_BIT_BLEND_ENABLED:
                mBlendDesc.updateBlendEnabled(glState.getBlendState());
                invalidateRenderPipeline();
                break;
            case gl::State::DIRTY_BIT_BLEND_FUNCS:
                mBlendDesc.updateBlendFactors(glState.getBlendState());
                invalidateRenderPipeline();
                break;
            case gl::State::DIRTY_BIT_BLEND_EQUATIONS:
                mBlendDesc.updateBlendOps(glState.getBlendState());
                invalidateRenderPipeline();
                break;
            case gl::State::DIRTY_BIT_COLOR_MASK:
                mBlendDesc.updateWriteMask(glState.getBlendState());
                invalidateRenderPipeline();
                break;
            case gl::State::DIRTY_BIT_SAMPLE_ALPHA_TO_COVERAGE_ENABLED:
                // TODO(hqle): MSAA support
                break;
            case gl::State::DIRTY_BIT_SAMPLE_COVERAGE_ENABLED:
                // TODO(hqle): MSAA support
                break;
            case gl::State::DIRTY_BIT_SAMPLE_COVERAGE:
                // TODO(hqle): MSAA support
                break;
            case gl::State::DIRTY_BIT_SAMPLE_MASK_ENABLED:
                // TODO(hqle): MSAA support
                break;
            case gl::State::DIRTY_BIT_SAMPLE_MASK:
                // TODO(hqle): MSAA support
                break;
            case gl::State::DIRTY_BIT_DEPTH_TEST_ENABLED:
                mDepthStencilDesc.updateDepthTestEnabled(glState.getDepthStencilState());
                mDirtyBits.set(DIRTY_BIT_DEPTH_STENCIL_DESC);
                break;
            case gl::State::DIRTY_BIT_DEPTH_FUNC:
                mDepthStencilDesc.updateDepthCompareFunc(glState.getDepthStencilState());
                mDirtyBits.set(DIRTY_BIT_DEPTH_STENCIL_DESC);
                break;
            case gl::State::DIRTY_BIT_DEPTH_MASK:
                mDepthStencilDesc.updateDepthWriteEnabled(glState.getDepthStencilState());
                mDirtyBits.set(DIRTY_BIT_DEPTH_STENCIL_DESC);
                break;
            case gl::State::DIRTY_BIT_STENCIL_TEST_ENABLED:
                mDepthStencilDesc.updateStencilTestEnabled(glState.getDepthStencilState());
                mDirtyBits.set(DIRTY_BIT_DEPTH_STENCIL_DESC);
                break;
            case gl::State::DIRTY_BIT_STENCIL_FUNCS_FRONT:
                mDepthStencilDesc.updateStencilFrontFuncs(glState.getDepthStencilState());
                mDirtyBits.set(DIRTY_BIT_DEPTH_STENCIL_DESC);
                mDirtyBits.set(DIRTY_BIT_STENCIL_REF);
                break;
            case gl::State::DIRTY_BIT_STENCIL_FUNCS_BACK:
                mDepthStencilDesc.updateStencilBackFuncs(glState.getDepthStencilState());
                mDirtyBits.set(DIRTY_BIT_DEPTH_STENCIL_DESC);
                mDirtyBits.set(DIRTY_BIT_STENCIL_REF);
                break;
            case gl::State::DIRTY_BIT_STENCIL_OPS_FRONT:
                mDepthStencilDesc.updateStencilFrontOps(glState.getDepthStencilState());
                mDirtyBits.set(DIRTY_BIT_DEPTH_STENCIL_DESC);
                break;
            case gl::State::DIRTY_BIT_STENCIL_OPS_BACK:
                mDepthStencilDesc.updateStencilBackOps(glState.getDepthStencilState());
                mDirtyBits.set(DIRTY_BIT_DEPTH_STENCIL_DESC);
                break;
            case gl::State::DIRTY_BIT_STENCIL_WRITEMASK_FRONT:
                mDepthStencilDesc.updateStencilFrontWriteMask(glState.getDepthStencilState());
                mDirtyBits.set(DIRTY_BIT_DEPTH_STENCIL_DESC);
                break;
            case gl::State::DIRTY_BIT_STENCIL_WRITEMASK_BACK:
                mDepthStencilDesc.updateStencilBackWriteMask(glState.getDepthStencilState());
                mDirtyBits.set(DIRTY_BIT_DEPTH_STENCIL_DESC);
                break;
            case gl::State::DIRTY_BIT_CULL_FACE_ENABLED:
            case gl::State::DIRTY_BIT_CULL_FACE:
                updateCullMode(glState);
                break;
            case gl::State::DIRTY_BIT_FRONT_FACE:
                updateFrontFace(glState);
                break;
            case gl::State::DIRTY_BIT_POLYGON_OFFSET_FILL_ENABLED:
            case gl::State::DIRTY_BIT_POLYGON_OFFSET:
                updateDepthBias(glState);
                break;
            case gl::State::DIRTY_BIT_RASTERIZER_DISCARD_ENABLED:
                // TODO(hqle): ES 3.0 feature.
                break;
            case gl::State::DIRTY_BIT_LINE_WIDTH:
                // Do nothing
                break;
            case gl::State::DIRTY_BIT_PRIMITIVE_RESTART_ENABLED:
                // TODO(hqle): ES 3.0 feature.
                break;
            case gl::State::DIRTY_BIT_CLEAR_COLOR:
                mClearColor.red   = glState.getColorClearValue().red;
                mClearColor.green = glState.getColorClearValue().green;
                mClearColor.blue  = glState.getColorClearValue().blue;
                mClearColor.alpha = glState.getColorClearValue().alpha;
                break;
            case gl::State::DIRTY_BIT_CLEAR_DEPTH:
                break;
            case gl::State::DIRTY_BIT_CLEAR_STENCIL:
                break;
            case gl::State::DIRTY_BIT_UNPACK_STATE:
                // This is a no-op, its only important to use the right unpack state when we do
                // setImage or setSubImage in TextureVk, which is plumbed through the frontend call
                break;
            case gl::State::DIRTY_BIT_UNPACK_BUFFER_BINDING:
                break;
            case gl::State::DIRTY_BIT_PACK_STATE:
                // This is a no-op, its only important to use the right pack state when we do
                // call readPixels later on.
                break;
            case gl::State::DIRTY_BIT_PACK_BUFFER_BINDING:
                break;
            case gl::State::DIRTY_BIT_DITHER_ENABLED:
                break;
            case gl::State::DIRTY_BIT_GENERATE_MIPMAP_HINT:
                break;
            case gl::State::DIRTY_BIT_SHADER_DERIVATIVE_HINT:
                break;
            case gl::State::DIRTY_BIT_READ_FRAMEBUFFER_BINDING:
                break;
            case gl::State::DIRTY_BIT_DRAW_FRAMEBUFFER_BINDING:
                updateDrawFrameBufferBinding(context);
                break;
            case gl::State::DIRTY_BIT_RENDERBUFFER_BINDING:
                break;
            case gl::State::DIRTY_BIT_VERTEX_ARRAY_BINDING:
                updateVertexArray(context);
                break;
            case gl::State::DIRTY_BIT_DRAW_INDIRECT_BUFFER_BINDING:
                break;
            case gl::State::DIRTY_BIT_DISPATCH_INDIRECT_BUFFER_BINDING:
                break;
            case gl::State::DIRTY_BIT_PROGRAM_BINDING:
                mProgram = mtl::GetImpl(glState.getProgram());
                break;
            case gl::State::DIRTY_BIT_PROGRAM_EXECUTABLE:
                updateProgramExecutable(context);
                break;
            case gl::State::DIRTY_BIT_TEXTURE_BINDINGS:
                invalidateCurrentTextures();
                break;
            case gl::State::DIRTY_BIT_SAMPLER_BINDINGS:
                invalidateCurrentTextures();
                break;
            case gl::State::DIRTY_BIT_TRANSFORM_FEEDBACK_BINDING:
                // Nothing to do.
                break;
            case gl::State::DIRTY_BIT_SHADER_STORAGE_BUFFER_BINDING:
                // TODO(hqle): ES 3.0 feature.
                break;
            case gl::State::DIRTY_BIT_UNIFORM_BUFFER_BINDINGS:
                // TODO(hqle): ES 3.0 feature.
                break;
            case gl::State::DIRTY_BIT_ATOMIC_COUNTER_BUFFER_BINDING:
                break;
            case gl::State::DIRTY_BIT_IMAGE_BINDINGS:
                break;
            case gl::State::DIRTY_BIT_MULTISAMPLING:
                // TODO(hqle): MSAA feature.
                break;
            case gl::State::DIRTY_BIT_SAMPLE_ALPHA_TO_ONE:
                // TODO(syoussefi): this is part of EXT_multisample_compatibility.
                // TODO(hqle): MSAA feature.
                break;
            case gl::State::DIRTY_BIT_COVERAGE_MODULATION:
                break;
            case gl::State::DIRTY_BIT_PATH_RENDERING:
                break;
            case gl::State::DIRTY_BIT_FRAMEBUFFER_SRGB:
                break;
            case gl::State::DIRTY_BIT_CURRENT_VALUES:
            {
                invalidateDefaultAttributes(glState.getAndResetDirtyCurrentValues());
                break;
            }
            case gl::State::DIRTY_BIT_PROVOKING_VERTEX:
                break;
            default:
                UNREACHABLE();
                break;
        }
    }

    return angle::Result::Continue;
}

// Disjoint timer queries
GLint ContextMtl::getGPUDisjoint()
{
    // TODO(hqle)
    UNIMPLEMENTED();
    return 0;
}
GLint64 ContextMtl::getTimestamp()
{
    // TODO(hqle)
    UNIMPLEMENTED();
    return 0;
}

// Context switching
angle::Result ContextMtl::onMakeCurrent(const gl::Context *context)
{
    invalidateState(context);
    // TODO(hqle): More work to do?
    return angle::Result::Continue;
}
angle::Result ContextMtl::onUnMakeCurrent(const gl::Context *context)
{
    return angle::Result::Continue;
}

// Native capabilities, unmodified by gl::Context.
gl::Caps ContextMtl::getNativeCaps() const
{
    initializeCaps();
    return mNativeCaps;
}
const gl::TextureCapsMap &ContextMtl::getNativeTextureCaps() const
{
    initializeCaps();
    return mNativeTextureCaps;
}
const gl::Extensions &ContextMtl::getNativeExtensions() const
{
    initializeCaps();
    return mNativeExtensions;
}
const gl::Limitations &ContextMtl::getNativeLimitations() const
{
    return getRenderer()->getNativeLimitations();
}

// Shader creation
CompilerImpl *ContextMtl::createCompiler()
{
    return new CompilerMtl();
}
ShaderImpl *ContextMtl::createShader(const gl::ShaderState &state)
{
    return new ShaderMtl(state);
}
ProgramImpl *ContextMtl::createProgram(const gl::ProgramState &state)
{
    return new ProgramMtl(state);
}

// Framebuffer creation
FramebufferImpl *ContextMtl::createFramebuffer(const gl::FramebufferState &state)
{
    return new FramebufferMtl(state);
}

// Texture creation
TextureImpl *ContextMtl::createTexture(const gl::TextureState &state)
{
    return new TextureMtl(state);
}

// Renderbuffer creation
RenderbufferImpl *ContextMtl::createRenderbuffer(const gl::RenderbufferState &state)
{
    return new RenderbufferMtl(state);
}

// Buffer creation
BufferImpl *ContextMtl::createBuffer(const gl::BufferState &state)
{
    return new BufferMtl(state);
}

// Vertex Array creation
VertexArrayImpl *ContextMtl::createVertexArray(const gl::VertexArrayState &state)
{
    return new VertexArrayMtl(state, this);
}

// Query and Fence creation
QueryImpl *ContextMtl::createQuery(gl::QueryType type)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return nullptr;
}
FenceNVImpl *ContextMtl::createFenceNV()
{
    // TODO(hqle)
    UNIMPLEMENTED();
    return nullptr;
}
SyncImpl *ContextMtl::createSync()
{
    // TODO(hqle)
    UNIMPLEMENTED();
    return nullptr;
}

// Transform Feedback creation
TransformFeedbackImpl *ContextMtl::createTransformFeedback(const gl::TransformFeedbackState &state)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return nullptr;
}

// Sampler object creation
SamplerImpl *ContextMtl::createSampler(const gl::SamplerState &state)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return nullptr;
}

// Program Pipeline object creation
ProgramPipelineImpl *ContextMtl::createProgramPipeline(const gl::ProgramPipelineState &data)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return nullptr;
}

// Path object creation
std::vector<PathImpl *> ContextMtl::createPaths(GLsizei)
{
    // TODO(hqle)
    UNIMPLEMENTED();
    return std::vector<PathImpl *>();
}

// Memory object creation.
MemoryObjectImpl *ContextMtl::createMemoryObject()
{
    // TODO(hqle)
    UNIMPLEMENTED();
    return nullptr;
}

// Semaphore creation.
SemaphoreImpl *ContextMtl::createSemaphore()
{
    // TODO(hqle)
    UNIMPLEMENTED();
    return nullptr;
}

OverlayImpl *ContextMtl::createOverlay(const gl::OverlayState &state)
{
    // TODO(hqle)
    UNIMPLEMENTED();
    return nullptr;
}

angle::Result ContextMtl::dispatchCompute(const gl::Context *context,
                                          GLuint numGroupsX,
                                          GLuint numGroupsY,
                                          GLuint numGroupsZ)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return angle::Result::Stop;
}
angle::Result ContextMtl::dispatchComputeIndirect(const gl::Context *context, GLintptr indirect)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return angle::Result::Stop;
}

angle::Result ContextMtl::memoryBarrier(const gl::Context *context, GLbitfield barriers)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return angle::Result::Stop;
}
angle::Result ContextMtl::memoryBarrierByRegion(const gl::Context *context, GLbitfield barriers)
{
    // TODO(hqle): ES 3.0
    UNIMPLEMENTED();
    return angle::Result::Stop;
}

// override mtl::ErrorHandler
void ContextMtl::handleError(GLenum glErrorCode,
                             const char *file,
                             const char *function,
                             unsigned int line)
{
    std::stringstream errorStream;
    errorStream << "Metal backend encountered an error. Code=" << glErrorCode << ".";

    mErrors->handleError(glErrorCode, errorStream.str().c_str(), file, function, line);
}

void ContextMtl::handleError(NSError *nserror,
                             const char *file,
                             const char *function,
                             unsigned int line)
{
    if (!nserror)
    {
        return;
    }

    std::stringstream errorStream;
    errorStream << "Metal backend encountered an error: \n"
                << nserror.localizedDescription.UTF8String;

    mErrors->handleError(GL_INVALID_OPERATION, errorStream.str().c_str(), file, function, line);
}

void ContextMtl::invalidateState(const gl::Context *context)
{
    mDirtyBits.set();

    invalidateDefaultAttributes(context->getStateCache().getActiveDefaultAttribsMask());
}

void ContextMtl::invalidateDefaultAttribute(size_t attribIndex)
{
    mDirtyDefaultAttribsMask.set(attribIndex);
    mDirtyBits.set(DIRTY_BIT_DEFAULT_ATTRIBS);
}

void ContextMtl::invalidateDefaultAttributes(const gl::AttributesMask &dirtyMask)
{
    if (dirtyMask.any())
    {
        mDirtyDefaultAttribsMask |= dirtyMask;
        mDirtyBits.set(DIRTY_BIT_DEFAULT_ATTRIBS);
    }
}

void ContextMtl::invalidateCurrentTextures()
{
    mDirtyBits.set(DIRTY_BIT_TEXTURES);
}

void ContextMtl::invalidateDriverUniforms()
{
    mDirtyBits.set(DIRTY_BIT_DRIVER_UNIFORMS);
}

void ContextMtl::invalidateRenderPipeline()
{
    mDirtyBits.set(DIRTY_BIT_RENDER_PIPELINE);
}

const MTLClearColor &ContextMtl::getClearColorValue() const
{
    return mClearColor;
}
MTLColorWriteMask ContextMtl::getColorMask() const
{
    return mBlendDesc.writeMask;
}
float ContextMtl::getClearDepthValue() const
{
    return getState().getDepthClearValue();
}
uint32_t ContextMtl::getClearStencilValue() const
{
    return static_cast<uint32_t>(getState().getStencilClearValue());
}
uint32_t ContextMtl::getStencilMask() const
{
    return getState().getDepthStencilState().stencilWritemask;
}

bool ContextMtl::isDepthWriteEnabled() const
{
    return mDepthStencilDesc.depthWriteEnabled;
}

void ContextMtl::endEncoding(mtl::RenderCommandEncoder *encoder)
{
    encoder->endEncoding();
}

void ContextMtl::endEncoding(mtl::BlitCommandEncoder *encoder)
{
    encoder->endEncoding();
}

void ContextMtl::endEncoding(mtl::ComputeCommandEncoder *encoder)
{
    encoder->endEncoding();
}

void ContextMtl::endEncoding(bool forceSaveRenderPassContent)
{
    if (mRenderEncoder.valid())
    {
        if (forceSaveRenderPassContent)
        {
            // Save the work in progress.
            mRenderEncoder.setColorStoreAction(MTLStoreActionStore);
            mRenderEncoder.setDepthStencilStoreAction(MTLStoreActionStore, MTLStoreActionStore);
        }

        mRenderEncoder.endEncoding();
    }

    if (mBlitEncoder.valid())
    {
        mBlitEncoder.endEncoding();
    }

    if (mComputeEncoder.valid())
    {
        mComputeEncoder.endEncoding();
    }
}

void ContextMtl::flushCommandBufer()
{
    if (!mCmdBuffer.valid())
    {
        return;
    }

    endEncoding(true);
    mCmdBuffer.commit();
}

void ContextMtl::present(const gl::Context *context, id<CAMetalDrawable> presentationDrawable)
{
    ensureCommandBufferValid();

    if (hasStartedRenderPass(mDrawFramebuffer))
    {
        mDrawFramebuffer->onFinishedDrawingToFrameBuffer(context, &mRenderEncoder);
    }

    endEncoding(false);
    mCmdBuffer.present(presentationDrawable);
    mCmdBuffer.commit();
}

angle::Result ContextMtl::finishCommandBuffer()
{
    flushCommandBufer();

    if (mCmdBuffer.valid())
    {
        mCmdBuffer.finish();
    }

    return angle::Result::Continue;
}

bool ContextMtl::hasStartedRenderPass(const mtl::RenderPassDesc &desc)
{
    return mRenderEncoder.valid() &&
           mRenderEncoder.renderPassDesc().equalIgnoreLoadStoreOptions(desc);
}

bool ContextMtl::hasStartedRenderPass(FramebufferMtl *framebuffer)
{
    return framebuffer && hasStartedRenderPass(framebuffer->getRenderPassDesc(this));
}

// Get current render encoder
mtl::RenderCommandEncoder *ContextMtl::getRenderCommandEncoder()
{
    if (!mRenderEncoder.valid())
    {
        return nullptr;
    }

    return &mRenderEncoder;
}

mtl::RenderCommandEncoder *ContextMtl::getCurrentFramebufferRenderCommandEncoder()
{
    if (!mDrawFramebuffer)
    {
        return nullptr;
    }

    return getRenderCommandEncoder(mDrawFramebuffer->getRenderPassDesc(this));
}

mtl::RenderCommandEncoder *ContextMtl::getRenderCommandEncoder(const mtl::RenderPassDesc &desc)
{
    if (hasStartedRenderPass(desc))
    {
        return &mRenderEncoder;
    }

    endEncoding();

    ensureCommandBufferValid();

    // Need to re-apply everything on next draw call.
    mDirtyBits.set();

    return &mRenderEncoder.restart(desc);
}

// Utilities to quickly create render command enconder to a specific texture:
// The previous content of texture will be loaded if clearColor is not provided
mtl::RenderCommandEncoder *ContextMtl::getRenderCommandEncoder(
    mtl::TextureRef textureTarget,
    const gl::ImageIndex &index,
    const Optional<MTLClearColor> &clearColor)
{
    ASSERT(textureTarget && textureTarget->valid());

    mtl::RenderPassDesc rpDesc;

    rpDesc.colorAttachments[0].texture = textureTarget;
    rpDesc.colorAttachments[0].level   = index.getLevelIndex();
    rpDesc.colorAttachments[0].slice   = index.hasLayer() ? index.getLayerIndex() : 0;
    rpDesc.numColorAttachments         = 1;

    if (clearColor.valid())
    {
        rpDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
        rpDesc.colorAttachments[0].clearColor =
            mtl::EmulatedAlphaClearColor(clearColor.value(), textureTarget->getColorWritableMask());
    }

    return getRenderCommandEncoder(rpDesc);
}
// The previous content of texture will be loaded
mtl::RenderCommandEncoder *ContextMtl::getRenderCommandEncoder(mtl::TextureRef textureTarget,
                                                               const gl::ImageIndex &index)
{
    return getRenderCommandEncoder(textureTarget, index, Optional<MTLClearColor>());
}

mtl::BlitCommandEncoder *ContextMtl::getBlitCommandEncoder()
{
    if (mBlitEncoder.valid())
    {
        return &mBlitEncoder;
    }

    endEncoding(true);

    ensureCommandBufferValid();

    return &mBlitEncoder.restart();
}

mtl::ComputeCommandEncoder *ContextMtl::getComputeCommandEncoder()
{
    if (mComputeEncoder.valid())
    {
        return &mComputeEncoder;
    }

    endEncoding(true);

    ensureCommandBufferValid();

    return &mComputeEncoder.restart();
}

void ContextMtl::initializeCaps() const
{
    if (mCapsInitialized)
    {
        return;
    }

    mCapsInitialized = true;
    // Reset
    mNativeCaps = gl::Caps();

    // Fill extension and texture caps
    initializeExtensions();
    initializeTextureCaps();

    // https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf
    mNativeCaps.maxElementIndex  = std::numeric_limits<GLuint>::max() - 1;
    mNativeCaps.max3DTextureSize = 2048;
#if TARGET_OS_OSX
    if ([getMetalDevice() supportsFeatureSet:MTLFeatureSet_macOS_GPUFamily1_v1])
    {
        mNativeCaps.max2DTextureSize          = 16384;
        mNativeCaps.maxVaryingVectors         = 31;
        mNativeCaps.maxVertexOutputComponents = 124;
    }
    else
#else
    if ([getMetalDevice() supportsFeatureSet:MTLFeatureSet_iOS_GPUFamily3_v1])
    {
        mNativeCaps.max2DTextureSize          = 16384;
        mNativeCaps.maxVertexOutputComponents = 124;
        mNativeCaps.maxVaryingVectors         = mNativeCaps.maxVertexOutputComponents / 4;
    }
    else
#endif
    {
        mNativeCaps.max2DTextureSize          = 8192;
        mNativeCaps.maxVertexOutputComponents = 60;
        mNativeCaps.maxVaryingVectors         = mNativeCaps.maxVertexOutputComponents / 4;
    }

    mNativeCaps.maxArrayTextureLayers = 2048;
    mNativeCaps.maxLODBias            = 0;
    mNativeCaps.maxCubeMapTextureSize = mNativeCaps.max2DTextureSize;
    mNativeCaps.maxRenderbufferSize   = mNativeCaps.max2DTextureSize;
    mNativeCaps.minAliasedPointSize   = 1;
    mNativeCaps.maxAliasedPointSize   = 511;

    mNativeCaps.minAliasedLineWidth = 1.0f;
    mNativeCaps.maxAliasedLineWidth = 1.0f;

    mNativeCaps.maxDrawBuffers       = kMaxRenderTargets;
    mNativeCaps.maxFramebufferWidth  = mNativeCaps.max2DTextureSize;
    mNativeCaps.maxFramebufferHeight = mNativeCaps.max2DTextureSize;
    mNativeCaps.maxColorAttachments  = kMaxRenderTargets;
    mNativeCaps.maxViewportWidth     = mNativeCaps.max2DTextureSize;
    mNativeCaps.maxViewportHeight    = mNativeCaps.max2DTextureSize;

    // TODO(hqle): MSAA
    mNativeCaps.maxSampleMaskWords     = 0;
    mNativeCaps.maxColorTextureSamples = 1;
    mNativeCaps.maxDepthTextureSamples = 1;
    mNativeCaps.maxIntegerSamples      = 1;

    mNativeCaps.maxVertexAttributes           = kMaxVertexAttribs;
    mNativeCaps.maxVertexAttribBindings       = kMaxVertexAttribs;
    mNativeCaps.maxVertexAttribRelativeOffset = std::numeric_limits<GLint>::max();
    mNativeCaps.maxVertexAttribStride         = std::numeric_limits<GLint>::max();

    mNativeCaps.maxElementsIndices  = std::numeric_limits<GLuint>::max();
    mNativeCaps.maxElementsVertices = std::numeric_limits<GLuint>::max();

    // Looks like all floats are IEEE according to the docs here:
    mNativeCaps.vertexHighpFloat.setIEEEFloat();
    mNativeCaps.vertexMediumpFloat.setIEEEFloat();
    mNativeCaps.vertexLowpFloat.setIEEEFloat();
    mNativeCaps.fragmentHighpFloat.setIEEEFloat();
    mNativeCaps.fragmentMediumpFloat.setIEEEFloat();
    mNativeCaps.fragmentLowpFloat.setIEEEFloat();

    mNativeCaps.vertexHighpInt.setTwosComplementInt(32);
    mNativeCaps.vertexMediumpInt.setTwosComplementInt(32);
    mNativeCaps.vertexLowpInt.setTwosComplementInt(32);
    mNativeCaps.fragmentHighpInt.setTwosComplementInt(32);
    mNativeCaps.fragmentMediumpInt.setTwosComplementInt(32);
    mNativeCaps.fragmentLowpInt.setTwosComplementInt(32);

    GLuint maxUniformVectors = kDefaultUniformsMaxSize / (sizeof(GLfloat) * 4);

    const GLuint maxUniformComponents = maxUniformVectors * 4;

    // Uniforms are implemented using a uniform buffer, so the max number of uniforms we can
    // support is the max buffer range divided by the size of a single uniform (4X float).
    mNativeCaps.maxVertexUniformVectors                              = maxUniformVectors;
    mNativeCaps.maxShaderUniformComponents[gl::ShaderType::Vertex]   = maxUniformComponents;
    mNativeCaps.maxFragmentUniformVectors                            = maxUniformVectors;
    mNativeCaps.maxShaderUniformComponents[gl::ShaderType::Fragment] = maxUniformComponents;

    // TODO(hqle): support UBO (ES 3.0 feature)
    mNativeCaps.maxShaderUniformBlocks[gl::ShaderType::Vertex]   = 0;
    mNativeCaps.maxShaderUniformBlocks[gl::ShaderType::Fragment] = 0;
    mNativeCaps.maxCombinedUniformBlocks                         = 0;

    // Note that we currently implement textures as combined image+samplers, so the limit is
    // the minimum of supported samplers and sampled images.
    const uint32_t maxPerStageTextures                               = 16;
    mNativeCaps.maxCombinedTextureImageUnits                         = maxPerStageTextures;
    mNativeCaps.maxShaderTextureImageUnits[gl::ShaderType::Fragment] = maxPerStageTextures;
    mNativeCaps.maxShaderTextureImageUnits[gl::ShaderType::Vertex]   = maxPerStageTextures;

    // TODO(hqle): support storage buffer.
    const uint32_t maxPerStageStorageBuffers                     = 0;
    mNativeCaps.maxShaderStorageBlocks[gl::ShaderType::Vertex]   = maxPerStageStorageBuffers;
    mNativeCaps.maxShaderStorageBlocks[gl::ShaderType::Fragment] = maxPerStageStorageBuffers;
    mNativeCaps.maxCombinedShaderStorageBlocks                   = maxPerStageStorageBuffers;

    // Fill in additional limits for UBOs and SSBOs.
    mNativeCaps.maxUniformBufferBindings     = 0;
    mNativeCaps.maxUniformBlockSize          = 0;
    mNativeCaps.uniformBufferOffsetAlignment = 0;

    mNativeCaps.maxShaderStorageBufferBindings     = 0;
    mNativeCaps.maxShaderStorageBlockSize          = 0;
    mNativeCaps.shaderStorageBufferOffsetAlignment = 0;

    // TODO(hqle): support UBO
    for (gl::ShaderType shaderType : gl::kAllGraphicsShaderTypes)
    {
        mNativeCaps.maxCombinedShaderUniformComponents[shaderType] = maxUniformComponents;
    }

    mNativeCaps.maxCombinedShaderOutputResources = 0;

    mNativeCaps.maxTransformFeedbackInterleavedComponents =
        gl::IMPLEMENTATION_MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS;
    mNativeCaps.maxTransformFeedbackSeparateAttributes =
        gl::IMPLEMENTATION_MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS;
    mNativeCaps.maxTransformFeedbackSeparateComponents =
        gl::IMPLEMENTATION_MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS;

    // TODO(hqle): support MSAA.
    mNativeCaps.maxSamples = 1;
}

void ContextMtl::initializeExtensions() const
{
    // Reset
    mNativeExtensions = gl::Extensions();

    // Enable this for simple buffer readback testing, but some functionality is missing.
    // TODO(jmadill): Support full mapBufferRange extension.
    mNativeExtensions.mapBuffer              = true;
    mNativeExtensions.mapBufferRange         = false;
    mNativeExtensions.textureStorage         = false;
    mNativeExtensions.drawBuffers            = false;
    mNativeExtensions.fragDepth              = true;
    mNativeExtensions.framebufferBlit        = false;
    mNativeExtensions.framebufferMultisample = false;
    mNativeExtensions.copyTexture            = false;
    mNativeExtensions.copyCompressedTexture  = false;
    mNativeExtensions.debugMarker            = false;
    mNativeExtensions.robustness             = true;
    mNativeExtensions.textureBorderClamp     = false;  // not implemented yet
    mNativeExtensions.translatedShaderSource = true;
    mNativeExtensions.discardFramebuffer     = true;

    // Enable EXT_blend_minmax
    mNativeExtensions.blendMinMax = true;

    // TODO(hqle)
    mNativeExtensions.eglImage         = false;
    mNativeExtensions.eglImageExternal = false;
    // TODO(geofflang): Support GL_OES_EGL_image_external_essl3. http://anglebug.com/2668
    mNativeExtensions.eglImageExternalEssl3 = false;

    // TODO(hqle)
    mNativeExtensions.memoryObject   = false;
    mNativeExtensions.memoryObjectFd = false;

    mNativeExtensions.semaphore   = false;
    mNativeExtensions.semaphoreFd = false;

    // TODO: Enable this always and emulate instanced draws if any divisor exceeds the maximum
    // supported.  http://anglebug.com/2672
    mNativeExtensions.instancedArraysANGLE = false;

    mNativeExtensions.robustBufferAccessBehavior = false;

    mNativeExtensions.eglSync = false;

    // TODO(hqle): support occlusion query
    mNativeExtensions.occlusionQueryBoolean = false;

    mNativeExtensions.disjointTimerQuery          = false;
    mNativeExtensions.queryCounterBitsTimeElapsed = false;
    mNativeExtensions.queryCounterBitsTimestamp   = false;

    mNativeExtensions.textureFilterAnisotropic = true;
    mNativeExtensions.maxTextureAnisotropy     = 16;

    // TODO(hqle): Support true NPOT textures.
    mNativeExtensions.textureNPOT = false;

    mNativeExtensions.texture3DOES = false;

    mNativeExtensions.standardDerivatives = true;

    mNativeExtensions.elementIndexUint = true;
}

void ContextMtl::initializeTextureCaps() const
{
    mNativeTextureCaps.clear();

    mtl::Format::GenerateTextureCapsMap(this, &mNativeTextureCaps,
                                        &mNativeCaps.compressedTextureFormats);

    // Re-verify texture extensions.
    mNativeExtensions.setTextureExtensionSupport(mNativeTextureCaps);
}

void ContextMtl::ensureCommandBufferValid()
{
    if (!mCmdBuffer.valid())
    {
        mCmdBuffer.restart();
    }

    ASSERT(mCmdBuffer.valid());
}

void ContextMtl::updateViewport(FramebufferMtl *framebufferMtl,
                                const gl::Rectangle &viewport,
                                float nearPlane,
                                float farPlane)
{
    mViewport = mtl::GetViewport(viewport, framebufferMtl->getState().getDimensions().height,
                                 framebufferMtl->flipY(), nearPlane, farPlane);
    mDirtyBits.set(DIRTY_BIT_VIEWPORT);

    invalidateDriverUniforms();
}

void ContextMtl::updateDepthRange(float nearPlane, float farPlane)
{
    mViewport.znear = nearPlane;
    mViewport.zfar  = farPlane;
    mDirtyBits.set(DIRTY_BIT_VIEWPORT);

    invalidateDriverUniforms();
}

void ContextMtl::updateScissor(const gl::State &glState)
{
    FramebufferMtl *framebufferMtl = mtl::GetImpl(glState.getDrawFramebuffer());
    gl::Rectangle renderArea       = framebufferMtl->getCompleteRenderArea();

    // Clip the render area to the viewport.
    gl::Rectangle viewportClippedRenderArea;
    gl::ClipRectangle(renderArea, glState.getViewport(), &viewportClippedRenderArea);

    gl::Rectangle scissoredArea = ClipRectToScissor(getState(), viewportClippedRenderArea, false);
    if (framebufferMtl->flipY())
    {
        scissoredArea.y = renderArea.height - scissoredArea.y - scissoredArea.height;
    }

    mScissorRect = mtl::GetScissorRect(scissoredArea);
    mDirtyBits.set(DIRTY_BIT_SCISSOR);
}

void ContextMtl::updateCullMode(const gl::State &glState)
{
    const gl::RasterizerState &rasterState = glState.getRasterizerState();

    mCullAllPolygons = false;
    if (!rasterState.cullFace)
    {
        mCullMode = MTLCullModeNone;
    }
    else
    {
        switch (rasterState.cullMode)
        {
            case gl::CullFaceMode::Back:
                mCullMode = MTLCullModeBack;
                break;
            case gl::CullFaceMode::Front:
                mCullMode = MTLCullModeFront;
                break;
            case gl::CullFaceMode::FrontAndBack:
                mCullAllPolygons = true;
                break;
            default:
                UNREACHABLE();
                break;
        }
    }

    mDirtyBits.set(DIRTY_BIT_CULL_MODE);
}

void ContextMtl::updateFrontFace(const gl::State &glState)
{
    FramebufferMtl *framebufferMtl = mtl::GetImpl(glState.getDrawFramebuffer());
    mWinding =
        mtl::GetFontfaceWinding(glState.getRasterizerState().frontFace, !framebufferMtl->flipY());
    mDirtyBits.set(DIRTY_BIT_WINDING);
}

void ContextMtl::updateDepthBias(const gl::State &glState)
{
    mDirtyBits.set(DIRTY_BIT_DEPTH_BIAS);
}

void ContextMtl::updateDrawFrameBufferBinding(const gl::Context *context)
{
    const gl::State &glState = getState();

    auto oldFrameBuffer = mDrawFramebuffer;

    mDrawFramebuffer = mtl::GetImpl(glState.getDrawFramebuffer());

    if (oldFrameBuffer && hasStartedRenderPass(oldFrameBuffer->getRenderPassDesc(this)))
    {
        oldFrameBuffer->onFinishedDrawingToFrameBuffer(context, &mRenderEncoder);
    }

    onDrawFrameBufferChange(context, mDrawFramebuffer);
}

void ContextMtl::onDrawFrameBufferChange(const gl::Context *context, FramebufferMtl *framebuffer)
{
    const gl::State &glState = getState();

    mDirtyBits.set(DIRTY_BIT_DRAW_FRAMEBUFFER);

    updateViewport(framebuffer, glState.getViewport(), glState.getNearPlane(),
                   glState.getFarPlane());
    updateFrontFace(glState);
    updateScissor(glState);

    // Need to re-apply state to RenderCommandEncoder
    invalidateState(context);
}

void ContextMtl::updateProgramExecutable(const gl::Context *context)
{
    // Need to rebind textures
    invalidateCurrentTextures();
    // Need to re-upload default attributes
    invalidateDefaultAttributes(context->getStateCache().getActiveDefaultAttribsMask());
    // Render pipeline need to be re-applied
    invalidateRenderPipeline();
}

void ContextMtl::updateVertexArray(const gl::Context *context)
{
    const gl::State &glState = getState();
    mVertexArray             = mtl::GetImpl(glState.getVertexArray());
    invalidateDefaultAttributes(context->getStateCache().getActiveDefaultAttribsMask());
    invalidateRenderPipeline();
}

angle::Result ContextMtl::updateDefaultAttribute(size_t attribIndex)
{
    const gl::State &glState = mState;
    const gl::VertexAttribCurrentValueData &defaultValue =
        glState.getVertexAttribCurrentValues()[attribIndex];

    constexpr size_t kDefaultGLAttributeValueSize =
        sizeof(gl::VertexAttribCurrentValueData::Values);

    static_assert(kDefaultGLAttributeValueSize == kDefaultAttributeSize,
                  "Unexpected default attribute size");
    memcpy(mDefaultAttributes[attribIndex].values, &defaultValue.Values, kDefaultAttributeSize);

    return angle::Result::Continue;
}

angle::Result ContextMtl::setupDraw(const gl::Context *context,
                                    gl::PrimitiveMode mode,
                                    GLint firstVertex,
                                    GLsizei vertexOrIndexCount,
                                    GLsizei instanceCount,
                                    gl::DrawElementsType indexTypeOrNone,
                                    const void *indices)
{
    if (!mProgram)
    {
        // Is this an error?
        return angle::Result::Continue;
    }

    // Must be called before the command buffer is started.
    if (context->getStateCache().hasAnyActiveClientAttrib())
    {
        ANGLE_TRY(mVertexArray->updateClientAttribs(context, firstVertex, vertexOrIndexCount,
                                                    instanceCount, indexTypeOrNone, indices));
    }

    if (!mRenderEncoder.valid())
    {
        // re-apply everything
        invalidateState(context);
    }

    if (mDirtyBits.test(DIRTY_BIT_DRAW_FRAMEBUFFER))
    {
        // Start new render command encoder
        const mtl::RenderPassDesc &rpDesc = mDrawFramebuffer->getRenderPassDesc(this);
        ANGLE_MTL_CHECK(this, getRenderCommandEncoder(rpDesc));

        // re-apply everything
        invalidateState(context);
    }

    Optional<mtl::RenderPipelineDesc> changedPipelineDesc;
    ANGLE_TRY(checkIfPipelineChanged(context, mode, &changedPipelineDesc));

    bool textureChanged = false;
    for (size_t bit : mDirtyBits)
    {
        switch (bit)
        {
            case DIRTY_BIT_DEFAULT_ATTRIBS:
                ANGLE_TRY(handleDirtyDefaultAttribs(context));
                break;
            case DIRTY_BIT_DRIVER_UNIFORMS:
                ANGLE_TRY(handleDirtyDriverUniforms(context));
                break;
            case DIRTY_BIT_TEXTURES:
                textureChanged = true;
                break;
            case DIRTY_BIT_DEPTH_STENCIL_DESC:
                ANGLE_TRY(handleDirtyDepthStencilState(context));
                break;
            case DIRTY_BIT_DEPTH_BIAS:
                ANGLE_TRY(handleDirtyDepthBias(context));
                break;
            case DIRTY_BIT_STENCIL_REF:
                mRenderEncoder.setStencilRefVals(mState.getStencilRef(),
                                                 mState.getStencilBackRef());
                break;
            case DIRTY_BIT_BLEND_COLOR:
                mRenderEncoder.setBlendColor(
                    mState.getBlendColor().red, mState.getBlendColor().green,
                    mState.getBlendColor().blue, mState.getBlendColor().alpha);
                break;
            case DIRTY_BIT_VIEWPORT:
                mRenderEncoder.setViewport(mViewport);
                break;
            case DIRTY_BIT_SCISSOR:
                mRenderEncoder.setScissorRect(mScissorRect);
                break;
            case DIRTY_BIT_CULL_MODE:
                mRenderEncoder.setCullMode(mCullMode);
                break;
            case DIRTY_BIT_WINDING:
                mRenderEncoder.setFrontFacingWinding(mWinding);
                break;
        }

        mDirtyBits.reset(bit);
    }

    ANGLE_TRY(mProgram->setupDraw(context, &mRenderEncoder, changedPipelineDesc, textureChanged));

    return angle::Result::Continue;
}

angle::Result ContextMtl::handleDirtyDefaultAttribs(const gl::Context *context)
{
    for (size_t attribIndex : mDirtyDefaultAttribsMask)
    {
        ANGLE_TRY(updateDefaultAttribute(attribIndex));
    }

    ASSERT(mRenderEncoder.valid());
    mRenderEncoder.setFragmentData(mDefaultAttributes, kDefaultAttribsBindingIndex);
    mRenderEncoder.setVertexData(mDefaultAttributes, kDefaultAttribsBindingIndex);

    mDirtyDefaultAttribsMask.reset();
    mDirtyBits.reset(DIRTY_BIT_DEFAULT_ATTRIBS);
    return angle::Result::Continue;
}

angle::Result ContextMtl::handleDirtyDriverUniforms(const gl::Context *context)
{
    const gl::Rectangle &glViewport = mState.getViewport();

    float depthRangeNear = mState.getNearPlane();
    float depthRangeFar  = mState.getFarPlane();
    float depthRangeDiff = depthRangeFar - depthRangeNear;

    mDriverUniforms.viewport[0] = glViewport.x;
    mDriverUniforms.viewport[1] = glViewport.y;
    mDriverUniforms.viewport[2] = glViewport.width;
    mDriverUniforms.viewport[3] = glViewport.height;

    mDriverUniforms.halfRenderAreaHeight =
        static_cast<float>(mDrawFramebuffer->getState().getDimensions().height) * 0.5f;
    mDriverUniforms.viewportYScale    = mDrawFramebuffer->flipY() ? -1.0f : 1.0f;
    mDriverUniforms.negViewportYScale = -mDriverUniforms.viewportYScale;

    mDriverUniforms.depthRange[0] = depthRangeNear;
    mDriverUniforms.depthRange[1] = depthRangeFar;
    mDriverUniforms.depthRange[2] = depthRangeDiff;

    ASSERT(mRenderEncoder.valid());
    mRenderEncoder.setFragmentData(mDriverUniforms, kDriverUniformsBindingIndex);
    mRenderEncoder.setVertexData(mDriverUniforms, kDriverUniformsBindingIndex);

    mDirtyBits.reset(DIRTY_BIT_DRIVER_UNIFORMS);
    return angle::Result::Continue;
}

angle::Result ContextMtl::handleDirtyDepthStencilState(const gl::Context *context)
{
    ASSERT(mRenderEncoder.valid());

    // Need to handle the case when render pass doesn't have depth/stencil attachment.
    mtl::DepthStencilDesc dsDesc              = mDepthStencilDesc;
    const mtl::RenderPassDesc &renderPassDesc = mDrawFramebuffer->getRenderPassDesc(this);

    if (!renderPassDesc.depthAttachment.texture)
    {
        dsDesc.depthWriteEnabled    = false;
        dsDesc.depthCompareFunction = MTLCompareFunctionAlways;
    }

    if (!renderPassDesc.stencilAttachment.texture)
    {
        dsDesc.frontFaceStencil.set();
        dsDesc.backFaceStencil.set();
    }

    // Apply depth stencil state
    mRenderEncoder.setDepthStencilState(getRenderer()->getDepthStencilState(dsDesc));

    mDirtyBits.reset(DIRTY_BIT_DEPTH_STENCIL_DESC);
    return angle::Result::Continue;
}

angle::Result ContextMtl::handleDirtyDepthBias(const gl::Context *context)
{
    const gl::RasterizerState &raserState = mState.getRasterizerState();
    ASSERT(mRenderEncoder.valid());
    if (!mState.isPolygonOffsetFillEnabled())
    {
        mRenderEncoder.setDepthBias(0, 0, 0);
    }
    else
    {
        mRenderEncoder.setDepthBias(raserState.polygonOffsetUnits, raserState.polygonOffsetFactor,
                                    0);
    }

    mDirtyBits.reset(DIRTY_BIT_DEPTH_BIAS);
    return angle::Result::Continue;
}

angle::Result ContextMtl::checkIfPipelineChanged(
    const gl::Context *context,
    gl::PrimitiveMode primitiveMode,
    Optional<mtl::RenderPipelineDesc> *changedPipelineDesc)
{
    ASSERT(mRenderEncoder.valid());
    mtl::PrimitiveTopologyClass topologyClass = mtl::GetPrimitiveTopologyClass(primitiveMode);

    bool rppChange = mDirtyBits.test(DIRTY_BIT_RENDER_PIPELINE) ||
                     topologyClass != mRenderPipelineDesc.inputPrimitiveTopology;

    // Obtain RenderPipelineDesc's vertex array descriptor.
    ANGLE_TRY(mVertexArray->setupDraw(context, &mRenderEncoder, &rppChange,
                                      &mRenderPipelineDesc.vertexDescriptor));

    if (rppChange)
    {
        const mtl::RenderPassDesc &renderPassDesc = mDrawFramebuffer->getRenderPassDesc(this);
        // Obtain RenderPipelineDesc's output descriptor.
        renderPassDesc.populateRenderPipelineOutputDesc(mBlendDesc,
                                                        &mRenderPipelineDesc.outputDescriptor);

        mRenderPipelineDesc.inputPrimitiveTopology = topologyClass;

        *changedPipelineDesc = mRenderPipelineDesc;
    }

    return angle::Result::Continue;
}
}
