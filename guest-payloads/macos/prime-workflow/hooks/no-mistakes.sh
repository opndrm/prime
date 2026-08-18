#!/bin/bash
# Guest-only, validation-only no-mistakes workflow hook.
# This file contains no installer, package-manager, network, launch, service,
# activation, credential, or deletion operation.

set -euo pipefail
IFS=$'\n\t'

readonly COMPONENT='no-mistakes'
readonly SELF="${BASH_SOURCE[0]}"
[[ -f "$SELF" && ! -L "$SELF" ]] || {
  printf 'prime-workflow hook: refused: hook path must be a regular file\n' >&2
  exit 1
}
readonly SCRIPT_DIR="$(cd -P "$(/usr/bin/dirname "$SELF")" && /bin/pwd -P)"
[[ "$SCRIPT_DIR" == "$HOME/"* ]] || {
  printf 'prime-workflow hook: refused: hook must reside under guest HOME\n' >&2
  exit 1
}
readonly COMMON="$SCRIPT_DIR/lib/guest-plan-common.sh"
[[ -f "$COMMON" && ! -L "$COMMON" ]] || {
  printf 'prime-workflow hook: refused: shared validation library unavailable\n' >&2
  exit 1
}
# shellcheck source=lib/guest-plan-common.sh
source "$COMMON"
validate_component_plan "$COMPONENT" "$@"
