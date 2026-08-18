#!/bin/bash
# Shared validation library for the inert, guest-only Prime workflow hooks.
# It validates owner-supplied guest-local declarations; it never installs,
# launches, downloads, configures, activates, or deletes software.

set -euo pipefail
IFS=$'\n\t'

readonly OPNDRM_GUEST_MARKER_NAME='.opndrm-guest-context'
readonly OPNDRM_CONFIRMATION='I CONFIRM THIS GUEST-ONLY PRIME WORKFLOW PLAN'
readonly OPNDRM_PLAN_RELATIVE_ROOT='.config/opndrm-prime/prime-workflow'
readonly OPNDRM_REQUIRED_COMPONENTS=$'wezterm-herdr\nprime-agent\njcode\nwayfinder\nno-mistakes'

die() {
  printf 'prime-workflow hook: refused: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat >&2 <<'USAGE'
Usage (inside the prepared macOS guest only):
  OPNDRM_GUEST_CONTEXT=macos-guest \
  OPNDRM_GUEST_OWNER_CONFIRMATION='I CONFIRM THIS GUEST-ONLY PRIME WORKFLOW PLAN' \
  hooks/<component>.sh --validate-plan --guest-owner-confirmed

The hook only verifies a complete guest-local approval lock and artifacts.
It has no install, download, launch, activation, service, or credential mode.
USAGE
  exit 64
}

require_exact_invocation() {
  [[ $# -eq 2 ]] || usage
  local saw_validate=0 saw_confirmation=0 arg
  for arg in "$@"; do
    case "$arg" in
      --validate-plan) saw_validate=1 ;;
      --guest-owner-confirmed) saw_confirmation=1 ;;
      *) usage ;;
    esac
  done
  [[ "$saw_validate" -eq 1 && "$saw_confirmation" -eq 1 ]] || usage
  [[ "${OPNDRM_GUEST_OWNER_CONFIRMATION:-}" == "$OPNDRM_CONFIRMATION" ]] || \
    die 'fresh explicit guest owner confirmation is required'
}

assert_guest_context() {
  [[ "${OPNDRM_GUEST_CONTEXT:-}" == 'macos-guest' ]] || \
    die 'macos-guest context assertion is required'
  [[ "$(/usr/bin/uname -s)" == 'Darwin' ]] || die 'macOS guest required'
  [[ "$(/usr/bin/id -u)" -ne 0 ]] || die 'root invocation is refused'
  [[ -z "${SUDO_USER:-}" ]] || die 'sudo invocation is refused'

  local guest_user marker
  guest_user="$(/usr/bin/id -un)"
  [[ "$HOME" == "/Users/$guest_user" && ! -L "$HOME" ]] || \
    die 'verified non-root guest HOME is required'
  marker="$HOME/$OPNDRM_GUEST_MARKER_NAME"
  [[ -f "$marker" && ! -L "$marker" ]] || \
    die 'image-provisioned guest marker is absent'
  [[ "$(/bin/cat "$marker")" == 'macos-guest' ]] || \
    die 'image-provisioned guest marker is invalid'
  [[ -z "${OPNDRM_HOST_BRIDGE:-}" && -z "${OPNDRM_BRIDGE_CONTEXT:-}" ]] || \
    die 'declared host or bridge context is refused'
  if /sbin/mount | /usr/bin/grep -Eiq '\((virtiofs|9p|sshfs|smbfs|nfs|webdav)(,|\))'; then
    die 'shared or bridged filesystem is detected'
  fi
}

# Require an existing path beneath $HOME with no symlink in any checked part.
# The plan creates no directory: absence is a refusal, not a provisioning step.
assert_existing_guest_local_path() {
  local path="$1" rel current segment
  [[ "$path" == "$HOME" || "$path" == "$HOME/"* ]] || \
    die 'path is outside the verified guest HOME'
  [[ ! -L "$HOME" ]] || die 'guest HOME symlink is refused'
  rel="${path#"$HOME"}"
  current="$HOME"
  while [[ -n "$rel" ]]; do
    rel="${rel#/}"
    segment="${rel%%/*}"
    [[ -n "$segment" && "$segment" != '.' && "$segment" != '..' ]] || \
      die 'unsafe guest-local path'
    current="$current/$segment"
    [[ ! -L "$current" ]] || die 'guest-local symlink is refused'
    if [[ "$rel" == */* ]]; then
      [[ -d "$current" ]] || die 'guest-local parent directory is absent'
      rel="${rel#*/}"
    else
      [[ -e "$current" ]] || die 'required guest-local path is absent'
      rel=''
    fi
  done
}

plan_root() {
  printf '%s/%s\n' "$HOME" "$OPNDRM_PLAN_RELATIVE_ROOT"
}

expected_mode_for_component() {
  case "$1" in
    no-mistakes) printf '%s\n' 'install-inactive-only' ;;
    wezterm-herdr|prime-agent|jcode|wayfinder) printf '%s\n' 'install-plan-only' ;;
    *) die 'unknown workflow component' ;;
  esac
}

