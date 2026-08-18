#!/usr/bin/env bash
# Static contract check only.  It never starts a VM or a macOS app.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROOF="$SCRIPT_DIR/orchard-agent-computers-visual-proof.sh"

fail() { printf 'Orchard visual-proof handoff check failed: %s\n' "$*" >&2; exit 1; }
require() { rg -F --quiet -- "$2" "$1" || fail "missing $2"; }
forbid() { ! rg -i -F --quiet -- "$2" "$1" || fail "forbidden $2"; }

bash -n "$PROOF"
require "$PROOF" 'orchard-agent-computers-lifecycle.sh'
require "$PROOF" 'inspect-before-view'
require "$PROOF" 'chmod 0600 "$HOST_SOCKET"'
require "$PROOF" 'ORCHARD_AGENT_COMPUTER_VIEW_SOCKET'
require "$PROOF" 'ORCHARD_AGENT_COMPUTER_VIEW_TOKEN'
require "$PROOF" 'ORCHARD_AGENT_COMPUTER_VIEW_RECEIPT'
require "$PROOF" 'rendered-nonblank-frame'
require "$PROOF" 'watch-only-unix-socket'
require "$PROOF" 'finish --evidence-handled'
require "$PROOF" 'does not include Agent Computers visual proof support'
forbid "$PROOF" 'container run'
forbid "$PROOF" 'container exec'
forbid "$PROOF" 'container shell'
forbid "$PROOF" 'open -a'
forbid "$PROOF" 'http://'
forbid "$PROOF" 'https://'
forbid "$PROOF" 'record'
forbid "$PROOF" 'openadapt'
forbid "$PROOF" 'cleanshot'
forbid "$PROOF" 'clipboard'
forbid "$PROOF" 'terminal input'
printf 'Orchard visual-proof handoff static contract passed.\n'
