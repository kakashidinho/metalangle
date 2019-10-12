//
// Copyright 2016 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// GlslangWrapper: Wrapper for Vulkan's glslang compiler.
//

#include "libANGLE/renderer/vulkan/GlslangWrapper.h"

#include "libANGLE/renderer/glslang_wrapper_utils.h"
#include "libANGLE/renderer/vulkan/ContextVk.h"
#include "libANGLE/renderer/vulkan/vk_cache_utils.h"

namespace rx
{
namespace
{
angle::Result ErrorHandler(vk::Context *context, GlslangWrapperUtils::Error)
{
    ANGLE_VK_CHECK(context, false, VK_ERROR_INVALID_SHADER_NV);
    return angle::Result::Stop;
}

GlslangWrapperUtils::Options CreateOptions(vk::Context *context)
{
    GlslangWrapperUtils::Options options;
    options.uniformsAndXfbDescriptorSetIndex = kUniformsAndXfbDescriptorSetIndex;
    options.textureDescriptorSetIndex        = kTextureDescriptorSetIndex;
    options.shaderResourceDescriptorSetIndex = kShaderResourceDescriptorSetIndex;
    options.driverUniformsDescriptorSetIndex = kDriverUniformsDescriptorSetIndex;
    options.xfbBindingIndexStart             = kXfbBindingIndexStart;

    if (context)
    {
        options.errorCallback = [context](GlslangWrapperUtils::Error error) {
            return ErrorHandler(context, error);
        };
    }

    return options;
}
}  // namespace

// static
void GlslangWrapper::Initialize()
{
    GlslangWrapperUtils::Initialize();
}

// static
void GlslangWrapper::Release()
{
    GlslangWrapperUtils::Release();
}

// static
void GlslangWrapper::GetShaderSource(bool useOldRewriteStructSamplers,
                                     const gl::ProgramState &programState,
                                     const gl::ProgramLinkedResources &resources,
                                     gl::ShaderMap<std::string> *shaderSourcesOut)
{
    GlslangWrapperUtils::GetShaderSource(CreateOptions(nullptr), useOldRewriteStructSamplers,
                                         programState, resources, shaderSourcesOut);
}

// static
angle::Result GlslangWrapper::GetShaderCode(vk::Context *context,
                                            const gl::Caps &glCaps,
                                            bool enableLineRasterEmulation,
                                            const gl::ShaderMap<std::string> &shaderSources,
                                            gl::ShaderMap<std::vector<uint32_t>> *shaderCodeOut)
{
    return GlslangWrapperUtils::GetShaderCode(
        CreateOptions(context), glCaps, enableLineRasterEmulation, shaderSources, shaderCodeOut);
}
}  // namespace rx
