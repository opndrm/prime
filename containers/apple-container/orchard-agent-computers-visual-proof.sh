#!/usr/bin/env bash
# Owner-invoked end-to-end visual proof handoff for the locally built Orchard
# app.  This is intentionally narrow: it delegates all VM lifecycle actions to
# the reviewed adapter and supplies only an in-memory Unix-socket/token pair to
# a local custom Orchard executable.  It is not an Orchard manager or a
# general-purpose launcher.

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
LIFECYCLE="$SCRIPT_DIR/orchard-agent-computers-lifecycle.sh"
SESSION_DIR="$PROJECT_ROOT/.opndrm/buzz-container-view/visual-proof"
TOKEN_FILE="$SESSION_DIR/orchard-view.token"
HOST_SOCKET="$SESSION_DIR/view.sock"
RECEIPT_FILE="$SESSION_DIR/orchard-frame-receipt.json"
PID_FILE="$SESSION_DIR/orchard-viewer.pid"

command_name="${1:-help}"
shift || true

usage() {
  cat <<'EOF'
Usage: orchard-agent-computers-visual-proof.sh <command> [options]

Commands:
  preflight --app PATH
      Check the local custom Orchard app and the guarded visual lifecycle.
      Starts nothing.
  prove --confirm-visual-proof --app PATH
      Explicitly start one disposable visual proof, inspect it before view,
      then launch the local custom Orchard executable with an in-memory scoped
      socket/token handoff.  A successful proof requires an owner-only frame
      receipt written by Orchard after it rendered a nonblank frame.
  finish --evidence-handled
      Stop the proof VM and perform the explicit lifecycle teardown.  This
      never deletes an active proof without the exact evidence confirmation.

This script never invokes generic Orchard container, machine, sandbox, model,
or network flows.  It has no input, capture, remote, repository, credential,
or host-workspace capabilities.
EOF
}

fail() { printf 'Orchard visual proof: %s\n' "$*" >&2; exit 1; }

