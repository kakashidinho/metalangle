//
// Copyright 2021 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// mtl_msl_vertex_fetch_codegen: utils to generate vertex fetch code into msl code.
//

#ifndef LIBANGLE_RENDERER_METAL_MTL_MSL_VERTEX_FETCH_CODEGEN_H_
#define LIBANGLE_RENDERER_METAL_MTL_MSL_VERTEX_FETCH_CODEGEN_H_

#include <string>

namespace rx
{
namespace mtl
{

std::string AppendVertexFetchingCode(const std::string &desiredEntryName,
                                     const std::string &verticesPerInstanceDriverUniformName,
                                     const std::string &mslSource);
}
}  // namespace rx

#endif
