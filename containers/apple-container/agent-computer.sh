#!/usr/bin/env bash
# Lifecycle for the first local-only OpenDream Prime agent computer.
#
# The only host mount is the explicitly scoped, project-local workspace. It is
# necessary for persistence and is never shared with another project or agent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONTAINER_NAME="opndrm-prime-agent-computer"
IMAGE_NAME="opndrm-prime/apple-container:dev"
WORKSPACE="$PROJECT_ROOT/.opndrm/agent-computers/prime/workspace"
METADATA="$PROJECT_ROOT/.opndrm/agent-computers/prime/metadata.json"
JSON=false

usage() {
  cat <<'EOF'
Usage: ./containers/apple-container/agent-computer.sh <command> [--json]

Commands:
  status    Show the local agent computer state.
  start     Start the named container, or reuse it if it is ready.
  stop      Stop the named container; its workspace remains intact.
  restart   Stop and start the named container; its workspace remains intact.
  terminal  Open a real interactive terminal in the running container.
  clean     Remove only this agent computer's persistent workspace and container.

The agent computer is local to this Mac. It has one project-local workspace
mount, no published ports, no network or DNS, no SSH forwarding, and no host
credentials. Browser control is intentionally not part of this first slice.
EOF
}

command_name="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi
for option in "$@"; do
  case "$option" in
    --json) JSON=true ;;
    *) usage >&2; exit 2 ;;
  esac
done

require_runtime() {
  if ! command -v container >/dev/null 2>&1; then
    printf 'Apple Container CLI is not installed.\n' >&2
    return 1
  fi
  if ! container system status --format json >/dev/null 2>&1; then
    printf 'Apple Container is installed but not running. The Mac owner must run: container system start\n' >&2
    return 1
  fi
}

image_ready() {
  container image inspect "$IMAGE_NAME" >/dev/null 2>&1
}

write_metadata() {
  mkdir -p "$(dirname "$METADATA")" "$WORKSPACE"
  if [[ -f "$METADATA" ]]; then
    return 0
  fi
  python3 - "$METADATA" "$WORKSPACE" <<'PY'
import json, pathlib, sys
metadata_path, workspace_path = map(pathlib.Path, sys.argv[1:])
metadata_path.write_text(json.dumps({
  "schemaVersion": 1,
  "agentComputerId": "prime-agent-computer",
  "agentId": "prime",
  "provider": "apple-container-local",
  "workspace": str(workspace_path),
  "snapshot": {"state": "not-created", "provider": None},
}, indent=2) + "\n")
PY
}

container_state() {
  local inspection
  if ! inspection="$(container inspect "$CONTAINER_NAME" 2>/dev/null)"; then
    printf 'absent'
    return 0
  fi
  printf '%s' "$inspection" | python3 -c '
import json, sys
record = json.load(sys.stdin)[0]
print(record.get("status", {}).get("state", "unknown"))
'
}

reported_state() {
  local runtime="failed" state="absent"
  if require_runtime >/dev/null 2>&1; then
    runtime="ready"
    state="$(container_state)"
  fi
  case "$state" in
    running) printf 'ready' ;;
    absent|stopped|created) printf 'stopped' ;;
    *) printf 'failed' ;;
  esac
}

