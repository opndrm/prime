#!/usr/bin/env bash
# Verify the visual proof image without starting its desktop entrypoint.
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
manifest="$script_dir/buzz-visual-container-image-manifest.json"
image="$(python3 - "$manifest" <<'PY'
import json, sys
i = json.load(open(sys.argv[1], encoding='utf-8'))['image']
print(f"{i['name']}:{i['tag']}")
PY
)"

container system status --format json >/dev/null
container image inspect "$image" >/dev/null
python3 - "$manifest" <<'PY'
import json, sys
m = json.load(open(sys.argv[1], encoding='utf-8'))
tools = {x['name']: x for x in m['tools']}
if tools['WezTerm']['status'] != 'installed-visual-proof-only': raise SystemExit('WezTerm visual-only contract missing')
if tools['HERDR']['status'] != 'inherited-isolated-session': raise SystemExit('HERDR isolated-session proof contract missing')
r = m['runtime']
for key, expected in {'network': 'disabled-at-proof-runtime', 'dns': 'disabled-at-proof-runtime', 'host_mounts': 'disabled-at-proof-runtime', 'tcp_ports': 'disabled-at-proof-runtime', 'ssh': 'disabled-at-proof-runtime', 'input': 'unavailable', 'recording': 'unavailable'}.items():
    if r.get(key) != expected: raise SystemExit(f'{key} contract missing')
PY

container run --rm \
  --name opndrm-prime-buzz-visual-proof-smoke \
  --cpus 1 --memory 768M --cap-drop ALL --read-only \
  --tmpfs /tmp --tmpfs /workspace --tmpfs /home/opndrm --tmpfs /run/buzz-container \
  --network none --no-dns \
  --entrypoint bash \
  "$image" -euc '
    test "$(id -un)" = opndrm
    test -w /tmp && test -w /workspace && test -w /home/opndrm && test -w /run/buzz-container
    wezterm --version
    herdr --version
    herdr --help | grep -F -- "--session <name>" >/dev/null
    test -f /usr/local/share/buzz-container/visual-manifest.json
    test -f /usr/local/share/buzz-container/licenses/wezterm-LICENSE.md
    test -f /usr/local/share/buzz-container/licenses/herdr-LICENSE
    echo buzz-visual-proof-image-smoke-ok
  '

printf 'Buzz visual proof image verification passed. No desktop entrypoint, task VM, network, repository, credentials, recording, or host app was started.\n'
