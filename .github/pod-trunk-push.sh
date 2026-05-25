#!/usr/bin/env bash
# Wrapper around `pod trunk push` that treats a 409 Conflict
# ("Unable to accept duplicate entry") from trunk as success.
#
# Why: trunk sometimes returns 504 Gateway Timeout while the spec
# still lands in CocoaPods/Specs (Heroku 30s router cap on the
# GitHub Commits API call). Without this wrapper, re-running the
# failed publish job fails again with 409 "duplicate entry",
# keeping the workflow red even though the release is actually done.

set -uo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <Pod.podspec> [pod trunk push args...]" >&2
  exit 64
fi

PODSPEC="$1"; shift

set +e
OUT="$(pod trunk push "$PODSPEC" "$@" 2>&1)"
RC=$?
set -e
printf '%s\n' "$OUT"

if [ "$RC" -eq 0 ]; then
  exit 0
fi

if grep -qE 'HTTP/1\.[01] 409 Conflict|Unable to accept duplicate entry' <<<"$OUT"; then
  echo "[pod-trunk-push] trunk returned 409 — version already published, treating as success"
  exit 0
fi

exit "$RC"
