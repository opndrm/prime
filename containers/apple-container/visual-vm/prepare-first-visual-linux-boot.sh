#!/usr/bin/env bash
# Owner-confirmed preparation for the first direct GUI Linux VM handoff.
# This script is deliberately not a launcher. It may create only a private VM
# state bundle and its matching owner-only handoff document.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)"
STATE_UTILITY="$SCRIPT_DIR/provision-visual-linux-vm-state.sh"
STATE_ROOT="$PROJECT_ROOT/.opndrm/agent-computers/visual-vm-state"
HANDOFF_ROOT="$PROJECT_ROOT/.opndrm/agent-computers/visual-vm-first-boot-handoffs"
ORCHARD_SOURCE="$PROJECT_ROOT/vendor/orchard"

fail() { printf 'First visual Linux boot preparation refused: %s\n' "$*" >&2; exit 1; }
usage() { cat <<'EOF'
Usage:
  prepare-first-visual-linux-boot.sh preflight --app <project-local-Orchard.app>
  prepare-first-visual-linux-boot.sh prepare --confirm-first-visual-boot --label <safe-label> --app <project-local-Orchard.app>
  prepare-first-visual-linux-boot.sh refresh --confirm-first-visual-boot --label <safe-label> --app <project-local-Orchard.app>
  prepare-first-visual-linux-boot.sh status --label <safe-label>

preflight checks the verified Ubuntu installer record and an explicit local
Orchard build. It does not write state or open anything.

prepare requires the exact owner confirmation. It creates a private VM bundle
through the existing state utility, then writes an owner-only handoff document
for Orchard's dedicated Agent Computers start-and-attach path. It does not
launch Orchard or the VM.
EOF
}

safe_label() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || fail 'label must use lowercase letters, digits, and hyphens only.'; }

