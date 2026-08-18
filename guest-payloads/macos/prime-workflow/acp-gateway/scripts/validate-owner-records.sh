#!/bin/bash
# Read-only guest-local consent/receipt validator. It never executes the Prime ACP binary.
set -euo pipefail
IFS=$'\n\t'

readonly CONFIRMATION='I CONSENT TO ONE GUEST-LOCAL ACP SESSION'
readonly RELATIVE_ROOT='.local/share/opndrm-prime/acp-gateway'
readonly CONSENT_SCOPE='I-CONSENT-TO-ONE-GUEST-LOCAL-ACP-SESSION'

die() { printf 'acp-gateway validator: refused: %s\n' "$*" >&2; exit 1; }
usage() {
  printf '%s\n' "Usage (prepared macOS guest only): OPNDRM_GUEST_CONTEXT=macos-guest OPNDRM_ACP_GATEWAY_OWNER_CONFIRMATION='$CONFIRMATION' validate-owner-records.sh --validate-owner-records --guest-owner-confirmed" >&2
  exit 64
}
[[ $# -eq 2 ]] || usage
[[ ( "$1" == '--validate-owner-records' && "$2" == '--guest-owner-confirmed' ) || ( "$2" == '--validate-owner-records' && "$1" == '--guest-owner-confirmed' ) ]] || usage
[[ "${OPNDRM_ACP_GATEWAY_OWNER_CONFIRMATION:-}" == "$CONFIRMATION" ]] || die 'fresh explicit guest-owner confirmation is required'
[[ "${OPNDRM_GUEST_CONTEXT:-}" == 'macos-guest' ]] || die 'macos-guest context assertion is required'
[[ "$(/usr/bin/uname -s)" == 'Darwin' ]] || die 'prepared macOS guest required'
[[ "$(/usr/bin/id -u)" -ne 0 && -z "${SUDO_USER:-}" ]] || die 'root and sudo are refused'
[[ -z "${OPNDRM_HOST_BRIDGE:-}" && -z "${OPNDRM_BRIDGE_CONTEXT:-}" ]] || die 'declared host or bridge context is refused'

GUEST_USER="$(/usr/bin/id -un)"
[[ "$HOME" == "/Users/$GUEST_USER" && ! -L "$HOME" ]] || die 'non-root /Users guest HOME is required'
ROOT="$HOME/$RELATIVE_ROOT"
WORK="$ROOT/work"
BINARY="$ROOT/bin/prime-agent-acp"
CONSENT="$ROOT/consent/owner-consent.tsv"
RECEIPT="$ROOT/receipts/prime-agent-acp.sha256.tsv"

# Every existing component is checked from HOME down; this creates and changes nothing.
assert_existing_unsymlinked_path() {
  local path="$1" remainder current segment
  [[ "$path" == "$HOME" || "$path" == "$HOME/"* ]] || die 'path escapes guest HOME'
  remainder="${path#"$HOME"}"; current="$HOME"
  while [[ -n "$remainder" ]]; do
    remainder="${remainder#/}"; segment="${remainder%%/*}"
    [[ -n "$segment" && "$segment" != '.' && "$segment" != '..' ]] || die 'unsafe path component'
    current="$current/$segment"
    [[ -e "$current" && ! -L "$current" ]] || die "missing or symlinked required path: $current"
    if [[ "$remainder" == */* ]]; then remainder="${remainder#*/}"; else remainder=''; fi
  done
}
mode_and_owner() { /usr/bin/stat -f '%u:%Lp' "$1"; }
require_owned_mode() {
  local path="$1" expected="$2" actual owner mode
  actual="$(mode_and_owner "$path")" || die "cannot stat $path"
  owner="${actual%%:*}"; mode="${actual#*:}"
  [[ "$owner" == "$(/usr/bin/id -u)" && "$mode" == "$expected" ]] || die "wrong owner or mode on $path (requires guest-owned $expected)"
}
valid_id() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{2,127}$ ]]; }
read_single_tsv_line() {
  local file="$1" line
  [[ -f "$file" && ! -L "$file" ]] || die "record is not a regular file: $file"
  [[ "$(/usr/bin/wc -l < "$file" | /usr/bin/tr -d ' ')" == '1' ]] || die "record must contain exactly one newline-terminated line: $file"
}

for private_dir in "$ROOT" "$ROOT/bin" "$ROOT/consent" "$ROOT/receipts" "$WORK"; do
  assert_existing_unsymlinked_path "$private_dir"
  [[ -d "$private_dir" ]] || die "fixed private path is not a directory: $private_dir"
  require_owned_mode "$private_dir" '700'
done
assert_existing_unsymlinked_path "$BINARY"; [[ -f "$BINARY" ]] || die 'fixed Prime ACP path is not a regular file'; require_owned_mode "$BINARY" '700'
assert_existing_unsymlinked_path "$CONSENT"; read_single_tsv_line "$CONSENT"; require_owned_mode "$CONSENT" '600'
assert_existing_unsymlinked_path "$RECEIPT"; read_single_tsv_line "$RECEIPT"; require_owned_mode "$RECEIPT" '600'

IFS=$'\t' read -r consent_version consent_id owner_id consent_scope consent_extra < "$CONSENT"
[[ -z "${consent_extra:-}" && "$consent_version" == 'acp-gateway-v1' && "$consent_scope" == "$CONSENT_SCOPE" ]] || die 'invalid consent record schema or scope'
valid_id "$consent_id" && valid_id "$owner_id" || die 'invalid consent identifier'
IFS=$'\t' read -r receipt_version receipt_consent_id binary_rel expected_hash receipt_extra < "$RECEIPT"
[[ -z "${receipt_extra:-}" && "$receipt_version" == 'acp-gateway-v1' && "$receipt_consent_id" == "$consent_id" && "$binary_rel" == 'bin/prime-agent-acp' ]] || die 'receipt is not bound to this one consent and fixed binary path'
[[ "$expected_hash" =~ ^[a-f0-9]{64}$ ]] || die 'invalid lowercase SHA-256 in receipt'
[[ -x /usr/bin/shasum ]] || die 'SHA-256 verifier unavailable'
actual_hash="$(/usr/bin/shasum -a 256 "$BINARY" | /usr/bin/awk '{print $1}')"
[[ "$actual_hash" == "$expected_hash" ]] || die 'guest-local Prime ACP binary checksum does not match receipt'
printf '%s\n' 'VALIDATED: guest-local owner consent and Prime ACP checksum receipt match. No binary was executed, no session was started, and no network was used.'
