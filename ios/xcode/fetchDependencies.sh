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
spirv_cross_revision="e58e8d5dbe03ea2cc755dbaf43ffefa1b8d77bef"
jsoncpp_revision="493c9385c91023c3819b51ee0de552d52229a1e5"
jsoncpp_src_revision="645250b6690785be60ab6780ce4b58698d884d11"

git_pull third_party/glslang/src ${glslang_revision} https://chromium.googlesource.com/external/github.com/KhronosGroup/glslang
git_pull third_party/spirv-cross/src ${spirv_cross_revision} https://chromium.googlesource.com/external/github.com/KhronosGroup/SPIRV-Cross

git_pull third_party/jsoncpp ${jsoncpp_revision} https://chromium.googlesource.com/chromium/src/third_party/jsoncpp
git_pull third_party/jsoncpp/source ${jsoncpp_src_revision} https://chromium.googlesource.com/external/github.com/open-source-parsers/jsoncpp

cd "$CURRENR_DIR"