#!/usr/bin/env bash
# Downloads the exact user-specified CANN toolkit; no driver installation.
set -euo pipefail
[[ "$(uname -m)" == x86_64 ]] || { echo 'Requires x86_64.' >&2; exit 1; }
CANN_TOOLKIT_URL="${CANN_TOOLKIT_URL:-https://ascend.devcloud.huaweicloud.com/artifactory/cann-run-mirror/software/legacy/20260422000325096/Ascend-cann-toolkit_9.0.0_linux-x86_64.run}"
CANN_OPS_URL="${CANN_OPS_URL:-https://ascend-repo.obs.cn-east-2.myhuaweicloud.com/CANN/CANN%209.0.0/Ascend-cann-950-ops_9.0.0_linux-x86_64.run}"
cache="${CANN_DOWNLOAD_DIR:-$PWD/.downloads}"
mkdir -p "$cache"
download() {
  local url=$1 dest=$2 expected=$3
  if [[ ! -s "$dest" ]]; then
    curl --fail --location --retry 5 --retry-delay 5 --connect-timeout 30 --max-time 2400 \
      --header 'Referer: https://www.hiascend.com/' "$url" -o "$dest.part"
    mv "$dest.part" "$dest"
  fi
  if [[ -n "$expected" ]]; then
    printf '%s  %s\n' "$expected" "$dest" | sha256sum --check -
  fi
  sha256sum "$dest"
  bash "$dest" --check
}
toolkit="$cache/Ascend-cann-toolkit_9.0.0_linux-x86_64.run"
download "$CANN_TOOLKIT_URL" "$toolkit" "${CANN_TOOLKIT_SHA256:-}"
bash "$toolkit" --quiet --install --install-for-all
# Needed by 950 SDK components on split-package installations.
if [[ "${INSTALL_950_OPS:-1}" == 1 ]]; then
  ops="$cache/Ascend-cann-950-ops_9.0.0_linux-x86_64.run"
  download "$CANN_OPS_URL" "$ops" "${CANN_OPS_SHA256:-}"
  bash "$ops" --quiet --install --install-for-all
fi
