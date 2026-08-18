#!/usr/bin/env bash
# Static design-contract verification only. It never starts a VM or Orchard.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
MANIFEST="$SCRIPT_DIR/visual-linux-vm-manifest.json"
SCHEMA="$SCRIPT_DIR/visual-linux-vm-manifest.schema.json"
README="$SCRIPT_DIR/README.md"
ACCEPTANCE="$SCRIPT_DIR/VISUAL-VM-ACCEPTANCE.md"
IMPLEMENTATION_MAP="$SCRIPT_DIR/APPLE-WWDC-VIRTUALIZATION-IMPLEMENTATION-MAP.md"
FIRST_LAUNCH="$SCRIPT_DIR/FIRST-LAUNCH-READINESS.md"
STATE_PROVISIONING_CHECK="$SCRIPT_DIR/check-visual-linux-vm-state-provisioning.sh"
FIRST_BOOT_PREPARATION_CHECK="$SCRIPT_DIR/check-first-visual-linux-boot-preparation.sh"

fail() { printf 'Visual Linux VM contract check failed: %s\n' "$*" >&2; exit 1; }
require() { rg -F --quiet -- "$2" "$1" || fail "missing $2 in $1"; }
forbid() { ! rg -i -F --quiet -- "$2" "$1" || fail "forbidden $2 in $1"; }

for file in "$MANIFEST" "$SCHEMA" "$README" "$ACCEPTANCE" "$IMPLEMENTATION_MAP" "$FIRST_LAUNCH" "$STATE_PROVISIONING_CHECK" "$FIRST_BOOT_PREPARATION_CHECK"; do
  test -f "$file" || fail "missing $file"
done

if command -v jq >/dev/null 2>&1; then
  jq -e . "$MANIFEST" >/dev/null || fail 'manifest is invalid JSON'
  jq -e . "$SCHEMA" >/dev/null || fail 'schema is invalid JSON'
fi

require "$MANIFEST" '"framework": "Virtualization.framework"'
require "$MANIFEST" '"required_entitlement": "com.apple.security.virtualization"'
require "$MANIFEST" '"hypervisor_framework": "not-required-for-this-design"'
require "$MANIFEST" '"architecture": "arm64"'
require "$MANIFEST" '"boot_loader": "VZEFIBootLoader"'
require "$MANIFEST" '"display": "VZVirtualMachineView"'
require "$MANIFEST" '"network": "disabled"'
require "$MANIFEST" '"shared_directories": "disabled"'
require "$MANIFEST" '"clipboard": "disabled"'
require "$MANIFEST" '"guest_keyboard_and_pointer": "disabled-until-explicit-owner-take-control"'
require "$MANIFEST" '"usb_passthrough": "disabled"'
require "$MANIFEST" '"host_desktop_capture": "never"'
require "$MANIFEST" '"recording": "unavailable"'

require "$SCHEMA" '"Virtualization.framework"'
require "$SCHEMA" '"com.apple.security.virtualization"'
require "$SCHEMA" '"VZVirtualMachineView"'
require "$README" 'official release URL'
require "$README" 'SHA-256'
require "$README" 'signature provenance'
require "$README" 'No guest keyboard/pointer'
require "$README" 'shared directory'
require "$README" 'network'
require "$README" 'clipboard'
require "$README" 'recording'

require "$ACCEPTANCE" 'VZVirtualMachineConfiguration'
require "$ACCEPTANCE" 'VZVirtualMachineView'
require "$ACCEPTANCE" 'first visible pixels are from the Linux guest itself'
require "$ACCEPTANCE" 'visibly opens WezTerm into one empty'
require "$ACCEPTANCE" 'HERDR session'
require "$ACCEPTANCE" 'no network device'
require "$ACCEPTANCE" 'shared-directory device'
require "$ACCEPTANCE" 'clipboard configuration'
require "$ACCEPTANCE" 'keyboard/pointer attachment'
require "$ACCEPTANCE" 'guest disk, EFI store,'
require "$ACCEPTANCE" 'machine identifier together'
require "$ACCEPTANCE" 'must not record pixels'
forbid "$ACCEPTANCE" 'start a VM automatically'

require "$IMPLEMENTATION_MAP" 'Virtualization.framework'
require "$IMPLEMENTATION_MAP" 'Hypervisor.framework'
require "$IMPLEMENTATION_MAP" 'VZVirtualMachineConfiguration'
require "$IMPLEMENTATION_MAP" 'VZEFIBootLoader'
require "$IMPLEMENTATION_MAP" 'VZVirtioGraphicsDeviceConfiguration'
require "$IMPLEMENTATION_MAP" 'VZVirtualMachineView'
require "$IMPLEMENTATION_MAP" 'Rosetta'
require "$IMPLEMENTATION_MAP" 'Host desktop capture or control'
require "$IMPLEMENTATION_MAP" 'configured in the first profile'

require "$FIRST_LAUNCH" 'com.apple.security.virtualization'
require "$FIRST_LAUNCH" 'Ubuntu arm64'
require "$FIRST_LAUNCH" 'official publisher URL'
require "$FIRST_LAUNCH" 'SHA-256'
require "$FIRST_LAUNCH" 'project-local visual-VM storage'
require "$FIRST_LAUNCH" 'VZVirtualMachineView'
require "$FIRST_LAUNCH" 'pixels belong to the new Linux guest'
require "$FIRST_LAUNCH" 'Network or DNS'
require "$FIRST_LAUNCH" 'Host shares'
require "$FIRST_LAUNCH" 'Clipboard, keyboard, pointer'
require "$FIRST_LAUNCH" 'Credentials, tokens, model servers'
require "$FIRST_LAUNCH" 'Recording, OpenAdapt, Buzz Record'
require "$FIRST_LAUNCH" 'Apple Container task worker'
require "$FIRST_LAUNCH" 'guest installer asset or its'
require "$FIRST_LAUNCH" 'provisioning record fails verification'

bash "$STATE_PROVISIONING_CHECK"
bash "$FIRST_BOOT_PREPARATION_CHECK"

printf 'Visual Linux VM static contract passed. Runtime boot and display proof remain required.\n'