is_required_component() {
  local required
  while IFS= read -r required; do
    [[ "$1" == "$required" ]] && return 0
  done <<EOF
$OPNDRM_REQUIRED_COMPONENTS
EOF
  return 1
}

validate_field() {
  local value="$1" label="$2"
  [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{2,127}$ ]] || \
    die "invalid $label in approval lock"
}

validate_artifact_relative_path() {
  local path="$1" component="$2"
  [[ "$path" =~ ^artifacts/"$component"/[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] || \
    die 'artifact path must be a simple component-scoped guest-local path'
}

validate_lock_and_artifacts() {
  local target="$1" root lock line_no=0
  local component source_id approval_id artifact_rel expected_hash mode extra
  local seen_wezterm=0 seen_prime=0 seen_jcode=0 seen_wayfinder=0 seen_nm=0 target_seen=0
  local artifact actual_hash expected_mode

  root="$(plan_root)"
  lock="$root/approved-artifacts.tsv"
  assert_existing_guest_local_path "$root"
  assert_existing_guest_local_path "$lock"
  [[ -f "$lock" && ! -L "$lock" && -s "$lock" ]] || \
    die 'approval lock must be a nonempty regular guest-local file'

  while IFS=$'\t' read -r component source_id approval_id artifact_rel expected_hash mode extra || [[ -n "${component:-}" ]]; do
    line_no=$((line_no + 1))
    [[ -n "${component:-}" ]] || continue
    [[ "${component:0:1}" != '#' ]] || continue
    [[ -z "${extra:-}" ]] || die "unexpected seventh field on approval-lock line $line_no"
    is_required_component "$component" || die "unknown component on approval-lock line $line_no"
    validate_field "$source_id" 'approved source identifier'
    validate_field "$approval_id" 'owner approval identifier'
    validate_artifact_relative_path "$artifact_rel" "$component"
    [[ "$expected_hash" =~ ^[a-f0-9]{64}$ ]] || \
      die "invalid SHA-256 on approval-lock line $line_no"
    expected_mode="$(expected_mode_for_component "$component")"
    [[ "$mode" == "$expected_mode" ]] || \
      die "invalid desired state for $component on approval-lock line $line_no"

    case "$component" in
      wezterm-herdr) [[ "$seen_wezterm" -eq 0 ]] || die 'duplicate wezterm-herdr lock entry'; seen_wezterm=1 ;;
      prime-agent) [[ "$seen_prime" -eq 0 ]] || die 'duplicate prime-agent lock entry'; seen_prime=1 ;;
      jcode) [[ "$seen_jcode" -eq 0 ]] || die 'duplicate jcode lock entry'; seen_jcode=1 ;;
      wayfinder) [[ "$seen_wayfinder" -eq 0 ]] || die 'duplicate wayfinder lock entry'; seen_wayfinder=1 ;;
      no-mistakes) [[ "$seen_nm" -eq 0 ]] || die 'duplicate no-mistakes lock entry'; seen_nm=1 ;;
    esac

    artifact="$root/$artifact_rel"
    assert_existing_guest_local_path "$artifact"
    [[ -f "$artifact" && ! -L "$artifact" ]] || \
      die "artifact for $component is not a regular guest-local file"
    [[ -x /usr/bin/shasum ]] || die 'SHA-256 verifier unavailable; refusing validation'
    actual_hash="$(/usr/bin/shasum -a 256 "$artifact" | /usr/bin/awk '{print $1}')"
    [[ "$actual_hash" == "$expected_hash" ]] || \
      die "guest-local artifact hash mismatch for $component"
    [[ "$component" == "$target" ]] && target_seen=1
  done < "$lock"

  [[ "$seen_wezterm" -eq 1 && "$seen_prime" -eq 1 && "$seen_jcode" -eq 1 && \
     "$seen_wayfinder" -eq 1 && "$seen_nm" -eq 1 && "$target_seen" -eq 1 ]] || \
    die 'approval lock must authorize exactly one complete five-component workflow'
}

validate_component_plan() {
  local component="$1"
  shift
  is_required_component "$component" || die 'unknown hook component'
  require_exact_invocation "$@"
  assert_guest_context
  validate_lock_and_artifacts "$component"
  printf 'VALIDATED: %s has a guest-local approved source declaration and matching SHA-256 artifact.\n' "$component"
  printf '%s\n' 'No software was installed, launched, configured, activated, or downloaded.'
}
