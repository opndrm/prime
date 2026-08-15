#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAC="$ROOT/scripts/install-macos.sh"
fail(){ printf 'check failed: %s\n' "$*" >&2; exit 1; }
require(){ rg -F --quiet -- "$2" "$1" || fail "missing $2 in ${1#$ROOT/}"; }
forbid(){ ! rg -i -F --quiet -- "$2" "$1" || fail "forbidden $2 in ${1#$ROOT/}"; }
bash -n "$MAC" "$ROOT/site/install-macos.sh"
[[ -f "$ROOT/site/jcode-prime-workflow.md" ]] || fail "missing JCode workflow download"
[[ -f "$ROOT/site/herdr-wezterm-layout.md" ]] || fail "missing HERDR layout download"
[[ -f "$ROOT/config/herdr-layout.json" ]] || fail "missing HERDR layout manifest"
python3 -m json.tool "$ROOT/config/herdr-layout.json" >/dev/null
require "$MAC" 'prime-agent --cwd'
require "$MAC" 'open -a Buzz'
require "$MAC" 'Workspace already exists at'
require "$MAC" 'OPNDRM-APP|ADAM|FRNKLY.ONE'
require "$MAC" 'configure_ollama_for_prime'
require "$MAC" 'install_prime_buzz_bridge'
require "$MAC" 'prime-agent package install git:github.com/opndrm/prime'
require "$MAC" 'start_jcode'
require "$MAC" 'ensure_general_research'
require "$MAC" 'JCODE — GENERAL RESEARCH'
require "$MAC" 'https://jcode.sh/install'
require "$MAC" 'setup_handy'
require "$MAC" 'superwhisper/ggml-large-v3-turbo.bin'
require "$MAC" 'brew install --cask wezterm ollama handy'
forbid "$MAC" 'qwen'
forbid "$MAC" 'omlx'
forbid "$MAC" 'apiKey'
forbid "$MAC" 'no-mistakes'
for path in "$ROOT"/README.md "$ROOT"/skills/opndrm-prime/SKILL.md "$ROOT"/docs/GETTING-STARTED.en.md; do
  forbid "$path" 'QM'
  forbid "$path" 'oMLX'
  forbid "$path" 'Qwen'
  forbid "$path" 'No Mistakes'
done
node --check <(sed -n '/<script>/,/<\/script>/p' "$ROOT/site/index.html" | sed '1d;$d')
printf 'Open Dream Prime static checks passed.\n'
