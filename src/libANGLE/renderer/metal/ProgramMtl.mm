//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// ProgramMtl.mm:
//    Implements the class methods for ProgramMtl.
//

#include "libANGLE/renderer/metal/ProgramMtl.h"

#include <TargetConditionals.h>

#include <sstream>

#include "common/debug.h"
#include "compiler/translator/TranslatorMetal.h"
#include "libANGLE/Context.h"
#include "libANGLE/ProgramLinkedResources.h"
#include "libANGLE/renderer/metal/BufferMtl.h"
#include "libANGLE/renderer/metal/ContextMtl.h"
#include "libANGLE/renderer/metal/DisplayMtl.h"
#include "libANGLE/renderer/metal/TextureMtl.h"
#include "libANGLE/renderer/metal/mtl_glslang_utils.h"
#include "libANGLE/renderer/metal/mtl_utils.h"
#include "libANGLE/renderer/renderer_utils.h"

namespace rx
{

namespace
{

#define SHADER_ENTRY_NAME @"main0"
constexpr char kSpirvCrossSpecConstSuffix[] = "_tmp";

template <typename T>
class ScopedAutoClearVector
{
  public:
    ScopedAutoClearVector(std::vector<T> *array) : mArray(*array) {}
    ~ScopedAutoClearVector() { mArray.clear(); }

