#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CURRENR_DIR=$PWD
CONFIGURATION=$1
SDK=$2
OUTPUT_DIR=$3
QUIET=$4

if [ "$CONFIGURATION" = "" ]; then
    CONFIGURATION=Debug
fi

if [ "$SDK" = "" ]; then
    SDK=iphoneos
fi

if [ ! "$OUTPUT_DIR" = "" ]; then
    OUTPUT_DIR_OPTION="-derivedDataPath $OUTPUT_DIR"
fi

cd $SCRIPT_DIR

invoke_xcodebuild()
{
    TARGET=$1

    ERR=0
    xcodebuild build \
               -project MGLKitSamples.xcodeproj \
               -scheme $TARGET  \
               -sdk $SDK \
               -configuration $CONFIGURATION \
               CODE_SIGN_IDENTITY="" \
               CODE_SIGN_ENTITLEMENTS="" \
               CODE_SIGNING_REQUIRED=NO \
               CODE_SIGNING_ALLOWED=NO \
               $OUTPUT_DIR_OPTION \
               $QUIET \
               |  tee xcodebuild.log | xcpretty && ERR=${PIPESTATUS[0]}

    if [ ! "$ERR" = "0" ]; then
        exit $ERR
    fi
}

./fetchDependencies.sh

invoke_xcodebuild MetalANGLE_static
invoke_xcodebuild MGLKitSampleApp
invoke_xcodebuild MGLPaint
invoke_xcodebuild MGLKitSampleApp_ios9.0
invoke_xcodebuild hello_triangle
invoke_xcodebuild multi_texture
invoke_xcodebuild particle_system
invoke_xcodebuild simple_texture_2d
invoke_xcodebuild simple_texture_cubemap
invoke_xcodebuild simple_vertex_shader
invoke_xcodebuild texture_wrap
invoke_xcodebuild mip_map_2d
invoke_xcodebuild stencil_operations
invoke_xcodebuild tri_fan_microbench

cd $CURRENR_DIR

