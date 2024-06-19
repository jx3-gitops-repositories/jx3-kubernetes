#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

CHECKSUMS=$(curl -Ls "https://github.com/jenkins-x/jx/releases/download/v${JX_VERSION}/jx-checksums.txt")
declare -A sha256
while read sha file
do
  if [[ "$file" =~ ^jx-darwin-(.*)\.tar\.gz$ ]]
  then
    sha256[${BASH_REMATCH[1]}]=$sha
  fi
done <<< "$CHECKSUMS"

content=$(base64 -w 0 << EOT
cask "jx" do
  arch arm: "arm64", intel: "amd64"

  version "${JX_VERSION}"
  sha256 arm:   "${sha256[arm64]}",
         intel: "${sha256[amd64]}"

  url "http://github.com/jenkins-x/jx/releases/download/v#{version}/jx-darwin-#{arch}.tar.gz"

  name "Jenkins X cli"
  desc "A tool to install and interact with Jenkins X on your Kubernetes cluster."
  homepage "https://jenkins-x.io/"

  binary 'jx'
end
EOT
)

existingfile=$(curl -Ls \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/jenkins-x/homebrew-jx/contents/Casks/jx.rb)

prevcontent="$(grep '"content"' <<< "$existingfile" | cut -d\" -f4)"
# Github returns content wrapped at column 60. Removing the newlines before comparing

if [ "$content" == "${prevcontent//\\n}" ]
then
  echo Cask already current
  exit 0
fi

prevsha=$(grep '"sha"' <<< "$existingfile" | cut -d\" -f4)

curl -Ls \
  -X PUT \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/jenkins-x/homebrew-jx/contents/Casks/jx.rb \
  -d @- << EOT
{
  "message":"chore: upgrade cask jx to version $JX_VERSION",
  "committer":{"name":"jenkins-x-bot","email":"jenkinsx@cd.foundation"},
  "content":"$content",
  "sha":"$prevsha"
}
EOT
