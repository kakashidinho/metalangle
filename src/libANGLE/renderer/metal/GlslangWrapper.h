//
// Copyright (c) 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// GlslangWrapper: Wrapper for Vulkan's glslang compiler.
//

//
// TODO(hqle): This file is just a modified copy of Vulkan renderer's file of the same name
// In the future, should move their common code to a separate file.
//

#ifndef LIBANGLE_RENDERER_METAL_GLSLANGWRAPPER_H_
#define LIBANGLE_RENDERER_METAL_GLSLANGWRAPPER_H_

#include "libANGLE/Caps.h"
#include "libANGLE/Context.h"
#include "libANGLE/renderer/ProgramImpl.h"
#include "libANGLE/renderer/metal/mtl_common.h"

namespace rx
{
// This class currently holds no state. If we want to hold state we would need to solve the
// potential race conditions with multiple threads.
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
