#!/usr/bin/env bash

set -ex

diff_releases() {
  local namespace=$1
  local tmp_dir=tmp_head
  mkdir -p $tmp_dir

  local full_namespace_regen_needed=false

  git show "${defaultBranch}":helmfiles/${namespace}/helmfile.yaml > $tmp_dir/helmfile.yaml

  # If there are any non-version changes to the helmfile, trigger a full regen
    if ! diff <(sed '/version:/d' helmfiles/${namespace}/helmfile.yaml) <(sed '/version:/d' $tmp_dir/helmfile.yaml) >/dev/null; then
      full_namespace_regen_needed=true
      rm -rf $tmp_dir
      echo "full_namespace_regen"
      return
    else
      full_namespace_regen_needed=false
    fi

  declare -A local_releases_map head_releases_map

  while IFS= read -r line; do
    release_name=$(echo "$line" | cut -d " " -f 1)
    release_version=$(echo "$line" | cut -d " " -f 2)
    local_releases_map["$release_name"]="$release_version"
  done < <(yq e '.releases[] | .name + " " + .version' helmfiles/${namespace}/helmfile.yaml)

  while IFS= read -r line; do
    release_name=$(echo "$line" | cut -d " " -f 1)
    release_version=$(echo "$line" | cut -d " " -f 2)
    head_releases_map["$release_name"]="$release_version"
  done < <(yq e '.releases[] | .name + " " + .version' $tmp_dir/helmfile.yaml)

  local changed_releases=()


  # Compare versions of releases present in both local and main
  for release in "${!local_releases_map[@]}"; do
    local_version="${local_releases_map[$release]}"
    head_version="${head_releases_map[$release]}"

    if [[ -n "$head_version" && "$local_version" != "$head_version" ]]; then
      changed_releases+=("${release}")
    fi
  done

  # Identify releases added in local but not in main
  for release in "${!local_releases_map[@]}"; do
    if [[ -z "${head_releases_map[$release]}" ]]; then
      full_namespace_regen_needed=true
    fi
  done

  # Identify releases removed from main but not in local
  for release in "${!head_releases_map[@]}"; do
    if [[ -z "${local_releases_map[$release]}" ]]; then
      full_namespace_regen_needed=true
    fi
  done

  rm -rf $tmp_dir

  # If full regen is needed, return full_namespace_regen, otherwise return changed releases
  if $full_namespace_regen_needed; then
    echo "full_namespace_regen"
    return
  else
    for release in "${changed_releases[@]}"; do
      echo "${release}"
    done
  fi
}

diff_configs() {
  local namespace=$1
  local changed_files=("$@")  # Array of changed config files (e.g., configs/foo.yaml)
  local changed_release_configs=()  # Array to store the releases with changed configs

  # Loop through each release in the helmfile and check if any of the changed files apply
  while IFS= read -r release_name; do
    # Get the values files for this release
    values_files=$(yq e ".releases[] | select(.name == \"$release_name\") | .values[]" helmfiles/${namespace}/helmfile.yaml)

    # Normalize paths in changed_files by stripping the helmfiles/${namespace}/ prefix
    for changed_file in "${changed_files[@]:1}"; do
      normalized_changed_file="${changed_file#helmfiles/${namespace}/}"

      # Check if the normalized changed file matches any of the values files
      if echo "$values_files" | grep -q "$normalized_changed_file"; then
        changed_release_configs+=("$release_name")
        break  # No need to check other files if one is already found for this release
      fi
    done
  done < <(yq e '.releases[].name' helmfiles/${namespace}/helmfile.yaml)

  # Output the changed releases, ensuring each release is on a new line
  >&2 echo "Changes in config detected for releases: ${changed_release_configs[*]}"
  printf "%s\n" "${changed_release_configs[@]}"
}


OUTPUT_DIR=$1
SELECTOR=""
defaultBranch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')

changed_files=($(git log -m HEAD ^"${defaultBranch}" --name-only --pretty=format:))
helmfile_changes=false

