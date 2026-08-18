#!/usr/bin/env bash
# Owner-invoked filesystem preparation for the direct GUI Linux VM lane.
# This utility never boots a VM, opens Orchard, downloads an ISO, or attaches devices.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)"
MANIFEST="$SCRIPT_DIR/visual-linux-vm-manifest.json"
STATE_ROOT="$PROJECT_ROOT/.opndrm/agent-computers/visual-vm-state"
NATIVE_INITIALIZER="$SCRIPT_DIR/initialize-visual-linux-vm-state.swift"

fail() { printf 'Visual VM state provisioning refused: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'EOF'
Usage:
  provision-visual-linux-vm-state.sh preflight
  provision-visual-linux-vm-state.sh provision --confirm-state-provision --label <safe-label>
  provision-visual-linux-vm-state.sh repair-manifest --confirm-state-repair --label <safe-label>
  provision-visual-linux-vm-state.sh status --label <safe-label>

Preflight verifies a locally downloaded, signed and checksum-matching installer
record. Provision creates a new owner-only project-local bundle with a private
64 GiB sparse guest disk, native EFI variable store, and generic VM identity.
It never launches a VM, downloads an asset, or enables host sharing, network,
clipboard, input, USB, recording, or any external integration.
EOF
}

require_node() { command -v node >/dev/null 2>&1 || fail 'Node.js is required to validate the JSON manifest.'; }
safe_label() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || fail 'label must use lowercase letters, digits, and hyphens only.'; }
is_project_relative() { [[ "$1" != /* && "$1" != *'..'* && "$1" != *$'\n'* ]] || fail 'manifest asset directory is not a safe project-relative path.'; }

read_manifest() {
  require_node
  test -f "$MANIFEST" || fail 'missing visual Linux VM manifest.'
  node - "$MANIFEST" <<'NODE'
const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const iso = manifest?.guest?.assets?.installer_iso;
if (manifest.status !== 'installer-downloaded-local-hash-verified') process.exit(10);
if (!iso || typeof iso.asset_directory !== 'string' || typeof iso.filename !== 'string' ||
    !/^[a-f0-9]{64}$/.test(iso.sha256 || '') || !iso.signature_verification?.startsWith('verified-')) process.exit(11);
const diskBytes = manifest?.guest?.provisioning?.guest_installation_disk_bytes;
if (!Number.isSafeInteger(diskBytes) || diskBytes < 32 * 1024 * 1024 * 1024) process.exit(12);
process.stdout.write([iso.asset_directory, iso.filename, iso.sha256, iso.signing_key_fingerprint, diskBytes].join('\n'));
NODE
}

preflight() {
  local values asset_dir filename expected_sha fingerprint disk_bytes asset_path verification_record actual_sha
  values="$(read_manifest)" || fail 'manifest does not declare a verified local installer state and pinned signature provenance.'
  asset_dir="$(printf '%s\n' "$values" | sed -n '1p')"
  filename="$(printf '%s\n' "$values" | sed -n '2p')"
  expected_sha="$(printf '%s\n' "$values" | sed -n '3p')"
  fingerprint="$(printf '%s\n' "$values" | sed -n '4p')"
  disk_bytes="$(printf '%s\n' "$values" | sed -n '5p')"
  is_project_relative "$asset_dir"
  [[ "$filename" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'manifest installer filename is unsafe.'
  [[ "$fingerprint" =~ ^[A-F0-9]{40}$ ]] || fail 'manifest signing-key fingerprint is malformed.'
  [[ "$disk_bytes" =~ ^[0-9]+$ ]] || fail 'manifest guest disk size is malformed.'
  asset_path="$PROJECT_ROOT/$asset_dir/$filename"
  verification_record="$PROJECT_ROOT/$asset_dir/installer-verification.json"
  test -f "$asset_path" && test ! -L "$asset_path" || fail 'verified installer ISO is missing or is not a regular project-local file.'
  test -f "$verification_record" && test ! -L "$verification_record" || fail 'owner-created installer verification record is missing.'
  actual_sha="$(shasum -a 256 "$asset_path" | awk '{print $1}')"
  [[ "$actual_sha" == "$expected_sha" ]] || fail 'installer ISO SHA-256 does not match the pinned manifest value.'
  node - "$verification_record" "$filename" "$expected_sha" "$fingerprint" <<'NODE'
const fs = require('fs');
const [recordPath, filename, sha256, fingerprint] = process.argv.slice(2);
const record = JSON.parse(fs.readFileSync(recordPath, 'utf8'));
if (record.schema_version !== '1.0' || record.filename !== filename || record.sha256 !== sha256 ||
    record.signature_verification !== 'verified' || record.signing_key_fingerprint !== fingerprint ||
    typeof record.verified_at !== 'string' || record.verified_at.length < 10) process.exit(1);
NODE
  test ! -e "$STATE_ROOT" || { test -d "$STATE_ROOT" && test ! -L "$STATE_ROOT"; } || fail 'project-local state root is unsafe.'
  printf 'Visual VM state preflight passed. No VM state was created.\n'
}

write_orchard_manifest() {
  local bundle="$1" installer_path="$2" expected_sha="$3" orchard_manifest manifest_staging
  orchard_manifest="$bundle/orchard-ubuntu-installer-manifest.json"
  manifest_staging="$(mktemp "$bundle/.orchard-ubuntu-installer-manifest.XXXXXX")"
  node - "$manifest_staging" "$installer_path" "$expected_sha" "$bundle/guest-installation-disk.raw" "$bundle/efi-variable-store.bin" "$bundle/generic-machine-identifier.bin" <<'NODE'
const fs = require('fs');
const [output, iso, sha256, disk, efi, identifier] = process.argv.slice(2);
const manifest = {
  schema_version: 1,
  approval: 'owner-approved',
  distribution: 'ubuntu-desktop',
  release: '24.04.4-lts',
  architecture: 'arm64',
  installer_iso_path: iso,
  installer_iso_sha256: sha256,
  install_disk_path: disk,
  efi_variable_store_path: efi,
  machine_identifier_path: identifier
};
fs.writeFileSync(output, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600, flag: 'w' });
NODE
  chmod 0600 "$manifest_staging"
  mv "$manifest_staging" "$orchard_manifest"
}

provision() {
  local label="$1" bundle staging metadata initializer_bin values asset_dir filename expected_sha disk_bytes installer_path
  safe_label "$label"
  preflight
  bundle="$STATE_ROOT/$label"
  test ! -e "$bundle" && test ! -L "$bundle" || fail 'the requested VM bundle label already exists.'
  test -f "$NATIVE_INITIALIZER" || fail 'missing native VM state initializer.'
  values="$(read_manifest)" || fail 'manifest does not declare a verified local installer state and pinned signature provenance.'
  asset_dir="$(printf '%s\n' "$values" | sed -n '1p')"
  filename="$(printf '%s\n' "$values" | sed -n '2p')"
  expected_sha="$(printf '%s\n' "$values" | sed -n '3p')"
  disk_bytes="$(printf '%s\n' "$values" | sed -n '5p')"
  installer_path="$PROJECT_ROOT/$asset_dir/$filename"
  umask 077
  mkdir -p "$STATE_ROOT"
  chmod 0700 "$STATE_ROOT"
  staging="$(mktemp -d "$STATE_ROOT/.${label}.provisioning.XXXXXX")"
  chmod 0700 "$staging"
  initializer_bin="$staging/native-state-initializer"
  cleanup() { rm -rf -- "$staging"; }
  trap cleanup EXIT HUP INT TERM
  swiftc -framework Virtualization "$NATIVE_INITIALIZER" -o "$initializer_bin"
  "$initializer_bin" --bundle "$staging" --disk-bytes "$disk_bytes"
  rm -f -- "$initializer_bin"
  metadata="$staging/state-layout.json"
  cat > "$metadata" <<EOF
{
  "schema_version": "1.0",
  "label": "$label",
  "state": "native-vm-state-initialized-awaiting-orchard-preflight",
  "guest_installation_disk": "guest-installation-disk.raw",
  "efi_variable_store": "efi-variable-store.bin",
  "generic_machine_identifier": "generic-machine-identifier.bin",
  "orchard_installer_manifest": "orchard-ubuntu-installer-manifest.json",
  "guest_installation_disk_bytes": $disk_bytes,
  "network": "disabled",
  "shared_directories": "disabled",
  "clipboard": "disabled",
  "guest_input": "disabled",
  "usb": "disabled",
  "recording": "unavailable"
}
EOF
  chmod 0600 "$metadata"
  mv "$staging" "$bundle"
  # The bundle was atomically promoted above. Only now write the Orchard
  # manifest, so every state path is durable and never references the deleted
  # staging directory.
  write_orchard_manifest "$bundle" "$installer_path" "$expected_sha"
  trap - EXIT HUP INT TERM
  printf 'Created owner-only initialized native VM state for %s. No VM was launched.\n' "$label"
}

repair_manifest() {
  local label="$1" bundle values asset_dir filename expected_sha installer_path
  safe_label "$label"
  bundle="$STATE_ROOT/$label"
  test -d "$bundle" && test ! -L "$bundle" || fail 'requested VM bundle does not exist.'
  for file in guest-installation-disk.raw efi-variable-store.bin generic-machine-identifier.bin state-layout.json; do
    test -f "$bundle/$file" && test ! -L "$bundle/$file" || fail "missing safe state artifact: $file"
  done
  values="$(read_manifest)" || fail 'manifest does not declare a verified local installer state and pinned signature provenance.'
  asset_dir="$(printf '%s\n' "$values" | sed -n '1p')"
  filename="$(printf '%s\n' "$values" | sed -n '2p')"
  expected_sha="$(printf '%s\n' "$values" | sed -n '3p')"
  is_project_relative "$asset_dir"
  installer_path="$PROJECT_ROOT/$asset_dir/$filename"
  test -f "$installer_path" && test ! -L "$installer_path" || fail 'verified installer ISO is missing or unsafe.'
  write_orchard_manifest "$bundle" "$installer_path" "$expected_sha"
  status "$label"
  printf 'Regenerated durable Orchard installer manifest for %s. No VM was launched.\n' "$label"
}

status() {
  local label="$1" bundle
  safe_label "$label"
  bundle="$STATE_ROOT/$label"
  test -d "$bundle" && test ! -L "$bundle" || fail 'requested VM bundle does not exist.'
  for file in guest-installation-disk.raw efi-variable-store.bin generic-machine-identifier.bin orchard-ubuntu-installer-manifest.json state-layout.json; do
    test -f "$bundle/$file" && test ! -L "$bundle/$file" || fail "missing safe state artifact: $file"
  done
  rg -F --quiet 'native-vm-state-initialized-awaiting-orchard-preflight' "$bundle/state-layout.json" || fail 'VM bundle has not completed native state initialization.'
  node - "$bundle/orchard-ubuntu-installer-manifest.json" <<'NODE'
const fs = require('fs');
const manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (manifest.schema_version !== 1 || manifest.approval !== 'owner-approved' ||
    manifest.distribution !== 'ubuntu-desktop' || manifest.release !== '24.04.4-lts' ||
    manifest.architecture !== 'arm64' || !manifest.installer_iso_path ||
    !/^[a-f0-9]{64}$/.test(manifest.installer_iso_sha256 || '') || !manifest.install_disk_path ||
    !manifest.efi_variable_store_path || !manifest.machine_identifier_path) process.exit(1);
NODE
  printf 'VM state bundle %s has valid initialized state and awaits Orchard preflight.\n' "$label"
}

case "${1:-}" in
  preflight)
    [[ $# -eq 1 ]] || { usage >&2; exit 2; }
    preflight
    ;;
  provision)
    [[ $# -eq 4 && "${2:-}" == '--confirm-state-provision' && "${3:-}" == '--label' ]] || { usage >&2; exit 2; }
    provision "$4"
    ;;
  repair-manifest)
    [[ $# -eq 4 && "${2:-}" == '--confirm-state-repair' && "${3:-}" == '--label' ]] || { usage >&2; exit 2; }
    repair_manifest "$4"
    ;;
  status)
    [[ $# -eq 3 && "${2:-}" == '--label' ]] || { usage >&2; exit 2; }
    status "$3"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
