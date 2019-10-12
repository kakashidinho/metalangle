//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// GlslangWrapperUtils: Wrapper for Khronos glslang compiler.
//

#ifndef LIBANGLE_RENDERER_GLSLANG_WRAPPER_UTILS_H_
#define LIBANGLE_RENDERER_GLSLANG_WRAPPER_UTILS_H_

#include "libANGLE/renderer/ProgramImpl.h"

namespace rx
{
// This class currently holds no state. If we want to hold state we would need to solve the
// potential race conditions with multiple threads.
class GlslangWrapperUtils
{
  public:
    enum Error
    {
        ERROR_INVALID_SHADER,
    };

    struct Options
    {
        Options();
        ~Options();

        std::function<angle::Result(Error)> errorCallback;

        // Uniforms set index:
        uint32_t uniformsAndXfbDescriptorSetIndex;
        // Textures set index:
        uint32_t textureDescriptorSetIndex;
        // Other shader resources set index:
        uint32_t shaderResourceDescriptorSetIndex;
        // ANGLE driver uniforms set index:
        uint32_t driverUniformsDescriptorSetIndex;

        // Binding index start for transform feedback buffers:
        uint32_t xfbBindingIndexStart;
    };

    static void Initialize();
    static void Release();

    static std::string GetMappedSamplerName(const std::string &originalName);

    static void GetShaderSource(const Options &options,
                                bool useOldRewriteStructSamplers,
                                const gl::ProgramState &programState,
                                const gl::ProgramLinkedResources &resources,
                                gl::ShaderMap<std::string> *shaderSourcesOut);

    static angle::Result GetShaderCode(const Options &options,
                                       const gl::Caps &glCaps,
                                       bool enableLineRasterEmulation,
                                       const gl::ShaderMap<std::string> &shaderSources,
                                       gl::ShaderMap<std::vector<uint32_t>> *shaderCodesOut);

  private:
    static angle::Result GetShaderCodeImpl(const Options &options,
                                           const gl::Caps &glCaps,
                                           const gl::ShaderMap<std::string> &shaderSources,
                                           gl::ShaderMap<std::vector<uint32_t>> *shaderCodesOut);
};
}  // namespace rx

#endif  // LIBANGLE_RENDERER_GLSLANG_WRAPPER_UTILS_H_
