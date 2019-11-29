#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CURRENR_DIR=$PWD
CONFIGURATION=$1
SDK=$2
QUIET=$3

if [ "$CONFIGURATION" = "" ]; then
    CONFIGURATION=Debug
fi

if [ "$SDK" = "" ]; then
    SDK=iphoneos
fi

cd $SCRIPT_DIR

invoke_xcodebuild()
{
    TARGET=$1

    xcodebuild build \
               -project MGLKitSamples.xcodeproj \
               -scheme $TARGET  \
               -sdk $SDK \
               -configuration $CONFIGURATION \
               CODE_SIGN_IDENTITY="" \
               CODE_SIGN_ENTITLEMENTS="" \
               CODE_SIGNING_REQUIRED=NO \
               CODE_SIGNING_ALLOWED=NO \
               $QUIET \
               | xcpretty
}

invoke_xcodebuild MGLKitSampleApp
invoke_xcodebuild MGLPaint
invoke_xcodebuild MGLKitSampleApp_ios9.0
invoke_xcodebuild hello_triangle

cd $CURRENR_DIR

