#!/bin/bash
# Guest-only first-boot skeleton for a macOS Agent Computer.
#
# Invoke only from inside the intended macOS guest, after the owner confirms:
#   OPNDRM_GUEST_CONTEXT=macos-guest OPNDRM_GUEST_VM_IDENTIFIER=<vm-id> \
#     ./first-boot-opndrm.sh --owner-confirmed
#
# This payload deliberately contains no download URL, package-manager command,
# credential, repository reference, or host path.  Component installation and
# configuration are delegated only to separately reviewed, guest-local hooks.

set -euo pipefail
IFS=$'\n\t'
umask 077

readonly RECEIPT_LIMIT=40
readonly GUEST_MARKER_NAME='.opndrm-guest-context'

usage() {
  cat >&2 <<'USAGE'
Usage: OPNDRM_GUEST_CONTEXT=macos-guest OPNDRM_GUEST_VM_IDENTIFIER=<vm-id> \
  first-boot-opndrm.sh --owner-confirmed

This is a guest-only first-boot payload.  It refuses host or bridge contexts.
The owner confirmation flag is required for every invocation.
USAGE
  exit 64
}

die() {
  printf 'first-boot-opndrm: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 1 && "$1" == '--owner-confirmed' ]] || usage
[[ "${OPNDRM_GUEST_CONTEXT:-}" == 'macos-guest' ]] || \
  die 'missing macos-guest context assertion'
[[ -n "${OPNDRM_GUEST_VM_IDENTIFIER:-}" ]] || die 'missing guest VM identifier'
readonly VM_IDENTIFIER="$OPNDRM_GUEST_VM_IDENTIFIER"
[[ "$VM_IDENTIFIER" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]] || \
  die 'guest VM identifier must be 1–63 alphanumeric/hyphen characters'

assert_guest_context() {
  [[ "$(/usr/bin/uname -s)" == 'Darwin' ]] || die 'this payload is for a macOS guest only'
  [[ "$(/usr/bin/id -u)" -ne 0 ]] || die 'refusing to run as root'
  [[ -z "${SUDO_USER:-}" ]] || die 'refusing a sudo or bridged invocation'

  readonly GUEST_USER="$(/usr/bin/id -un)"
  [[ "$HOME" == "/Users/$GUEST_USER" ]] || die 'guest HOME does not match the non-root guest user'
  [[ ! -L "$HOME" ]] || die 'guest HOME must not be a symlink or bridge'

  # This immutable marker is placed by the guest image build, never by this
  # script.  A host cannot become a guest merely by running the payload.
  readonly GUEST_MARKER="$HOME/$GUEST_MARKER_NAME"
  [[ -f "$GUEST_MARKER" && ! -L "$GUEST_MARKER" ]] || \
    die 'guest image marker is absent; refusing unknown host/bridge context'
  [[ "$(/bin/cat "$GUEST_MARKER")" == 'macos-guest' ]] || \
    die 'guest image marker is invalid'

  [[ -z "${OPNDRM_HOST_BRIDGE:-}" && -z "${OPNDRM_BRIDGE_CONTEXT:-}" ]] || \
    die 'host/bridge environment is declared'
  if /sbin/mount | /usr/bin/grep -Eiq '\((virtiofs|9p|sshfs|smbfs|nfs|webdav)(,|\))'; then
    die 'a shared or bridged filesystem is mounted'
  fi
}

assert_guest_context

# All mutable locations below are interpreted inside the verified guest HOME.
readonly PRIME_ROOT="$HOME/opndrm-prime"
readonly CONFIG_ROOT="$HOME/.config/opndrm-prime"
readonly WORKSPACE_ROOT="$HOME/workspace"
readonly WORKTREES_ROOT="$WORKSPACE_ROOT/worktrees"
readonly RECEIPT_ROOT="$CONFIG_ROOT/receipts/first-boot"
readonly STAGE_ROOT="$CONFIG_ROOT/first-boot-stages"
readonly HOOK_ROOT="$CONFIG_ROOT/component-hooks"
readonly BUZZ_AGENT_ID="buzz-$VM_IDENTIFIER"
readonly BUZZ_AGENT_ROOT="$CONFIG_ROOT/buzz/agents/$BUZZ_AGENT_ID"
readonly WAYFINDER_ISSUE_ID="issue-$VM_IDENTIFIER"
readonly WAYFINDER_LANE_ROOT="$WORKSPACE_ROOT/wayfinder"
readonly WAYFINDER_WORKTREE="$WORKTREES_ROOT/$WAYFINDER_ISSUE_ID"

receipt() {
  # Fixed-size JSONL receipt log: keep only the newest RECEIPT_LIMIT records.
  # Fields are fixed literals from this script; it never records arguments,
  # environment values, paths, credentials, or component output.
  local stage="$1" outcome="$2" detail="$3" now tmp
  now="$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
  tmp="$RECEIPT_ROOT/.receipts.$$.tmp"
  {
    [[ -f "$RECEIPT_ROOT/receipts.jsonl" ]] && /usr/bin/tail -n "$((RECEIPT_LIMIT - 1))" "$RECEIPT_ROOT/receipts.jsonl" || true
    printf '{"at":"%s","stage":"%s","outcome":"%s","detail":"%s"}\n' \
      "$now" "$stage" "$outcome" "$detail"
  } > "$tmp"
  /bin/mv -f "$tmp" "$RECEIPT_ROOT/receipts.jsonl"
}

ensure_file_contents() {
  # Reconciliation is atomic and does not append unbounded state.
  local file="$1" contents="$2" tmp
  tmp="$file.$$.tmp"
  printf '%s\n' "$contents" > "$tmp"
  /bin/mv -f "$tmp" "$file"
}

stage_guest_local_directories() {
  /usr/bin/install -d -m 0700 \
    "$PRIME_ROOT" "$CONFIG_ROOT" "$WORKSPACE_ROOT" "$WORKTREES_ROOT" \
    "$RECEIPT_ROOT" "$STAGE_ROOT" "$HOOK_ROOT" \
    "$CONFIG_ROOT/wezterm" "$CONFIG_ROOT/herdr" "$CONFIG_ROOT/prime-agent" \
    "$CONFIG_ROOT/jcode" "$CONFIG_ROOT/openadapt" "$CONFIG_ROOT/buzz/agents" \
    "$WAYFINDER_LANE_ROOT" "$WORKSPACE_ROOT/no-mistakes"
  ensure_file_contents "$STAGE_ROOT/01-guest-local-directories" 'ensure-present'
  receipt '01-guest-local-directories' 'reconciled' 'guest-local-roots-only'
}

stage_component() {
  # A hook is an intentionally empty extension point in this repository.  The
  # payload neither supplies nor infers a component source.  When a separately
  # approved guest-local hook is absent, fail closed instead of downloading.
  local order="$1" component="$2" component_dir="$3"
  local hook="$HOOK_ROOT/$component.sh"
  [[ -x "$hook" && ! -L "$hook" ]] || {
    receipt "$order-$component" 'blocked' 'guest-local-component-hook-unavailable'
    die "required guest-local hook unavailable for $component"
  }
  "$hook" --reconcile --component "$component" --directory "$component_dir"
  ensure_file_contents "$STAGE_ROOT/$order-$component" 'reconcile'
  receipt "$order-$component" 'reconciled' 'guest-local-hook-completed'
}

stage_no_mistakes_inactive() {
  # Never call an installer, daemon, gate, pipeline, or service for No Mistakes.
  ensure_file_contents "$WORKSPACE_ROOT/no-mistakes/STATE" 'inactive'
  ensure_file_contents "$STAGE_ROOT/07-no-mistakes-workspace" 'ensure-inactive'
  receipt '07-no-mistakes-workspace' 'reconciled' 'inactive-not-started'
}

assert_only_expected_directory() {
  local parent="$1" expected="$2" entry
  while IFS= read -r entry; do
    [[ "${entry##*/}" == "$expected" ]] || \
      die 'another lane identity/worktree exists; refusing to merge or delete it'
  done < <(/usr/bin/find "$parent" -mindepth 1 -maxdepth 1 -type d -print)
}

stage_buzz_identity() {
  assert_only_expected_directory "$CONFIG_ROOT/buzz/agents" "$BUZZ_AGENT_ID"
  /usr/bin/install -d -m 0700 "$BUZZ_AGENT_ROOT"
  ensure_file_contents "$BUZZ_AGENT_ROOT/identity" "$BUZZ_AGENT_ID"
  ensure_file_contents "$STAGE_ROOT/08-buzz-identity" 'ensure-single-identity'
  receipt '08-buzz-identity' 'reconciled' 'one-guest-local-buzz-identity'
}

stage_wayfinder_worktree() {
  assert_only_expected_directory "$WORKTREES_ROOT" "$WAYFINDER_ISSUE_ID"
  /usr/bin/install -d -m 0700 "$WAYFINDER_WORKTREE"
  ensure_file_contents "$WAYFINDER_LANE_ROOT/assignment" \
    "buzz-agent=$BUZZ_AGENT_ID"$'\n'"issue=$WAYFINDER_ISSUE_ID"$'\n'"worktree=$WAYFINDER_ISSUE_ID"
  ensure_file_contents "$STAGE_ROOT/09-wayfinder-worktree" 'ensure-single-worktree'
  receipt '09-wayfinder-worktree' 'reconciled' 'one-guest-local-wayfinder-lane'
}

# Ordered manifest reconciliation.  Do not reorder these stages: dependencies
# match AgentComputerGuestBootstrap's desired-state provisioning recipe.
stage_guest_local_directories
stage_component '02' 'opndrm-prime' "$PRIME_ROOT"
stage_component '03' 'wezterm' "$CONFIG_ROOT/wezterm"
stage_component '04' 'herdr' "$CONFIG_ROOT/herdr"
stage_component '05' 'prime-agent' "$CONFIG_ROOT/prime-agent"
stage_component '06' 'jcode' "$CONFIG_ROOT/jcode"
stage_no_mistakes_inactive
stage_buzz_identity
stage_wayfinder_worktree
stage_component '10' 'openadapt' "$CONFIG_ROOT/openadapt"

receipt 'complete' 'reconciled' 'guest-first-boot-finished'
printf 'Guest first-boot reconciliation completed for %s.\n' "$VM_IDENTIFIER"
