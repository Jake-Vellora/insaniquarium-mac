#!/bin/bash
# create a flat dir of symlinks to SexyAppFramework
export RDEST="../src/SexyAppFrameworkFlat/SexyAppFramework"
mkdir -p $RDEST
export DEST=$(realpath $RDEST)
find ../src/SexyAppFramework -type f ! -path "*/platform/*" | while read f; do
    abs=$(realpath "$f")       # get absolute path
    ln -s "$abs" "$DEST"
done
