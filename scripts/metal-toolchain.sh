#!/usr/bin/env bash
set -euo pipefail

TOOLCHAIN_ID="${METAL_TOOLCHAIN_ID:-com.apple.dt.toolchain.Metal.32023.864}"

echo "Metal toolchain:"
xcodebuild -showComponent MetalToolchain

echo
echo "metal:"
xcodebuild -find-executable metal -toolchain "$TOOLCHAIN_ID"

echo
echo "metallib:"
xcodebuild -find-executable metallib -toolchain "$TOOLCHAIN_ID"
