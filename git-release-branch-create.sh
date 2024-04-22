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

if [[ ! $current_branch =~ ^test_release/[0-9]+\.[0-9]+\.[0-9]+(-rc)?$ ]]; then
echo "The current Git branch ($current_branch) is not 'develop' or in the format 'test_release/X.Y.Z' or 'test_release/X.Y.Z-rc'."
exit 1
fi

#Create a branch with the version name
version=$1
#branch_name="test_release/$version"
#git branch $branch_name
#git checkout $branch_name


#Add changelog to the index and create a commit
podspec_file="Mindbox.podspec"
notifivation_podspec_file="MindboxNotifications.podspec"
sdkversionprovider_file="SDKVersionProvider/SDKVersionProvider.swift"
sdkversionconfig_file="SDKVersionProvider/SDKVersionConfig.xcconfig"
current_version=$(grep -E '^\s+spec.version\s+=' "$podspec_file" | cut -d'"' -f2)

# Обновление версии в Mindbox.podspec
sed -i '' "s/^[[:space:]]*spec.version[[:space:]]*=[[:space:]]*\".*\"$/  spec.version      = \"$version\"/" $podspec_file

# Обновление версии в MindboxNotifications.podspec
sed -i '' "s/^[[:space:]]*spec.version[[:space:]]*=[[:space:]]*\".*\"$/  spec.version      = \"$version\"/" $notifivation_podspec_file

# Обновление версии в SDKVersionProvider.swift
sed -i '' "s/public static let sdkVersion = \".*\"$/public static let sdkVersion = \"$version\"/" $sdkversionprovider_file

# Обновление MARKETING_VERSION в SDKVersionConfig.xcconfig
sed -i '' "s/^MARKETING_VERSION = .*$/MARKETING_VERSION = $version/" $sdkversionconfig_file

echo "Bump SDK version from $current_version to $version."

git add $podspec_file
git add $notifivation_podspec_file
git add $sdkversionprovider_file
git commit -m "Bump SDK version to $version"

#git push origin $branch_name
git push origin $current_branch

git tag $version
git push origin $version

#echo "Branch $branch_name has been created and pushed."
echo "Changes have been committed and tagged as $version on branch $current_branch."
