#!/usr/bin/env bash
#
# Build XCFrameworks for Mindbox SDK schemes (Mindbox, MindboxLogger, MindboxNotifications).
# Output: Example/Frameworks/<Scheme>.xcframework (consumed by Example.xcodeproj).
# Intermediate archives go to build/archives (gitignored).

set -euo pipefail

PROJECT="Mindbox.xcodeproj"
SCHEMES=(MindboxLogger MindboxNotifications Mindbox)
OUTPUT_DIR="Example/Frameworks"
ARCHIVES_DIR="build/archives"

rm -rf "$OUTPUT_DIR" "$ARCHIVES_DIR"
mkdir -p "$OUTPUT_DIR" "$ARCHIVES_DIR"

if command -v xcbeautify >/dev/null 2>&1; then
    FORMATTER=(xcbeautify --quiet)
elif command -v xcpretty >/dev/null 2>&1; then
    FORMATTER=(xcpretty)
else
    FORMATTER=(cat)
fi

archive() {
    local scheme="$1"
    local destination="$2"
    local archive_path="$3"

    echo "==> Archiving $scheme for $destination"
    set -o pipefail
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$scheme" \
        -configuration Release \
        -destination "$destination" \
        -archivePath "$archive_path" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO \
        OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -enable-module-selectors-in-module-interface' \
        | "${FORMATTER[@]}"
}

for scheme in "${SCHEMES[@]}"; do
    device_archive="$ARCHIVES_DIR/${scheme}-iOS.xcarchive"
    sim_archive="$ARCHIVES_DIR/${scheme}-iOS-Simulator.xcarchive"

    archive "$scheme" "generic/platform=iOS" "$device_archive"
    archive "$scheme" "generic/platform=iOS Simulator" "$sim_archive"

    device_fw="$device_archive/Products/Library/Frameworks/${scheme}.framework"
    sim_fw="$sim_archive/Products/Library/Frameworks/${scheme}.framework"

    if [[ ! -d "$device_fw" || ! -d "$sim_fw" ]]; then
        echo "Expected framework not found for $scheme:"
        echo "  device: $device_fw"
        echo "  simulator: $sim_fw"
        exit 1
    fi

    echo "==> Creating ${scheme}.xcframework"
    xcodebuild -create-xcframework \
        -framework "$device_fw" \
        -framework "$sim_fw" \
        -output "$OUTPUT_DIR/${scheme}.xcframework"
done

echo
echo "XCFrameworks created in: $OUTPUT_DIR"
ls -1 "$OUTPUT_DIR"
