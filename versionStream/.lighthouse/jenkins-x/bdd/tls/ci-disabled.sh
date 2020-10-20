#!/usr/bin/env bash
set -e
set -x

# BDD test specific part
export BDD_NAME="bdd-gke-tls"

# the gitops repository template to use
export GITOPS_TEMPLATE_PROJECT="jx3-gitops-repositories/jx3-gke-terraform-vault"

export RUN_TEST="`pwd`/`dirname "$0"`/test.sh"

`dirname "$0"`/../ci.sh
