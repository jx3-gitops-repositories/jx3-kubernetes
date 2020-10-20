#!/usr/bin/env bash
set -e

# setup environment
KUBECONFIG="/tmp/jxhome/config"

export XDG_CONFIG_HOME="/builder/home/.config"
mkdir -p $XDG_CONFIG_HOME/git

jx --version

export GH_USERNAME="jenkins-x-labs-bot"
export GH_EMAIL="jenkins-x@googlegroups.com"
export GH_OWNER="cb-kubecd"

export PROJECT_ID=jenkins-x-labs-bdd
export CREATED_TIME=$(date '+%a-%b-%d-%Y-%H-%M-%S')
export CLUSTER_NAME="${BRANCH_NAME,,}-$BUILD_NUMBER-bdd-tls"
export ZONE=europe-west1-c
export LABELS="branch=${BRANCH_NAME,,},cluster=bdd-tls,create-time=${CREATED_TIME,,}"

# lets setup git
git config --global --add user.name JenkinsXBot
git config --global --add user.email jenkins-x@googlegroups.com

echo "running the BDD test with JX_HOME = $JX_HOME"

# replace the credentials file with a single user entry
echo "https://${GH_USERNAME//[[:space:]]}:${GH_ACCESS_TOKEN//[[:space:]]}@github.com" > $XDG_CONFIG_HOME/git/credentials

echo "using git credentials: $XDG_CONFIG_HOME/git/credentials"
ls -al $XDG_CONFIG_HOME/git/credentials

echo "creating cluster $CLUSTER_NAME in project $PROJECT_ID with labels $LABELS"

# lets find the current cloud resources version
export CLOUD_RESOURCES_VERSION=$(grep  'version: ' /workspace/source/git/github.com/jenkins-x-labs/cloud-resources.yml | awk '{ print $2}')
echo "found cloud-resources version $CLOUD_RESOURCES_VERSION"

git clone -b v${CLOUD_RESOURCES_VERSION} https://github.com/jenkins-x-labs/cloud-resources.git
cloud-resources/gcloud/create_cluster.sh

# TODO remove once we remove the code from the multicluster branch of jx:
export JX_SECRETS_YAML=/tmp/secrets.yaml

echo "using the version stream ref: $PULL_PULL_SHA"

# add external-dns and certmanager
jxl boot create -b --env dev --provider=gke --version-stream-ref=$PULL_PULL_SHA --env-git-owner=$GH_OWNER --project=$PROJECT_ID --cluster=$CLUSTER_NAME --zone=$ZONE \
  --domain $CLUSTER_NAME.jenkinsxlabs-test.com \
  --tls \
  --add=bitnami/external-dns \
  --tls-email jenkins-x-admin@googlegroups.com \
  --tls-production=false

# create service account key used by certmanager to add A records for the dns challange by letsencrypt
gcloud iam service-accounts create $CLUSTER_NAME-dns01-solver --display-name "$CLUSTER_NAME dns01-solver" --project jenkins-x-labs-bdd
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$CLUSTER_NAME-dns01-solver@$PROJECT_ID.iam.gserviceaccount.com --role roles/dns.admin --project jenkins-x-labs-bdd
gcloud iam service-accounts keys create /tmp/credentials.json --iam-account $CLUSTER_NAME-dns01-solver@$PROJECT_ID.iam.gserviceaccount.com --project jenkins-x-labs-bdd
kubectl create secret generic external-dns-gcp-sa --from-file=/tmp/credentials.json
rm /tmp/credentials.json


# import secrets...
echo "secrets:
  adminUser:
    username: admin
    password: $JENKINS_PASSWORD
  hmacToken: $GH_ACCESS_TOKEN
  pipelineUser:
    username: $GH_USERNAME
    token: $GH_ACCESS_TOKEN
    email: $GH_EMAIL" > /tmp/secrets.yaml

jxl boot secrets import -f /tmp/secrets.yaml --git-url https://github.com/${GH_OWNER}/environment-${CLUSTER_NAME}-dev.git

jxl boot run -b --job


# lets make sure jx defaults to helm3
export JX_HELM3="true"

gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
jx ns jx

# diagnostic commands to test the image's kubectl
kubectl version

# for some reason we need to use the full name once for the second command to work!
kubectl get environments
kubectl get env
kubectl get env dev -oyaml

# verify that we have a stagin certificate from LetsEncrypt
kubectl get issuer letsencrypt-staging -ojsonpath='{.status.conditions[0].status}'
kubectl get issuer letsencrypt-staging -ojsonpath='{.status.conditions[0].message}'
jxl verify tls hook-jx.$CLUSTER_NAME.jenkinsxlabs-test.com  --production=false --issuer 'Fake LE Intermediate X1'

echo cleaning up cloud resources
curl https://raw.githubusercontent.com/jenkins-x-labs/cloud-resources/v$CLOUD_RESOURCES_VERSION/gcloud/cleanup-cloud-resurces.sh | bash
gcloud container clusters delete $CLUSTER_NAME --zone $ZONE --quiet