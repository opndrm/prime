#!/usr/bin/env bash
# Static acceptance checks for the intentionally inert Buzz Record contract.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)"
GUARD="$ROOT/containers/apple-container/buzz-record/buzz-record.sh"
CONTRACT="$ROOT/containers/apple-container/buzz-record/CONTRACT.md"
SKILL="$ROOT/skills/buzz-record/SKILL.md"

fail() { printf 'Buzz Record check failed: %s\n' "$*" >&2; exit 1; }
require() { rg -F --quiet -- "$2" "$1" || fail "missing $2 in ${1#$ROOT/}"; }
forbid() { ! rg -i -F --quiet -- "$2" "$1" || fail "forbidden $2 in ${1#$ROOT/}"; }

bash -n "$GUARD"
python3 -m json.tool < <("$GUARD" status) >/dev/null
"$GUARD" preflight --session-id visual-proof >/dev/null 2>&1 && fail 'preflight unexpectedly succeeded'
"$GUARD" start --session-id visual-proof --confirm-start-recording >/dev/null 2>&1 && fail 'start unexpectedly succeeded'
"$GUARD" stop --session-id visual-proof --confirm-stop-recording >/dev/null 2>&1 && fail 'stop unexpectedly succeeded'
require "$GUARD" 'hostCapture'
require "$GUARD" 'No validated visual-session adapter'
require "$CONTRACT" 'host Mac display'
require "$CONTRACT" 'OpenAdapt'
require "$SKILL" 'confirm-start-recording'
require "$SKILL" 'host Mac'
forbid "$GUARD" 'container run'
forbid "$GUARD" 'curl'
printf 'Buzz Record contract checks passed.\n'
