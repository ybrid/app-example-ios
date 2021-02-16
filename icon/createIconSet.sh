#!/bin/zsh

#
# creates necessary png files for app icon from given png file.
# Usage: $1 - png file name (including '.png')
# 

name=$(basename $1 .png)
dir="$name.iconset"
rm -rfd $dir
mkdir -p $dir
sizes=(20 40 60 80 120 58 87 180 29 58 76 152 167 1024)
for size in ${sizes[@]}; do
    out="$dir/${name}_${size}x${size}.png"
    sips -z $size $size $1 --out $out
done

