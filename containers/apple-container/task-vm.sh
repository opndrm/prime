#!/usr/bin/env bash
# One bot / one task lifecycle for local Apple Container task VMs.
# Defaults: no host mounts, credentials, network, DNS, ports, SSH, or deletion.

set -euo pipefail

IMAGE_NAME="opndrm-prime/apple-container:dev"
TASK_LABEL="org.opndrm.prime.task-vm"
MAX_CONCURRENT_TASKS=2
command_name="${1:-}"
bot="${2:-}"
task="${3:-}"
flag="${4:-}"

usage() {
  cat <<'EOF'
Usage: ./containers/apple-container/task-vm.sh <command> <bot> <task> [flag]
Commands: create, start, status, terminal, stop, teardown, smoke
Names use lowercase letters, digits, and hyphens. One bot may have one running
task VM; at most two task VMs may run on this Mac.
EOF
}

validate_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]{0,47}$ ]] || { printf 'Invalid task name: %s\n' "$1" >&2; exit 2; }
}

require_runtime() {
  command -v container >/dev/null 2>&1 || { printf 'Apple Container CLI is not installed.\n' >&2; return 1; }
  container system status --format json >/dev/null 2>&1 || { printf 'Apple Container service is not running.\n' >&2; return 1; }
  container image inspect "$IMAGE_NAME" >/dev/null 2>&1 || { printf 'Baseline image missing. Run ./containers/apple-container/verify.sh first.\n' >&2; return 1; }
}

container_name() { printf 'opndrm-prime-task-%s-%s' "$bot" "$task"; }

container_state() {
  local inspected
  if ! inspected="$(container inspect "$(container_name)" 2>/dev/null)"; then printf absent; return; fi
  printf '%s' "$inspected" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0].get("status", {}).get("state", "unknown"))'
}

active_task_count() {
  container list --format json | python3 -c 'import json,sys; print(sum(x.get("configuration",{}).get("labels",{}).get("org.opndrm.prime.task-vm")=="1" for x in json.load(sys.stdin)))'
}

bot_has_running_task() {
  container list --format json | python3 -c '
import json, sys
for record in json.load(sys.stdin):
    labels = record.get("configuration", {}).get("labels", {})
    if labels.get("org.opndrm.prime.task-vm") == "1" and labels.get("org.opndrm.prime.bot") == sys.argv[1]:
        raise SystemExit(0)
raise SystemExit(1)
' "$bot"
}

create() {
  require_runtime
  [[ "$(container_state)" == absent ]] || { printf 'Task VM already exists: %s\n' "$(container_name)" >&2; return 1; }
  bot_has_running_task && { printf 'This bot already has a running task VM.\n' >&2; return 1; }
  [[ "$(active_task_count)" -lt "$MAX_CONCURRENT_TASKS" ]] || { printf 'Task VM concurrency limit reached (%s).\n' "$MAX_CONCURRENT_TASKS" >&2; return 1; }
  container run --detach --name "$(container_name)" \
    --label "$TASK_LABEL=1" --label "org.opndrm.prime.bot=$bot" --label "org.opndrm.prime.task=$task" \
    --cpus 1 --memory 512M --cap-drop ALL --read-only \
    --tmpfs /tmp --tmpfs /workspace --tmpfs /home/opndrm \
    --network none --no-dns "$IMAGE_NAME" bash -lc 'while :; do sleep 3600; done' >/dev/null
  printf 'Created isolated task VM: %s\n' "$(container_name)"
}

start() {
  require_runtime
  case "$(container_state)" in
    absent) create ;;
    running) printf 'Task VM is already running: %s\n' "$(container_name)" ;;
    stopped|created) container start "$(container_name)" >/dev/null; printf 'Started existing isolated task VM: %s\n' "$(container_name)" ;;
    *) printf 'Unexpected task VM state: %s\n' "$(container_state)" >&2; return 1 ;;
  esac
}

status() {
  require_runtime
  local state inspected
  state="$(container_state)"
  if [[ "$state" == absent ]]; then
    python3 - "$(container_name)" "$bot" "$task" <<'PY'
import json,sys
name,bot,task=sys.argv[1:]
print(json.dumps({"name":name,"bot":bot,"task":task,"state":"absent","evidence":"no task VM exists"}))
PY
    return
  fi
  inspected="$(container inspect "$(container_name)")"
  printf '%s' "$inspected" | python3 -c '
import json,sys
record=json.load(sys.stdin)[0]
configuration=record.get("configuration", {})
mounts=configuration.get("mounts", [])
print(json.dumps({
  "name": record.get("id"), "bot": sys.argv[1], "task": sys.argv[2],
  "state": record.get("status", {}).get("state", "unknown"),
  "security": {"hostMounts": [m for m in mounts if m.get("type", {}).get("virtiofs")], "networks": configuration.get("networks", []), "publishedPorts": configuration.get("publishedPorts", []), "ssh": configuration.get("ssh"), "readOnlyRoot": configuration.get("readOnly"), "capDrop": configuration.get("capDrop", [])},
  "evidence": "inspection metadata only; task output and files are not captured automatically"
}))
' "$bot" "$task"
}

stop() {
  require_runtime
  case "$(container_state)" in
    running) container stop --time 5 "$(container_name)" >/dev/null; printf 'Stopped task VM. Inspection evidence remains until explicit teardown.\n' ;;
    stopped|created) printf 'Task VM is already stopped.\n' ;;
    absent) printf 'No task VM exists.\n' >&2; return 1 ;;
    *) printf 'Unexpected task VM state: %s\n' "$(container_state)" >&2; return 1 ;;
  esac
}

terminal() {
  require_runtime
  [[ "$(container_state)" == running ]] || { printf 'Task VM is not running.\n' >&2; return 1; }
  exec container exec --interactive --tty "$(container_name)" bash -l
}

teardown() {
  require_runtime
  [[ "$flag" == --evidence-handled ]] || { printf 'Refusing teardown without --evidence-handled.\n' >&2; return 2; }
  [[ "$(container_state)" != running ]] || { printf 'Stop the task VM and handle evidence before teardown.\n' >&2; return 1; }
  [[ "$(container_state)" != absent ]] || { printf 'No task VM exists.\n' >&2; return 1; }
  container delete "$(container_name)" >/dev/null
  printf 'Task VM torn down after explicit evidence-handled confirmation.\n'
}

smoke() {
  create
  container exec "$(container_name)" bash -lc 'test "$(id -un)" = opndrm; test -w /workspace; test -w /tmp; test -w /home/opndrm; echo task-vm-smoke-ok'
  stop
  status
}

case "$command_name" in
  create|start|status|terminal|stop|teardown|smoke) validate_name "$bot"; validate_name "$task"; "$command_name" ;;
  -h|--help|help|'') usage ;;
  *) usage >&2; exit 2 ;;
esac
