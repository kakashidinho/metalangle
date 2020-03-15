//
// Copyright 2019 The ANGLE Project. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include "common.h"

// Combine the visibility result of current render pass with previous value from previous render
// pass
kernel void combineVisibilityResult(uint idx [[thread_position_in_grid]],
                                    constant ushort4 *renderpassVisibilityResults [[buffer(0)]],
                                    device ushort4 *finalResults [[buffer(1)]])
{
    if (idx > 0)
    {
        // NOTE(hqle):
        // This is a bit wasteful to use a WARP of multiple threads just for combining one integer.
        // Consider a better approach.
        return;
    }
    // Metal only supports 64 bit integer in 2.2. So we have to emulate the 64 bit addition by
    // using a vector of 4 ushort integers.
    ushort4 cur              = finalResults[idx];
    ushort4 renderpassResult = renderpassVisibilityResults[idx];
    ushort4 finalResult16x4(0);
    uint carry = 0;
    for (int i = 0; i < 4; ++i)
    {
        uint sum           = cur[i] + renderpassResult[i] + carry;
        finalResult16x4[i] = sum % 0x10000;
        carry              = sum / 0x10000;
    }
    finalResults[idx] = finalResult16x4;
}
