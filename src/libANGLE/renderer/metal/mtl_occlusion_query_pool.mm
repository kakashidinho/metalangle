//
// Copyright (c) 2020 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// mtl_occlusion_query_pool: A visibility pool for allocating visibility query within
// one render pass.
//

#include "libANGLE/renderer/metal/mtl_occlusion_query_pool.h"

#include "libANGLE/renderer/metal/ContextMtl.h"
#include "libANGLE/renderer/metal/DisplayMtl.h"
#include "libANGLE/renderer/metal/QueryMtl.h"

namespace rx
{
namespace mtl
{

// OcclusionQueryPool implementation
OcclusionQueryPool::OcclusionQueryPool() {}
OcclusionQueryPool::~OcclusionQueryPool() {}

void OcclusionQueryPool::destroy(ContextMtl *contextMtl)
{
    mRenderPassResultsPool = nullptr;
    for (QueryMtl *allocatedQuery : mAllocatedQueries)
    {
        allocatedQuery->setAllocatedVisibilityOffset(-1);
    }
    mAllocatedQueries.clear();
}

angle::Result OcclusionQueryPool::allocateQueryOffset(ContextMtl *contextMtl,
                                                      QueryMtl *query,
                                                      bool clearOldValue)
{
    // Only first query of the render pass is allowed to keep old value. Subsequent queries will
    // be reset to zero before counting the visibility of draw calls.
    ASSERT(clearOldValue || mAllocatedQueries.empty());

    if (query->getAllocatedVisibilityOffset() == -1)
    {
        size_t currentOffset = mAllocatedQueries.size() * kOcclusionQueryResultSize;
        if (!mRenderPassResultsPool)
        {
            // First allocation
            ANGLE_TRY(Buffer::MakeBuffer(contextMtl, MTLResourceStorageModePrivate,
                                         kOcclusionQueryResultSize, nullptr,
                                         &mRenderPassResultsPool));
            mRenderPassResultsPool->get().label = @"OcclusionQueryPool";
        }
        else if (currentOffset + kOcclusionQueryResultSize > mRenderPassResultsPool->size())
        {
            // Double the capacity
            ANGLE_TRY(Buffer::MakeBuffer(contextMtl, MTLResourceStorageModePrivate,
                                         mRenderPassResultsPool->size() * 2, nullptr,
                                         &mRenderPassResultsPool));
            mRenderPassResultsPool->get().label = @"OcclusionQueryPool";
        }

        query->setAllocatedVisibilityOffset(currentOffset);

        mAllocatedQueries.push_back(query);
    }
    else
    {
        // This query is already allocated, just reuse the old offset
    }

    if (query->getAllocatedVisibilityOffset() == 0)
    {
        mResetFirstQuery = clearOldValue;
    }

    return angle::Result::Continue;
}

void OcclusionQueryPool::deallocateQueryOffset(ContextMtl *contextMtl, QueryMtl *query)
{
    if (query->getAllocatedVisibilityOffset() == -1)
    {
        return;
    }

    mAllocatedQueries[query->getAllocatedVisibilityOffset() / kOcclusionQueryResultSize] = nullptr;
    query->setAllocatedVisibilityOffset(-1);
}

void OcclusionQueryPool::resolveVisibilityResults(ContextMtl *contextMtl)
{
    if (mAllocatedQueries.empty())
    {
        return;
    }

    size_t startBlitIdx             = 0;
    BlitCommandEncoder *blitEncoder = nullptr;
    if (!mResetFirstQuery)
    {
        // Combine the result of first query
        startBlitIdx = 1;
        if (mAllocatedQueries[0])
        {
            const BufferRef &dstBuf = mAllocatedQueries[0]->getVisibilityResultBuffer();
            contextMtl->getDisplay()->getUtils().combineVisibilityResult(
                contextMtl, mRenderPassResultsPool, dstBuf);

            blitEncoder = contextMtl->getBlitCommandEncoder();
            dstBuf->syncContent(contextMtl, blitEncoder);

            mAllocatedQueries[0]->setAllocatedVisibilityOffset(-1);
        }
    }

    if (!blitEncoder)
    {
        blitEncoder = contextMtl->getBlitCommandEncoder();
    }

    // Copy results from pool to the respective query's buffers
    for (size_t i = startBlitIdx; i < mAllocatedQueries.size(); ++i)
    {
        QueryMtl *query = mAllocatedQueries[i];
        if (!query)
        {
            continue;
        }

        blitEncoder->copyBuffer(mRenderPassResultsPool, query->getAllocatedVisibilityOffset(),
                                query->getVisibilityResultBuffer(), 0, kOcclusionQueryResultSize);
        query->getVisibilityResultBuffer()->syncContent(contextMtl, blitEncoder);
        query->setAllocatedVisibilityOffset(-1);
    }

    mAllocatedQueries.clear();
}

}
}