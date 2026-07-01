#!/bin/bash
# Fresh multishow measurement: two in-apps back-to-back in one session.
#   show #1 = стирашка (imageCount=2), show #2 = онбординг (imageCount=3), both via Async op.
#   cold  = -MBWVForceInfoLog only            (no cache, fresh WKWebView each show = "как сейчас")
#   warm  = + -MBWVPersistentStore -MBWVReuseInstance (persistent cache + borrowed warm instance)
UDID=BD6E5E37-A73E-4E32-9BA9-6BCD7B7153D6
BID=Pushok.Native
RS=/opt/homebrew/bin/rocketsim
DIR=/private/tmp/claude-502/-Users-semko-dev-Mindbox-ios-sdk/49ed9194-7640-4522-a6f0-aed76fd0f341/scratchpad
OUT=$DIR/multishow_results.txt
: > "$OUT"

run() {
  local label="$1"; local flags="$2"
  xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1; sleep 1
  xcrun simctl launch "$UDID" "$BID" $flags >/dev/null 2>&1; sleep 3
  "$RS" screen >/dev/null 2>&1
  "$RS" interact tap --label Next >/dev/null 2>&1; sleep 13     # SDK init + config download
  "$RS" interact tap --label Async >/dev/null 2>&1; sleep 10    # show #1 (стирашка) → finalize
  "$RS" interact tap 373 84 >/dev/null 2>&1; sleep 2            # close стирашка
  "$RS" interact tap --label Async >/dev/null 2>&1; sleep 10    # show #2 (онбординг) → finalize
  "$RS" interact tap 373 84 >/dev/null 2>&1; sleep 1            # close онбординг
  xcrun simctl spawn "$UDID" log show --predicate 'subsystem == "cloud.Mindbox"' --info --last 45s 2>/dev/null \
    | grep "WVProfile] SUMMARY" | sed -E 's/^.*\[WVProfile\] //' | tail -2 \
    | while IFS= read -r line; do echo "[$label] $line" >> "$OUT"; done
  echo "[$label] captured $(date +%H:%M:%S)" >&2
}

WARM="-MBWVForceInfoLog -MBWVPersistentStore -MBWVReuseInstance"
run "prime" "$WARM"                       # seed persistent cache; discarded in parsing
for i in 1 2 3 4 5 6; do run "warm-$i" "$WARM"; done
for i in 1 2 3 4; do run "cold-$i" "-MBWVForceInfoLog"; done
echo "ALL DONE" >> "$OUT"
