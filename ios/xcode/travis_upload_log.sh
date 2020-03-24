#/bin/sh

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CURRENR_DIR=$PWD
TAG_PREFIX=

if [ ! "$TRAVIS_JOB_NAME" = "" ]; then
    TAG_PREFIX=${TRAVIS_JOB_NAME// /_}
fi

cd $SCRIPT_DIR

if [ ! -f "xcodebuild.log" ]; then
    exit 0
fi

github-release delete \
    -T ${GITHUB_TOKEN} \
    -o kakashidinho \
    -r metalangle \
    -d true \
    -t "${TAG_PREFIX}errorLog" \
    xcodebuild.log || true

github-release upload \
    -T ${GITHUB_TOKEN} \
    -o kakashidinho \
    -r metalangle \
    -d true \
    -t "${TAG_PREFIX}errorLog" \
    xcodebuild.log || true

cd $CURRENR_DIR
