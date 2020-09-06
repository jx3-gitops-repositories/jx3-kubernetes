#!/bin/bash

set -x
set -e

echo "promoting changes in jx3-gitops-template to downstream templates"

declare -a repos=(
  # GKE
  "jx3-gke-terraform-vault" "jx3-gke-gcloud-vault" 
  # EKS
  "jx3-eks-terraform-vault"
  # local
  "jx3-kind-vault" "jx3-minikube-vault" "jx3-docker-vault"
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
  jx gitops kpt update || true
  git add * || true
  git commit -a -m "chore: upgrade version stream" || true
  git push || true
done
