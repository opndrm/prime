#!/usr/bin/env bash
# Owner-explicit guard for a future container-only Buzz Record integration.
# This script deliberately cannot start a recording. It makes the current
# unavailable state and future consent/session prerequisites machine-checkable.

set -euo pipefail

COMMAND="${1:-status}"
shift || true

usage() {
  cat <<'EOF'
Usage: buzz-record.sh <command> [options]

Commands:
  status
      Report the inert Buzz Record capability state without inspecting or
      starting a container.
  preflight --session-id ID
      Refuse unless a future validated visual-session adapter exists.
  start --session-id ID --confirm-start-recording
      Requires explicit consent, then refuses because no recorder exists.
  stop --session-id ID --confirm-stop-recording
      Requires explicit stop consent, then refuses because no capture exists.

Buzz Record is reserved for a future OpenAdapt recorder inside an already
validated visual Agent Computer. It never captures the host Mac.
EOF
}

fail() {
  printf 'Buzz Record blocked: %s\n' "$*" >&2
  exit 1
}

require_session_id() {
  local session_id="$1"
  [[ "$session_id" =~ ^[a-z0-9][a-z0-9-]{0,63}$ ]] || \
    fail 'A lowercase assigned visual-session identifier is required.'
}

parse_session_id() {
  local session_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session-id) shift; session_id="${1:-}" ;;
      *) usage >&2; exit 2 ;;
    esac
    shift || true
  done
  require_session_id "$session_id"
  printf '%s' "$session_id"
}

status() {
  cat <<'EOF'
{"capability":"Buzz Record","state":"unavailable","target":"validated visual Agent Computer only","hostCapture":false,"activeCapture":false,"artifactState":"none","evidenceState":"none","openAdapt":"not installed or configured","reason":"No validated visual-session adapter or recorder is implemented."}
EOF
}

preflight() {
  local session_id
  session_id="$(parse_session_id "$@")"
  fail "visual session '$session_id' cannot be validated: the Orchard visual-session adapter is not implemented."
}

start() {
  local session_id="" confirmation=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session-id) shift; session_id="${1:-}" ;;
      --confirm-start-recording) confirmation=1 ;;
      *) usage >&2; exit 2 ;;
    esac
    shift || true
  done
  require_session_id "$session_id"
  [[ "$confirmation" == 1 ]] || fail 'Explicit --confirm-start-recording consent is required.'
  fail "visual session '$session_id' cannot be validated: no recording engine may start."
}

stop() {
  local session_id="" confirmation=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session-id) shift; session_id="${1:-}" ;;
      --confirm-stop-recording) confirmation=1 ;;
      *) usage >&2; exit 2 ;;
    esac
    shift || true
  done
  require_session_id "$session_id"
  [[ "$confirmation" == 1 ]] || fail 'Explicit --confirm-stop-recording consent is required.'
  fail "no active capture exists for visual session '$session_id'."
}

case "$COMMAND" in
  status) [[ $# -eq 0 ]] || { usage >&2; exit 2; }; status ;;
  preflight) preflight "$@" ;;
  start) start "$@" ;;
  stop) stop "$@" ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
