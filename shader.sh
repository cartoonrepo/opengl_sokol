#!/usr/bin/env bash
set -e

dir="$1"
file="$2"

./sokol-tools-bin/bin/linux/sokol-shdc -i $dir/$file -o $dir/shader.odin -l glsl430:metal_macos:hlsl5 -f sokol_odin