print_status() {
  local runtime="unavailable" image="missing" raw_state="absent" state workspace_state="missing"
  if require_runtime >/dev/null 2>&1; then
    runtime="ready"
    raw_state="$(container_state)"
  fi
  if image_ready; then
    image="ready"
  fi
  if [[ -d "$WORKSPACE" ]]; then
    workspace_state="persistent"
  fi
  state="$(reported_state)"

  if [[ "$JSON" == true ]]; then
    python3 - "$state" "$runtime" "$image" "$raw_state" "$workspace_state" "$WORKSPACE" "$METADATA" "$CONTAINER_NAME" "$IMAGE_NAME" "$SCRIPT_DIR/agent-computer.sh terminal" <<'PY'
import json, sys
state, runtime, image, raw_state, workspace, workspace_path, metadata_path, name, image_name, terminal = sys.argv[1:]
print(json.dumps({
  "agent": "PRIME",
  "state": state,
  "runtime": runtime,
  "image": image,
  "container": {"name": name, "state": raw_state},
  "workspace": {"state": workspace, "path": workspace_path, "metadataPath": metadata_path},
  "terminalCommand": terminal,
  "browser": "deferred",
  "security": [
    "non-root user",
    "one project-local workspace mount",
    "no network or DNS",
    "no published ports",
    "no SSH or inherited credentials",
    "read-only root filesystem"
  ]
}))
PY
  else
    cat <<EOF
PRIME local agent computer: $state
Runtime: $runtime
Image: $image
Container: $CONTAINER_NAME ($raw_state)
Workspace: $WORKSPACE ($workspace_state)
Metadata: $METADATA
Browser: deferred — no browser is installed or exposed in this slice.
EOF
  fi
}

start() {
  require_runtime
  if ! image_ready; then
    printf 'The approved local baseline image is missing. Run ./containers/apple-container/verify.sh first.\n' >&2
    return 1
  fi

  case "$(container_state)" in
    running)
      printf 'PRIME local agent computer is already ready.\n'
      return 0
      ;;
    absent)
      write_metadata
      container run \
        --detach \
        --name "$CONTAINER_NAME" \
        --label org.opencontainers.image.title=opndrm-prime-agent-computer \
        --label org.opencontainers.image.description=local-only-prime-agent-computer \
        --cpus 1 \
        --memory 768M \
        --cap-drop ALL \
        --read-only \
        --tmpfs /tmp \
        --network none \
        --no-dns \
        --mount "type=bind,source=$WORKSPACE,target=/workspace" \
        "$IMAGE_NAME" \
        bash -lc 'while :; do sleep 3600; done'
      ;;
    *)
      container start "$CONTAINER_NAME"
      ;;
  esac
  printf 'PRIME local agent computer is ready.\n'
}

stop() {
  require_runtime
  case "$(container_state)" in
    running) container stop --time 5 "$CONTAINER_NAME" ;;
    absent) printf 'PRIME local agent computer is already stopped.\n' ;;
    *) printf 'PRIME local agent computer is already stopped.\n' ;;
  esac
}

restart() {
  stop
  start
}

terminal() {
  require_runtime
  if [[ "$(container_state)" != "running" ]]; then
    printf 'PRIME local agent computer is not ready. Run: %s start\n' "$SCRIPT_DIR/agent-computer.sh" >&2
    return 1
  fi
  exec container exec --interactive --tty "$CONTAINER_NAME" bash -l
}

clean() {
  require_runtime
  if [[ "$(container_state)" == "running" ]]; then
    container stop --time 5 "$CONTAINER_NAME"
  fi
  if [[ "$(container_state)" != "absent" ]]; then
    container delete "$CONTAINER_NAME"
  fi
  case "$WORKSPACE" in
    "$PROJECT_ROOT/.opndrm/agent-computers/prime/workspace") ;;
    *) printf 'Refusing to clean an unexpected workspace path.\n' >&2; return 1 ;;
  esac
  rm -rf "$WORKSPACE"
  rm -f "$METADATA"
  printf 'Removed only the PRIME local agent computer workspace and container.\n'
}

case "$command_name" in
  status) print_status ;;
  start) start; if [[ "$JSON" == true ]]; then print_status; fi ;;
  stop) stop; if [[ "$JSON" == true ]]; then print_status; fi ;;
  restart) restart; if [[ "$JSON" == true ]]; then print_status; fi ;;
  terminal) terminal ;;
  clean) clean; if [[ "$JSON" == true ]]; then print_status; fi ;;
  -h|--help|help|'') usage ;;
  *) usage >&2; exit 2 ;;
esac
