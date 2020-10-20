#!/bin/bash

set -x
set -e

echo "promoting changes in jx3-gitops-template to downstream templates"

declare -a repos=(
  # local
  "jx3-kubernetes" "jx3-kind-vault" "jx3-minikube-vault" "jx3-docker-vault"
  # GKE
  "jx3-gke-vault" "jx3-gke-gsm" "jx3-gke-gcloud-vault" 
  # EKS
  "jx3-eks-terraform-vault"
  # Azure
  "jx3-azure-terraform"
)

export TMPDIR=/tmp/jx3-gitops-promote
rm -rf $TMPDIR
mkdir -p $TMPDIR

for r in "${repos[@]}"
do
  echo "upgrading repository https://github.com/jx3-gitops-repositories/$r"

  cd $TMPDIR
  git clone https://github.com/jx3-gitops-repositories/$r.git
  cd "$r"

  echo "recreating a clean version stream"
  rm -rf versionStream
  jx gitops kpt update || true

  kpt pkg get https://github.com/jenkins-x/jxr-versions.git/ versionStream
  rm -rf versionStream/jenkins*.yml versionStream/jx versionStream/.github versionStream/.pre* versionStream/.secrets* versionStream/OWNER*
  
  git add * || true
  git commit -a -m "chore: upgrade version stream" || true
  git push || true
done
