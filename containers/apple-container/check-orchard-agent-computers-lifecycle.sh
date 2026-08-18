#!/usr/bin/env bash
# Static contract check only. It does not invoke any lifecycle command.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BRIDGE="$SCRIPT_DIR/orchard-agent-computers-lifecycle.sh"

fail() { printf 'Orchard Agent Computers lifecycle check failed: %s\n' "$*" >&2; exit 1; }
require() { rg -F --quiet -- "$2" "$1" || fail "missing $2"; }
forbid() { ! rg -i -F --quiet -- "$2" "$1" || fail "forbidden $2"; }

bash -n "$BRIDGE"
require "$BRIDGE" 'visual-proof-runtime/visual-profile.sh'
require "$BRIDGE" 'inspect-visual-proof-session.sh'
require "$BRIDGE" 'start --confirm-start --token-file "$TOKEN_FILE"'
require "$BRIDGE" 'inspect-before-view'
require "$BRIDGE" 'teardown --evidence-handled'
require "$BRIDGE" 'openssl rand -hex 32'
require "$BRIDGE" 'chmod 0600 "$TOKEN_FILE"'
require "$BRIDGE" 'chmod 0700 "$SESSION_DIR"'
require "$BRIDGE" 'Refusing to start without exactly --confirm-start.'
require "$BRIDGE" 'does not expose the token or open a viewer'
forbid "$BRIDGE" 'container run'
forbid "$BRIDGE" 'container start'
forbid "$BRIDGE" 'container exec'
forbid "$BRIDGE" 'container shell'
forbid "$BRIDGE" 'open -a'
forbid "$BRIDGE" 'http://'
forbid "$BRIDGE" 'https://'
forbid "$BRIDGE" 'tcp'
forbid "$BRIDGE" 'record'
forbid "$BRIDGE" 'openadapt'
forbid "$BRIDGE" 'cleanshot'
forbid "$BRIDGE" 'clipboard'
forbid "$BRIDGE" 'terminal'
forbid "$BRIDGE" 'browser'
printf 'Orchard Agent Computers lifecycle static contract passed.\n'
