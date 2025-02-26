#!/bin/bash

#Check if the parameter is provided
if [ $# -eq 0 ]; then
echo "Please provide the release version number as a parameter."
exit 1
fi

#Check if the version number matches the semver format
if ! [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+(-rc)?$ ]]; then
echo "The release version number does not match the semver format (X.Y.Z or X.Y.Z-rc)."
exit 1
fi

#Check the current Git branch
current_branch=$(git symbolic-ref --short HEAD)
echo "Currently on branch: $current_branch"

if [[ ! $current_branch =~ ^(release|support)/[0-9]+\.[0-9]+\.[0-9]+(-rc)?$ ]]; then
    echo "The current Git branch ($current_branch) is not in the format 'release/X.Y.Z', 'release/X.Y.Z-rc', 'support/X.Y.Z' or 'support/X.Y.Z-rc'."
    exit 1
fi

version=$1

#Add changelog to the index and create a commit
podspec_file="Mindbox.podspec"
notification_podspec_file="MindboxNotifications.podspec"
sdkversionprovider_file="SDKVersionProvider/SDKVersionProvider.swift"
sdkversionconfig_file="SDKVersionProvider/SDKVersionConfig.xcconfig"
logger_podspec_file="MindboxLogger.podspec"

current_version=$(grep -E '^\s+spec.version\s+=' "$podspec_file" | cut -d'"' -f2)

# Update Mindbox.podspec version
echo "'Mindbox.podspec' Before updating version:"
grep "spec.version" $podspec_file

sed -i '' "s/\(spec.dependency 'MindboxLogger', '\)[^']*\(\'\)/\1$version\2/g" "$podspec_file"
echo "$podspec_file dependency on MindboxLogger updated to $version."

sed -i '' "s/^\([[:space:]]*spec.version[[:space:]]*=[[:space:]]*\"\).*\(\"$\)/\1$version\2/" $podspec_file

echo "'Mindbox.podspec' After updating version:"
grep "spec.version" $podspec_file

# Update MindboxNotifications.podspec version
echo "'MindboxNotifications.podspec' Before updating version:"
grep "spec.version" $notification_podspec_file

sed -i '' "s/\(spec.dependency 'MindboxLogger', '\)[^']*\(\'\)/\1$version\2/g" "$notification_podspec_file"
echo "$notification_podspec_file dependency on MindboxLogger updated to $version."

sed -i '' "s/^\([[:space:]]*spec.version[[:space:]]*=[[:space:]]*\"\).*\(\"$\)/\1$version\2/" $notification_podspec_file

echo "'MindboxNotifications.podspec' After updating version:"
grep "spec.version" $notification_podspec_file

# Update SDKVersionProvider.swift version
echo "'SDKVersionProvider.swift' Before updating version:"
grep "sdkVersion" $sdkversionprovider_file

sed -i '' "s/\(public static let sdkVersion = \"\).*\(\"$\)/\1$version\2/" $sdkversionprovider_file

echo "'SDKVersionProvider.swift' After updating version:"
grep "sdkVersion" $sdkversionprovider_file

# Update SDKVersionConfig.xcconfig version
echo "'SDKVersionConfig.xcconfig' Before updating version:"
grep "MARKETING_VERSION" $sdkversionconfig_file

sed -i '' "s/\(MARKETING_VERSION = \).*\$/\1$version/" $sdkversionconfig_file

echo "'SDKVersionConfig.xcconfig' After updating version:"
grep "MARKETING_VERSION" $sdkversionconfig_file

# Update MindboxLogger.podspec version
echo "'MindboxLogger.podspec' Before updating version:"
grep "spec.version" $logger_podspec_file

sed -i '' "s/^\([[:space:]]*spec.version[[:space:]]*=[[:space:]]*\"\).*\(\"$\)/\1$version\2/" $logger_podspec_file

echo "'MindboxLogger.podspec' After updating version:"
grep "spec.version" $logger_podspec_file

echo "Bump SDK version from $current_version to $version."

git add $podspec_file
git add $notification_podspec_file
git add $sdkversionprovider_file
git add $sdkversionconfig_file
git add $logger_podspec_file
git commit -m "Bump SDK version from $current_version to $version"

echo "Pushing changes to branch: $current_branch"
if ! git push origin $current_branch; then
    echo "Failed to push changes to the origin $current_branch"
    exit 1
fi

