#!/usr/bin/python
# Copyright 2019 The ANGLE Project Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

import os
import sys
from datetime import datetime


def main():
    os.chdir(sys.path[0])
    print('Compiling macos version of default shaders ...')
    os.system(
        'xcrun -sdk macosx metal default.metal -mmacosx-version-min=10.13 -c -o compiled/default.air')
    os.system(
        'xcrun -sdk macosx metallib compiled/default.air -o compiled/default.metallib')
    os.system('xcrun -sdk macosx metal default.metal -g -mmacosx-version-min=10.13  -c -o compiled/default.debug.air')
    os.system(
        'xcrun -sdk macosx metallib compiled/default.debug.air -o compiled/default.debug.metallib')

    print('Compiling ios version of default shaders ...')
    os.system(
        'xcrun -sdk iphoneos metal default.metal -mios-version-min=8.0 -c -o compiled/default.ios.air')
    os.system(
        'xcrun -sdk iphoneos metallib compiled/default.ios.air -o compiled/default.ios.metallib')

    print('Compiling ios simulator version of default shaders ...')
    os.system(
        'xcrun -sdk iphonesimulator metal default.metal -c -o compiled/default.ios_sim.air')
    os.system('xcrun -sdk iphonesimulator metallib compiled/default.ios_sim.air -o compiled/default.ios_sim.metallib')

    os.system("echo \"// GENERATED FILE on {0} - DO NOT EDIT.\" > compiled/mtl_default_shaders.inc"
              .format(datetime.now()))
    os.system('echo "#pragma once\n\n" >> compiled/mtl_default_shaders.inc')
    os.system(
        'echo "#include <TargetConditionals.h>\n\n" >> compiled/mtl_default_shaders.inc')

    # Mac version
    os.system('echo "#if TARGET_OS_OSX\n" >> compiled/mtl_default_shaders.inc')

    # Non-debug version
    os.system('echo "#  if defined (NDEBUG)\n" >> compiled/mtl_default_shaders.inc')
    os.system('echo "static const " >> compiled/mtl_default_shaders.inc')
    os.system('xxd -i compiled/default.metallib >> compiled/mtl_default_shaders.inc')

    # Debug version
    os.system('echo "#  else  // NDEBUG\n" >> compiled/mtl_default_shaders.inc')
    os.system('echo "#define compiled_default_metallib     compiled_default_debug_metallib" >> compiled/mtl_default_shaders.inc')
    os.system('echo "#define compiled_default_metallib_len compiled_default_debug_metallib_len\n" >> compiled/mtl_default_shaders.inc')
    os.system('echo "static const " >> compiled/mtl_default_shaders.inc')
    os.system(
        'xxd -i compiled/default.debug.metallib >> compiled/mtl_default_shaders.inc')

    os.system('echo "#  endif  // NDEBUG\n" >> compiled/mtl_default_shaders.inc')

    # iOS simulator version
    os.system(
        'echo "\n#elif TARGET_OS_SIMULATOR  // TARGET_OS_OSX\n" >> compiled/mtl_default_shaders.inc')

    os.system('echo "#define compiled_default_metallib     compiled_default_ios_sim_metallib" >> compiled/mtl_default_shaders.inc')
    os.system('echo "#define compiled_default_metallib_len compiled_default_ios_sim_metallib_len\n" >> compiled/mtl_default_shaders.inc')
    os.system('echo "static const " >> compiled/mtl_default_shaders.inc')
    os.system(
        'xxd -i compiled/default.ios_sim.metallib >> compiled/mtl_default_shaders.inc')

    # iOS version
    os.system(
        'echo "\n#elif TARGET_OS_IOS  // TARGET_OS_OSX\n" >> compiled/mtl_default_shaders.inc')

    os.system('echo "#define compiled_default_metallib     compiled_default_ios_metallib" >> compiled/mtl_default_shaders.inc')
    os.system('echo "#define compiled_default_metallib_len compiled_default_ios_metallib_len\n" >> compiled/mtl_default_shaders.inc')
    os.system('echo "static const " >> compiled/mtl_default_shaders.inc')
    os.system(
        'xxd -i compiled/default.ios.metallib >> compiled/mtl_default_shaders.inc')

    os.system(
        'echo "#endif  // TARGET_OS_OSX\n" >> compiled/mtl_default_shaders.inc')

    # Write full source string for debug purpose
    os.system("echo \"// GENERATED FILE on {0} - DO NOT EDIT.\" > mtl_default_shaders_src_autogen.inc"
              .format(datetime.now()))
    os.system('echo "\n\nstatic const char default_metallib_src[] = R\\"(" >> mtl_default_shaders_src_autogen.inc')
    os.system('cat default.metal >> mtl_default_shaders_src_autogen.inc')
    os.system('echo ")\\";" >> mtl_default_shaders_src_autogen.inc')


if __name__ == '__main__':
    sys.exit(main())