require_project_local_app() {
  local app_path="$1" plist executable entitlements
  [[ "$app_path" = /* ]] || fail 'the Orchard app path must be absolute.'
  [[ "$app_path" == "$PROJECT_ROOT"/* ]] || fail 'the Orchard app must live inside this project checkout.'
  [[ "$app_path" == *.app ]] || fail 'the Orchard app path must end in .app.'
  [[ -d "$app_path" && ! -L "$app_path" ]] || fail 'the Orchard app must be a local directory, not a symlink.'
  plist="$app_path/Contents/Info.plist"
  [[ -f "$plist" && ! -L "$plist" ]] || fail 'the local Orchard app has no safe Info.plist.'
  executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist" 2>/dev/null)" || fail 'the local Orchard app has no executable declaration.'
  [[ "$executable" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'the local Orchard executable declaration is unsafe.'
  [[ -f "$app_path/Contents/MacOS/$executable" && ! -L "$app_path/Contents/MacOS/$executable" ]] || fail 'the local Orchard app executable is missing or unsafe.'
  entitlements="$(/usr/bin/codesign -d --entitlements :- "$app_path" 2>/dev/null)" || fail 'the local Orchard app does not expose a signed entitlement record.'
  printf '%s\n' "$entitlements" | /usr/libexec/PlistBuddy -c 'Print :com.apple.security.virtualization' /dev/stdin 2>/dev/null | rg -Fx --quiet 'true' || fail 'the local Orchard app lacks the Apple Virtualization entitlement.'
}

require_dedicated_orchard_source() {
  local lifecycle="$ORCHARD_SOURCE/Orchard/Services/AgentComputerVMLifecycle.swift"
  local display="$ORCHARD_SOURCE/Orchard/Views/Features/AgentComputers/AgentComputerVisualMachine.swift"
  [[ -f "$lifecycle" && -f "$display" ]] || fail 'the project-local Orchard source lacks the dedicated Agent Computers VM implementation.'
  rg -F --quiet 'startUbuntuDesktopInstaller' "$lifecycle" || fail 'the dedicated Orchard lifecycle cannot start the verified installer VM.'
  rg -F --quiet 'VZVirtualMachineView' "$display" || fail 'the dedicated Orchard display host is missing.'
  rg -F --quiet 'attachOwnerStartedInstallerMachine' "$display" || fail 'the dedicated Orchard display attach seam is missing.'
}

preflight() {
  local app_path="$1"
  [[ -x "$STATE_UTILITY" ]] || fail 'the existing VM state utility is unavailable.'
  "$STATE_UTILITY" preflight
  require_project_local_app "$app_path"
  require_dedicated_orchard_source
  printf 'First visual Linux boot preflight passed. No VM, app, or handoff was started or created.\n'
}

prepare() {
  local label="$1" app_path="$2" bundle handoff staging
  safe_label "$label"
  preflight "$app_path"
  bundle="$STATE_ROOT/$label"
  handoff="$HANDOFF_ROOT/$label.json"
  [[ ! -e "$handoff" && ! -L "$handoff" ]] || fail 'the requested first-boot handoff label already exists.'
  if [[ -e "$bundle" || -L "$bundle" ]]; then
    "$STATE_UTILITY" status --label "$label"
  else
    "$STATE_UTILITY" provision --confirm-state-provision --label "$label"
  fi
  "$STATE_UTILITY" status --label "$label"
  umask 077
  mkdir -p "$HANDOFF_ROOT"
  chmod 0700 "$HANDOFF_ROOT"
  staging="$(mktemp "$HANDOFF_ROOT/.${label}.handoff.XXXXXX")"
  trap 'rm -f -- "$staging"' EXIT HUP INT TERM
  node - "$staging" "$label" "$app_path" "$bundle" <<'NODE'
const fs = require('fs');
const [output, label, appPath, bundle] = process.argv.slice(2);
const handoff = {
  schema_version: '1.0',
  purpose: 'owner-confirmed-first-direct-gui-linux-vm-boot',
  consumer: 'Orchard Agent Computers dedicated start-and-attach path',
  owner_confirmation: 'confirmed-by-prepare-command',
  vm_label: label,
  orchard_app_path: appPath,
  installer_manifest_path: `${bundle}/orchard-ubuntu-installer-manifest.json`,
  state_layout_path: `${bundle}/state-layout.json`,
  required_runtime_assertions: {
    direct_guest_display: 'VZVirtualMachineView',
    network: 'disabled', shared_directories: 'disabled', clipboard: 'disabled',
    guest_input: 'disabled', usb: 'disabled', audio: 'disabled',
    credentials_and_models: 'disabled', recording: 'disabled',
    apple_container_integration: 'disabled'
  },
  forbidden_consumers: [
    'Orchard generic Machine controls', 'Orchard Sandbox controls',
    'Apple Container task-worker lifecycle', 'remote or browser viewer'
  ],
  state: 'prepared-awaiting-separate-owner-start-action'
};
// mktemp created this owner-only staging file; overwrite that exact file before
// atomically moving it into place.  Exclusive creation here would always fail.
fs.writeFileSync(output, `${JSON.stringify(handoff, null, 2)}\n`, { mode: 0o600, flag: 'w' });
NODE
  chmod 0600 "$staging"
  mv "$staging" "$handoff"
  trap - EXIT HUP INT TERM
  printf 'Prepared owner-only first visual Linux boot handoff for %s. No VM or app was started.\n' "$label"
}

refresh() {
  local label="$1" app_path="$2" bundle handoff staging
  safe_label "$label"
  # Refreshing the handoff never re-hashes the multi-gigabyte ISO. The ISO was
  # already fully verified during owner-confirmed provisioning; `status` below
  # verifies the durable private state before the handoff is replaced.
  require_project_local_app "$app_path"
  require_dedicated_orchard_source
  bundle="$STATE_ROOT/$label"
  handoff="$HANDOFF_ROOT/$label.json"
  [[ -f "$handoff" && ! -L "$handoff" ]] || fail 'the requested first-boot handoff does not exist.'
  "$STATE_UTILITY" status --label "$label"
  umask 077
  staging="$(mktemp "$HANDOFF_ROOT/.${label}.handoff.XXXXXX")"
  trap 'rm -f -- "$staging"' EXIT HUP INT TERM
  node - "$staging" "$label" "$app_path" "$bundle" <<'NODE'
const fs = require('fs');
const [output, label, appPath, bundle] = process.argv.slice(2);
const handoff = {
  schema_version: '1.0',
  purpose: 'owner-confirmed-first-direct-gui-linux-vm-boot',
  consumer: 'Orchard Agent Computers dedicated start-and-attach path',
  owner_confirmation: 'confirmed-by-prepare-command',
  vm_label: label,
  orchard_app_path: appPath,
  installer_manifest_path: `${bundle}/orchard-ubuntu-installer-manifest.json`,
  state_layout_path: `${bundle}/state-layout.json`,
  required_runtime_assertions: {
    direct_guest_display: 'VZVirtualMachineView',
    network: 'disabled', shared_directories: 'disabled', clipboard: 'disabled',
    guest_input: 'disabled', usb: 'disabled', audio: 'disabled',
    credentials_and_models: 'disabled', recording: 'disabled',
    apple_container_integration: 'disabled'
  },
  forbidden_consumers: [
    'Orchard generic Machine controls', 'Orchard Sandbox controls',
    'Apple Container task-worker lifecycle', 'remote or browser viewer'
  ],
  state: 'prepared-awaiting-separate-owner-start-action'
};
fs.writeFileSync(output, `${JSON.stringify(handoff, null, 2)}\n`, { mode: 0o600, flag: 'w' });
NODE
  chmod 0600 "$staging"
  mv "$staging" "$handoff"
  trap - EXIT HUP INT TERM
  status "$label"
  printf 'Refreshed owner-only first visual Linux boot handoff for %s. No VM or app was started.\n' "$label"
}

status() {
  local label="$1" handoff
  safe_label "$label"
  handoff="$HANDOFF_ROOT/$label.json"
  [[ -f "$handoff" && ! -L "$handoff" ]] || fail 'the requested first-boot handoff does not exist.'
  [[ "$(stat -f '%Lp' "$handoff")" == '600' ]] || fail 'the first-boot handoff is not owner-only.'
  node - "$handoff" <<'NODE'
const fs = require('fs');
const h = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (h.schema_version !== '1.0' || h.purpose !== 'owner-confirmed-first-direct-gui-linux-vm-boot' ||
    h.consumer !== 'Orchard Agent Computers dedicated start-and-attach path' ||
    h.owner_confirmation !== 'confirmed-by-prepare-command' ||
    h.state !== 'prepared-awaiting-separate-owner-start-action' ||
    !/^[a-z0-9][a-z0-9-]{0,63}$/.test(h.vm_label || '') ||
    typeof h.orchard_app_path !== 'string' || typeof h.installer_manifest_path !== 'string' ||
    h.required_runtime_assertions?.network !== 'disabled' ||
    h.required_runtime_assertions?.shared_directories !== 'disabled' ||
    h.required_runtime_assertions?.clipboard !== 'disabled' ||
    h.required_runtime_assertions?.guest_input !== 'disabled' ||
    h.required_runtime_assertions?.recording !== 'disabled' ||
    h.required_runtime_assertions?.apple_container_integration !== 'disabled') process.exit(1);
NODE
  printf 'First visual Linux boot handoff %s is valid and still awaits a separate owner start action.\n' "$label"
}

case "${1:-}" in
  preflight) [[ $# -eq 3 && "${2:-}" == '--app' ]] || { usage >&2; exit 2; }; preflight "$3" ;;
  prepare) [[ $# -eq 6 && "${2:-}" == '--confirm-first-visual-boot' && "${3:-}" == '--label' && "${5:-}" == '--app' ]] || { usage >&2; exit 2; }; prepare "$4" "$6" ;;
  refresh) [[ $# -eq 6 && "${2:-}" == '--confirm-first-visual-boot' && "${3:-}" == '--label' && "${5:-}" == '--app' ]] || { usage >&2; exit 2; }; refresh "$4" "$6" ;;
  status) [[ $# -eq 3 && "${2:-}" == '--label' ]] || { usage >&2; exit 2; }; status "$3" ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
