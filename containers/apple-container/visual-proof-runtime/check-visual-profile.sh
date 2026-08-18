#!/usr/bin/env bash
# Static verification only. It never invokes visual-profile.sh lifecycle commands.
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
LAUNCHER="$SCRIPT_DIR/visual-profile.sh"
SESSION_CHECKER="$SCRIPT_DIR/inspect-visual-proof-session.sh"

fail() { printf 'Visual profile contract check failed: %s\n' "$*" >&2; exit 1; }
require() { rg -F --quiet -- "$2" "$1" || fail "missing $2"; }
forbid() { ! rg -i -F --quiet -- "$2" "$1" || fail "forbidden $2"; }

bash -n "$LAUNCHER"
bash -n "$SESSION_CHECKER"
require "$LAUNCHER" 'opndrm-prime/buzz-container-visual-proof:0.2.6'
require "$LAUNCHER" '--cap-drop ALL'
require "$LAUNCHER" '--read-only'
require "$LAUNCHER" '--tmpfs /tmp --tmpfs /workspace --tmpfs /home/opndrm --tmpfs /run/buzz-container'
require "$LAUNCHER" '--network none --no-dns'
require "$LAUNCHER" '--publish-socket "$HOST_SOCKET:$CONTAINER_SOCKET"'
require "$LAUNCHER" 'BUZZ_CONTAINER_VIEW_TOKEN=$token'
require "$LAUNCHER" '--confirm-start'
require "$LAUNCHER" '--token-file'
require "$LAUNCHER" 'mode 0600'
require "$LAUNCHER" '--evidence-handled'
require "$LAUNCHER" 'rm -f -- "$HOST_SOCKET"'
forbid "$LAUNCHER" '--mount'
forbid "$LAUNCHER" '--publish '
forbid "$LAUNCHER" '--ssh'
forbid "$LAUNCHER" 'task-vm.sh'
forbid "$LAUNCHER" 'openadapt'
forbid "$LAUNCHER" 'cleanshot'
forbid "$LAUNCHER" 'wezterm'
forbid "$LAUNCHER" 'herdr'
forbid "$LAUNCHER" 'jcode'
forbid "$LAUNCHER" 'prime-agent'
require "$SESSION_CHECKER" 'container inspect "$CONTAINER_NAME"'
require "$SESSION_CHECKER" 'Exactly one Unix socket is required'
require "$SESSION_CHECKER" 'root filesystem is not read-only'
require "$SESSION_CHECKER" 'all Linux capabilities must be dropped'
require "$SESSION_CHECKER" 'writable paths must be exactly the approved tmpfs targets'
require "$SESSION_CHECKER" 'host mounts are present'
require "$SESSION_CHECKER" 'network attachments are present'
require "$SESSION_CHECKER" 'published TCP or UDP ports are present'
require "$SESSION_CHECKER" 'SSH configuration is present'
forbid "$SESSION_CHECKER" 'container run'
forbid "$SESSION_CHECKER" 'container start'
forbid "$SESSION_CHECKER" 'container stop'
forbid "$SESSION_CHECKER" 'container delete'
forbid "$SESSION_CHECKER" 'BUZZ_CONTAINER_VIEW_TOKEN'
printf 'Visual profile launcher static contract passed.\n'
