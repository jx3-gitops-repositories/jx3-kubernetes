## Charts

This directory tree contains default properties of helm charts if no version or namespace is specified in your `helmfile.yaml` file along with default values files.

### Defaults 

The file layout is `[repositoryPrefix]/chartName/defaults.yaml` with the YAML file containing a `version:` property and an optional default `namespace` property which is used if no namespace is specified in the `helmfile.yaml`

e.g.

* [jenkins-x](jenkins-x)/[tekton](jenkins-x/tekton)/[defaults.yaml](jenkins-x/tekton/defaults.yaml)

The mapping of repository prefixes to URLs is specified in the [repositories.yml](repositories.yml) file

### Values files

A chart folder can include a values file or values template:

* `[repositoryPrefix]/chartName/values.yaml` the `values.yaml` which should be added to the helm command via `--values` argument
* `[repositoryPrefix]/chartName/values.yaml.gotmpl` a go template which is rendered by `helmfile` into a `values.yaml` which will be added to the helm command via `--values` argument

e.g.

* [jenkins-x](jenkins-x)/[tekton](jenkins-x/tekton)/[values.yaml.gotmpl](jenkins-x/tekton/values.yaml.gotmpl)

### Migrating a chart to an OCI registry

Charts published to an OCI registry (e.g. `oci://ghcr.io/...`) are added to [repositories.yml](repositories.yml) under the old prefix with an `-oci` suffix. The old chart folder is kept with a `replacementChartPrefix` so that existing `helmfile.yaml` releases are rewritten to the new prefix by `jx gitops helmfile resolve`.

See `ingress-nginx-oci` and `external-secrets-operator-oci` as examples.