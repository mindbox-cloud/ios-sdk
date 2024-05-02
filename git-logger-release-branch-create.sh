#!/bin/bash

# Check if the parameter is provided
if [ $# -eq 0 ]; then
  echo "Please provide the release version number as a parameter."
  exit 1
fi

# Check if the version number matches the semver format
if ! [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+(-rc)?$ ]]; then
  echo "The release version number does not match the semver format (X.Y.Z or X.Y.Z-rc)."
  exit 1
fi

version=$1

# Update version in MindboxLogger.podspec
logger_podspec_file="MindboxLogger.podspec"
sed -i '' "s/^\([[:space:]]*spec.version[[:space:]]*=[[:space:]]*'logger-\).*\('\)$/\1$version\2/" "$logger_podspec_file"
echo "$logger_podspec_file version updated to logger-$version."

# Update dependency version in Mindbox.podspec
podspec_file="Mindbox.podspec"
sed -i '' "s/\(spec.dependency 'MindboxLogger', '\)[^']*\(\'\)/\1$version\2/g" "$podspec_file"
echo "$podspec_file dependency on MindboxLogger updated to $version."

# Update dependency version in MindboxNotifications.podspec
notification_podspec_file="MindboxNotifications.podspec"
sed -i '' "s/\(spec.dependency 'MindboxLogger', '\)[^']*\(\'\)/\1$version\2/g" "$notification_podspec_file"
echo "$notification_podspec_file dependency on MindboxLogger updated to $version."


git add $logger_podspec_file $podspec_file $notification_podspec_file
git commit -m "Update MindboxLogger and dependencies to version $version"
git push origin HEAD
echo "Version update completed and pushed to repository."

tag="logger-$version"
git tag $tag
git push origin $tag

echo "Tag $tag pushed to repository."
