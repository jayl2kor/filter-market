#!/usr/bin/env bash
set -euo pipefail

TOOLCHAIN_ID="${METAL_TOOLCHAIN_ID:-com.apple.dt.toolchain.Metal.32023.864}"
DESTINATION="${IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.3.1}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build/DerivedData}"

xcodegen generate

xcodebuild \
  -project moodit.xcodeproj \
  -scheme moodit \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -toolchain "$TOOLCHAIN_ID" \
  test
