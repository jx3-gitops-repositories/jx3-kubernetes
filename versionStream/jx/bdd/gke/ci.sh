#!/usr/bin/env bash
set -e
set -x

# BDD test specific part
export BDD_NAME="bdd-gke"

# the gitops repository template to use
#export GITOPS_TEMPLATE_PROJECT="jx3-gitops-repositories/jx3-gke-gcloud-vault"
export GITOPS_TEMPLATE_PROJECT="jx3-gitops-repositories/jx3-gke-terraform-vault"

# to enable spring / gradle...
#export RUN_TEST="bddjx -ginkgo.focus=spring-boot-http-gradle -test.v"

`dirname "$0"`/../ci.sh