  private:
    std::vector<T> &mArray;
};

angle::Result StreamUniformBufferData(ContextMtl *contextMtl,
                                      mtl::BufferPool *dynamicBuffer,
                                      const uint8_t *sourceData,
                                      size_t bytesToAllocate,
                                      size_t sizeToCopy,
                                      mtl::BufferRef *bufferOut,
                                      size_t *bufferOffsetOut)
{
    uint8_t *dst = nullptr;
    dynamicBuffer->releaseInFlightBuffers(contextMtl);
    ANGLE_TRY(dynamicBuffer->allocate(contextMtl, bytesToAllocate, &dst, bufferOut, bufferOffsetOut,
                                      nullptr));
    memcpy(dst, sourceData, sizeToCopy);

    ANGLE_TRY(dynamicBuffer->commit(contextMtl));
    return angle::Result::Continue;
}

void InitDefaultUniformBlock(const std::vector<sh::Uniform> &uniforms,
                             gl::Shader *shader,
                             sh::BlockLayoutMap *blockLayoutMapOut,
                             size_t *blockSizeOut)
{
    if (uniforms.empty())
    {
        *blockSizeOut = 0;
        return;
    }

    sh::Std140BlockEncoder blockEncoder;
    sh::GetUniformBlockInfo(uniforms, "", &blockEncoder, blockLayoutMapOut);

    size_t blockSize = blockEncoder.getCurrentOffset();

    // TODO(jmadill): I think we still need a valid block for the pipeline even if zero sized.
    if (blockSize == 0)
    {
        *blockSizeOut = 0;
        return;
    }

    // Need to round up to multiple of vec4
    *blockSizeOut = roundUp(blockSize, static_cast<size_t>(16));
    return;
}

template <typename T>
void UpdateDefaultUniformBlock(GLsizei count,
                               uint32_t arrayIndex,
                               int componentCount,
                               const T *v,
                               const sh::BlockMemberInfo &layoutInfo,
                               angle::MemoryBuffer *uniformData)
{
    const int elementSize = sizeof(T) * componentCount;

    uint8_t *dst = uniformData->data() + layoutInfo.offset;
    if (layoutInfo.arrayStride == 0 || layoutInfo.arrayStride == elementSize)
    {
        uint32_t arrayOffset = arrayIndex * layoutInfo.arrayStride;
        uint8_t *writePtr    = dst + arrayOffset;
        ASSERT(writePtr + (elementSize * count) <= uniformData->data() + uniformData->size());
        memcpy(writePtr, v, elementSize * count);
    }
    else
    {
        // Have to respect the arrayStride between each element of the array.
        int maxIndex = arrayIndex + count;
        for (int writeIndex = arrayIndex, readIndex = 0; writeIndex < maxIndex;
             writeIndex++, readIndex++)
        {
            const int arrayOffset = writeIndex * layoutInfo.arrayStride;
            uint8_t *writePtr     = dst + arrayOffset;
            const T *readPtr      = v + (readIndex * componentCount);
            ASSERT(writePtr + elementSize <= uniformData->data() + uniformData->size());
            memcpy(writePtr, readPtr, elementSize);
        }
    }
}

template <typename T>
void ReadFromDefaultUniformBlock(int componentCount,
                                 uint32_t arrayIndex,
                                 T *dst,
                                 const sh::BlockMemberInfo &layoutInfo,
                                 const angle::MemoryBuffer *uniformData)
{
    ASSERT(layoutInfo.offset != -1);

    const int elementSize = sizeof(T) * componentCount;
    const uint8_t *source = uniformData->data() + layoutInfo.offset;

    if (layoutInfo.arrayStride == 0 || layoutInfo.arrayStride == elementSize)
    {
        const uint8_t *readPtr = source + arrayIndex * layoutInfo.arrayStride;
        memcpy(dst, readPtr, elementSize);
    }
    else
    {
        // Have to respect the arrayStride between each element of the array.
        const int arrayOffset  = arrayIndex * layoutInfo.arrayStride;
        const uint8_t *readPtr = source + arrayOffset;
        memcpy(dst, readPtr, elementSize);
    }
}

class Std140BlockLayoutEncoderFactory : public gl::CustomBlockLayoutEncoderFactory
{
  public:
    sh::BlockLayoutEncoder *makeEncoder() override { return new sh::Std140BlockEncoder(); }
};

void InitArgumentBufferEncoder(ContextMtl *context,
                               id<MTLFunction> function,
                               ProgramArgumentBufferEncoderMtl *encoder)
{
    encoder->metalArgBufferEncoder =
        [function newArgumentEncoderWithBufferIndex:mtl::kUBOArgumentBufferBindingIndex];
    if (encoder->metalArgBufferEncoder)
    {
        encoder->bufferPool.initialize(context, encoder->metalArgBufferEncoder.get().encodedLength,
                                       4);
    }
}

angle::Result CreateMslShader(ContextMtl *contextMtl,
                              id<MTLLibrary> shaderLib,
                              MTLFunctionConstantValues *funcConstants,
                              gl::InfoLog &infoLog,
                              id<MTLFunction> *shaderOut)
{
    NSError *nsErr = nil;

    auto mtlShader = [shaderLib newFunctionWithName:SHADER_ENTRY_NAME
                                     constantValues:funcConstants
                                              error:&nsErr];
    [mtlShader ANGLE_MTL_AUTORELEASE];
    if (nsErr && !mtlShader)
    {
        std::ostringstream ss;
        ss << "Internal error compiling Metal shader:\n"
           << nsErr.localizedDescription.UTF8String << "\n";

        ERR() << ss.str();

        infoLog << ss.str();

        ANGLE_MTL_CHECK(contextMtl, false, GL_INVALID_OPERATION);
    }

    *shaderOut = mtlShader;

    return angle::Result::Continue;
}

}  // namespace

// ProgramMtl implementation
ProgramMtl::DefaultUniformBlock::DefaultUniformBlock() {}

ProgramMtl::DefaultUniformBlock::~DefaultUniformBlock() = default;

ProgramMtl::ProgramMtl(const gl::ProgramState &state) : ProgramImpl(state) {}

ProgramMtl::~ProgramMtl() {}

void ProgramMtl::destroy(const gl::Context *context)
{
    auto contextMtl = mtl::GetImpl(context);

    reset(contextMtl);
}

void ProgramMtl::reset(ContextMtl *context)
{
    for (auto &block : mDefaultUniformBlocks)
    {
        block.uniformLayout.clear();
    }

    for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
    {
        mMslShaderTranslateInfo[shaderType].hasArgumentBuffer = false;
        for (mtl::SamplerBinding &binding :
             mMslShaderTranslateInfo[shaderType].actualSamplerBindings)
        {
            binding.textureBinding = mtl::kMaxShaderSamplers;
        }

        for (uint32_t &binding : mMslShaderTranslateInfo[shaderType].actualUBOBindings)
        {
            binding = mtl::kMaxShaderBuffers;
        }
    }

    for (ProgramArgumentBufferEncoderMtl &encoder : mVertexArgumentBufferEncoders)
    {
        encoder.metalArgBufferEncoder = nil;
        encoder.bufferPool.destroy(context);
    }
    for (ProgramArgumentBufferEncoderMtl &encoder : mFragmentArgumentBufferEncoders)
    {
        encoder.metalArgBufferEncoder = nil;
        encoder.bufferPool.destroy(context);
    }

    mMetalRenderPipelineCache.clear();
}

void ProgramMtl::saveTranslatedShaders(gl::BinaryOutputStream *stream)
{
    // Write out shader sources for all shader types
    for (const gl::ShaderType shaderType : gl::AllShaderTypes())
    {
        stream->writeString(mTranslatedMslShader[shaderType]);
    }
}

void ProgramMtl::loadTranslatedShaders(gl::BinaryInputStream *stream)
{
    // Read in shader sources for all shader types
    for (const gl::ShaderType shaderType : gl::AllShaderTypes())
    {
        mTranslatedMslShader[shaderType] = stream->readString();
    }
}

std::unique_ptr<rx::LinkEvent> ProgramMtl::load(const gl::Context *context,
                                                gl::BinaryInputStream *stream,
                                                gl::InfoLog &infoLog)
{

    return std::make_unique<LinkEventDone>(linkTranslatedShaders(context, stream, infoLog));
}

void ProgramMtl::save(const gl::Context *context, gl::BinaryOutputStream *stream)
{
    saveTranslatedShaders(stream);
    saveShaderInternalInfo(stream);
    saveDefaultUniformBlocksInfo(stream);
}

void ProgramMtl::setBinaryRetrievableHint(bool retrievable)
{
    UNIMPLEMENTED();
}

void ProgramMtl::setSeparable(bool separable)
{
    UNIMPLEMENTED();
}

std::unique_ptr<LinkEvent> ProgramMtl::link(const gl::Context *context,
                                            const gl::ProgramLinkedResources &resources,
                                            gl::InfoLog &infoLog)
{
    // Link resources before calling GetShaderSource to make sure they are ready for the set/binding
    // assignment done in that function.
    linkResources(resources);

    gl::ShaderMap<std::string> shaderSource;
    mtl::GlslangGetShaderSource(mState, resources, &shaderSource);

    // NOTE(hqle): Parallelize linking.
    return std::make_unique<LinkEventDone>(linkImpl(context, shaderSource, infoLog));
}

angle::Result ProgramMtl::linkImpl(const gl::Context *glContext,
                                   const gl::ShaderMap<std::string> &shaderSource,
                                   gl::InfoLog &infoLog)
{
    ContextMtl *contextMtl = mtl::GetImpl(glContext);
    // NOTE(hqle): No transform feedbacks for now, since we only support ES 2.0 atm

    reset(contextMtl);

    ANGLE_TRY(initDefaultUniformBlocks(glContext));

    // Convert GLSL to spirv code
    gl::ShaderMap<std::vector<uint32_t>> shaderCodes;
    ANGLE_TRY(mtl::GlslangGetShaderSpirvCode(contextMtl, contextMtl->getCaps(), false, shaderSource,
                                             &shaderCodes));

    // Convert spirv code to MSL
    ANGLE_TRY(mtl::SpirvCodeToMsl(contextMtl, mState, &shaderCodes, &mMslShaderTranslateInfo,
                                  &mTranslatedMslShader));

    for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
    {
        // Create actual Metal shader
        ANGLE_TRY(
            createMslShader(glContext, shaderType, infoLog, mTranslatedMslShader[shaderType]));
    }

    return angle::Result::Continue;
}

angle::Result ProgramMtl::linkTranslatedShaders(const gl::Context *glContext,
                                                gl::BinaryInputStream *stream,
                                                gl::InfoLog &infoLog)
{
    ContextMtl *contextMtl = mtl::GetImpl(glContext);
    // NOTE(hqle): No transform feedbacks for now, since we only support ES 2.0 atm

    reset(contextMtl);

    loadTranslatedShaders(stream);
    loadShaderInternalInfo(stream);
    ANGLE_TRY(loadDefaultUniformBlocksInfo(glContext, stream));

    ANGLE_TRY(createMslShader(glContext, gl::ShaderType::Vertex, infoLog,
                              mTranslatedMslShader[gl::ShaderType::Vertex]));
    ANGLE_TRY(createMslShader(glContext, gl::ShaderType::Fragment, infoLog,
                              mTranslatedMslShader[gl::ShaderType::Fragment]));

    return angle::Result::Continue;
}

void ProgramMtl::linkResources(const gl::ProgramLinkedResources &resources)
{
    Std140BlockLayoutEncoderFactory std140EncoderFactory;
    gl::ProgramLinkedResourcesLinker linker(&std140EncoderFactory);

    linker.linkResources(mState, resources);
}

angle::Result ProgramMtl::initDefaultUniformBlocks(const gl::Context *glContext)
{
    // Process vertex and fragment uniforms into std140 packing.
    gl::ShaderMap<sh::BlockLayoutMap> layoutMap;
    gl::ShaderMap<size_t> requiredBufferSize;
    requiredBufferSize.fill(0);

    for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
    {
        gl::Shader *shader = mState.getAttachedShader(shaderType);
        if (shader)
        {
            const std::vector<sh::Uniform> &uniforms = shader->getUniforms();
            InitDefaultUniformBlock(uniforms, shader, &layoutMap[shaderType],
                                    &requiredBufferSize[shaderType]);
        }
    }

    // Init the default block layout info.
    const auto &uniforms         = mState.getUniforms();
    const auto &uniformLocations = mState.getUniformLocations();
    for (size_t locSlot = 0; locSlot < uniformLocations.size(); ++locSlot)
    {
        const gl::VariableLocation &location = uniformLocations[locSlot];
        gl::ShaderMap<sh::BlockMemberInfo> layoutInfo;

        if (location.used() && !location.ignored)
        {
            const gl::LinkedUniform &uniform = uniforms[location.index];
            if (uniform.isInDefaultBlock() && !uniform.isSampler())
            {
                std::string uniformName = uniform.name;
                if (uniform.isArray())
                {
                    // Gets the uniform name without the [0] at the end.
                    uniformName = gl::ParseResourceName(uniformName, nullptr);
                }

                bool found = false;

                for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
                {
                    auto it = layoutMap[shaderType].find(uniformName);
                    if (it != layoutMap[shaderType].end())
                    {
                        found                  = true;
                        layoutInfo[shaderType] = it->second;
                    }
                }

                ASSERT(found);
            }
        }

        for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
        {
            mDefaultUniformBlocks[shaderType].uniformLayout.push_back(layoutInfo[shaderType]);
        }
    }

    return resizeDefaultUniformBlocksMemory(glContext, requiredBufferSize);
}

angle::Result ProgramMtl::resizeDefaultUniformBlocksMemory(
    const gl::Context *glContext,
    const gl::ShaderMap<size_t> &requiredBufferSize)
{
    ContextMtl *contextMtl = mtl::GetImpl(glContext);

    for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
    {
        if (requiredBufferSize[shaderType] > 0)
        {
            ASSERT(requiredBufferSize[shaderType] <= mtl::kDefaultUniformsMaxSize);

            if (!mDefaultUniformBlocks[shaderType].uniformData.resize(
                    requiredBufferSize[shaderType]))
            {
                ANGLE_MTL_CHECK(contextMtl, false, GL_OUT_OF_MEMORY);
            }

            // Initialize uniform buffer memory to zero by default.
            mDefaultUniformBlocks[shaderType].uniformData.fill(0);
            mDefaultUniformBlocksDirty.set(shaderType);
        }
    }

    return angle::Result::Continue;
}

void ProgramMtl::saveDefaultUniformBlocksInfo(gl::BinaryOutputStream *stream)
{
    // Serializes the uniformLayout data of mDefaultUniformBlocks
    for (gl::ShaderType shaderType : gl::AllShaderTypes())
    {
        const size_t uniformCount = mDefaultUniformBlocks[shaderType].uniformLayout.size();
        stream->writeInt<size_t>(uniformCount);
        for (unsigned int uniformIndex = 0; uniformIndex < uniformCount; ++uniformIndex)
        {
            sh::BlockMemberInfo &blockInfo =
                mDefaultUniformBlocks[shaderType].uniformLayout[uniformIndex];
            gl::WriteBlockMemberInfo(stream, blockInfo);
        }
    }

    // Serializes required uniform block memory sizes
    for (gl::ShaderType shaderType : gl::AllShaderTypes())
    {
        stream->writeInt(mDefaultUniformBlocks[shaderType].uniformData.size());
    }
}

angle::Result ProgramMtl::loadDefaultUniformBlocksInfo(const gl::Context *glContext,
                                                       gl::BinaryInputStream *stream)
{
    gl::ShaderMap<size_t> requiredBufferSize;
    requiredBufferSize.fill(0);

    // Deserializes the uniformLayout data of mDefaultUniformBlocks
    for (gl::ShaderType shaderType : gl::AllShaderTypes())
    {
        const size_t uniformCount = stream->readInt<size_t>();
        for (unsigned int uniformIndex = 0; uniformIndex < uniformCount; ++uniformIndex)
        {
            sh::BlockMemberInfo blockInfo;
            gl::LoadBlockMemberInfo(stream, &blockInfo);
            mDefaultUniformBlocks[shaderType].uniformLayout.push_back(blockInfo);
        }
    }

    // Deserializes required uniform block memory sizes
    for (gl::ShaderType shaderType : gl::AllShaderTypes())
    {
        requiredBufferSize[shaderType] = stream->readInt<size_t>();
    }

    return resizeDefaultUniformBlocksMemory(glContext, requiredBufferSize);
}

void ProgramMtl::saveShaderInternalInfo(gl::BinaryOutputStream *stream)
{
    for (gl::ShaderType shaderType : gl::AllShaderTypes())
    {
        stream->writeInt<int>(mMslShaderTranslateInfo[shaderType].hasArgumentBuffer);
        for (const mtl::SamplerBinding &binding :
             mMslShaderTranslateInfo[shaderType].actualSamplerBindings)
        {
            stream->writeInt<uint32_t>(binding.textureBinding);
            stream->writeInt<uint32_t>(binding.samplerBinding);
        }

        for (uint32_t uboBinding : mMslShaderTranslateInfo[shaderType].actualUBOBindings)
        {
            stream->writeInt<uint32_t>(uboBinding);
        }
    }
}

void ProgramMtl::loadShaderInternalInfo(gl::BinaryInputStream *stream)
{
    for (gl::ShaderType shaderType : gl::AllShaderTypes())
    {
        mMslShaderTranslateInfo[shaderType].hasArgumentBuffer = stream->readInt<int>() != 0;
        for (mtl::SamplerBinding &binding :
             mMslShaderTranslateInfo[shaderType].actualSamplerBindings)
        {
            binding.textureBinding = stream->readInt<uint32_t>();
            binding.samplerBinding = stream->readInt<uint32_t>();
        }

        for (uint32_t &uboBinding : mMslShaderTranslateInfo[shaderType].actualUBOBindings)
        {
            uboBinding = stream->readInt<uint32_t>();
        }
    }
}

angle::Result ProgramMtl::createMslShader(const gl::Context *glContext,
                                          gl::ShaderType shaderType,
                                          gl::InfoLog &infoLog,
                                          const std::string &translatedMsl)
{
    ANGLE_MTL_OBJC_SCOPE
    {
        ContextMtl *contextMtl  = mtl::GetImpl(glContext);
        DisplayMtl *display     = contextMtl->getDisplay();
        id<MTLDevice> mtlDevice = display->getMetalDevice();

        // Convert to actual binary shader
        mtl::AutoObjCPtr<NSError *> err = nil;
        mtl::AutoObjCPtr<id<MTLLibrary>> mtlShaderLib =
            mtl::CreateShaderLibrary(mtlDevice, translatedMsl, &err);
        if (err && !mtlShaderLib)
        {
            std::ostringstream ss;
            ss << "Internal error compiling Metal shader:\n"
               << err.get().localizedDescription.UTF8String << "\n";

            ERR() << ss.str();

            infoLog << ss.str();

            ANGLE_MTL_CHECK(contextMtl, false, GL_INVALID_OPERATION);
        }

        static_assert(YES == 1, "YES should have value of 1");
        auto funcConstants = [[[MTLFunctionConstantValues alloc] init] ANGLE_MTL_AUTORELEASE];
        if (shaderType == gl::ShaderType::Vertex)
        {
            // For vertex shader, we need to create 2 variances, one with emulated rasterization
            // discard and one without.
            NSString *discardEnabledStr = [NSString
                stringWithFormat:@"%s%s",
                                 sh::TranslatorMetal::GetRasterizationDiscardEnabledConstName(),
                                 kSpirvCrossSpecConstSuffix];

            BOOL enables[] = {NO, YES};
            for (auto enable : enables)
            {
                [funcConstants setConstantValue:&enable
                                           type:MTLDataTypeBool
                                       withName:discardEnabledStr];

                id<MTLFunction> mtlShader = nil;
                ANGLE_TRY(
                    CreateMslShader(contextMtl, mtlShaderLib, funcConstants, infoLog, &mtlShader));
                mMetalRenderPipelineCache.setVertexShader(contextMtl, mtlShader, enable);

                if (mMslShaderTranslateInfo[shaderType].hasArgumentBuffer)
                {
                    InitArgumentBufferEncoder(contextMtl, mtlShader,
                                              &mVertexArgumentBufferEncoders[enable]);
                }
            }
        }
        else if (shaderType == gl::ShaderType::Fragment)
        {
            // For fragment shader, we need to create 2 variances, one with sample coverage mask
            // disabled, one with the mask enabled.
            NSString *coverageMaskEnabledStr = [NSString
                stringWithFormat:@"%s%s", sh::TranslatorMetal::GetCoverageMaskEnabledConstName(),
                                 kSpirvCrossSpecConstSuffix];

            BOOL enables[] = {NO, YES};
            for (auto enable : enables)
            {
                [funcConstants setConstantValue:&enable
                                           type:MTLDataTypeBool
                                       withName:coverageMaskEnabledStr];

                id<MTLFunction> mtlShader = nil;
                ANGLE_TRY(
                    CreateMslShader(contextMtl, mtlShaderLib, funcConstants, infoLog, &mtlShader));

                mMetalRenderPipelineCache.setFragmentShader(contextMtl, mtlShader, enable);

                if (mMslShaderTranslateInfo[shaderType].hasArgumentBuffer)
                {
                    InitArgumentBufferEncoder(contextMtl, mtlShader,
                                              &mFragmentArgumentBufferEncoders[enable]);
                }
            }
        }  // gl::ShaderType::Fragment

        return angle::Result::Continue;
    }
}

GLboolean ProgramMtl::validate(const gl::Caps &caps, gl::InfoLog *infoLog)
{
    // No-op. The spec is very vague about the behavior of validation.
    return GL_TRUE;
}

template <typename T>
void ProgramMtl::setUniformImpl(GLint location, GLsizei count, const T *v, GLenum entryPointType)
{
    const gl::VariableLocation &locationInfo = mState.getUniformLocations()[location];
    const gl::LinkedUniform &linkedUniform   = mState.getUniforms()[locationInfo.index];

    if (linkedUniform.isSampler())
    {
        // Sampler binding has changed.
        mSamplerBindingsDirty.set();
        return;
    }

    if (linkedUniform.typeInfo->type == entryPointType)
    {
        for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
        {
            DefaultUniformBlock &uniformBlock     = mDefaultUniformBlocks[shaderType];
            const sh::BlockMemberInfo &layoutInfo = uniformBlock.uniformLayout[location];

            // Assume an offset of -1 means the block is unused.
            if (layoutInfo.offset == -1)
            {
                continue;
            }

            const GLint componentCount = linkedUniform.typeInfo->componentCount;
            UpdateDefaultUniformBlock(count, locationInfo.arrayIndex, componentCount, v, layoutInfo,
                                      &uniformBlock.uniformData);
            mDefaultUniformBlocksDirty.set(shaderType);
        }
    }
    else
    {
        for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
        {
            DefaultUniformBlock &uniformBlock     = mDefaultUniformBlocks[shaderType];
            const sh::BlockMemberInfo &layoutInfo = uniformBlock.uniformLayout[location];

            // Assume an offset of -1 means the block is unused.
            if (layoutInfo.offset == -1)
            {
                continue;
            }

            const GLint componentCount = linkedUniform.typeInfo->componentCount;

            ASSERT(linkedUniform.typeInfo->type == gl::VariableBoolVectorType(entryPointType));

            GLint initialArrayOffset =
                locationInfo.arrayIndex * layoutInfo.arrayStride + layoutInfo.offset;
            for (GLint i = 0; i < count; i++)
            {
                GLint elementOffset = i * layoutInfo.arrayStride + initialArrayOffset;
                GLint *dest =
                    reinterpret_cast<GLint *>(uniformBlock.uniformData.data() + elementOffset);
                const T *source = v + i * componentCount;

                for (int c = 0; c < componentCount; c++)
                {
                    dest[c] = (source[c] == static_cast<T>(0)) ? GL_FALSE : GL_TRUE;
                }
            }

            mDefaultUniformBlocksDirty.set(shaderType);
        }
    }
}

template <typename T>
void ProgramMtl::getUniformImpl(GLint location, T *v, GLenum entryPointType) const
{
    const gl::VariableLocation &locationInfo = mState.getUniformLocations()[location];
    const gl::LinkedUniform &linkedUniform   = mState.getUniforms()[locationInfo.index];

    ASSERT(!linkedUniform.isSampler());

    const gl::ShaderType shaderType = linkedUniform.getFirstShaderTypeWhereActive();
    ASSERT(shaderType != gl::ShaderType::InvalidEnum);

    const DefaultUniformBlock &uniformBlock = mDefaultUniformBlocks[shaderType];
    const sh::BlockMemberInfo &layoutInfo   = uniformBlock.uniformLayout[location];

    ASSERT(linkedUniform.typeInfo->componentType == entryPointType ||
           linkedUniform.typeInfo->componentType == gl::VariableBoolVectorType(entryPointType));

    if (gl::IsMatrixType(linkedUniform.type))
    {
        const uint8_t *ptrToElement = uniformBlock.uniformData.data() + layoutInfo.offset +
                                      (locationInfo.arrayIndex * layoutInfo.arrayStride);
        GetMatrixUniform(linkedUniform.type, v, reinterpret_cast<const T *>(ptrToElement), false);
    }
    else
    {
        ReadFromDefaultUniformBlock(linkedUniform.typeInfo->componentCount, locationInfo.arrayIndex,
                                    v, layoutInfo, &uniformBlock.uniformData);
    }
}

void ProgramMtl::setUniform1fv(GLint location, GLsizei count, const GLfloat *v)
{
    setUniformImpl(location, count, v, GL_FLOAT);
}

void ProgramMtl::setUniform2fv(GLint location, GLsizei count, const GLfloat *v)
{
    setUniformImpl(location, count, v, GL_FLOAT_VEC2);
}

void ProgramMtl::setUniform3fv(GLint location, GLsizei count, const GLfloat *v)
{
    setUniformImpl(location, count, v, GL_FLOAT_VEC3);
}

void ProgramMtl::setUniform4fv(GLint location, GLsizei count, const GLfloat *v)
{
    setUniformImpl(location, count, v, GL_FLOAT_VEC4);
}

void ProgramMtl::setUniform1iv(GLint startLocation, GLsizei count, const GLint *v)
{
    setUniformImpl(startLocation, count, v, GL_INT);
}

void ProgramMtl::setUniform2iv(GLint location, GLsizei count, const GLint *v)
{
    setUniformImpl(location, count, v, GL_INT_VEC2);
}

void ProgramMtl::setUniform3iv(GLint location, GLsizei count, const GLint *v)
{
    setUniformImpl(location, count, v, GL_INT_VEC3);
}

void ProgramMtl::setUniform4iv(GLint location, GLsizei count, const GLint *v)
{
    setUniformImpl(location, count, v, GL_INT_VEC4);
}

void ProgramMtl::setUniform1uiv(GLint location, GLsizei count, const GLuint *v)
{
    setUniformImpl(location, count, v, GL_UNSIGNED_INT);
}

void ProgramMtl::setUniform2uiv(GLint location, GLsizei count, const GLuint *v)
{
    setUniformImpl(location, count, v, GL_UNSIGNED_INT_VEC2);
}

void ProgramMtl::setUniform3uiv(GLint location, GLsizei count, const GLuint *v)
{
    setUniformImpl(location, count, v, GL_UNSIGNED_INT_VEC3);
}

void ProgramMtl::setUniform4uiv(GLint location, GLsizei count, const GLuint *v)
{
    setUniformImpl(location, count, v, GL_UNSIGNED_INT_VEC4);
}

template <int cols, int rows>
void ProgramMtl::setUniformMatrixfv(GLint location,
                                    GLsizei count,
                                    GLboolean transpose,
                                    const GLfloat *value)
{
    const gl::VariableLocation &locationInfo = mState.getUniformLocations()[location];
    const gl::LinkedUniform &linkedUniform   = mState.getUniforms()[locationInfo.index];

    for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
    {
        DefaultUniformBlock &uniformBlock     = mDefaultUniformBlocks[shaderType];
        const sh::BlockMemberInfo &layoutInfo = uniformBlock.uniformLayout[location];

        // Assume an offset of -1 means the block is unused.
        if (layoutInfo.offset == -1)
        {
            continue;
        }

        SetFloatUniformMatrixGLSL<cols, rows>::Run(
            locationInfo.arrayIndex, linkedUniform.getArraySizeProduct(), count, transpose, value,
            uniformBlock.uniformData.data() + layoutInfo.offset);

        mDefaultUniformBlocksDirty.set(shaderType);
    }
}

void ProgramMtl::setUniformMatrix2fv(GLint location,
                                     GLsizei count,
                                     GLboolean transpose,
                                     const GLfloat *value)
{
    setUniformMatrixfv<2, 2>(location, count, transpose, value);
}

void ProgramMtl::setUniformMatrix3fv(GLint location,
                                     GLsizei count,
                                     GLboolean transpose,
                                     const GLfloat *value)
{
    setUniformMatrixfv<3, 3>(location, count, transpose, value);
}

void ProgramMtl::setUniformMatrix4fv(GLint location,
                                     GLsizei count,
                                     GLboolean transpose,
                                     const GLfloat *value)
{
    setUniformMatrixfv<4, 4>(location, count, transpose, value);
}

void ProgramMtl::setUniformMatrix2x3fv(GLint location,
                                       GLsizei count,
                                       GLboolean transpose,
                                       const GLfloat *value)
{
    setUniformMatrixfv<2, 3>(location, count, transpose, value);
}

void ProgramMtl::setUniformMatrix3x2fv(GLint location,
                                       GLsizei count,
                                       GLboolean transpose,
                                       const GLfloat *value)
{
    setUniformMatrixfv<3, 2>(location, count, transpose, value);
}

void ProgramMtl::setUniformMatrix2x4fv(GLint location,
                                       GLsizei count,
                                       GLboolean transpose,
                                       const GLfloat *value)
{
    setUniformMatrixfv<2, 4>(location, count, transpose, value);
}

void ProgramMtl::setUniformMatrix4x2fv(GLint location,
                                       GLsizei count,
                                       GLboolean transpose,
                                       const GLfloat *value)
{
    setUniformMatrixfv<4, 2>(location, count, transpose, value);
}

void ProgramMtl::setUniformMatrix3x4fv(GLint location,
                                       GLsizei count,
                                       GLboolean transpose,
                                       const GLfloat *value)
{
    setUniformMatrixfv<3, 4>(location, count, transpose, value);
}

void ProgramMtl::setUniformMatrix4x3fv(GLint location,
                                       GLsizei count,
                                       GLboolean transpose,
                                       const GLfloat *value)
{
    setUniformMatrixfv<4, 3>(location, count, transpose, value);
}

void ProgramMtl::setPathFragmentInputGen(const std::string &inputName,
                                         GLenum genMode,
                                         GLint components,
                                         const GLfloat *coeffs)
{
    UNIMPLEMENTED();
}

void ProgramMtl::getUniformfv(const gl::Context *context, GLint location, GLfloat *params) const
{
    getUniformImpl(location, params, GL_FLOAT);
}

void ProgramMtl::getUniformiv(const gl::Context *context, GLint location, GLint *params) const
{
    getUniformImpl(location, params, GL_INT);
}

void ProgramMtl::getUniformuiv(const gl::Context *context, GLint location, GLuint *params) const
{
    getUniformImpl(location, params, GL_UNSIGNED_INT);
}

angle::Result ProgramMtl::setupDraw(const gl::Context *glContext,
                                    mtl::RenderCommandEncoder *cmdEncoder,
                                    const mtl::RenderPipelineDesc &pipelineDesc,
                                    bool pipelineDescChanged,
                                    bool forceTexturesSetting,
                                    bool uniformBuffersDirty)
{
    ContextMtl *context = mtl::GetImpl(glContext);
    if (pipelineDescChanged)
    {
        // Render pipeline state needs to be changed
        id<MTLRenderPipelineState> pipelineState =
            mMetalRenderPipelineCache.getRenderPipelineState(context, pipelineDesc);
        if (!pipelineState)
        {
            // Error already logged inside getRenderPipelineState()
            return angle::Result::Stop;
        }
        cmdEncoder->setRenderPipelineState(pipelineState);

        // We need to rebind uniform buffers & textures also
        mDefaultUniformBlocksDirty.set();
        mSamplerBindingsDirty.set();
    }

    ANGLE_TRY(commitUniforms(context, cmdEncoder));
    ANGLE_TRY(updateTextures(glContext, cmdEncoder, forceTexturesSetting));

    if (uniformBuffersDirty)
    {
        ANGLE_TRY(updateUniformBuffers(context, cmdEncoder, pipelineDesc));
    }

    return angle::Result::Continue;
}

angle::Result ProgramMtl::commitUniforms(ContextMtl *context, mtl::RenderCommandEncoder *cmdEncoder)
{
    for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
    {
        if (!mDefaultUniformBlocksDirty[shaderType])
        {
            continue;
        }
        DefaultUniformBlock &uniformBlock = mDefaultUniformBlocks[shaderType];

        if (!uniformBlock.uniformData.size())
        {
            continue;
        }
        cmdEncoder->setBytes(shaderType, uniformBlock.uniformData.data(),
                             uniformBlock.uniformData.size(), mtl::kDefaultUniformsBindingIndex);

        mDefaultUniformBlocksDirty.reset(shaderType);
    }

    return angle::Result::Continue;
}

angle::Result ProgramMtl::updateTextures(const gl::Context *glContext,
                                         mtl::RenderCommandEncoder *cmdEncoder,
                                         bool forceUpdate)
{
    ContextMtl *contextMtl     = mtl::GetImpl(glContext);
    const auto &glState        = glContext->getState();
    const gl::Program *program = glState.getProgram();

    const gl::ActiveTexturePointerArray &completeTextures = glState.getActiveTexturesCache();
    const gl::ActiveTextureTypeArray &textureTypes        = program->getActiveSamplerTypes();

    for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
    {
        if (!mSamplerBindingsDirty[shaderType] && !forceUpdate)
        {
            continue;
        }

        bool hasDepthSampler = false;

        for (uint32_t textureIndex = 0; textureIndex < mState.getSamplerBindings().size();
             ++textureIndex)
        {
            const gl::SamplerBinding &samplerBinding = mState.getSamplerBindings()[textureIndex];

            ASSERT(!samplerBinding.unreferenced);

            const mtl::SamplerBinding &mslBinding =
                mMslShaderTranslateInfo[shaderType].actualSamplerBindings[textureIndex];
            if (mslBinding.textureBinding >= mtl::kMaxShaderSamplers)
            {
                // No binding assigned
                continue;
            }

            for (uint32_t arrayElement = 0; arrayElement < samplerBinding.boundTextureUnits.size();
                 ++arrayElement)
            {
                GLuint textureUnit          = samplerBinding.boundTextureUnits[arrayElement];
                gl::Texture *texture        = completeTextures[textureUnit];
                gl::Sampler *sampler        = contextMtl->getState().getSampler(textureUnit);
                gl::TextureType textureType = textureTypes[textureUnit];
                uint32_t textureSlot        = mslBinding.textureBinding + arrayElement;
                uint32_t samplerSlot        = mslBinding.samplerBinding + arrayElement;
                if (!texture)
                {
                    ANGLE_TRY(contextMtl->getNullTexture(glContext, textureType, &texture));
                }
                const gl::SamplerState *samplerState =
                    sampler ? &sampler->getSamplerState() : &texture->getSamplerState();
                TextureMtl *textureMtl = mtl::GetImpl(texture);
                if (samplerBinding.format == gl::SamplerFormat::Shadow)
                {
                    hasDepthSampler                  = true;
                    mShadowCompareModes[textureSlot] = mtl::MslGetShaderShadowCompareMode(
                        samplerState->getCompareMode(), samplerState->getCompareFunc());
                }

                ANGLE_TRY(textureMtl->bindToShader(glContext, cmdEncoder, shaderType, sampler,
                                                   textureSlot, samplerSlot));
            }  // for array elements
        }      // for sampler bindings

        if (hasDepthSampler)
        {
            cmdEncoder->setData(shaderType, mShadowCompareModes,
                                mtl::kShadowSamplerCompareModesBindingIndex);
        }
    }  // for shader types

    return angle::Result::Continue;
}

angle::Result ProgramMtl::updateUniformBuffers(ContextMtl *context,
                                               mtl::RenderCommandEncoder *cmdEncoder,
                                               const mtl::RenderPipelineDesc &pipelineDesc)
{
    const std::vector<gl::InterfaceBlock> &blocks = mState.getUniformBlocks();
    if (blocks.empty())
    {
        return angle::Result::Continue;
    }

    mCurrentArgumentBufferEncoders[gl::ShaderType::Vertex] =
        &mVertexArgumentBufferEncoders[pipelineDesc.emulatedRasterizatonDiscard];
    mCurrentArgumentBufferEncoders[gl::ShaderType::Fragment] =
        &mFragmentArgumentBufferEncoders[pipelineDesc.coverageMaskEnabled];

    // This array is only used inside this function and its callees.
    ScopedAutoClearVector<uint32_t> scopeArrayClear(&mArgumentBufferRenderStageUsages);
    ScopedAutoClearVector<std::pair<mtl::BufferRef, uint32_t>> scopeArrayClear2(
        &mLegalizedOffsetedUniformBuffers);
    mArgumentBufferRenderStageUsages.resize(blocks.size());
    mLegalizedOffsetedUniformBuffers.resize(blocks.size());

    ANGLE_TRY(legalizeUniformBufferOffsets(context, blocks));

    const gl::State &glState = context->getState();

    for (gl::ShaderType shaderType : gl::AllGLES2ShaderTypes())
    {
        if (mCurrentArgumentBufferEncoders[shaderType]->metalArgBufferEncoder)
        {
            ANGLE_TRY(
                encodeUniformBuffersInfoArgumentBuffer(context, cmdEncoder, blocks, shaderType));
        }
        else
        {
            ANGLE_TRY(bindUniformBuffersToDiscreteSlots(context, cmdEncoder, blocks, shaderType));
        }
    }  // for shader types

    // After encode the uniform buffers into an argument buffer, we need to tell Metal that
    // the buffers are being used by what shader stages.
    for (uint32_t bufferIndex = 0; bufferIndex < blocks.size(); ++bufferIndex)
    {
        const gl::InterfaceBlock &block = blocks[bufferIndex];
        const gl::OffsetBindingPointer<gl::Buffer> &bufferBinding =
            glState.getIndexedUniformBuffer(block.binding);
        if (bufferBinding.get() == nullptr)
        {
            continue;
        }

        // Remove any other stages other than vertex and fragment.
        uint32_t stages = mArgumentBufferRenderStageUsages[bufferIndex] &
                          (mtl::kRenderStageVertex | mtl::kRenderStageFragment);

        if (stages == 0)
        {
            continue;
        }

        cmdEncoder->useResource(mLegalizedOffsetedUniformBuffers[bufferIndex].first,
                                MTLResourceUsageRead, static_cast<mtl::RenderStages>(stages));
    }

    return angle::Result::Continue;
}

angle::Result ProgramMtl::legalizeUniformBufferOffsets(
    ContextMtl *context,
    const std::vector<gl::InterfaceBlock> &blocks)
{
    const gl::State &glState = context->getState();

    for (uint32_t bufferIndex = 0; bufferIndex < blocks.size(); ++bufferIndex)
    {
        const gl::InterfaceBlock &block = blocks[bufferIndex];
        const gl::OffsetBindingPointer<gl::Buffer> &bufferBinding =
            glState.getIndexedUniformBuffer(block.binding);

        if (bufferBinding.get() == nullptr)
        {
            continue;
        }

        BufferMtl *bufferMtl = mtl::GetImpl(bufferBinding.get());
        size_t srcOffset     = std::min<size_t>(bufferBinding.getOffset(), bufferMtl->size());
        size_t offsetModulo  = srcOffset % mtl::kUniformBufferSettingOffsetMinAlignment;
        if (offsetModulo)
        {
            ConversionBufferMtl *conversion =
                bufferMtl->getUniformConversionBuffer(context, offsetModulo);
            // Has the content of the buffer has changed since last conversion?
            if (conversion->dirty)
            {
                const uint8_t *srcBytes = bufferMtl->getClientShadowCopyData(context);
                srcBytes += offsetModulo;
                size_t sizeToCopy      = bufferMtl->size() - offsetModulo;
                size_t bytesToAllocate = roundUp<size_t>(sizeToCopy, 16u);
                ANGLE_TRY(StreamUniformBufferData(
                    context, &conversion->data, srcBytes, bytesToAllocate, sizeToCopy,
                    &conversion->convertedBuffer, &conversion->convertedOffset));
#ifndef NDEBUG
                ANGLE_MTL_OBJC_SCOPE
                {
                    conversion->convertedBuffer->get().label = [NSString
                        stringWithFormat:@"Converted from %p offset=%zu", bufferMtl, offsetModulo];
                }
#endif
                conversion->dirty = false;
            }
            // reuse the converted buffer
            mLegalizedOffsetedUniformBuffers[bufferIndex].first = conversion->convertedBuffer;
            mLegalizedOffsetedUniformBuffers[bufferIndex].second =
                static_cast<uint32_t>(conversion->convertedOffset + srcOffset - offsetModulo);
        }
        else
        {
            mLegalizedOffsetedUniformBuffers[bufferIndex].first = bufferMtl->getCurrentBuffer();
            mLegalizedOffsetedUniformBuffers[bufferIndex].second =
                static_cast<uint32_t>(bufferBinding.getOffset());
        }
    }
    return angle::Result::Continue;
}

angle::Result ProgramMtl::bindUniformBuffersToDiscreteSlots(
    ContextMtl *context,
    mtl::RenderCommandEncoder *cmdEncoder,
    const std::vector<gl::InterfaceBlock> &blocks,
    gl::ShaderType shaderType)
{
    const gl::State &glState = context->getState();
    for (uint32_t bufferIndex = 0; bufferIndex < blocks.size(); ++bufferIndex)
    {
        const gl::InterfaceBlock &block = blocks[bufferIndex];
        const gl::OffsetBindingPointer<gl::Buffer> &bufferBinding =
            glState.getIndexedUniformBuffer(block.binding);

        if (bufferBinding.get() == nullptr || !block.activeShaders().test(shaderType))
        {
            continue;
        }

        uint32_t actualBufferIdx =
            mMslShaderTranslateInfo[shaderType].actualUBOBindings[bufferIndex];

        if (actualBufferIdx >= mtl::kMaxShaderBuffers)
        {
            continue;
        }

        mtl::BufferRef mtlBuffer = mLegalizedOffsetedUniformBuffers[bufferIndex].first;
        uint32_t offset          = mLegalizedOffsetedUniformBuffers[bufferIndex].second;
        cmdEncoder->setBuffer(shaderType, mtlBuffer, offset, actualBufferIdx);
    }
    return angle::Result::Continue;
}
angle::Result ProgramMtl::encodeUniformBuffersInfoArgumentBuffer(
    ContextMtl *context,
    mtl::RenderCommandEncoder *cmdEncoder,
    const std::vector<gl::InterfaceBlock> &blocks,
    gl::ShaderType shaderType)
{
    const gl::State &glState = context->getState();

    // Encoder all uniform buffers into an argument buffer.
    ProgramArgumentBufferEncoderMtl &bufferEncoder = *mCurrentArgumentBufferEncoders[shaderType];

    mtl::BufferRef argumentBuffer;
    size_t argumentBufferOffset;
    bufferEncoder.bufferPool.releaseInFlightBuffers(context);
    ANGLE_TRY(bufferEncoder.bufferPool.allocate(
        context, bufferEncoder.metalArgBufferEncoder.get().encodedLength, nullptr, &argumentBuffer,
        &argumentBufferOffset));

    [bufferEncoder.metalArgBufferEncoder setArgumentBuffer:argumentBuffer->get()
                                                    offset:argumentBufferOffset];

    static_assert(MTLRenderStageVertex == (0x1 << static_cast<uint32_t>(gl::ShaderType::Vertex)),
                  "Expected gl ShaderType enum and Metal enum to relative to each other");
    static_assert(
        MTLRenderStageFragment == (0x1 << static_cast<uint32_t>(gl::ShaderType::Fragment)),
        "Expected gl ShaderType enum and Metal enum to relative to each other");
    auto mtlRenderStage = static_cast<MTLRenderStages>(0x1 << static_cast<uint32_t>(shaderType));

    for (uint32_t bufferIndex = 0; bufferIndex < blocks.size(); ++bufferIndex)
    {
        const gl::InterfaceBlock &block = blocks[bufferIndex];
        const gl::OffsetBindingPointer<gl::Buffer> &bufferBinding =
            glState.getIndexedUniformBuffer(block.binding);

        if (bufferBinding.get() == nullptr || !block.activeShaders().test(shaderType))
        {
            continue;
        }

        mArgumentBufferRenderStageUsages[bufferIndex] |= mtlRenderStage;

        uint32_t actualBufferIdx =
            mMslShaderTranslateInfo[shaderType].actualUBOBindings[bufferIndex];
        if (actualBufferIdx >= mtl::kMaxShaderBuffers)
        {
            continue;
        }

        mtl::BufferRef mtlBuffer = mLegalizedOffsetedUniformBuffers[bufferIndex].first;
        uint32_t offset          = mLegalizedOffsetedUniformBuffers[bufferIndex].second;
        [bufferEncoder.metalArgBufferEncoder setBuffer:mtlBuffer->get()
                                                offset:offset
                                               atIndex:actualBufferIdx];
    }

    ANGLE_TRY(bufferEncoder.bufferPool.commit(context));

    cmdEncoder->setBuffer(shaderType, argumentBuffer, static_cast<uint32_t>(argumentBufferOffset),
                          mtl::kUBOArgumentBufferBindingIndex);
    return angle::Result::Continue;
}

}  // namespace rx
