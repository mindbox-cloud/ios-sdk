#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <checkout of the release tag>" >&2
  exit 64
fi

readonly PODSPEC_DIR="$1"
readonly REPO_NAME="mindbox-specs"
readonly REPO_URL="https://github.com/mindbox-cloud/Specs.git"
readonly REPO_DIR="${CP_REPOS_DIR:-$HOME/.cocoapods/repos}/$REPO_NAME"
readonly CDN_URL="https://cdn.cocoapods.org/"
readonly PODS_IN_DEPENDENCY_ORDER=(MindboxLogger MindboxNotifications Mindbox)

CHECKED_OUT_COMMIT="$(git -C "$PODSPEC_DIR" rev-parse 'HEAD^{commit}')"
readonly CHECKED_OUT_COMMIT

tag_commit() {
  git -C "$PODSPEC_DIR" fetch --quiet --depth=1 origin "refs/tags/$1" &&
    git -C "$PODSPEC_DIR" rev-parse 'FETCH_HEAD^{commit}'
}

if [ -d "$REPO_DIR" ]; then
  pod repo update "$REPO_NAME"
else
  pod repo add "$REPO_NAME" "$REPO_URL"
fi

for pod_name in "${PODS_IN_DEPENDENCY_ORDER[@]}"; do
  podspec="$PODSPEC_DIR/$pod_name.podspec"
  version="$(pod ipc spec "$podspec" | ruby -rjson -e 'puts JSON.parse(STDIN.read).fetch("version")')"
  if [ "$(tag_commit "$version")" != "$CHECKED_OUT_COMMIT" ]; then
    echo "$PODSPEC_DIR is not at tag $version; publish from the release tag." >&2
    exit 1
  fi
  if [ -d "$REPO_DIR/$pod_name/$version" ]; then
    echo "$pod_name $version is already in $REPO_URL, skipping."
    continue
  fi
  pod repo push "$REPO_NAME" "$podspec" --use-json --allow-warnings --sources="$REPO_NAME,$CDN_URL"
done
