#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <Pod.podspec> [pod trunk push args...]" >&2
  exit 64
fi

readonly PODSPEC="$1"
shift

readonly MAX_PUSHES=4
readonly LANDING_POLLS=10
readonly LANDING_POLL_SECONDS=20
readonly TRUNK_API="https://trunk.cocoapods.org/api/v1"

readonly DUPLICATE='^-> "HTTP/1\.[01] 409 |Unable to accept duplicate entry'
readonly REFUSED='^-> "HTTP/1\.[01] 4[0-9]{2} |did not pass validation'
readonly TRANSIENT='^-> "HTTP/1\.[01] 5[0-9]{2} |Calling the GitHub commit API timed out|An error occurred on GitHub|An internal server error occurred|There was an error pushing a new version to trunk|An unexpected error occurred'

SPEC_ID="$(pod ipc spec "$PODSPEC" | ruby -rjson -e 'puts JSON.parse(STDIN.read).fetch_values("name", "version").join(" ")')"
read -r POD_NAME POD_VERSION <<<"$SPEC_ID"
readonly POD_NAME POD_VERSION

PUSH_LOG="$(mktemp)"
trap 'rm -f "$PUSH_LOG"' EXIT

trunk_has_version() {
  local status
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 30 \
    "$TRUNK_API/pods/$POD_NAME/specs/$POD_VERSION" || true)"
  [ "$status" = 302 ]
}

version_lands_on_trunk() {
  local poll
  for ((poll = 1; poll <= LANDING_POLLS; poll++)); do
    if trunk_has_version; then
      return 0
    fi
    if [ "$poll" -lt "$LANDING_POLLS" ]; then
      sleep "$LANDING_POLL_SECONDS"
    fi
  done
  return 1
}

push_output_matches() {
  grep -qE "$1" "$PUSH_LOG"
}

if trunk_has_version; then
  echo "::notice::$POD_NAME $POD_VERSION is already on trunk, skipping the push"
  exit 0
fi

for ((push = 1; ; push++)); do
  set +e
  pod trunk push "$PODSPEC" "$@" 2>&1 | tee "$PUSH_LOG"
  rc=$?
  set -e

  if [ "$rc" -eq 0 ]; then
    exit 0
  fi

  if push_output_matches "$DUPLICATE"; then
    echo "::notice::trunk returned 409, $POD_NAME $POD_VERSION is already published"
    exit 0
  fi

  if push_output_matches "$REFUSED"; then
    exit "$rc"
  fi

  if version_lands_on_trunk; then
    echo "::warning::pod trunk push exited with $rc, but trunk has $POD_NAME $POD_VERSION; treating it as published"
    exit 0
  fi

  if ! push_output_matches "$TRANSIENT"; then
    exit "$rc"
  fi

  if [ "$push" -ge "$MAX_PUSHES" ]; then
    echo "::error::pod trunk push of $POD_NAME $POD_VERSION failed $push times and trunk does not have it"
    exit "$rc"
  fi

  echo "::warning::pod trunk push of $POD_NAME $POD_VERSION failed with $rc and trunk does not have it; pushing again ($((push + 1))/$MAX_PUSHES)"
done
