//
// Copyright 2019 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#include <Foundation/Foundation.h>

namespace rx
{
namespace mtl
{

typedef void *AutoReleasePoolRef;
AutoReleasePoolRef InitAutoreleasePool(AutoReleasePoolRef *poolInOut)
{
    if (*poolInOut)
    {
        return *poolInOut;
    }
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    return *poolInOut = (__bridge void *)pool;
}
void ReleaseAutoreleasePool(AutoReleasePoolRef *poolInOut)
{
    auto &pool = *poolInOut;
    if (!pool)
    {
        return;
    }
    NSAutoreleasePool *arpool = (__bridge NSAutoreleasePool *)pool;

    [arpool release];
    pool = nullptr;
}
}
}
