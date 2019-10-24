//
// Copyright (c) 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// GlslangWrapperMtl: Wrapper for Khronos's glslang compiler.
//

#include "libANGLE/renderer/metal/GlslangWrapperMtl.h"

#include "libANGLE/renderer/glslang_wrapper_utils.h"

namespace rx
{
namespace
{
angle::Result ErrorHandler(mtl::ErrorHandler *context, GlslangError)
{
    ANGLE_MTL_TRY(context, false);
    return angle::Result::Stop;
}

GlslangSourceOptions CreateSourceOptions()
{
    GlslangSourceOptions options;
    // We don't actually use descriptor set for now, the actual binding will be done inside
    // ProgramMtl using spirv-cross.
    options.uniformsAndXfbDescriptorSetIndex = mtl::kDefaultUniformsBindingIndex;
    options.textureDescriptorSetIndex        = 0;
    options.driverUniformsDescriptorSetIndex = mtl::kDriverUniformsBindingIndex;
    // NOTE(hqle): Unused for now, until we support ES 3.0
    options.shaderResourceDescriptorSetIndex = -1;
    options.xfbBindingIndexStart             = -1;

    static_assert(mtl::kDefaultUniformsBindingIndex != 0,
                  "mtl::kDefaultUniformsBindingIndex must not be 0");
    static_assert(mtl::kDriverUniformsBindingIndex != 0,
                  "mtl::kDriverUniformsBindingIndex must not be 0");

    return options;
}
}  // namespace

// static
void GlslangWrapperMtl::GetShaderSource(const gl::ProgramState &programState,
                                        const gl::ProgramLinkedResources &resources,
                                        gl::ShaderMap<std::string> *shaderSourcesOut)
{
    GlslangGetShaderSource(CreateSourceOptions(), false, programState, resources, shaderSourcesOut);
}

// static
angle::Result GlslangWrapperMtl::GetShaderCode(mtl::ErrorHandler *context,
                                               const gl::Caps &glCaps,
                                               bool enableLineRasterEmulation,
                                               const gl::ShaderMap<std::string> &shaderSources,
                                               gl::ShaderMap<std::vector<uint32_t>> *shaderCodeOut)
{
    return GlslangGetShaderSpirvCode(
        [context](GlslangError error) { return ErrorHandler(context, error); }, glCaps,
        enableLineRasterEmulation, shaderSources, shaderCodeOut);
}
}  // namespace rx
