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
spirv_headers_revision="f8bf11a0253a32375c32cad92c841237b96696c0"
spirv_tools_revision="67f4838659f475d618c120e13d1a196d7e00ba4b"
spirv_cross_revision="e58e8d5dbe03ea2cc755dbaf43ffefa1b8d77bef"
jsoncpp_revision="493c9385c91023c3819b51ee0de552d52229a1e5"
jsoncpp_src_revision="645250b6690785be60ab6780ce4b58698d884d11"
zlib_revision="156be8c52f80cde343088b4a69a80579101b6e67"

# Fetch source code
git_pull third_party/glslang/src ${glslang_revision} https://chromium.googlesource.com/external/github.com/KhronosGroup/glslang
git_pull third_party/spirv-headers/src ${spirv_headers_revision} https://chromium.googlesource.com/external/github.com/KhronosGroup/SPIRV-Headers
git_pull third_party/spirv-tools/src ${spirv_tools_revision} https://chromium.googlesource.com/external/github.com/KhronosGroup/SPIRV-Tools
git_pull third_party/spirv-cross/src ${spirv_cross_revision} https://chromium.googlesource.com/external/github.com/KhronosGroup/SPIRV-Cross

git_pull third_party/jsoncpp ${jsoncpp_revision} https://chromium.googlesource.com/chromium/src/third_party/jsoncpp
git_pull third_party/jsoncpp/source ${jsoncpp_src_revision} https://chromium.googlesource.com/external/github.com/open-source-parsers/jsoncpp
git_pull third_party/zlib ${zlib_revision} https://chromium.googlesource.com/chromium/src/third_party/zlib

# Generate headers for some third-party modules
cd "$SCRIPT_DIR/../.."

# SPIRV-Tools
cd third_party/spirv-tools/src
rm -rf "$SCRIPT_DIR/gen/spirv-tools"

python utils/update_build_version.py . "$SCRIPT_DIR/gen/spirv-tools/build-version.inc"

python utils/generate_grammar_tables.py \
    --spirv-core-grammar \
    ../../spirv-headers/src/include/spirv/unified1/spirv.core.grammar.json \
    --extinst-glsl-grammar \
    ../../spirv-headers/src/include/spirv/unified1/extinst.glsl.std.450.grammar.json \
    --extinst-opencl-grammar \
    ../../spirv-headers/src/include/spirv/unified1/extinst.opencl.std.100.grammar.json \
    --extinst-debuginfo-grammar \
    source/extinst.debuginfo.grammar.json \
    --extinst-cldebuginfo100-grammar \
    source/extinst.opencl.debuginfo.100.grammar.json \
    --core-insts-output \
    "$SCRIPT_DIR/gen/spirv-tools/core.insts-unified1.inc" \
    --glsl-insts-output \
    "$SCRIPT_DIR/gen/spirv-tools/glsl.std.450.insts.inc" \
    --opencl-insts-output \
    "$SCRIPT_DIR/gen/spirv-tools/opencl.std.insts.inc" \
    --operand-kinds-output \
    "$SCRIPT_DIR/gen/spirv-tools/operand.kinds-unified1.inc" \
    --extension-enum-output \
    "$SCRIPT_DIR/gen/spirv-tools/extension_enum.inc" \
    --enum-string-mapping-output \
    "$SCRIPT_DIR/gen/spirv-tools/enum_string_mapping.inc" \

spvtools_vendor_table()
{
    python utils/generate_grammar_tables.py \
        --extinst-vendor-grammar \
        source/extinst.$1.grammar.json \
        --vendor-insts-output \
        "$SCRIPT_DIR/gen/spirv-tools/$1.insts.inc" \
        --vendor-operand-kind-prefix \
        $2
}

spvtools_vendor_table "spv-amd-shader-explicit-vertex-parameter" "...nil..."
spvtools_vendor_table "spv-amd-shader-trinary-minmax" "...nil..."
spvtools_vendor_table "spv-amd-gcn-shader" "...nil..."
spvtools_vendor_table "spv-amd-shader-ballot" "...nil..."
spvtools_vendor_table "debuginfo" "...nil..."
spvtools_vendor_table "opencl.debuginfo.100" "CLDEBUG100_"

python utils/generate_registry_tables.py \
    --xml \
    ../../spirv-headers/src/include/spirv/spir-v.xml \
    --generator \
    "$SCRIPT_DIR/gen/spirv-tools/generators.inc"

python utils/generate_language_headers.py \
    --extinst-grammar \
    source/extinst.debuginfo.grammar.json \
    --extinst-output-path \
    "$SCRIPT_DIR/gen/spirv-tools/DebugInfo.h" \

python utils/generate_language_headers.py \
    --extinst-grammar \
    source/extinst.opencl.debuginfo.100.grammar.json \
    --extinst-output-path \
    "$SCRIPT_DIR/gen/spirv-tools/OpenCLDebugInfo100.h" \

# Done
cd "$CURRENR_DIR"