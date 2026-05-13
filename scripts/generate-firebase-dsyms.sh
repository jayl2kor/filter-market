#!/bin/bash
#
# Generate dSYMs for Firebase prebuilt C++ frameworks that don't ship dSYMs.
# Runs only during archive (install action). Fixes "Upload Symbols Failed"
# warnings on App Store Connect for FirebaseFirestoreInternal/abseil/grpc/etc.
#
# Reference: https://github.com/firebase/firebase-ios-sdk/issues/8194

set -e

# Skip non-archive builds
if [[ "$ACTION" != "install" ]]; then
    exit 0
fi

DWARF_DSYM_FOLDER="${DWARF_DSYM_FOLDER_PATH}"
FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}/Frameworks"

if [[ ! -d "$FRAMEWORKS_DIR" ]]; then
    echo "warning: Frameworks dir not found at $FRAMEWORKS_DIR — skipping dSYM generation"
    exit 0
fi

FRAMEWORKS=(
    "FirebaseFirestoreInternal.framework"
    "absl.framework"
    "grpc.framework"
    "grpcpp.framework"
    "openssl_grpc.framework"
    "FirebaseAnalytics.framework"
    "GoogleAdsOnDeviceConversion.framework"
    "GoogleAppMeasurement.framework"
    "GoogleAppMeasurementIdentitySupport.framework"
)

for FRAMEWORK in "${FRAMEWORKS[@]}"; do
    BINARY_NAME="${FRAMEWORK%.framework}"
    BINARY_PATH="${FRAMEWORKS_DIR}/${FRAMEWORK}/${BINARY_NAME}"
    DSYM_PATH="${DWARF_DSYM_FOLDER}/${FRAMEWORK}.dSYM"

    if [[ -f "$BINARY_PATH" ]] && [[ ! -d "$DSYM_PATH" ]]; then
        echo "Generating dSYM for ${FRAMEWORK}"
        dsymutil "$BINARY_PATH" -o "$DSYM_PATH" 2>/dev/null || \
            echo "warning: dsymutil failed for ${FRAMEWORK} (may be expected if framework has no debug info)"
    fi
done

echo "Firebase dSYM generation complete"