require_exact() { [[ $# -eq 0 ]] || { usage >&2; exit 2; }; }

private_file() {
  local path="$1" expected_mode="$2"
  [[ -f "$path" && ! -L "$path" && -O "$path" ]] || return 1
  [[ "$(stat -f '%Lp' "$path")" == "$expected_mode" ]]
}

app_executable() {
  local app_path="$1" plist executable
  [[ "$app_path" = /* ]] || fail 'The Orchard app path must be absolute.'
  [[ -d "$app_path" && ! -L "$app_path" ]] || fail 'The Orchard app must be a local .app directory, not a symlink.'
  [[ "$app_path" == "$PROJECT_ROOT"/* ]] || fail 'Refusing an Orchard app outside this project checkout.'
  [[ "$app_path" == *.app ]] || fail 'The Orchard app path must end in .app.'
  plist="$app_path/Contents/Info.plist"
  [[ -f "$plist" && ! -L "$plist" ]] || fail 'The Orchard app bundle is missing its Info.plist.'
  executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist" 2>/dev/null)" || fail 'The Orchard app bundle has no executable declaration.'
  [[ "$executable" == Orchard ]] || fail 'The local app is not the expected Orchard executable.'
  [[ -x "$app_path/Contents/MacOS/$executable" ]] || fail 'The local Orchard executable is missing or not executable.'
  # A source-built app must contain the Agent Computers view marker.  This
  # prevents using an installed/upstream Orchard app by accident.
  strings "$app_path/Contents/MacOS/$executable" | rg -F --quiet 'Inside Apple Container — not this Mac' || fail 'The selected local Orchard build does not include Agent Computers visual proof support.'
  printf '%s' "$app_path/Contents/MacOS/$executable"
}

preflight() {
  local app_path="$1"
  app_executable "$app_path" >/dev/null
  [[ ! -e "$RECEIPT_FILE" && ! -e "$PID_FILE" ]] || fail 'A prior visual proof handoff remains; finish it before starting another.'
  "$LIFECYCLE" preflight
  printf 'Local custom Orchard and the guarded disposable visual-proof lifecycle are ready. Nothing started.\n'
}

require_safe_receipt() {
  private_file "$RECEIPT_FILE" 600 || fail 'Orchard did not write an owner-only frame receipt.'
  python3 - "$RECEIPT_FILE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    receipt = json.load(f)
required = {'schema': 1, 'event': 'rendered-nonblank-frame', 'input': 'watch-only-unix-socket'}
for key, value in required.items():
    if receipt.get(key) != value:
        raise SystemExit('Orchard visual proof: frame receipt is not a valid watch-only render receipt')
width, height = receipt.get('width'), receipt.get('height')
if not isinstance(width, int) or not isinstance(height, int) or width <= 0 or height <= 0 or width > 3840 or height > 2160:
    raise SystemExit('Orchard visual proof: frame receipt reports unsafe dimensions')
PY
}

prove() {
  local confirmation="" app_path=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --confirm-visual-proof) confirmation=1 ;;
      --app) shift; app_path="${1:-}" ;;
      *) usage >&2; exit 2 ;;
    esac
    shift || true
  done
  [[ "$confirmation" == 1 && -n "$app_path" ]] || fail 'Refusing to start without exactly --confirm-visual-proof and --app PATH.'
  local executable
  executable="$(app_executable "$app_path")"
  preflight "$app_path"
  "$LIFECYCLE" start --confirm-start
  # Apple Container publishes the socket after the VM starts.  It must become
  # owner-only before the independent inspection and before Orchard receives it.
  for _ in $(seq 1 40); do
    [[ -S "$HOST_SOCKET" ]] && break
    sleep 0.1
  done
  [[ -S "$HOST_SOCKET" ]] || { "$LIFECYCLE" stop || true; fail 'The visual-proof socket did not appear.'; }
  chmod 0600 "$HOST_SOCKET"
  "$LIFECYCLE" inspect-before-view
  rm -f -- "$RECEIPT_FILE" "$PID_FILE"
  # The authority stays only in the child environment and is never printed,
  # stored in Orchard preferences, supplied as an argument, or written to logs.
  local token
  IFS= read -r token < "$TOKEN_FILE"
  ( umask 077
    ORCHARD_AGENT_COMPUTER_VIEW_SOCKET="$HOST_SOCKET" \
    ORCHARD_AGENT_COMPUTER_VIEW_TOKEN="$token" \
    ORCHARD_AGENT_COMPUTER_VIEW_RECEIPT="$RECEIPT_FILE" \
      "$executable" >/dev/null 2>&1 &
    printf '%s\n' "$!" > "$PID_FILE"
  )
  chmod 0600 "$PID_FILE"
  # Rendering is the only accepted completion signal.  A bounded wait avoids
  # guessing from a running process or calling a container-side command.
  for _ in $(seq 1 100); do
    if [[ -e "$RECEIPT_FILE" ]]; then
      require_safe_receipt
      printf 'Visual proof rendered one nonblank native-pixel frame in the local custom Orchard Agent Computers view. It remains watch-only until explicit finish.\n'
      return 0
    fi
    sleep 0.1
  done
  fail 'The local Orchard app did not provide a valid rendered-frame receipt; visual proof remains unclaimed. Use finish --evidence-handled after inspection.'
}

finish() {
  [[ "${1:-}" == --evidence-handled && $# -eq 1 ]] || fail 'Refusing finish without exactly --evidence-handled.'
  if private_file "$PID_FILE" 600; then
    local pid
    IFS= read -r pid < "$PID_FILE"
    [[ "$pid" =~ ^[0-9]+$ ]] && kill "$pid" 2>/dev/null || true
  fi
  rm -f -- "$PID_FILE" "$RECEIPT_FILE"
  "$LIFECYCLE" stop
  "$LIFECYCLE" teardown --evidence-handled
  printf 'Stopped and removed the disposable visual proof after explicit evidence handling.\n'
}

case "$command_name" in
  preflight)
    [[ "${1:-}" == --app && $# -eq 2 ]] || { usage >&2; exit 2; }
    preflight "$2"
    ;;
  prove) prove "$@" ;;
  finish) finish "$@" ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
