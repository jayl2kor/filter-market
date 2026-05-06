#!/usr/bin/env bash
set -euo pipefail

TOOLCHAIN_ID="${METAL_TOOLCHAIN_ID:-com.apple.dt.toolchain.Metal.32023.864}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build/DerivedData}"

xcodegen generate

xcodebuild \
  -project moodit.xcodeproj \
  -scheme moodit \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -toolchain "$TOOLCHAIN_ID" \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
