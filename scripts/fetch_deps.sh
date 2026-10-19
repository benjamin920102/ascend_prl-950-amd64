#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source third_party/deps.env
repo=third_party/pearl
if [[ ! -d "$repo/.git" ]]; then
  mkdir -p "$repo"
  git -C "$repo" init
  git -C "$repo" remote add origin https://github.com/pearl-research-labs/pearl.git
fi
if [[ "$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)" != "$PEARL_REV" ]]; then
  git -C "$repo" fetch --depth 1 origin "$PEARL_REV"
  git -C "$repo" checkout --detach FETCH_HEAD
fi
[[ -f "$repo/pearl-blake3/Cargo.toml" && -f "$repo/zk-pow/Cargo.toml" && -f "$repo/plonky2/plonky2/Cargo.toml" ]]
echo "Pearl dependencies: $(git -C "$repo" rev-parse HEAD)"
