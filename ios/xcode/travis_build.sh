#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CURRENR_DIR=$PWD
CONFIGURATION=$1
SDK=$2

if [ "$CONFIGURATION" = "" ]; then
    CONFIGURATION=Debug
fi

if [ "$SDK" = "" ]; then
    SDK=iphoneos
fi

cd $SCRIPT_DIR

xcodebuild build \
           -project MGLKitSamples.xcodeproj \
           -scheme MGLKitSampleApp  \
           -sdk $SDK \
           -configuration $CONFIGURATION \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGN_ENTITLEMENTS="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO

xcodebuild build \
           -project MGLKitSamples.xcodeproj \
           -scheme MGLPaint  \
           -sdk $SDK \
           -configuration $CONFIGURATION \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGN_ENTITLEMENTS="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO

cd $CURRENR_DIR

