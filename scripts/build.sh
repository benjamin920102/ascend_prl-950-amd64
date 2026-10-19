#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -m)" == x86_64 ]] || { echo 'Requires Linux amd64/x86_64 host.' >&2; exit 1; }
source scripts/env.sh
bash scripts/fetch_deps.sh
make RANK="${RANK:-256}" JOBS="${JOBS:-4}" kernel
make RANK="${RANK:-256}" proof
make RANK="${RANK:-256}" miner
file build/ascend_prl_* build/libpearl_*.so
