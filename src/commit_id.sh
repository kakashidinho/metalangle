#!/usr/bin/env bash
#  Copyright 2018 The ANGLE Project Authors. All rights reserved.
#  Use of this source code is governed by a BSD-style license that can be
#  found in the LICENSE file.

# Generate commit.h with git commit hash.
#

set -e

function usage {
    echo 'Usage: commit_id.sh check <angle_dir>                - check if git is present'
    echo '       commit_id.sh gen <angle_dir> <file_to_write>  - generate commit.h'
}

if [ "$#" -lt 2 ]
then
    usage
    exit 1
fi

d="$2"

if [ "$1" == "check" ]
then
    if [ -f "$d/.git/index" ]
    then
        echo 1
    else
        echo 0
    fi
elif [ "$1" == "gen" ]
then
    if [ ! "$3" ]
    then
        usage
        exit 1
    fi
    output="$(cd "$(dirname "$3")"; pwd -P)/$(basename "$3")"
    
    (
        set +e
        cd "$d"
        commit_id_size=12
        commit_id=$(git rev-parse --short=$commit_id_size HEAD 2>/dev/null)
        commit_date=$(git show -s --format=%ci HEAD 2>/dev/null)

        echo '#define ANGLE_COMMIT_HASH "'"${commit_id:-invalid-hash}"'"' > "$output"
        echo '#define ANGLE_COMMIT_HASH_SIZE '"$commit_id_size" >> "$output"
        echo '#define ANGLE_COMMIT_DATE "'"${commit_date:-invalid-date}"'"' >> "$output"

    )
else
    usage
    exit 2
fi
