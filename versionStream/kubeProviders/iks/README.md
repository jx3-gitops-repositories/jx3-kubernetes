# Jenkins X Boot configuration for IBM Cloud

CAUTION: Current `iks` clusters need `kaniko` if you want to use them for building Docker images in the course of your CI pipeline (which is an essential step to get your applications into your JX k8s cluster). This is not yet implemented, cf. https://github.com/jenkins-x/jx/issues/3971.

## Prerequisites

* Make yourself familiar with the general Jenkins-X (JX) setup: https://jenkins-x.io/documentation/
* You need a GitHub account: https://github.com (Checkout the appendix of this document, if you would like to use IBM Cloud Git instead)
* Before setting up (JX) on IBM cloud with Kubernetes (IKS) you need an IBM account. 
You can apply for a free trial for one year here: https://www.ibm.com/partners/start/cloud-container-service/

NOTE: A _free_ IBM cloud account does not include all necessary permissions and resources to run k8s and JX. 

## Initial cloud setup

### Automatic initial setup

Run the following shell script, it should setup the local cloud tools (`ibmcloud`) on your machine.

    # An IKS 1.10 cluster must be used, 1.11 was broken with jenkins-x at the time of writing
    curl -sL https://ibm.biz/idt-installer | bash
    
### Manual initial setup

If the automatic setup fails, you may perform a manual setup, as described here: https://console.bluemix.net/docs/cli/index.html#overview

And install some additional plugins

    ibmcloud plugin install container-service
    ibmcloud plugin install container-registry

and some tools used by JX

* install latest helm -> https://docs.helm.sh/using_helm/#installing-helm
* install kubectl 1.10 -> https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-binary-using-curl
* install jx -> https://jenkins-x.io/getting-started/install/

Then login to the IBM cloud

    ibmcloud login -a https://api.us-east.bluemix.net (--sso / --apikey as appropriate)

## Create/Install k8s/JX

NOTE: Check out the open issues section at the end of the document (before the Appendix section) for some known limitations!

### Create IKS cluster and JX automatically

One of the large strengths of JX is, that it can even set up a k8s cluster automatically during the install process.

Just call:

```bash
jx create cluster iks \
   -n jx-wdc04 \
   -r us-east \
   -z wdc04 \
   -m b2c.4x16 \
   --workers=3 \
   --kube-version=1.11.9 \
   \
   --namespace='jx'
```

and answer some remaining questions, e.g., for your Git/GitHub user.

NOTE: If you run into problems or want to customize parts of the setup, follow the instructions in the next section.

### Set up IKS and JX manually

#### Set up IKS cluster manually

