#!/usr/bin/env bash

OUTPUT_DIR=$1

SELECTOR=""
if ! git log -m -1 --name-only --pretty=format: | grep -qv "^helmfiles/"; then
  changedNamespaces=$(git log -m -1 --name-only --pretty=format: | grep "^helmfiles/" | cut -d "/" -f 2 | sort -u)
  if echo "$changedNamespaces" | grep -q ^jx$; then
    >&2 echo jx namespace changed, no selectors added
  else
    for namespace in ${changedNamespaces}; do
      SELECTOR="${SELECTOR} --selector namespace=${namespace}"
      rm -rf ${OUTPUT_DIR}/cluster/namespaces/${namespace}.yaml
      rm -rf ${OUTPUT_DIR}/cluster/resources/${namespace}
      rm -rf ${OUTPUT_DIR}/customresourcedefinitions/${namespace}
      rm -rf ${OUTPUT_DIR}/namespaces/${namespace}
    done
    >&2 echo helmfile with selector ${SELECTOR}
  fi
fi

if [ -z "${SELECTOR}" ]; then
  >&2 echo helmfile without selector
  rm -rf ${OUTPUT_DIR}/*/*/
  jx gitops repository create >&2
fi

echo ${SELECTOR}
