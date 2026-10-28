#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd "$1" && pwd)
output_dir=$2
derived_data=$(mktemp -d)

for scheme in Mindbox MindboxNotifications; do
  xcodebuild docbuild \
    -quiet \
    -project "$source_dir/Mindbox.xcodeproj" \
    -scheme "$scheme" \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$derived_data" \
    DOCC_HOSTING_BASE_PATH=ios-sdk/api
done

products="$derived_data/Build/Products/Debug-iphoneos"
rm -rf "$output_dir"
xcrun docc merge \
  "$products/Mindbox.doccarchive" \
  "$products/MindboxNotifications.doccarchive" \
  "$products/MindboxLogger.doccarchive" \
  --synthesized-landing-page-name "Mindbox iOS SDK" \
  --synthesized-landing-page-kind SDK \
  --output-path "$output_dir"

cat > "$output_dir/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>Mindbox iOS SDK API reference</title>
<meta http-equiv="refresh" content="0; url=documentation/">
<a href="documentation/">Mindbox iOS SDK API reference</a>
HTML
