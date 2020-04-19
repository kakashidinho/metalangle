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
    SDK=appletvos
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

invoke_xcodebuild MetalANGLE_static_tvos
invoke_xcodebuild MGLKitSampleApp_tvos
invoke_xcodebuild MGLPaint_tvos
invoke_xcodebuild simple_vertex_shader_tvos

cd $CURRENR_DIR

