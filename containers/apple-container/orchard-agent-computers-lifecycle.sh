#!/usr/bin/env bash
# Narrow owner-invoked lifecycle adapter for a future Orchard Agent Computers
# view. This is deliberately not an Orchard container manager: it delegates
# only to the guarded disposable visual-proof lifecycle and never opens an app.

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
VISUAL_PROFILE="$SCRIPT_DIR/visual-proof-runtime/visual-profile.sh"
SESSION_CHECKER="$SCRIPT_DIR/visual-proof-runtime/inspect-visual-proof-session.sh"
SESSION_DIR="$PROJECT_ROOT/.opndrm/buzz-container-view/visual-proof"
TOKEN_FILE="$SESSION_DIR/orchard-view.token"
HOST_SOCKET="$SESSION_DIR/view.sock"
command_name="${1:-help}"
shift || true

usage() {
  cat <<'EOF'
Usage: orchard-agent-computers-lifecycle.sh <command>

Commands:
  preflight                         Check only; starts nothing.
  status                            Return inspection-only lifecycle state.
  start --confirm-start             Create one fresh private view token and
                                    start the approved disposable visual proof.
  inspect-before-view               Verify the running proof before any viewer
                                    is allowed to receive its private session.
  stop                              Stop only the visual proof VM.
  teardown --evidence-handled       Delete a stopped proof VM and local session.

This adapter is local and owner-invoked. It does not invoke Orchard, open a
macOS app, attach a viewer, expose a token, or create a generic container.
EOF
}

fail() { printf 'Orchard Agent Computers lifecycle: %s\n' "$*" >&2; exit 1; }

require_no_arguments() {
  [[ $# -eq 0 ]] || { usage >&2; exit 2; }
}

ensure_private_session_dir() {
  mkdir -p "$SESSION_DIR"
  chmod 0700 "$SESSION_DIR"
  [[ -O "$SESSION_DIR" ]] || fail 'The private session directory must be owned by the current Mac user.'
  [[ "$(stat -f '%Lp' "$SESSION_DIR")" == 700 ]] || fail 'The private session directory must have mode 0700.'
}

fresh_token() {
  ensure_private_session_dir
  [[ ! -e "$TOKEN_FILE" ]] || fail 'A private visual session token already exists; inspect, stop, and tear down the prior session first.'
  umask 077
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32 > "$TOKEN_FILE"
  else
    python3 - <<'PY' > "$TOKEN_FILE"
import secrets
print(secrets.token_hex(32))
PY
  fi
  chmod 0600 "$TOKEN_FILE"
  [[ -O "$TOKEN_FILE" && "$(stat -f '%Lp' "$TOKEN_FILE")" == 600 && -s "$TOKEN_FILE" ]] || fail 'Could not create an owner-only private view token.'
}

remove_private_token() {
  if [[ -e "$TOKEN_FILE" ]]; then
    [[ -f "$TOKEN_FILE" && ! -L "$TOKEN_FILE" && -O "$TOKEN_FILE" ]] || fail 'Refusing to remove an unsafe private token path.'
    rm -f -- "$TOKEN_FILE"
  fi
}

preflight() {
  [[ ! -e "$TOKEN_FILE" ]] || fail 'A private visual session token exists; inspect, stop, and tear down the prior session first.'
  "$VISUAL_PROFILE" preflight
  printf 'Orchard Agent Computers is ready for one explicit local visual-proof start.\n'
}

status() {
  "$VISUAL_PROFILE" status
}

start() {
  [[ "${1:-}" == --confirm-start && $# -eq 1 ]] || fail 'Refusing to start without exactly --confirm-start.'
  preflight
  fresh_token
  if ! "$VISUAL_PROFILE" start --confirm-start --token-file "$TOKEN_FILE"; then
    remove_private_token
    exit 1
  fi
  printf 'Started one disposable visual proof. Run inspect-before-view before a future Orchard Agent Computers viewer receives the private session.\n'
}

inspect_before_view() {
  require_no_arguments "$@"
  [[ -f "$TOKEN_FILE" && ! -L "$TOKEN_FILE" && -O "$TOKEN_FILE" ]] || fail 'A current private visual session token is required.'
  [[ "$(stat -f '%Lp' "$TOKEN_FILE")" == 600 && -s "$TOKEN_FILE" ]] || fail 'The private visual session token must remain owner-only and non-empty.'
  "$SESSION_CHECKER"
  printf '%s\n' "Visual proof passed inspection. A future Orchard receiver may use only this session's private Unix-socket frame contract; this command does not expose the token or open a viewer."
}

stop() {
  require_no_arguments "$@"
  "$VISUAL_PROFILE" stop
}

teardown() {
  [[ "${1:-}" == --evidence-handled && $# -eq 1 ]] || fail 'Refusing teardown without exactly --evidence-handled.'
  "$VISUAL_PROFILE" teardown --evidence-handled
  remove_private_token
  rmdir "$SESSION_DIR" 2>/dev/null || true
  printf 'Removed the private Orchard Agent Computers visual session after explicit evidence handling.\n'
}

case "$command_name" in
  preflight) require_no_arguments "$@"; preflight ;;
  status) require_no_arguments "$@"; status ;;
  start) start "$@" ;;
  inspect-before-view) inspect_before_view "$@" ;;
  stop) stop "$@" ;;
  teardown) teardown "$@" ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
