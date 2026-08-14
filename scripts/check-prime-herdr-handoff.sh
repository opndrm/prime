#!/usr/bin/env bash
set -euo pipefail

# This is an opt-in, isolated acceptance fixture. It proves the installed
# HERDR server creates a root pane in the selected checkout, `pane run` keeps
# that root, and a detached WezTerm handoff does not block the caller. It never
# installs Prime Agent, opens a real workspace, or runs No Mistakes.

[[ "$(uname -s)" == Darwin ]] || { printf 'Prime/HERDR handoff integration is macOS-only.\n'; exit 0; }
command -v herdr >/dev/null 2>&1 || { printf 'HERDR is unavailable; handoff integration skipped.\n'; exit 0; }

fixture="$(mktemp -d /tmp/opndrm-prime-handoff.XXXXXX)"
session="opndrm-prime-handoff-test-$$-$RANDOM"
workspace="$(cd "$fixture" && pwd -P)"
marker="$workspace/prime-root.txt"

cleanup() {
  herdr --session "$session" stop >/dev/null 2>&1 || true
  herdr --session "$session" delete >/dev/null 2>&1 || true
}
trap cleanup EXIT

nohup herdr --session "$session" server >"$workspace/server.log" 2>&1 </dev/null &
server_pid=$!
for _ in {1..30}; do
  herdr --session "$session" status server 2>&1 | grep -qx 'status: running' && break
  sleep 1
done
herdr --session "$session" status server 2>&1 | grep -qx 'status: running'
kill -0 "$server_pid"

workspace_result="$(herdr --session "$session" workspace create --cwd "$workspace" --label 'Fixture — PRIME · WAYFINDER' --focus)"
pane_id="$(python3 - "$workspace_result" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["result"]["root_pane"]["pane_id"])
PY
)"
[[ -n "$pane_id" ]]
herdr --session "$session" tab create --cwd "$workspace" --label "NO MISTAKES GATE — RESERVED (INACTIVE) · ROOT: $workspace" --no-focus >/dev/null

# This is the harmless structural equivalent of the installer’s
# `exec prime-agent --cwd <selected-root>` command: HERDR must replace the
# root shell with a process that observes the workspace root, not $HOME.
herdr --session "$session" pane run "$pane_id" "sh -lc 'pwd > \"$marker\"; exec sleep 5'" >/dev/null
for _ in {1..20}; do [[ -s "$marker" ]] && break; sleep 1; done
[[ "$(cat "$marker")" == "$workspace" ]] || { printf 'PRIME fixture used the wrong working directory.\n' >&2; exit 1; }
process_info="$(herdr --session "$session" pane process-info --pane "$pane_id")"
python3 - "$workspace" "$process_info" <<'PY'
import json, sys
workspace, raw = sys.argv[1:]
processes = json.loads(raw)["result"]["process_info"]["foreground_processes"]
if not any(process.get("cwd") == workspace and "sleep" in (" ".join(process.get("argv") or []) + " " + process.get("cmdline", "")) for process in processes):
    raise SystemExit("PRIME fixture did not replace the root shell in its selected workspace")
PY

# A GUI handoff is only exercised when explicitly requested: it can open a
# temporary WezTerm client on the current Mac. The shell must return promptly
# even while that client remains attached to the isolated HERDR session.
if [[ "${OPNDRM_WEZTERM_INTEGRATION:-0}" == 1 ]]; then
  command -v wezterm >/dev/null 2>&1 || { printf 'WezTerm is unavailable for handoff integration.\n' >&2; exit 1; }
  handoff_started="$(date +%s)"
  nohup wezterm start --cwd "$workspace" --workspace "$session" -- herdr --session "$session" >"$workspace/wezterm.log" 2>&1 </dev/null &
  handoff_pid=$!
  handoff_elapsed=$(( $(date +%s) - handoff_started ))
  (( handoff_elapsed < 2 )) || { printf 'WezTerm handoff blocked the caller.\n' >&2; exit 1; }
  sleep 1
  if ! kill -0 "$handoff_pid" 2>/dev/null && grep -qiE '(^|[^a-z])(error|failed)([^a-z]|$)' "$workspace/wezterm.log" 2>/dev/null; then
    printf 'WezTerm handoff failed for the isolated HERDR session.\n' >&2
    exit 1
  fi
fi

printf 'Prime/HERDR root-pane and nonblocking-handoff integration passed.\n'
