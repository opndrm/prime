#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'HERDR lifecycle check failed: %s\n' "$*" >&2; exit 1; }
command -v herdr >/dev/null 2>&1 || fail 'HERDR is not available on PATH.'

test_root="$(mktemp -d)"
session="opndrm-prime-bootstrap-test-$$-${RANDOM}"
workspace="$test_root/FRNKLY.ONE"
server_log="$test_root/herdr-server.log"
# shellcheck disable=SC2329 # Invoked by the EXIT trap below.
cleanup() {
  herdr session stop "$session" --json >/dev/null 2>&1 || true
  herdr session delete "$session" --json >/dev/null 2>&1 || true
  rm -rf -- "$test_root"
}
trap cleanup EXIT
mkdir -p "$workspace"

# In HERDR 0.7.4, this query exits successfully before a server exists. The
# installer must inspect the status marker instead of treating that exit code
# as proof that its named socket is usable.
initial_status="$(herdr --session "$session" status server 2>&1 || true)"
[[ "$initial_status" == *'status: not running'* ]] || fail 'Fresh named session did not report status: not running.'
herdr --session "$session" status server >/dev/null 2>&1 || fail 'HERDR status query did not complete.'
if printf '%s\n' "$initial_status" | grep -qx 'status: running'; then
  fail 'Fresh named session incorrectly reported a running server.'
fi

nohup herdr --session "$session" server >"$server_log" 2>&1 </dev/null &
server_pid=$!
for _ in {1..30}; do
  if ! kill -0 "$server_pid" 2>/dev/null; then
    sed -n '1,160p' "$server_log" >&2 || true
    fail 'Detached named HERDR server exited before its socket became available.'
  fi
  if herdr --session "$session" status server 2>&1 | grep -qx 'status: running'; then
    herdr --session "$session" workspace create --cwd "$workspace" --label 'PRIME TEST' --focus
    herdr --session "$session" tab create --cwd "$workspace" --label 'NO MISTAKES GATE — RESERVED (INACTIVE)' --no-focus
    printf 'HERDR detached named-session bootstrap passed.\n'
    exit 0
  fi
  sleep 1
done

sed -n '1,160p' "$server_log" >&2 || true
fail 'Detached named HERDR server never produced a running socket.'
