//
// Copyright (c) 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// GlslangWrapper: Wrapper for Khronos's glslang compiler.
//

#ifndef LIBANGLE_RENDERER_METAL_GLSLANGWRAPPER_H_
#define LIBANGLE_RENDERER_METAL_GLSLANGWRAPPER_H_

#include "libANGLE/Caps.h"
#include "libANGLE/Context.h"
#include "libANGLE/renderer/ProgramImpl.h"
#include "libANGLE/renderer/metal/mtl_common.h"

namespace rx
{
class GlslangWrapperMtl
{
  public:
    static void Initialize();
    static void Release();

    static void GetShaderSource(const gl::ProgramState &programState,
                                const gl::ProgramLinkedResources &resources,
                                std::string *vertexSourceOut,
                                std::string *fragmentSourceOut);

    static angle::Result GetShaderCode(mtl::ErrorHandler *context,
                                       const gl::Caps &glCaps,
                                       bool enableLineRasterEmulation,
                                       const std::string &vertexSource,
                                       const std::string &fragmentSource,
                                       std::vector<uint32_t> *vertexCodeOut,
                                       std::vector<uint32_t> *fragmentCodeOut);

  private:
    static angle::Result GetShaderCodeImpl(mtl::ErrorHandler *context,
                                           const gl::Caps &glCaps,
                                           const std::string &vertexSource,
                                           const std::string &fragmentSource,
                                           std::vector<uint32_t> *vertexCodeOut,
                                           std::vector<uint32_t> *fragmentCodeOut);
};

}  // namespace rx

#endif /* LIBANGLE_RENDERER_METAL_GLSLANGWRAPPER_H_ */
