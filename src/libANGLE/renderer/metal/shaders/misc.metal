//
// Copyright 2019 The ANGLE Project. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "common.h"

// Metal only supports 64 bit integer in 2.2. So we have to emulate the 64 bit addition by
// using a vector of 4 ushort integers since our target Metal version is 2.0.
static inline ushort4 sum64(ushort4 a, ushort4 b)
{
    ushort4 re(0);
    uint carry = 0;
    for (int i = 0; i < 4; ++i)
    {
        uint sum = a[i] + b[i] + carry;
        re[i]    = sum % 0x10000;
        carry    = sum / 0x10000;
    }

    return re;
}

// Combine the visibility result of current render pass with previous value from previous render
// pass
struct CombineVisibilityResultOptions
{
    // 1: the previous value of query's buffer will be combined.
    // 0: the previous value is ignored.
    uint combineWithCurrentValue;
    // Start offset in the render pass's visibility buffer allocated for the query.
    uint startOffset;
    // How many offsets in the render pass's visibility buffer is used for the query?
    uint numOffsets;
};

kernel void combineVisibilityResult(uint idx [[thread_position_in_grid]],
                                    constant CombineVisibilityResultOptions &options [[buffer(0)]],
                                    constant ushort4 *renderpassVisibilityResult [[buffer(1)]],
                                    device ushort4 *finalResults [[buffer(2)]])
{
    if (idx > 0)
    {
        // NOTE(hqle):
        // This is a bit wasteful to use a WARP of multiple threads just for combining one integer.
        // Consider a better approach.
        return;
    }
    ushort4 finalResult16x4 =
        finalResults[0] * static_cast<ushort>(options.combineWithCurrentValue);
    for (uint i = 0; i < options.numOffsets; ++i)
    {
        uint offset              = options.startOffset + i;
        ushort4 renderpassResult = renderpassVisibilityResult[offset];
        finalResult16x4          = sum64(finalResult16x4, renderpassResult);
    }
    finalResults[0] = finalResult16x4;
}
