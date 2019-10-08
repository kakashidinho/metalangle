#!/usr/bin/python
# Copyright 2019 The ANGLE Project Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#

import os
import sys
import json
from datetime import datetime


def main():
    # auto_script parameters.
    if len(sys.argv) > 1:
        inputs = ['master_source.metal']
        outputs = ['compiled/mtl_default_shaders.inc', 'mtl_default_shaders_src_autogen.inc']

        if sys.argv[1] == 'inputs':
            print ','.join(inputs)
        elif sys.argv[1] == 'outputs':
            print ','.join(outputs)
        else:
            print('Invalid script parameters')
            return 1
        return 0

    os.chdir(sys.path[0])

    print('Compiling macos version of default shaders ...')
    os.system(
        'xcrun -sdk macosx metal master_source.metal -mmacosx-version-min=10.13 -c -o compiled/default.air'
    )
    os.system('xcrun -sdk macosx metallib compiled/default.air -o compiled/default.metallib')

    print('Compiling ios version of default shaders ...')
    os.system(
        'xcrun -sdk iphoneos metal master_source.metal -mios-version-min=8.0 -c -o compiled/default.ios.air'
    )
    os.system(
        'xcrun -sdk iphoneos metallib compiled/default.ios.air -o compiled/default.ios.metallib')

    print('Compiling ios simulator version of default shaders ...')
    os.system(
        'xcrun -sdk iphonesimulator metal master_source.metal -c -o compiled/default.ios_sim.air')
    os.system(
        'xcrun -sdk iphonesimulator metallib compiled/default.ios_sim.air -o compiled/default.ios_sim.metallib'
    )

    os.system("echo \"// GENERATED FILE on {0} - DO NOT EDIT.\" > compiled/mtl_default_shaders.inc"
              .format(datetime.now()))
    os.system('echo "#pragma once\n\n" >> compiled/mtl_default_shaders.inc')
    os.system('echo "#include <TargetConditionals.h>\n\n" >> compiled/mtl_default_shaders.inc')

    # Mac version
    os.system('echo "#if TARGET_OS_OSX\n" >> compiled/mtl_default_shaders.inc')

    os.system('echo "static const " >> compiled/mtl_default_shaders.inc')
    os.system('xxd -i compiled/default.metallib >> compiled/mtl_default_shaders.inc')

    # iOS simulator version
    os.system(
        'echo "\n#elif TARGET_OS_SIMULATOR  // TARGET_OS_OSX\n" >> compiled/mtl_default_shaders.inc'
    )

    os.system(
        'echo "#define compiled_default_metallib     compiled_default_ios_sim_metallib" >> compiled/mtl_default_shaders.inc'
    )
    os.system(
        'echo "#define compiled_default_metallib_len compiled_default_ios_sim_metallib_len\n" >> compiled/mtl_default_shaders.inc'
    )
    os.system('echo "static const " >> compiled/mtl_default_shaders.inc')
    os.system('xxd -i compiled/default.ios_sim.metallib >> compiled/mtl_default_shaders.inc')

    # iOS version
    os.system(
        'echo "\n#elif TARGET_OS_IOS  // TARGET_OS_OSX\n" >> compiled/mtl_default_shaders.inc')

    os.system(
        'echo "#define compiled_default_metallib     compiled_default_ios_metallib" >> compiled/mtl_default_shaders.inc'
    )
    os.system(
        'echo "#define compiled_default_metallib_len compiled_default_ios_metallib_len\n" >> compiled/mtl_default_shaders.inc'
    )
    os.system('echo "static const " >> compiled/mtl_default_shaders.inc')
    os.system('xxd -i compiled/default.ios.metallib >> compiled/mtl_default_shaders.inc')

    os.system('echo "#endif  // TARGET_OS_OSX\n" >> compiled/mtl_default_shaders.inc')

    # Write full source string for debug purpose
    os.system(
        "echo \"// GENERATED FILE on {0} - DO NOT EDIT.\" > mtl_default_shaders_src_autogen.inc"
        .format(datetime.now()))
    os.system(
        'echo "\n\nstatic const char default_metallib_src[] = R\\"(" >> mtl_default_shaders_src_autogen.inc'
    )
    os.system('echo "#include <metal_stdlib>" >> mtl_default_shaders_src_autogen.inc')
    os.system('echo "#include <simd/simd.h>" >> mtl_default_shaders_src_autogen.inc')
    os.system(
        'clang -xc++ -E -DSKIP_STD_HEADERS master_source.metal >> mtl_default_shaders_src_autogen.inc'
    )
    os.system('echo ")\\";" >> mtl_default_shaders_src_autogen.inc')


if __name__ == '__main__':
    sys.exit(main())