# Detect changes in helmfiles/ or outside helmfiles/
for file in "${changed_files[@]}"; do
  if [[ "$file" == helmfiles/* ]]; then
    >&2 echo "Changes in helmfiles/ detected: $file"
    helmfile_changes=true
  else
    >&2 echo "Changes outside helmfiles/ detected: $file"
    rm -rf ${OUTPUT_DIR:?}/*/*/
    SELECTOR=""
    jx gitops repository create >&2
    echo ${SELECTOR}
    exit 0
  fi
done

if $helmfile_changes; then
  # Get the changed namespaces
  changedNamespaces=$(git log -m HEAD ^"$defaultBranch" --name-only --pretty=format: | grep "^helmfiles/" | cut -d "/" -f 2 | sort -u)

  # Get the list of changed config files (filtered by namespace)
  changedConfigs=$(git log -m HEAD ^"$defaultBranch" --name-only --pretty=format: | grep "/configs/" | sort -u)

  for namespace in ${changedNamespaces}; do
    # Filter config changes by namespace
    namespace_changed_configs=()
    while IFS= read -r file; do
      if [[ "$file" == helmfiles/${namespace}/configs/* ]]; then
        namespace_changed_configs+=("$file")
      fi
    done <<< "$changedConfigs"

    # Get release changes due to version differences
    versions_result=$(diff_releases "${namespace}")

    # If diff_releases indicates full_namespace_regen, trigger a full regen and continue
    if [[ "$versions_result" == "full_namespace_regen" ]]; then
      >&2 echo "Full namespace regeneration required for ${namespace} due to non-version changes"
      SELECTOR="${SELECTOR} --selector namespace=${namespace}"
      rm -rf ${OUTPUT_DIR}/cluster/namespaces/${namespace}.yaml
      rm -rf ${OUTPUT_DIR}/cluster/resources/${namespace}
      rm -rf ${OUTPUT_DIR}/customresourcedefinitions/${namespace}
      rm -rf ${OUTPUT_DIR}/namespaces/${namespace}
      continue
    fi

    # Get release changes due to config file changes
    config_result=$(diff_configs "${namespace}" "${namespace_changed_configs[@]}")

    # Combine version and config changes, removing duplicates and ensuring each release is separated correctly
    mapfile -t combined_changes < <(echo -e "${versions_result}\n${config_result}" | tr ' ' '\n' | sort -u)

    # If combined_changes is empty, trigger a full regen
    if [[ ${#combined_changes[@]} -eq 0 ]]; then
      >&2 echo "Full namespace regeneration required for ${namespace} due to no specific release changes"
      SELECTOR="${SELECTOR} --selector namespace=${namespace}"
      rm -rf ${OUTPUT_DIR}/cluster/namespaces/${namespace}.yaml
      rm -rf ${OUTPUT_DIR}/cluster/resources/${namespace}
      rm -rf ${OUTPUT_DIR}/customresourcedefinitions/${namespace}
      rm -rf ${OUTPUT_DIR}/namespaces/${namespace}
      continue
    fi

    # Ensure we don't add an empty release selector
    for release in "${combined_changes[@]}"; do
      if [[ -n "$release" ]]; then
        SELECTOR="${SELECTOR} --selector namespace=${namespace},name=${release}"
        rm -rf ${OUTPUT_DIR}/cluster/resources/${namespace}/${release}
        rm -rf ${OUTPUT_DIR}/customresourcedefinitions/${namespace}/${release}
        rm -rf ${OUTPUT_DIR}/namespaces/${namespace}/${release}
        >&2 echo "Regen resources for ${namespace}/${release}"
      fi
    done
  done
fi

# Default to full regen if no selectors were generated
if [ -z "${SELECTOR}" ]; then
  >&2 echo "No selector chosen - full regen."
  rm -rf ${OUTPUT_DIR}/*/*/
fi

jx gitops repository create >&2


echo ${SELECTOR}