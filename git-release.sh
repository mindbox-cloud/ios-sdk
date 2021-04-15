#!/bin/bash
set -e
version=$(cat Mindbox.podspec |grep 'spec.version      =' | cut -f2 -d"\"")
text=$1
token=$2
user=$3
branch=${GITHUB_REF##*/}
repo_full_name=$(git config --get remote.origin.url | sed 's/.*:\/\/github.com\///;s/.git$//' | cut -f2 -d":")
generate_post_data()
{
  cat <<EOF
{
  "tag_name": "$version",
  "target_commitish": "$branch",
  "name": "Pre-release-$version",
  "body": "$text",
  "draft": false,
  "prerelease": true
}
EOF
}
set-tag(){
  set-local-tag
}
set-local-tag(){
if [ $(git tag -l | grep $version) ]; then
    echo "Local tag cleanup"
    git tag -d $version
    git tag $version
else
    git tag $version
fi
}
set-remote-tag(){
if [ $(git ls-remote --tags https://$user:$token@github.com/$repo_full_name.git | cut -f3 -d"/" | grep $version) ]; then
    echo "Remote tag cleanup"
    git push --delete https://$user:$token@github.com/$repo_full_name.git $version
    git push https://$user:$token@github.com/$repo_full_name.git $version
else
    git push https://$user:$token@github.com/$repo_full_name.git $version
fi
}
echo "Create release $version for repo: $repo_full_name branch: $branch"
echo "Release settings: $(generate_post_data)"
post-request(){
  curl -s --show-error --user "$user:$token" --data "$(generate_post_data)" "https://api.github.com/repos/$repo_full_name/releases"
}
set-tag
post-request