#!/bin/bash
# WebView show profiling: N cold (ephemeral) + prime + N warm (persistent) runs.
UDID=BD6E5E37-A73E-4E32-9BA9-6BCD7B7153D6
BID=Pushok.Native
RS=/opt/homebrew/bin/rocketsim
OUT=/private/tmp/claude-502/-Users-semko-dev-Mindbox-ios-sdk/49ed9194-7640-4522-a6f0-aed76fd0f341/scratchpad/results.txt
N=10
: > "$OUT"

run_one() {
  local label="$1"; shift
  xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1
  sleep 1
  xcrun simctl launch "$UDID" "$BID" "$@" >/dev/null 2>&1
  sleep 2.5                                  # config screen settles
  "$RS" screen >/dev/null 2>&1               # seed snapshot store
  "$RS" interact tap --label Next >/dev/null 2>&1
  sleep 10                                   # wait for network-idle finalize (<= 9s JS cap)
  local sum imet
  sum=$(xcrun simctl spawn "$UDID" log show --predicate 'subsystem == "cloud.Mindbox"' --info --last 16s 2>/dev/null | grep "WVProfile] SUMMARY" | tail -1 | sed -E 's/^.*\[WVProfile\] //')
  if [ -z "$sum" ]; then
    sleep 4
    sum=$(xcrun simctl spawn "$UDID" log show --predicate 'subsystem == "cloud.Mindbox"' --info --last 22s 2>/dev/null | grep "WVProfile] SUMMARY" | tail -1 | sed -E 's/^.*\[WVProfile\] //')
  fi
  imet=$(xcrun simctl spawn "$UDID" log show --predicate 'subsystem == "cloud.Mindbox"' --info --last 22s 2>/dev/null | grep "InAppMetric" | tail -1 | sed -E 's/^.*\[InAppMetric\] //')
  echo "[$label] ${sum:-MISS} || ${imet:-noInAppMetric}" >> "$OUT"
  echo "[$label] done" >&2
}

for i in $(seq 1 $N); do run_one "cold-$i" -MBWVForceInfoLog; done
run_one "prime-warm" -MBWVForceInfoLog -MBWVPersistentStore     # seeds the persistent cache; discard
for i in $(seq 1 $N); do run_one "warm-$i" -MBWVForceInfoLog -MBWVPersistentStore; done
echo "ALL DONE" >> "$OUT"
