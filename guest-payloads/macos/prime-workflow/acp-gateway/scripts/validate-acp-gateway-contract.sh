#!/bin/bash
# Read-only validation of this inert contract bundle. It never runs Prime or opens a connection.
set -euo pipefail
IFS=$'\n\t'

usage() {
  printf '%s\n' 'Usage: validate-acp-gateway-contract.sh --validate-static' >&2
  exit 64
}
[[ $# -eq 1 && "$1" == '--validate-static' ]] || usage
SELF="${BASH_SOURCE[0]}"
[[ -f "$SELF" && ! -L "$SELF" ]] || { printf '%s\n' 'refused: validator must be a regular file' >&2; exit 1; }
SCRIPT_DIR="$(cd -P "$(/usr/bin/dirname "$SELF")" && /bin/pwd -P)"
ROOT="$(cd -P "$SCRIPT_DIR/.." && /bin/pwd -P)"

for relative in README.md CONTRACT.md payload/acp-session-lifecycle.json payload/restricted-prompt.json payload/owner-consent.tsv.template payload/prime-acp-binary-checksum-receipt.tsv.template; do
  item="$ROOT/$relative"
  [[ -f "$item" && ! -L "$item" ]] || { printf 'refused: missing or symlinked required file: %s\n' "$relative" >&2; exit 1; }
done

PYTHON="$(command -v python3 || true)"
[[ -n "$PYTHON" ]] || { printf '%s\n' 'refused: python3 is required only to parse the static JSON contract' >&2; exit 1; }
"$PYTHON" - "$ROOT/payload/acp-session-lifecycle.json" "$ROOT/payload/restricted-prompt.json" <<'PY'
import json, sys
lifecycle = json.load(open(sys.argv[1], encoding='utf-8'))
prompt = json.load(open(sys.argv[2], encoding='utf-8'))
assert lifecycle['contract'] == 'opndrm-prime.acp-gateway.guest-local.v1'
assert lifecycle['transport'] == {'kind': 'stdio-ndjson-only', 'network': 'forbidden', 'listener': 'forbidden'}
work = '/Users/<guest-user>/.local/share/opndrm-prime/acp-gateway/work'
assert lifecycle['fixedGuestWorkDirectory'] == work
assert lifecycle['inboundFrameLimit'] == {'maximumBytesPerFrame': 32768, 'maximumFrames': 3}
assert lifecycle['outboundFrameLimit'] == {'maximumBytesPerFrame': 32768, 'maximumFrames': 16}
assert lifecycle['lifecycle'] == [
 {'ordinal': 1, 'jsonrpc': '2.0', 'id': 'init-1', 'method': 'initialize'},
 {'ordinal': 2, 'jsonrpc': '2.0', 'id': 'new-1', 'method': 'session/new', 'cwd': work, 'mcpServers': []},
 {'ordinal': 3, 'jsonrpc': '2.0', 'id': 'prompt-1', 'method': 'session/prompt', 'sessionBinding': 'one-returned-session-id', 'paramsFile': 'restricted-prompt.json'},
]
assert lifecycle['afterPromptResult'] == 'close-stdio-and-terminate'
assert prompt == {'content': [{'type': 'text', 'text': 'Acknowledge exactly: guest-local ACP contract received; no action requested.'}]}
assert set(('all-other-methods', 'notifications', 'batches', 'reconnect', 'retry', 'session-reuse', 'tool-calls', 'mcp', 'generic-command-execution', 'shell', 'file-transfer', 'environment-override')).issubset(lifecycle['forbidden'])
PY
printf '%s\n' 'VALIDATED: inert ACP gateway contract bundle is structurally fixed; no software was run or network used.'
