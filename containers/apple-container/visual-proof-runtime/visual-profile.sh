#!/usr/bin/env bash
# Disposable, view-only visual-profile lifecycle for Buzz Container.
#
# This is deliberately separate from the headless coding lifecycle.
# Nothing runs unless the owner invokes `start --confirm-start` with an
# owner-only token file. The visual profile has no input, repository, network,
# ports, SSH, browser, recorder, or host mounts.

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)"
IMAGE_NAME="opndrm-prime/buzz-container-visual-proof:0.2.6"
CONTAINER_NAME="opndrm-prime-buzz-container-visual-proof"
SOCKET_DIR="$PROJECT_ROOT/.opndrm/buzz-container-view/visual-proof"
HOST_SOCKET="$SOCKET_DIR/view.sock"
CONTAINER_SOCKET="/run/buzz-container/view.sock"
LABEL="org.opndrm.prime.visual-proof=1"
command_name="${1:-help}"
shift || true

usage() {
  cat <<'EOF'
Usage: visual-profile.sh <command> [options]

Commands:
  preflight                         Check readiness without starting anything.
  plan                              Print the exact isolated runtime contract.
  start --confirm-start --token-file PATH
                                    Start one disposable visual-proof VM.
  status                            Print inspection-only state and security facts.
  stop                              Stop the proof VM; socket evidence remains.
  teardown --evidence-handled       Delete a stopped proof VM and its socket.

The token file must be regular, owner-only (0600), non-empty, and supplied by
the Mac owner. It is never printed. `start` is the only command that can create
a VM, and it needs both explicit flags.
EOF
}

fail() { printf 'Visual proof: %s\n' "$*" >&2; exit 1; }

require_runtime() {
  command -v container >/dev/null 2>&1 || fail 'Apple Container CLI is not installed.'
  container system status --format json >/dev/null 2>&1 || fail 'Apple Container service is not running.'
}

container_state() {
  local inspected
  if ! inspected="$(container inspect "$CONTAINER_NAME" 2>/dev/null)"; then
    printf absent
    return 0
  fi
  printf '%s' "$inspected" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0].get("status", {}).get("state", "unknown"))'
}

assert_token_file() {
  local token_file="$1" mode
  [[ -n "$token_file" ]] || fail 'A token file is required.'
  [[ -f "$token_file" && ! -L "$token_file" ]] || fail 'Token input must be a regular file, not a symlink.'
  [[ -O "$token_file" ]] || fail 'Token input must be owned by the current Mac user.'
  mode="$(stat -f '%Lp' "$token_file")"
  [[ "$mode" == 600 ]] || fail 'Token input must have mode 0600.'
  [[ -s "$token_file" ]] || fail 'Token input must not be empty.'
  [[ "$(wc -l < "$token_file" | tr -d ' ')" -eq 1 ]] || fail 'Token input must contain exactly one line.'
  [[ "$(wc -c < "$token_file" | tr -d ' ')" -le 257 ]] || fail 'Token input is unexpectedly long.'
}

ensure_socket_directory() {
  mkdir -p "$SOCKET_DIR"
  chmod 0700 "$SOCKET_DIR"
  [[ -O "$SOCKET_DIR" ]] || fail 'Visual socket directory must be owned by the current Mac user.'
}

preflight() {
  require_runtime
  container image inspect "$IMAGE_NAME" >/dev/null 2>&1 || fail 'Visual proof image is not built.'
  [[ "$(container_state)" == absent ]] || fail 'A visual proof VM already exists; inspect, stop, or tear it down first.'
  ensure_socket_directory
  [[ ! -e "$HOST_SOCKET" ]] || fail 'Visual proof socket path already exists; do not overwrite it.'
  printf 'Visual proof is ready for an explicit owner-confirmed start.\n'
}

plan() {
  cat <<EOF
Image: $IMAGE_NAME
User: opndrm (non-root)
Root filesystem: read-only
Writable paths: tmpfs /tmp, /workspace, /home/opndrm, /run/buzz-container
Capabilities: all dropped
Host mounts: none
Network and DNS: disabled
TCP/UDP published ports: none
SSH: disabled
Visual egress: one owner-only Unix socket, $HOST_SOCKET -> $CONTAINER_SOCKET
Viewer authentication: one owner-supplied token file, never printed
Input capabilities: none (no keyboard, mouse, clipboard, terminal, or browser)
EOF
}