* Find a region: `ibmcloud ks regions`
* Set the region (eg. us-east, cf. [issue 2984](https://github.com/jenkins-x/jx/issues/2984)): `ibmcloud ks region-set us-east`
* Find a zone (eg. wdc07): `ibmcloud ks zones`
* Find machine types (should use `b2c.4x16 minimum`): `ibmcloud ks machine-types --zone wdc07`
* Find the k8s 1.11.x version: `ibmcloud ks kube-versions`
* Find the Public and private vlans (if none exist, they will be created): `ibmcloud ks vlans --zone wdc07`
* Create VLANs, if vlans exist in the zone, they will need to be specified here otherwise they will be created.
* If you want to use let's encrypt, make sure to specify a cluster name so that `docker-registry.jx.<clustername>.<regionname>.containers.appdomain.cloud` is less than 64 characters (will be checked automatically during install), eg., `docker-registry.jx.jx-wdc07.us-east.container.appdomain.cloud < 64 chars` (Smallest possible is best).
* Set up the cluster (some parameters depend on your settings before or what resource types are available in the chosen region, zone etc.):

```bash
    ibmcloud ks cluster-create \
        --name jx-wdc07 \
        --kube-version 1.11.9 \ 
        --zone wdc07 \
        --machine-type b2c.4x16 \
        --workers 3 \
        --private-vlan 2323675 \
        --public-vlan 2323691
```

* Check until state is "normal" (takes about 25 minutes): `ibmcloud ks cluster-get --cluster jx-wdc07`
* Import cluster parameters to your shell environment: `eval $(ibmcloud ks cluster-config --export --cluster jx-wdc07)`

#### Setup Helm / Tiller

CAUTION: This gives Tiller all privileges, do not use it for production environments!

```bash
    kubectl create serviceaccount --namespace kube-system tiller
    kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    # kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'      
    helm init --service-account tiller --upgrade
```

#### Setup block storage drivers (Optional)

* Install block storage drives with helm

```bash
    # helm init # Unless you already have initialized helm in the setup step before?
    helm repo add ibm  https://registry.bluemix.net/helm/ibm
    helm repo update
    helm install ibm/ibmcloud-block-storage-plugin --name ibmcloud-block-storage-plugin
```

* Make block default

```bash
    kubectl patch storageclass ibmc-file-bronze -p \
        '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

* Alternatively (if included in your plan) you can also choose `ibmc-block-silver` or `ibmc-block-gold` for better IOPS

```bash
    kubectl patch storageclass ibmc-block-silver -p \
        '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

#### Setup https (Recommended)

WARNING: This does not work and needs further testing/investigation!

Note: There is also a jenkins- addon, may work but never tested with IBM Cloud

```bash
# Optional/Sometime necessary? kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6.1/deploy/manifests/00-crds.yaml
helm install \
    --namespace=kube-system \
    --name=cert-manager stable/cert-manager \
    --set=ingressShim.defaultIssuerKind=ClusterIssuer \
    --set=ingressShim.defaultIssuerName=letsencrypt-staging \
    --version v0.5.2
cat << EOF| kubectl create -n kube-system -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: YOUREEMAIL@ca.ibm.com
    privateKeySecretRef:
      name: letsencrypt-staging
    http01: {}
EOF
```

#### Install JX manually

* Have your GitHub account at hand,
* Have your cluster subdomain for the domain flag (example provided) at hand,
* answer Y to create ingress when asked,

```bash
jx install cluster --provider=iks \
    --domain='jx-wdc07.us-east.containers.appdomain.cloud' \
    [ --default-admin-password=<password> ]
```

* wait until done. can check status by doing `kubectl get deployments,services,pvc,pv,ingress -n jx` in another terminal
* Upgrade ingress if you have installed https: `jx upgrade ingress`
* Make sure you can push and pull images into the account: `ibmcloud cr token-add --non-expiring --readwrite --description "Jenkins-X Token"`

## Open issues

There are some open issues at the time of this writing (2019-02-05), some of which may limit your usage of IKS.

NOTE: This is only a snapshot, check out their state or if others exist meanwhile: https://github.com/jenkins-x/jx/issues?utf8=%E2%9C%93&q=is%3Aopen+is%3Aissue+label%3Aarea%2FIKS+

| *Limitation*                                                              | *GitHub Issue*                                       | *WIP* |
| ------------------------------------------------------------------------- |:----------------------------------------------------:|:-----:|
| Currently it is only possible to create a cluster in the region *us-east* | [#2984](https://github.com/jenkins-x/jx/issues/2984) |   -   |
| JX environments are not created automatically                             | [#2985](https://github.com/jenkins-x/jx/issues/2985) |   -   |
| Cluster registry is not automatically created                             | [#2997](https://github.com/jenkins-x/jx/issues/2997) |   -   |
| `batch-mode`, `verbose`-Flag etc. not possible                            | [#2996](https://github.com/jenkins-x/jx/issues/2996) |   -   |
| IKS needs `kaniko` to perform builds                                      | [#3971](https://github.com/jenkins-x/jx/issues/3971) |   -   |
----

## Appendix

These setups are usually not necessary.

### Create Docker secret

* `kubectl --namespace default create secret docker-registry registrysecret --docker-server=registry.<region>.bluemix.net --docker-username=token --docker-password=<token_value> --docker-email=<email>`
* Copy the "Token"

    echo -n token:<Token here> | base64 -w0

* Copy the base64 value and create a file called `config.json` with this contents:

```{
  "auths": {
    "registry.ng.bluemix.net": {
      "auth": "<base64 encoded token>"
    }
  }
}
```

* Replace the existing Docker secret

    kubectl delete secret jenkins-docker-cfg -n jx
    kubectl create secret generic jenkins-docker-cfg --from-file=./config.json -n jx

* At this point the jenkins server needs to restarted to pick up the new docker creds: `kubectl -njx delete pods` -lapp=jenkins

### Use IBM Git

If you want to use git.ng.bluemix.net (gitlab), create a personal access token there

    jx create git server gitlab https://git.ng.bluemix.net -n gitlab
    jx create git token -n gitlab -t <gitlab token> <gitlab username> 
