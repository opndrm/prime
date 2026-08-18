#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAC="$ROOT/scripts/install-macos.sh"
fail(){ printf 'check failed: %s\n' "$*" >&2; exit 1; }
require(){ grep -F -q -- "$2" "$1" || fail "missing $2 in ${1#$ROOT/}"; }
forbid(){ ! grep -i -F -q -- "$2" "$1" || fail "forbidden $2 in ${1#$ROOT/}"; }
bash -n "$MAC" "$ROOT/site/install-macos.sh"
[[ -f "$ROOT/site/jcode-prime-workflow.md" ]] || fail "missing JCode workflow download"
[[ -f "$ROOT/site/herdr-wezterm-layout.md" ]] || fail "missing HERDR layout download"
[[ -f "$ROOT/config/herdr-layout.json" ]] || fail "missing HERDR layout manifest"
python3 -m json.tool "$ROOT/config/herdr-layout.json" >/dev/null
require "$MAC" 'prime-agent --cwd'
require "$MAC" 'open -a Buzz'
require "$MAC" 'Usage: install-macos.sh OPNDRM-APP'
require "$MAC" 'ROOT="${OPNDRM_ROOT:-$HOME/Desktop/opndrm}"'
require "$MAC" 'SESSION="opndrm"'
require "$MAC" 'configure_ollama_for_prime'
require "$MAC" 'install_prime_buzz_bridge'
require "$MAC" 'prime-agent package install git:github.com/opndrm/prime'
require "$MAC" 'ensure_exact_opndrm_layout'
require "$MAC" "create_workspace 'OFFLINE'"
require "$MAC" "create_workspace 'OPNDRM'"
require "$MAC" "create_workspace 'OPNDRM JC'"
require "$MAC" "create_workspace 'OPNDRM NO-MISTAKES'"
require "$MAC" 'https://jcode.sh/install'
require "$MAC" 'setup_handy'
require "$MAC" 'superwhisper/ggml-large-v3-turbo.bin'
require "$MAC" 'brew install --cask wezterm'
forbid "$MAC" 'ADAM'
forbid "$MAC" 'FRNKLY.ONE'
forbid "$MAC" 'GENERAL RESEARCH'
forbid "$MAC" 'qwen'
forbid "$MAC" 'omlx'
forbid "$MAC" 'apiKey'
forbid "$MAC" 'no-mistakes init'
forbid "$MAC" 'no-mistakes attach'
forbid "$MAC" 'no-mistakes axi'
python3 - "$ROOT/config/herdr-layout.json" <<'PY'
import json, sys
layout = json.load(open(sys.argv[1]))
labels = [item["label"] for item in layout["workspaces"]]
expected = ["OFFLINE", "OPNDRM", "OPNDRM JC", "OPNDRM NO-MISTAKES"]
if labels != expected:
    raise SystemExit(f"check failed: HERDR labels/order {labels!r} != {expected!r}")
PY
cmp -s "$ROOT/docs/HERDR-WEZTERM-LAYOUT.md" "$ROOT/site/herdr-wezterm-layout.md" || fail 'HERDR layout downloads are out of sync'
for path in "$ROOT"/README.md "$ROOT"/skills/opndrm-prime/SKILL.md "$ROOT"/docs/GETTING-STARTED.en.md; do
  forbid "$path" 'QM'
  forbid "$path" 'oMLX'
  forbid "$path" 'Qwen'
done
node --check <(sed -n '/<script>/,/<\/script>/p' "$ROOT/site/index.html" | sed '1d;$d')
bash "$ROOT/scripts/check-agent-computer.sh"
bash "$ROOT/containers/apple-container/check-orchard-agent-computers-lifecycle.sh"
bash "$ROOT/containers/apple-container/check-orchard-agent-computers-visual-proof.sh"
bash "$ROOT/containers/apple-container/visual-vm/check-visual-linux-vm-contract.sh"
bash -n "$ROOT/evaluations/openadapt-desktop/managed-vision.sh"
require "$ROOT/evaluations/openadapt-desktop/managed-vision.sh" 'OPENADAPT_CONFIG_TOML'
require "$ROOT/evaluations/openadapt-desktop/managed-vision.sh" 'OPENADAPT_DATA_DIR'
require "$ROOT/evaluations/openadapt-desktop/offline-pilot.toml" 'storage_mode = "air-gapped"'
require "$ROOT/evaluations/openadapt-desktop/offline-pilot.toml" 'runner_enabled = false'
printf 'Open Dream Prime static checks passed.\n'