start() {
  local confirmation="" token_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --confirm-start) confirmation=1 ;;
      --token-file) shift; token_file="${1:-}" ;;
      *) usage >&2; exit 2 ;;
    esac
    shift || true
  done
  [[ "$confirmation" == 1 ]] || fail 'Refusing to start without --confirm-start.'
  assert_token_file "$token_file"
  preflight

  # The token enters only the new VM environment. It is never logged or emitted.
  local token
  IFS= read -r token < "$token_file"
  container run --detach --name "$CONTAINER_NAME" \
    --label "$LABEL" \
    --cpus 1 --memory 768M --cap-drop ALL --read-only \
    --tmpfs /tmp --tmpfs /workspace --tmpfs /home/opndrm --tmpfs /run/buzz-container \
    --network none --no-dns \
    --publish-socket "$HOST_SOCKET:$CONTAINER_SOCKET" \
    --env "BUZZ_CONTAINER_VIEW_TOKEN=$token" \
    "$IMAGE_NAME" >/dev/null
  printf 'Started one isolated visual-proof VM. Use status before viewing; stop and evidence-handled teardown are explicit.\n'
}

status() {
  require_runtime
  local state inspected
  state="$(container_state)"
  if [[ "$state" == absent ]]; then
    python3 - "$CONTAINER_NAME" "$HOST_SOCKET" <<'PY'
import json,sys
print(json.dumps({"name":sys.argv[1],"state":"absent","socket":sys.argv[2],"evidence":"no visual proof VM exists"}))
PY
    return 0
  fi
  inspected="$(container inspect "$CONTAINER_NAME")"
  # A here-document would consume standard input before the JSON pipe reaches
  # Python, so keep the small decoder in -c and reserve stdin for inspect.
  printf '%s' "$inspected" | python3 -c '
import json, sys
record = json.load(sys.stdin)[0]
cfg = record.get("configuration", {})
mounts = cfg.get("mounts", [])
print(json.dumps({
  "name": record.get("id"),
  "state": record.get("status", {}).get("state", "unknown"),
  "socket": sys.argv[1],
  "security": {
    "hostMounts": [m for m in mounts if m.get("type", {}).get("virtiofs")],
    "networks": cfg.get("networks", []),
    "publishedPorts": cfg.get("publishedPorts", []),
    "ssh": cfg.get("ssh"),
    "readOnlyRoot": cfg.get("readOnly"),
    "capDrop": cfg.get("capDrop", []),
  },
  "evidence": "inspection metadata only; no frame, terminal output, files, or token are returned"
}))
' "$HOST_SOCKET"
}

stop() {
  require_runtime
  case "$(container_state)" in
    running) container stop --time 5 "$CONTAINER_NAME" >/dev/null; printf 'Stopped visual-proof VM. Inspect evidence before explicit teardown.\n' ;;
    stopped|created) printf 'Visual-proof VM is already stopped.\n' ;;
    absent) fail 'No visual-proof VM exists.' ;;
    *) fail "Unexpected visual-proof state: $(container_state)" ;;
  esac
}

teardown() {
  [[ "${1:-}" == --evidence-handled ]] || fail 'Refusing teardown without --evidence-handled.'
  require_runtime
  [[ "$(container_state)" != running ]] || fail 'Stop the visual-proof VM and handle evidence before teardown.'
  [[ "$(container_state)" != absent ]] || fail 'No visual-proof VM exists.'
  container delete "$CONTAINER_NAME" >/dev/null
  rm -f -- "$HOST_SOCKET"
  rmdir "$SOCKET_DIR" 2>/dev/null || true
  printf 'Visual-proof VM and private socket removed after explicit evidence-handled confirmation.\n'
}

case "$command_name" in
  preflight) [[ $# -eq 0 ]] || { usage >&2; exit 2; }; preflight ;;
  plan) [[ $# -eq 0 ]] || { usage >&2; exit 2; }; plan ;;
  start) start "$@" ;;
  status) [[ $# -eq 0 ]] || { usage >&2; exit 2; }; status ;;
  stop) [[ $# -eq 0 ]] || { usage >&2; exit 2; }; stop ;;
  teardown) teardown "$@" ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
