//
// Copyright (c) 2014 The ANGLE Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//

#import <Foundation/Foundation.h>

#include "util/ios/IOSWindow.h"
#include "util/system_utils.h"

namespace
{

__attribute__((constructor)) void SetEGLLibName()
{
    @autoreleasepool
    {
        NSString *pathMetalANGLEv13 = [[NSBundle mainBundle].privateFrameworksPath
            stringByAppendingPathComponent:@"MetalANGLE_ios_13.0.framework/MetalANGLE_ios_13.0"];
        NSString *pathMetalANGLE    = [[NSBundle mainBundle].privateFrameworksPath
            stringByAppendingPathComponent:@"MetalANGLE.framework/MetalANGLE"];

        if ([[NSFileManager defaultManager] fileExistsAtPath:pathMetalANGLEv13])
        {
            angle::SetEnvironmentVar("ANGLE_EGL_LIBRARY_NAME", "MetalANGLE_ios_13");
        }
        else if ([[NSFileManager defaultManager] fileExistsAtPath:pathMetalANGLE])
        {
            angle::SetEnvironmentVar("ANGLE_EGL_LIBRARY_NAME", "MetalANGLE");
        }
    }
}

}
