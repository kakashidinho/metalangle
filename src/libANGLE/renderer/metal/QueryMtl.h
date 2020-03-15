//
// Copyright (c) 2020 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// QueryMtl.h:
//    Defines the class interface for QueryMtl, implementing QueryImpl.
//

#ifndef LIBANGLE_RENDERER_METAL_QUERYMTL_H_
#define LIBANGLE_RENDERER_METAL_QUERYMTL_H_

#include "libANGLE/renderer/QueryImpl.h"
#include "libANGLE/renderer/metal/mtl_common.h"
#include "libANGLE/renderer/metal/mtl_resources.h"

namespace rx
{

class ContextMtl;

class QueryMtl : public QueryImpl
{
  public:
    QueryMtl(gl::QueryType type);
    ~QueryMtl() override;

    void onDestroy(const gl::Context *context) override;

    angle::Result begin(const gl::Context *context) override;
    angle::Result end(const gl::Context *context) override;
    angle::Result queryCounter(const gl::Context *context) override;
    angle::Result getResult(const gl::Context *context, GLint *params) override;
    angle::Result getResult(const gl::Context *context, GLuint *params) override;
    angle::Result getResult(const gl::Context *context, GLint64 *params) override;
    angle::Result getResult(const gl::Context *context, GLuint64 *params) override;
    angle::Result isResultAvailable(const gl::Context *context, bool *available) override;

    // Get allocated offset in the occlusion query pool for a render pass. -1 means no allocation.
    ssize_t getAllocatedVisibilityOffset() const { return mVisibilityBufferOffset; }
    // Set allocated offset in the occlusion query pool for a render pass.
    void setAllocatedVisibilityOffset(ssize_t offset) { mVisibilityBufferOffset = offset; }
    // Returns the buffer containing the final occlusion query result.
    const mtl::BufferRef &getVisibilityResultBuffer() const { return mVisibilityResultBuffer; }
    // Reset the occlusion query result stored in buffer to zero
    void resetVisibilityResult(ContextMtl *contextMtl);

  private:
    template <typename T>
    angle::Result waitAndGetResult(const gl::Context *context, T *params);

    ssize_t mVisibilityBufferOffset = -1;
    mtl::BufferRef mVisibilityResultBuffer;
};

}  // namespace rx

#endif /* LIBANGLE_RENDERER_METAL_QUERYMTL_H_ */
