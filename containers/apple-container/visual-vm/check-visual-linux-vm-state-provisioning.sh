#!/usr/bin/env bash
# Static and no-write safety checks for the owner-invoked VM state utility.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
UTILITY="$SCRIPT_DIR/provision-visual-linux-vm-state.sh"
NATIVE_INITIALIZER="$SCRIPT_DIR/initialize-visual-linux-vm-state.swift"
MANIFEST="$SCRIPT_DIR/visual-linux-vm-manifest.json"

fail() { printf 'Visual VM state provisioning check failed: %s\n' "$*" >&2; exit 1; }
require() { rg -F --quiet -- "$2" "$1" || fail "missing $2"; }
forbid() { ! rg -i -F --quiet -- "$2" "$1" || fail "forbidden $2"; }

test -f "$UTILITY" || fail 'missing state provisioning utility'
test -f "$NATIVE_INITIALIZER" || fail 'missing native state initializer'
bash -n "$UTILITY"
swiftc -typecheck -framework Virtualization "$NATIVE_INITIALIZER"
require "$UTILITY" 'provision --confirm-state-provision --label <safe-label>'
require "$UTILITY" 'installer-downloaded-local-hash-verified'
require "$UTILITY" 'installer-verification.json'
require "$UTILITY" 'shasum -a 256'
require "$UTILITY" 'guest-installation-disk.raw'
require "$UTILITY" 'efi-variable-store.bin'
require "$UTILITY" 'generic-machine-identifier.bin'
require "$UTILITY" 'native-vm-state-initialized-awaiting-orchard-preflight'
require "$UTILITY" 'swiftc -framework Virtualization'
require "$UTILITY" 'installer_iso_sha256'
require "$UTILITY" 'chmod 0700 "$STATE_ROOT"'
require "$NATIVE_INITIALIZER" 'VZEFIVariableStore(creatingVariableStoreAt: efi)'
require "$NATIVE_INITIALIZER" 'VZGenericMachineIdentifier()'
require "$NATIVE_INITIALIZER" 'truncate(atOffset: diskSize)'
require "$NATIVE_INITIALIZER" 'No VM was created or started.'
require "$UTILITY" 'No VM state was created.'
forbid "$UTILITY" 'open -a'
forbid "$UTILITY" 'xcodebuild'
forbid "$UTILITY" 'curl '
forbid "$UTILITY" 'wget '
forbid "$UTILITY" 'container '
forbid "$NATIVE_INITIALIZER" 'VZVirtualMachine('
forbid "$NATIVE_INITIALIZER" '.start('
forbid "$NATIVE_INITIALIZER" 'networkDevices'
forbid "$NATIVE_INITIALIZER" 'directorySharingDevices'
forbid "$NATIVE_INITIALIZER" 'pointingDevices'
forbid "$NATIVE_INITIALIZER" 'keyboards'

if "$UTILITY" provision --label missing-confirmation >/dev/null 2>&1; then
  fail 'provisioning unexpectedly accepted missing owner confirmation'
fi
if ! "$UTILITY" preflight >/dev/null 2>&1; then
  fail 'preflight did not accept the verified local ISO record.'
fi
require "$MANIFEST" '"installer-downloaded-local-hash-verified"'
printf 'Visual VM state provisioning static and no-write checks passed.\n'
