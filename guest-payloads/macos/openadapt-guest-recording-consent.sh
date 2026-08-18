#!/bin/bash
# Guest-only OpenAdapt screen-recording consent skeleton.
#
# This is a plan renderer and consent gate, not a recorder. It contains no
# installation, launch, screen-capture, screenshot, audio, microphone, input,
# network, upload, download, filesystem-write, or deletion command. It only
# prints the next owner-visible lifecycle step after validating guest context
# and a fresh explicit consent phrase.

set -euo pipefail
IFS=$'\n\t'

readonly CONSENT_PHRASE='I CONSENT TO GUEST-ONLY SCREEN RECORDING'
readonly GUEST_MARKER_NAME='.opndrm-guest-context'

usage() {
  cat >&2 <<'USAGE'
Usage (inside the prepared macOS guest only):
  OPNDRM_GUEST_CONTEXT=macos-guest OPNDRM_GUEST_VM_IDENTIFIER=<guest-id> \
    openadapt-guest-recording-consent.sh --stage <plan|review|delete|certify> \
    --explicit-consent 'I CONSENT TO GUEST-ONLY SCREEN RECORDING'

Use --show-consent alone to print the owner-visible consent text. No recording
or other side effect is performed by any invocation.
USAGE
  exit 64
}

die() {
  printf 'openadapt-guest-recording-consent: refused: %s\n' "$*" >&2
  exit 1
}

show_consent() {
  cat <<'CONSENT'
GUEST SCREEN-RECORDING REQUEST

For this named task only, may OpenAdapt record the visible guest display?
No host display, host screenshots, microphone, audio, keyboard input, mouse
input, network upload, or automatic sharing is included. You will be asked to
review and delete the guest-local recording before any certification.

Choose “I CONSENT TO GUEST-ONLY SCREEN RECORDING” to continue, or Decline to
stop. Decline is the default. This skeleton does not record anything.
CONSENT
}

assert_guest_context() {
  [[ "${OPNDRM_GUEST_CONTEXT:-}" == 'macos-guest' ]] || \
    die 'missing macos-guest context assertion'
  [[ -n "${OPNDRM_GUEST_VM_IDENTIFIER:-}" ]] || die 'missing guest VM identifier'
  [[ "${OPNDRM_GUEST_VM_IDENTIFIER}" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}$ ]] || \
    die 'guest VM identifier must be 1–63 alphanumeric/hyphen characters'

  [[ "$(/usr/bin/uname -s)" == 'Darwin' ]] || die 'macOS guest required'
  [[ "$(/usr/bin/id -u)" -ne 0 ]] || die 'root invocation refused'
  [[ -z "${SUDO_USER:-}" ]] || die 'sudo or bridged invocation refused'

  local guest_user guest_marker
  guest_user="$(/usr/bin/id -un)"
  [[ "$HOME" == "/Users/$guest_user" ]] || die 'guest HOME does not match user'
  [[ ! -L "$HOME" ]] || die 'guest HOME symlink refused'
  guest_marker="$HOME/$GUEST_MARKER_NAME"
  [[ -f "$guest_marker" && ! -L "$guest_marker" ]] || \
    die 'image-provisioned guest marker is absent'
  [[ "$(/bin/cat "$guest_marker")" == 'macos-guest' ]] || \
    die 'image-provisioned guest marker is invalid'

  [[ -z "${OPNDRM_HOST_BRIDGE:-}" && -z "${OPNDRM_BRIDGE_CONTEXT:-}" ]] || \
    die 'declared host or bridge context refused'
  if /sbin/mount | /usr/bin/grep -Eiq '\((virtiofs|9p|sshfs|smbfs|nfs|webdav)(,|\))'; then
    die 'shared or bridged filesystem detected'
  fi
}

stage=''
consent=''
if [[ $# -eq 1 && "$1" == '--show-consent' ]]; then
  # Viewing the notice is not a lifecycle action and grants no permission.
  show_consent
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage)
      [[ $# -ge 2 ]] || usage
      stage="$2"
      shift 2
      ;;
    --explicit-consent)
      [[ $# -ge 2 ]] || usage
      consent="$2"
      shift 2
      ;;
    *) usage ;;
  esac
done

[[ -n "$stage" ]] || usage
assert_guest_context
show_consent
[[ "$consent" == "$CONSENT_PHRASE" ]] || \
  die 'missing or non-explicit owner consent; no action was performed'

case "$stage" in
  plan)
    printf '%s\n' 'PLAN: consent accepted for this invocation; no recording is implemented or started.'
    printf '%s\n' 'SCOPE: guest display only in a future reviewed integration; audio and microphone remain disabled.'
    ;;
  review)
    printf '%s\n' 'REVIEW: future integration must show guest-local recording to owner; this skeleton has no recording to review.'
    ;;
  delete)
    printf '%s\n' 'DELETE: future integration must obtain an affirmative guest-local deletion choice and verify it; this skeleton deletes nothing.'
    ;;
  certify)
    printf '%s\n' 'CERTIFY: future integration requires owner review and explicit certification; this skeleton creates no certificate.'
    ;;
  *)
    die 'unknown lifecycle stage; no action was performed'
    ;;
esac
