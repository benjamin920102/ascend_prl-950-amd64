#!/usr/bin/env bash
# Source this script; works with root and non-root CANN 9 installers.
_prl_env="${CANN_ENV:-}"
if [[ -z "$_prl_env" ]]; then
  for _prl_candidate in \
    /usr/local/Ascend/ascend-toolkit/set_env.sh \
    /usr/local/Ascend/ascend-toolkit/latest/set_env.sh \
    /usr/local/Ascend/cann-9.0.0/set_env.sh \
    "$HOME/Ascend/ascend-toolkit/set_env.sh" \
    "$HOME/Ascend/ascend-toolkit/latest/set_env.sh"; do
    if [[ -f "$_prl_candidate" ]]; then _prl_env="$_prl_candidate"; break; fi
  done
fi
if [[ ! -f "$_prl_env" ]]; then
  echo 'CANN set_env.sh not found. Set CANN_ENV=/absolute/path/set_env.sh' >&2
  return 1
fi
# Vendor setup scripts may reference unset variables.
_prl_had_nounset=0
[[ $- == *u* ]] && _prl_had_nounset=1
set +u
source "$_prl_env"
if [[ -z "${ASC_MODULES:-}" ]]; then
  _prl_prefix="${ASCEND_HOME_PATH:-$(dirname "$_prl_env")}"
  ASC_MODULES=$(find -L "$_prl_prefix" -type d -path '*/ascendc_kernel_cmake/asc_modules' -print -quit 2>/dev/null)
  export ASC_MODULES
fi
[[ $_prl_had_nounset == 1 ]] && set -u
if [[ -z "${ASC_MODULES:-}" ]]; then
  echo 'ASC CMake modules not found; set ASC_MODULES explicitly.' >&2
  return 1
fi
unset _prl_env _prl_candidate _prl_prefix _prl_had_nounset
