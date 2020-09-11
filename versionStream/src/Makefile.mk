FETCH_DIR := build/base
TMP_TEMPLATE_DIR := build/tmp
OUTPUT_DIR := config-root

VAULT_ADDR ?= https://vault.secret-infra:8200

# NOTE to enable debug logging of 'helmfile template' to diagnose any issues with values.yaml templating
# you can run:
#
#     export HELMFILE_TEMPLATE_FLAGS="--debug"
#
# or change the next line to:
# HELMFILE_TEMPLATE_FLAGS ?= --debug
HELMFILE_TEMPLATE_FLAGS ?=

.PHONY: clean
clean:
	rm -rf build $(OUTPUT_DIR)

.PHONY: setup
setup:
	# lets create any missing SourceRepository defined in .jx/gitops/source-config.yaml which are not in: versionStream/src/base/namespaces/jx/source-repositories
	jx gitops repository create

.PHONY: init
init: setup
	mkdir -p $(FETCH_DIR)
	mkdir -p $(TMP_TEMPLATE_DIR)
	mkdir -p $(OUTPUT_DIR)/namespaces/jx
	cp -r versionStream/src/* build
	mkdir -p $(FETCH_DIR)/cluster/crds


.PHONY: fetch
fetch: init
	# lets configure the cluster gitops repository URL on the requirements if its missing
	jx gitops repository resolve --source-dir $(OUTPUT_DIR)/namespaces

	# set any missing defaults in the secrets mapping file
	jx secret convert edit

	# lets resolve chart versions and values from the version stream
	jx gitops helmfile resolve

	# lets make sure we are using the latest jx-cli in the git operator Job
	jx gitops image -s .jx/git-operator

	# this line avoids the next helmfile command failing...
	helm repo add jx http://chartmuseum.jenkins-x.io

	# generate the yaml from the charts in helmfile.yaml and moves them to the right directory tree (cluster or namespaces/foo)
	jx gitops helmfile template $(HELMFILE_TEMPLATE_FLAGS) --args="--include-crds --values=jx-values.yaml --values=versionStream/src/fake-secrets.yaml.gotmpl --values=imagePullSecrets.yaml" --output-dir $(OUTPUT_DIR)

	# convert k8s Secrets => ExternalSecret resources using secret mapping + schemas
	# see: https://github.com/jenkins-x/jx-secret#mappings
	jx secret convert --dir $(OUTPUT_DIR)

	# replicate secrets to local staging/production namespaces
	jx secret replicate --selector secret.jenkins-x.io/replica-source=true

	# lets make sure all the namespaces exist for environments of the replicated secrets
	jx gitops namespace --dir-mode --dir $(OUTPUT_DIR)/namespaces

.PHONY: build
# uncomment this line to enable kustomize
#build: build-kustomise
build: build-nokustomise

.PHONY: build-kustomise
build-kustomise: kustomize post-build

.PHONY: build-nokustomise
build-nokustomise: copy-resources post-build


.PHONY: pre-build
pre-build:

.PHONY: post-build
post-build:
	# lets generate the lighthouse configuration
	jx gitops scheduler -d config-root/namespaces/jx -o versionStream/src/base/namespaces/jx/lighthouse-config

	# lets add the kubectl-apply prune annotations
	#
	# NOTE be very careful about these 2 labels as getting them wrong can remove stuff in you cluster!
	jx gitops label --dir $(OUTPUT_DIR)/cluster    gitops.jenkins-x.io/pipeline=cluster
	jx gitops label --dir $(OUTPUT_DIR)/namespaces gitops.jenkins-x.io/pipeline=namespaces

	# lets label all Namespace resources with the main namespace which creates them and contains the Environment resources
	jx gitops label --dir $(OUTPUT_DIR)/cluster --kind=Namespace team=jx

	# lets enable pusher-wave to perform rolling updates of any Deployment when its underlying Secrets get modified
	# by modifying the underlying secret store (e.g. vault / GSM / ASM) which then causes External Secrets to modify the k8s Secrets
	jx gitops annotate --dir  $(OUTPUT_DIR)/namespaces --kind Deployment wave.pusher.com/update-on-config-change=true

	# lets force a rolling upgrade of lighthouse pods whenever we update the lighthouse config...
	jx gitops hash -s config-root/namespaces/jx/lighthouse-config/config-cm.yaml -s config-root/namespaces/jx/lighthouse-config/plugins-cm.yaml -d config-root/namespaces/jx/lighthouse

.PHONY: kustomize
kustomize: pre-build
	kustomize build ./build  -o $(OUTPUT_DIR)/namespaces

.PHONY: copy-resources
copy-resources: pre-build
	cp -r ./build/base/* $(OUTPUT_DIR)
	rm $(OUTPUT_DIR)/kustomization.yaml

.PHONY: lint
lint:

.PHONY: dev-ns verify-ingress
verify-ingress:
	jx verify ingress -b

.PHONY: dev-ns verify-ingress-ignore
verify-ingress-ignore:
	-jx verify ingress -b

.PHONY: dev-ns verify-install
verify-install:
	# TODO lets disable errors for now
	# as some pods stick around even though they are failed causing errors
	-jx verify install --pod-wait-time=2m

.PHONY: verify
verify: dev-ns verify-ingress
	jx verify env
	jx verify webhooks --verbose --warn-on-fail

.PHONY: dev-ns verify-ignore
verify-ignore: verify-ingress-ignore

.PHONY: secrets-populate
secrets-populate:
	# lets populate any missing secrets we have a generator in `charts/repoName/chartName/secret-schema.yaml`
	# they can be modified/regenerated at any time via `jx secret edit`
	-VAULT_ADDR=$(VAULT_ADDR) jx secret populate -n jx

.PHONY: secrets-wait
secrets-wait:
	# lets wait for the ExternalSecrets service to populate the mandatory Secret resources
	VAULT_ADDR=$(VAULT_ADDR) jx secret wait -n jx

.PHONY: git-setup
git-setup:
	jx gitops git setup
	git pull

.PHONY: regen-check
regen-check:
	jx gitops condition --last-commit-msg-prefix '!Merge pull request' -- make git-setup resolve-metadata all kubectl-apply verify-ingress-ignore commit

	# lets run this twice to ensure that ingress is setup after applying nginx if not using a custom domain yet
	jx gitops condition --last-commit-msg-prefix '!Merge pull request' -- make verify-ingress-ignore all verify-ignore secrets-populate commit push secrets-wait

.PHONY: apply
apply: regen-check kubectl-apply verify

.PHONY: kubectl-apply
kubectl-apply:
	# NOTE be very careful about these 2 labels as getting them wrong can remove stuff in you cluster!
	kubectl apply --prune -l=gitops.jenkins-x.io/pipeline=cluster    -R -f $(OUTPUT_DIR)/cluster
	kubectl apply --prune -l=gitops.jenkins-x.io/pipeline=namespaces -R -f $(OUTPUT_DIR)/namespaces

	# lets apply any infrastructure specific labels or annotations to enable IAM roles on ServiceAccounts etc
	jx gitops postprocess

.PHONY: resolve-metadata
resolve-metadata:
	# lets merge in any output from Terraform in the ConfigMap default/terraform-jx-requirements if it exists
	jx gitops requirements merge

	# lets resolve any requirements
	jx gitops requirements resolve -n

.PHONY: commit
commit:
	-git add --all
	-git status
	# lets ignore commit errors in case there's no changes and to stop pipelines failing
	-git commit -m "chore: regenerated"

.PHONY: all
all: clean fetch build lint


.PHONY: pr
pr: all commit push-pr-branch

.PHONY: push-pr-branch
push-pr-branch:
	jx gitops pr push

.PHONY: push
push:
	git push

.PHONY: release
release: lint

.PHONY: dev-ns
dev-ns:
	@echo "****************************************"
	@echo "**                                    **"
	@echo "** CHANGING TO jx NAMESPACE TO VERIFY **"
	@echo "**                                    **"
	@echo "****************************************"
	kubectl config set-context dummy  --namespace=jx
	kubectl config use-context dummy
	jx ns -b