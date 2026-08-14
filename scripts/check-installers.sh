#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAC="$ROOT/scripts/install-macos.sh"
WINDOWS="$ROOT/scripts/install-windows.ps1"

fail() { printf 'installer check failed: %s\n' "$*" >&2; exit 1; }
require_text() { rg -F --quiet "$2" "$1" || fail "missing $2 in ${1#"$ROOT/"}"; }
forbid_text() { ! rg -F --quiet "$2" "$1" || fail "unexpected $2 in ${1#"$ROOT/"}"; }
require_once() {
  local count
  count="$(rg -F -c "$2" "$1" || true)"
  [[ "$count" == 1 ]] || fail "expected one $2 in ${1#"$ROOT/"}, found $count"
}

bash -n "$MAC"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -e SC2016 "$MAC" "$0"
  printf 'ShellCheck passed.\n'
else
  printf 'ShellCheck skipped: shellcheck is not available.\n'
fi
node --check "$ROOT/api/admin.js"
node --check "$ROOT/api/admin-login.js"
node - "$ROOT/api/admin.js" "$ROOT/site/guide/index.html" "$ROOT/site/es/guide/index.html" <<'NODE'
const fs = require('fs');
for (const file of process.argv.slice(2)) {
  const source = fs.readFileSync(file, 'utf8');
  const scripts = [...source.matchAll(/<script>([\s\S]*?)<\/script>/g)];
  if (!scripts.length) throw new Error(`No inline script found in ${file}`);
  for (const [, script] of scripts) new Function(script);
}
NODE

# Every lane remains valid, maps to the same private repository on both OSes,
# and public OPNDRM-APP has no GitHub authorization path.
for lane in ADAM FRNKLY.ONE OPNDRM-APP; do
  require_text "$MAC" "$lane"
  require_text "$WINDOWS" "'$lane'"
done
require_text "$MAC" "PRIVATE_REPOSITORY='opndrm/ADAM'"
require_text "$MAC" "PRIVATE_REPOSITORY='opndrm/Frnkly.one'"
require_text "$MAC" "repo='https://github.com/opndrm/Frnkly.one.git'"
require_text "$WINDOWS" "'opndrm/ADAM'"
require_text "$WINDOWS" "'opndrm/Frnkly.one'"
require_text "$WINDOWS" "'https://github.com/opndrm/Frnkly.one.git'"

# FRNKLY.ONE has one checkout focal point: clone, PRIME workspace, reserved
# inactive Gate, and Buzz context all use the selected checkout and issue plan.
require_text "$MAC" 'git clone "$repo" "$target"'
require_text "$MAC" 'workspace create --cwd "$target"'
require_text "$MAC" 'tab create --cwd "$target" --label "NO MISTAKES GATE" --no-focus'
require_text "$MAC" '"workspace_path": workspace_path'
require_text "$MAC" '"repository": repository or None'
require_text "$MAC" '"issue_tracker": issue_tracker'
require_text "$WINDOWS" 'git clone $repo $target'
require_text "$WINDOWS" 'workspace create --cwd $target'
require_text "$WINDOWS" "tab create --cwd \$target --label 'NO MISTAKES GATE' --no-focus"
require_text "$WINDOWS" 'workspace_path = $target'
require_text "$WINDOWS" 'repository = $PrivateRepository'
require_text "$WINDOWS" "issue_tracker = 'https://github.com/opndrm/prime/issues'"
forbid_text "$MAC" 'no-mistakes run'
forbid_text "$WINDOWS" 'no-mistakes run'

# Private lanes have exactly one GitHub CLI-owned flow, identify the account,
# preflight read access, and stop without cloning when read access is absent.
for script in "$MAC" "$WINDOWS"; do
  require_once "$script" "gh auth login --hostname github.com --git-protocol https --web"
  forbid_text "$script" "github.com/login/device"
  require_text "$script" "gh api --hostname github.com user --jq '.login'"
  require_text "$script" "normal collaborator"
  require_text "$script" "Stop here without cloning"
  require_text "$script" "GH_PROMPT_DISABLED"
  require_text "$script" "prime-agent package list"
  require_text "$script" "Open Dream Prime GitHub package installed successfully."
  require_text "$script" "Workspace already exists at"
done
require_text "$MAC" '[[ "$LANE" == '\''OPNDRM-APP'\'' ]] && return'
require_text "$WINDOWS" "if (\$Lane -ne 'OPNDRM-APP')"
require_text "$MAC" '"repos/$PRIVATE_REPOSITORY"'
require_text "$WINDOWS" '"repos/$PrivateRepository"'

# Published entrypoints delegate to the checked scripts, and the Team page
# retains the selected lane/platform in its guide link.
require_text "$ROOT/site/install-macos.sh" 'exec "$source_dir/scripts/install-macos.sh" "$lane"'
require_text "$ROOT/site/install-windows.ps1" "scripts\\install-windows.ps1"
require_text "$ROOT/api/admin.js" 'Selected app:'
require_text "$ROOT/api/admin.js" 'FRNKLY.ONE requires that personal account'
require_text "$ROOT/api/admin.js" 'FRNKLY.ONE is the Rust rebuild at opndrm/Frnkly.one'
require_text "$ROOT/api/admin.js" "platform='+platform+'&lane='+encodeURIComponent(lane)"
for guide in "$ROOT/site/guide/index.html" "$ROOT/site/es/guide/index.html"; do
  require_text "$guide" "requestedLane"
  require_text "$guide" "FRNKLY.ONE"
  require_text "$guide" "opndrm/Frnkly.one"
done
for onboarding in "$ROOT/skills/opndrm-prime/references/onboarding-en.md" "$ROOT/skills/opndrm-prime/references/onboarding-es.md" "$ROOT/docs/GETTING-STARTED.en.md" "$ROOT/docs/EMPEZAR.es.md"; do
  require_text "$onboarding" "FRNKLY.ONE"
  require_text "$onboarding" "OPNDRM APP"
  require_text "$onboarding" "https://github.com/opndrm/Frnkly.one.git"
done
require_text "$ROOT/README.md" "https://github.com/opndrm/Frnkly.one.git"
require_text "$ROOT/skills/opndrm-prime/SKILL.md" "https://github.com/opndrm/Frnkly.one.git"

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command '$errors = $null; [System.Management.Automation.Language.Parser]::ParseFile($args[0], [ref]$null, [ref]$errors) | Out-Null; if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }' "$WINDOWS"
  printf 'PowerShell parser check passed.\n'
else
  printf 'PowerShell parser check skipped: pwsh is not available on this Mac.\n'
fi

printf 'Installer static checks passed.\n'
