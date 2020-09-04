#/bin/sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CURRENR_DIR="$PWD"

git_pull()
{
    DIR=$1
    REV=$2
    URL=$3

    cd "$SCRIPT_DIR/../.."

    echo "--------------------------------------------------"
    echo "Fetching $URL ..."
    echo

    if [ -d $DIR -a -d $DIR/.git ]; then
		cd $DIR
		git fetch --all
		git checkout --force $REV
	else
		rm -rf $DIR
		git clone $URL $DIR
		cd $DIR
		git checkout $REV
	fi

    echo
    echo "Fetching $URL Done."
    echo
}

glslang_revision="7d65f09b83112c1ec9e29313cb9913ed2b850aa0"
spirv_cross_revision="f38cbeb814c73510b85697adbe5e894f9eac978f"
jsoncpp_revision="48246a099549ab325c01f69f24a34fc72e5c42e4"
jsoncpp_src_revision="645250b6690785be60ab6780ce4b58698d884d11"

git_pull third_party/glslang/src ${glslang_revision} https://chromium.googlesource.com/external/github.com/KhronosGroup/glslang
git_pull third_party/spirv-cross/src ${spirv_cross_revision} https://chromium.googlesource.com/external/github.com/KhronosGroup/SPIRV-Cross

git_pull third_party/jsoncpp ${jsoncpp_revision} https://chromium.googlesource.com/chromium/src/third_party/jsoncpp
git_pull third_party/jsoncpp/source ${jsoncpp_src_revision} https://chromium.googlesource.com/external/github.com/open-source-parsers/jsoncpp

cd "$CURRENR_DIR"