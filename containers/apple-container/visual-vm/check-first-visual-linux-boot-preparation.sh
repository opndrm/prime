#!/usr/bin/env bash
# Static/no-write verification for the first visual Linux boot preparer.
set -euo pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
UTILITY="$SCRIPT_DIR/prepare-first-visual-linux-boot.sh"
STATE_UTILITY="$SCRIPT_DIR/provision-visual-linux-vm-state.sh"
fail() { printf 'First visual Linux boot preparation check failed: %s\n' "$*" >&2; exit 1; }
require() { rg -F --quiet -- "$2" "$1" || fail "missing $2"; }
forbid() { ! rg -i -F --quiet -- "$2" "$1" || fail "forbidden $2"; }
test -f "$UTILITY" || fail 'missing first visual Linux boot preparation utility'
bash -n "$UTILITY"
require "$UTILITY" 'prepare --confirm-first-visual-boot --label <safe-label> --app <project-local-Orchard.app>'
require "$UTILITY" 'provision --confirm-state-provision --label'
require "$UTILITY" 'Orchard Agent Computers dedicated start-and-attach path'
require "$UTILITY" 'prepared-awaiting-separate-owner-start-action'
require "$UTILITY" 'VZVirtualMachineView'
require "$UTILITY" "network: 'disabled'"
require "$UTILITY" "shared_directories: 'disabled'"
require "$UTILITY" "clipboard: 'disabled'"
require "$UTILITY" "guest_input: 'disabled'"
require "$UTILITY" "recording: 'disabled'"
require "$UTILITY" "apple_container_integration: 'disabled'"
require "$UTILITY" 'Orchard generic Machine controls'
require "$UTILITY" 'Orchard Sandbox controls'
require "$UTILITY" 'Apple Container task-worker lifecycle'
forbid "$UTILITY" 'open -a'
forbid "$UTILITY" 'xcodebuild'
forbid "$UTILITY" 'curl '
forbid "$UTILITY" 'wget '
forbid "$UTILITY" 'VZVirtualMachine('
forbid "$UTILITY" '.start('
! rg -n -- '(^|[;&|][[:space:]]*)container([[:space:]]|$)' "$UTILITY" >/dev/null || fail 'forbidden Apple Container CLI invocation'
if "$UTILITY" prepare --label missing-confirmation --app /tmp/Nope.app >/dev/null 2>&1; then fail 'preparation unexpectedly accepted missing owner confirmation'; fi
test -x "$STATE_UTILITY" || fail 'state provisioning utility is not executable'
printf 'First visual Linux boot preparation static and no-write checks passed.\n'
