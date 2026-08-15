#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAC="$ROOT/scripts/install-macos.sh"
WIN="$ROOT/scripts/install-windows.ps1"
fail(){ printf 'check failed: %s\n' "$*" >&2; exit 1; }
require(){ rg -F --quiet -- "$2" "$1" || fail "missing $2 in ${1#$ROOT/}"; }
forbid(){ ! rg -i -F --quiet -- "$2" "$1" || fail "forbidden $2 in ${1#$ROOT/}"; }
bash -n "$MAC" "$ROOT/site/install-macos.sh"
require "$MAC" 'prime-agent --cwd'
require "$MAC" 'open -a Buzz'
require "$MAC" 'Workspace already exists at'
require "$MAC" 'OPNDRM-APP|ADAM|FRNKLY.ONE'
forbid "$MAC" 'ollama'
forbid "$MAC" 'qwen'
forbid "$MAC" 'omlx'
forbid "$MAC" 'apiKey'
forbid "$MAC" 'no-mistakes'
forbid "$ROOT/site/index.html" '/admin'
forbid "$ROOT/site/es/index.html" '/admin'
forbid "$ROOT/vercel.json" 'rewrites'
for path in "$ROOT"/README.md "$ROOT"/site/index.html "$ROOT"/site/es/index.html "$ROOT"/skills/opndrm-prime/SKILL.md "$ROOT"/docs/GETTING-STARTED.en.md "$ROOT"/docs/EMPEZAR.es.md; do
  forbid "$path" 'QM'
  forbid "$path" 'oMLX'
  forbid "$path" 'Qwen'
  forbid "$path" 'No Mistakes'
done
node --check <(sed -n '/<script>/,/<\/script>/p' "$ROOT/site/index.html" | sed '1d;$d')
node --check <(sed -n '/<script>/,/<\/script>/p' "$ROOT/site/es/index.html" | sed '1d;$d')
printf 'Open Dream Prime static checks passed.\n'
