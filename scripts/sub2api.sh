#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="${ROOT_DIR}/charts/sub2api"
INDEX_FILE="${ROOT_DIR}/charts/index.yaml"
SOURCE_CHART_OCI="${SOURCE_CHART_OCI:-oci://ghcr.io/ben-wangz/k8s-at-home-charts/sub2api}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-ghcr.io/wei-shaw/sub2api}"
OCI_REPOSITORY="${OCI_REPOSITORY:-oci://ghcr.io/aaronyang0628/helm-chart-mirror}"
TMP_DIR=""

cleanup() {
  if [[ -n "$TMP_DIR" ]]; then
    rm -rf -- "$TMP_DIR"
  fi
}

trap cleanup EXIT

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

write_output() {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "$1" "$2" >>"${GITHUB_OUTPUT}"
  fi
}

strip_quotes() {
  local value
  if (($# > 0)); then
    value="$1"
  else
    IFS= read -r value || true
  fi
  value="${value#\"}"
  value="${value%\"}"
  printf '%s' "$value"
}

chart_field() {
  local chart="$1"
  local field="$2"
  helm show chart "$chart" | awk -v wanted="${field}" '
    !found && substr($0, 1, length(wanted) + 1) == wanted ":" {
      $1 = ""
      sub(/^[[:space:]]+/, "")
      print
      found = 1
    }
  ' | strip_quotes
}

image_value() {
  local chart="$1"
  local field="$2"
  helm show values "$chart" | awk -v wanted="${field}" '
    /^image:$/ {
      inside_image = 1
      next
    }
    inside_image && /^[^[:space:]]/ {
      exit
    }
    inside_image && !found && $1 == wanted ":" {
      $1 = ""
      sub(/^[[:space:]]+/, "")
      print
      found = 1
    }
  ' | strip_quotes
}

latest_package() {
  local packages=()
  shopt -s nullglob
  packages=("${CHART_DIR}"/sub2api-*.tgz)
  ((${#packages[@]} > 0)) || return 1
  printf '%s\n' "${packages[@]}" | LC_ALL=C sort -V | awk 'NF {value = $0} END {print value}'
}

max_version() {
  printf '%s\n' "$@" | LC_ALL=C sort -V | awk 'NF {value = $0} END {print value}'
}

bump_patch() {
  local version="$1"
  [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || die "unsupported chart version: ${version}"
  printf '%d.%d.%d\n' \
    "$((10#${BASH_REMATCH[1]}))" \
    "$((10#${BASH_REMATCH[2]}))" \
    "$((10#${BASH_REMATCH[3]} + 1))"
}

latest_release_version() {
  local tag
  local auth_header=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  tag="$(curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60 \
    "${auth_header[@]}" \
    -H 'Accept: application/vnd.github+json' \
    'https://api.github.com/repos/Wei-Shaw/sub2api/releases?per_page=30' |
    jq -er '
      map(select(.draft == false and .prerelease == false and
        (.tag_name | test("^v?[0-9]+\\.[0-9]+\\.[0-9]+$")))) |
      .[0].tag_name
    ')" || die 'could not resolve the latest stable Sub2API release'
  tag="${tag#v}"
  [[ "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid release tag: ${tag}"
  printf '%s\n' "$tag"
}

resolve_image_digest() {
  local repository="$1"
  local tag="$2"
  local workdir="$3"
  local scope="${repository#ghcr.io/}"
  local token manifest_file headers_file selected_file selected_digest config_digest os arch
  local accept='application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'

  token="$(curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60 \
    "https://ghcr.io/token?service=ghcr.io&scope=repository:${scope}:pull" |
    jq -er '.token')" || die "could not get an anonymous GHCR token for ${repository}"

  manifest_file="${workdir}/manifest.json"
  headers_file="${workdir}/manifest.headers"
  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60 \
    -D "${headers_file}" -o "${manifest_file}" \
    -H "Authorization: Bearer ${token}" -H "Accept: ${accept}" \
    "https://ghcr.io/v2/${scope}/manifests/${tag}" ||
    die "image tag does not exist or is not readable: ${repository}:${tag}"

  selected_file="${workdir}/selected-manifest.json"
  if jq -e '(.manifests? // null) | type == "array"' "${manifest_file}" >/dev/null; then
    selected_digest="$(jq -er '
      [.manifests[] | select(.platform.os == "linux" and .platform.architecture == "amd64")] |
      if length == 1 then .[0].digest else error("expected exactly one Linux amd64 manifest") end
    ' "${manifest_file}")" || die "no unique Linux amd64 manifest for ${repository}:${tag}"
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60 \
      -o "${selected_file}" \
      -H "Authorization: Bearer ${token}" -H "Accept: ${accept}" \
      "https://ghcr.io/v2/${scope}/manifests/${selected_digest}" ||
      die "could not read the Linux amd64 manifest for ${repository}:${tag}"
  else
    selected_digest="$(awk '
      tolower($1) == "docker-content-digest:" {
        gsub(/\r/, "", $2)
        print $2
        exit
      }
    ' "${headers_file}")"
    [[ -n "$selected_digest" ]] || die "registry did not return a digest for ${repository}:${tag}"
    cp -- "${manifest_file}" "${selected_file}"
  fi

  config_digest="$(jq -er '.config.digest' "${selected_file}")" ||
    die "image manifest has no config for ${repository}:${tag}"
  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60 \
    -H "Authorization: Bearer ${token}" \
    "https://ghcr.io/v2/${scope}/blobs/${config_digest}" |
    jq -e '(.os == "linux" and .architecture == "amd64")' >/dev/null ||
    die "resolved image is not linux/amd64: ${repository}:${tag}"

  printf '%s\n' "${selected_digest}"
}

index_entry() {
  local chart_version="$1"
  awk -v target="${chart_version}" '
    /^  sub2api:/ {
      in_sub2api = 1
      next
    }
    in_sub2api && /^  [^ -]/ {
      exit
    }
    in_sub2api && /^  - apiVersion:/ {
      digest = ""
      url = ""
      version = ""
    }
    in_sub2api && /^    digest:/ {digest = $2}
    in_sub2api && /^    version:/ {version = $2}
    in_sub2api && /^    - sub2api\/sub2api-/ {url = $2}
    in_sub2api && version == target && url != "" {
      printf "%s\t%s\n", digest, url
      exit
    }
  ' "${INDEX_FILE}"
}

verify_package() {
  local package="${1:-}"
  local chart_version app_version image_repository image_tag image_digest expected_digest package_digest
  local package_name package_version entry index_digest index_url workdir

  if [[ -z "$package" ]]; then
    package="$(latest_package || true)"
  fi
  [[ -n "$package" && -f "$package" ]] || die 'no Sub2API chart package found'

  package_name="$(basename -- "$package")"
  package_version="${package_name#sub2api-}"
  package_version="${package_version%.tgz}"
  chart_version="$(chart_field "$package" version)"
  app_version="$(chart_field "$package" appVersion)"
  image_repository="$(image_value "$package" repository)"
  image_tag="$(image_value "$package" tag)"
  image_digest="$(image_value "$package" digest)"

  [[ "$package_version" == "$chart_version" ]] ||
    die "package filename version ${package_version} does not match Chart.yaml ${chart_version}"
  [[ "$image_repository" == "$IMAGE_REPOSITORY" ]] ||
    die "unexpected image repository: ${image_repository}"
  [[ "$image_tag" == "$app_version" ]] ||
    die "image tag ${image_tag} does not match appVersion ${app_version}"
  [[ "$image_digest" =~ ^sha256:[0-9a-f]{64}$ ]] ||
    die "image digest is missing or malformed: ${image_digest}"

  helm lint "$package"
  if [[ -z "$TMP_DIR" ]]; then
    TMP_DIR="$(mktemp -d)"
  fi
  workdir="$TMP_DIR"
  helm template sub2api-ci "$package" --namespace ai >"${workdir}/rendered.yaml"
  expected_digest="$(resolve_image_digest "$image_repository" "$image_tag" "$workdir")"
  [[ "$image_digest" == "$expected_digest" ]] ||
    die "image digest ${image_digest} does not match registry digest ${expected_digest}"

  package_digest="$(sha256sum "$package" | awk '{print $1}')"
  entry="$(index_entry "$chart_version")"
  IFS=$'\t' read -r index_digest index_url <<<"${entry}"
  [[ "$index_digest" == "$package_digest" ]] ||
    die "index digest does not match ${package_name}"
  [[ "$index_url" == "sub2api/${package_name}" ]] ||
    die "index URL does not match ${package_name}: ${index_url}"
  printf 'verified %s (application %s, image %s@%s)\n' \
    "$package_name" "$app_version" "$image_repository" "$image_digest"
}

update_chart() {
  local workdir release_version image_digest current_package current_chart_version current_app_version
  local current_image_tag current_image_digest source_chart_version source_image_repository base_version next_chart_version
  local source_dir package_output package index_work root_readme_line

  TMP_DIR="$(mktemp -d)"
  workdir="$TMP_DIR"
  release_version="$(latest_release_version)"
  image_digest="$(resolve_image_digest "$IMAGE_REPOSITORY" "$release_version" "$workdir")"
  current_package="$(latest_package || true)"

  if [[ -n "$current_package" ]]; then
    current_chart_version="$(chart_field "$current_package" version)"
    current_app_version="$(chart_field "$current_package" appVersion)"
    current_image_tag="$(image_value "$current_package" tag)"
    current_image_digest="$(image_value "$current_package" digest)"
    if [[ "$current_app_version" == "$release_version" &&
      "$current_image_tag" == "$release_version" &&
      "$current_image_digest" == "$image_digest" ]]; then
      write_output changed false
      write_output release_version "$release_version"
      write_output chart_version "$current_chart_version"
      write_output image_digest "$image_digest"
      printf 'Sub2API is already current at %s\n' "$release_version"
      return
    fi
  else
    current_chart_version=""
  fi

  source_chart_version="$(chart_field "$SOURCE_CHART_OCI" version)"
  [[ "$source_chart_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    die "unsupported upstream chart version: ${source_chart_version}"
  source_dir="${workdir}/source"
  mkdir -p -- "$source_dir"
  helm pull "$SOURCE_CHART_OCI" --untar --untardir "$source_dir" >/dev/null
  source_dir="${source_dir}/sub2api"
  [[ -f "${source_dir}/Chart.yaml" && -f "${source_dir}/values.yaml" ]] ||
    die 'upstream OCI chart did not contain Chart.yaml and values.yaml'
  rm -f -- "${source_dir}/.gitignore"
  source_image_repository="$(image_value "$source_dir" repository)"
  [[ "$source_image_repository" == "$IMAGE_REPOSITORY" ]] ||
    die "upstream image repository changed to ${source_image_repository}; review manually"

  if [[ -n "$current_chart_version" ]]; then
    base_version="$(max_version "$source_chart_version" "$current_chart_version")"
  else
    base_version="$source_chart_version"
  fi
  next_chart_version="$(bump_patch "$base_version")"

  sed -i -E "s|^appVersion:.*$|appVersion: \"${release_version}\"|" "${source_dir}/Chart.yaml"
  sed -i -E "s|^version:.*$|version: ${next_chart_version}|" "${source_dir}/Chart.yaml"
  sed -i -E "s|^  tag:.*$|  tag: ${release_version}|" "${source_dir}/values.yaml"
  if awk '
    /^image:$/ {inside_image = 1; next}
    inside_image && /^[^[:space:]]/ {exit}
    inside_image && /^  digest:/ {found = 1; exit}
    END {exit !found}
  ' "${source_dir}/values.yaml"; then
    sed -i -E "/^image:/,/^[^[:space:]]/ s|^  digest:.*$|  digest: ${image_digest}|" "${source_dir}/values.yaml"
  else
    sed -i "/^  tag:/a\\  digest: ${image_digest}" "${source_dir}/values.yaml"
  fi
  cp -- "${CHART_DIR}/README.md" "${source_dir}/README.md"
  sed -i -E "s|^export CHART_VERSION=.*$|export CHART_VERSION=${next_chart_version}|" "${source_dir}/README.md"

  package_output="$(helm package "$source_dir" --destination "$CHART_DIR")"
  package="$(printf '%s\n' "$package_output" | awk -F': ' '/saved it to:/ {print $2; exit}')"
  [[ -n "$package" && -f "$package" ]] || die 'helm package did not produce a chart package'

  index_work="${workdir}/index"
  mkdir -p -- "$index_work"
  cp -- "$package" "${index_work}/"
  helm repo index "$index_work" --merge "$INDEX_FILE" --url sub2api >/dev/null
  cp -- "${index_work}/index.yaml" "$INDEX_FILE"

  root_readme_line='  - **sub2api** chart version: `'
  root_readme_line+="${next_chart_version}"
  root_readme_line+='` (application `'
  root_readme_line+="${release_version}"
  root_readme_line+='`)'
  grep -q -- '^  - \*\*sub2api\*\* chart version:' "${ROOT_DIR}/README.md" ||
    die 'README.md has no Sub2API version marker'
  sed -i -E "s|^  - \*\*sub2api\*\* chart version:.*$|${root_readme_line}|" "${ROOT_DIR}/README.md"
  sed -i -E "s|^export CHART_VERSION=.*$|export CHART_VERSION=${next_chart_version}|" "${CHART_DIR}/README.md"

  verify_package "$package"
  write_output changed true
  write_output release_version "$release_version"
  write_output chart_version "$next_chart_version"
  write_output image_digest "$image_digest"
  printf 'prepared Sub2API chart %s for application %s\n' "$next_chart_version" "$release_version"
}

publish_package() {
  local package="$1"
  local chart_version package_name workdir auth_config anonymous_config remote_dir remote_package
  local local_digest remote_digest remote_output

  [[ -f "$package" ]] || die "chart package not found: ${package}"
  package_name="$(basename -- "$package")"
  chart_version="$(chart_field "$package" version)"
  TMP_DIR="$(mktemp -d)"
  workdir="$TMP_DIR"
  auth_config="${workdir}/registry.json"
  anonymous_config="${workdir}/anonymous-registry.json"
  remote_dir="${workdir}/remote"
  mkdir -p -- "$remote_dir"
  printf '{"auths":{}}\n' >"${auth_config}"
  printf '{"auths":{}}\n' >"${anonymous_config}"
  : "${GITHUB_TOKEN:?GITHUB_TOKEN is required to publish the chart}"
  printf '%s\n' "$GITHUB_TOKEN" |
    helm registry login ghcr.io --username "${GITHUB_ACTOR:-github-actions[bot]}" \
      --password-stdin --registry-config "$auth_config" >/dev/null

  if remote_output="$(helm pull --registry-config "$auth_config" "${OCI_REPOSITORY}/sub2api" \
    --version "$chart_version" --destination "$remote_dir" 2>&1)"; then
    remote_package="${remote_dir}/${package_name}"
    [[ -f "$remote_package" ]] || die 'registry returned a chart with an unexpected filename'
    local_digest="$(sha256sum "$package" | awk '{print $1}')"
    remote_digest="$(sha256sum "$remote_package" | awk '{print $1}')"
    [[ "$local_digest" == "$remote_digest" ]] ||
      die "OCI chart ${chart_version} already exists with different content"
    printf 'OCI chart %s already matches the repository package\n' "$chart_version"
  else
    case "$remote_output" in
      *'not found'*|*'404'*|*'MANIFEST_UNKNOWN'*|*'manifest unknown'*)
        helm push --registry-config "$auth_config" "$package" "$OCI_REPOSITORY"
        ;;
      *)
        printf '%s\n' "$remote_output" >&2
        die "could not inspect OCI chart ${chart_version}"
        ;;
    esac
  fi

  rm -f -- "${remote_dir}"/*
  helm pull --registry-config "$anonymous_config" "${OCI_REPOSITORY}/sub2api" \
    --version "$chart_version" --destination "$remote_dir" >/dev/null ||
    die 'OCI chart is not anonymously readable; make the GHCR package public and rerun'
  remote_package="${remote_dir}/${package_name}"
  [[ -f "$remote_package" ]] || die 'anonymous OCI pull returned an unexpected filename'
  local_digest="$(sha256sum "$package" | awk '{print $1}')"
  remote_digest="$(sha256sum "$remote_package" | awk '{print $1}')"
  [[ "$local_digest" == "$remote_digest" ]] || die 'anonymous OCI pull differs from the package in Git'
  printf 'published and anonymously verified %s\n' "$package_name"
}

usage() {
  printf 'usage: %s {update|verify [package]|publish package}\n' "$0" >&2
  exit 2
}

case "${1:-}" in
  update)
    update_chart
    ;;
  verify)
    verify_package "${2:-}"
    ;;
  publish)
    [[ $# -eq 2 ]] || usage
    publish_package "$2"
    ;;
  *)
    usage
    ;;
esac
