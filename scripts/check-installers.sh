#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAC="$ROOT/scripts/install-macos.sh"
WINDOWS="$ROOT/scripts/install-windows.ps1"

fail() { printf 'installer check failed: %s\n' "$*" >&2; exit 1; }
require_text() { rg -F --quiet -- "$2" "$1" || fail "missing $2 in ${1#"$ROOT/"}"; }
forbid_text() { ! rg -F --quiet -- "$2" "$1" || fail "unexpected $2 in ${1#"$ROOT/"}"; }
require_once() {
  local count
  count="$(rg -F -c -- "$2" "$1" || true)"
  [[ "$count" == 1 ]] || fail "expected one $2 in ${1#"$ROOT/"}, found $count"
}
require_before() {
  local first_line second_line
  first_line="$(rg -n -F -m 1 -- "$2" "$1" | cut -d: -f1)"
  second_line="$(rg -n -F -m 1 -- "$3" "$1" | cut -d: -f1)"
  [[ -n "$first_line" && -n "$second_line" && "$first_line" -lt "$second_line" ]] || fail "expected $2 before $3 in ${1#"$ROOT/"}"
}

bash -n "$MAC"
bash -n "$ROOT/scripts/check-herdr-bootstrap.sh"
bash -n "$ROOT/scripts/check-prime-herdr-handoff.sh"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -e SC2016 "$MAC" "$ROOT/scripts/check-herdr-bootstrap.sh" "$ROOT/scripts/check-prime-herdr-handoff.sh" "$0"
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
require_text "$MAC" "issue_tracker_url='https://github.com/opndrm/ADAM/issues'"
require_text "$MAC" "issue_tracker_url='https://github.com/opndrm/Frnkly.one/issues'"
require_text "$MAC" "issue_tracker_url='https://github.com/opndrm/prime/issues'"
require_text "$MAC" "OPNDRM-APP) PRIVATE_REPOSITORY=''; repository_name='opndrm/prime'; repo=''; issue_tracker_url='https://github.com/opndrm/prime/issues'; target=\"\$HOME/Desktop/OPNDRM APP\" ;;"
require_text "$WINDOWS" "'opndrm/ADAM'"
require_text "$WINDOWS" "'opndrm/Frnkly.one'"
require_text "$WINDOWS" "'https://github.com/opndrm/Frnkly.one.git'"
require_text "$WINDOWS" "\$IssueTrackerUrl = 'https://github.com/opndrm/ADAM/issues'"
require_text "$WINDOWS" "\$IssueTrackerUrl = 'https://github.com/opndrm/Frnkly.one/issues'"
require_text "$WINDOWS" "\$IssueTrackerUrl = 'https://github.com/opndrm/prime/issues'"
require_text "$WINDOWS" "\$target = Join-Path ([Environment]::GetFolderPath('Desktop')) 'OPNDRM APP'"

# FRNKLY.ONE has one checkout focal point: clone, PRIME workspace, reserved
# inactive Gate, and Buzz context all use the selected checkout and issue plan.
require_text "$MAC" 'git clone "$repo" "$target"'
require_text "$MAC" 'workspace create --cwd "$target"'
require_text "$MAC" 'tab create --cwd "$target" --label "NO MISTAKES GATE — RESERVED (INACTIVE) · ROOT: $target" --no-focus'
require_text "$MAC" '"workspace_path": workspace_path'
require_text "$MAC" '"repository": repository or None'
require_text "$MAC" '"issue_tracker": issue_tracker'
require_text "$MAC" 'wayfinder-onboarding.json'
require_text "$MAC" 'Use only this repository'\''s existing GitHub Issues/Wayfinder workflow.'
require_text "$WINDOWS" 'git clone $repo $target'
require_text "$WINDOWS" 'workspace create --cwd $target'
require_text "$WINDOWS" 'tab create --cwd $target --label "NO MISTAKES GATE — RESERVED (INACTIVE) · ROOT: $target" --no-focus'
require_text "$WINDOWS" 'workspace_path = $target'
require_text "$WINDOWS" 'repository = $RepositoryName'
require_text "$WINDOWS" 'issue_tracker = $IssueTrackerUrl'
require_text "$WINDOWS" 'wayfinder-onboarding.json'
require_text "$WINDOWS" "Use only this repository's existing GitHub Issues/Wayfinder workflow."
forbid_text "$MAC" 'no-mistakes run'
forbid_text "$WINDOWS" 'no-mistakes run'

# HERDR workspace and tab commands require a live named-session socket. Each
# selected root therefore gets its own server after that root exists, and a
# WezTerm client attaches before a success message can be printed.
require_text "$MAC" 'herdr --session "$1" status server'
require_text "$MAC" "grep -qx 'status: running'"
require_text "$MAC" 'nohup herdr --session "$session_name" server >"$herdr_log" 2>&1 </dev/null &'
require_text "$MAC" 'ensure_herdr_session "$session_name"'
require_text "$MAC" 'if herdr_session_running "$session_name"; then'
forbid_text "$MAC" 'status server >/dev/null 2>&1; then'
require_text "$MAC" "session_name=\"opndrm-\$(printf '%s' \"\$LANE\" | tr '[:upper:].' '[:lower:]-')\""
require_text "$MAC" 'nohup wezterm start --cwd "$workspace_path" --workspace "$session_name" -- herdr --session "$session_name"'
require_text "$MAC" 'this installer will now finish without waiting for that window to close.'
require_text "$MAC" 'pane run "$pane_id" "$prime_command"'
require_text "$MAC" 'exec prime-agent --cwd'
require_text "$MAC" 'pane process-info --pane "$pane_id"'
require_text "$MAC" 'Prime Agent is running in the selected %s workspace root.'
require_text "$MAC" 'HERDR could not start or attach the $session_name session.'
require_text "$MAC" 'Setup is not complete and no Ready message was shown.'
require_text "$MAC" 'Ready: PRIME is running in the %s HERDR workspace rooted at %s.'
require_before "$MAC" 'mkdir -p "$target"' 'ensure_herdr_session "$session_name"'
require_before "$MAC" 'git clone "$repo" "$target"' 'ensure_herdr_session "$session_name"'
require_before "$MAC" 'ensure_herdr_session "$session_name"' 'workspace create --cwd "$target"'
require_before "$MAC" 'workspace create --cwd "$target"' 'tab create --cwd "$target"'
require_before "$MAC" 'tab create --cwd "$target"' 'launch_prime_agent "$session_name" "$prime_pane_id" "$target"'
require_before "$MAC" 'launch_prime_agent "$session_name" "$prime_pane_id" "$target"' 'launch_herdr_workspace "$session_name" "$target"'
require_before "$MAC" 'launch_herdr_workspace "$session_name" "$target"' 'launch_buzz_onboarding "$buzz_state_dir/${session_name}-buzz-onboarding.json"'
require_before "$MAC" 'launch_buzz_onboarding "$buzz_state_dir/${session_name}-buzz-onboarding.json"' 'prepare_wayfinder_onboarding "$wayfinder_state_file"'
require_before "$MAC" 'prepare_wayfinder_onboarding "$wayfinder_state_file"' 'Ready: PRIME is running'
require_text "$MAC" 'open -a Buzz'
forbid_text "$MAC" 'open -gja Buzz'
require_text "$MAC" 'open "$issue_tracker_url"'
require_text "$MAC" 'No issue was created or changed.'

require_text "$WINDOWS" 'herdr --session $SessionName status server'
require_text "$WINDOWS" "return \$serverStatus -match '(?m)^status:\\s*running\\s*\$'"
require_text "$WINDOWS" "Start-Process -FilePath \$herdrCommand.Source -ArgumentList @('--session', \$SessionName, 'server')"
require_text "$WINDOWS" 'Ensure-HerdrSession -SessionName $session -WorkspacePath $target'
require_text "$WINDOWS" 'Test-HerdrSessionRunning -SessionName $SessionName'
require_text "$WINDOWS" "\$session = \"opndrm-\$(\$Lane.ToLower().Replace('.', '-'))\""
require_text "$WINDOWS" 'Start-Process -FilePath $weztermCommand.Source -ArgumentList'
require_text "$WINDOWS" '-PassThru'
require_text "$WINDOWS" 'this installer will now finish without waiting for that window to close.'
require_text "$WINDOWS" 'herdr --session $SessionName pane run $PaneId $primeCommand'
require_text "$WINDOWS" 'prime-agent --cwd'
require_text "$WINDOWS" 'pane process-info --pane $PaneId'
require_text "$WINDOWS" 'Prime Agent is running in the selected $Lane workspace root.'
require_text "$WINDOWS" 'HERDR could not start or attach the $SessionName session.'
require_text "$WINDOWS" 'Setup is not complete and no Ready message was shown.'
require_text "$WINDOWS" 'Ready: PRIME is running in the $session HERDR workspace rooted at $target.'
require_before "$WINDOWS" 'New-Item -ItemType Directory -Path $target | Out-Null' 'Ensure-HerdrSession -SessionName $session -WorkspacePath $target'
require_before "$WINDOWS" 'git clone $repo $target' 'Ensure-HerdrSession -SessionName $session -WorkspacePath $target'
require_before "$WINDOWS" 'Ensure-HerdrSession -SessionName $session -WorkspacePath $target' 'workspace create --cwd $target'
require_before "$WINDOWS" 'workspace create --cwd $target' 'tab create --cwd $target'
require_before "$WINDOWS" 'tab create --cwd $target' 'Start-PrimeAgent -SessionName $session -PaneId $primePaneId -WorkspacePath $target'
require_before "$WINDOWS" 'Start-PrimeAgent -SessionName $session -PaneId $primePaneId -WorkspacePath $target' 'Start-HerdrWorkspace -SessionName $session -WorkspacePath $target'
require_before "$WINDOWS" 'Start-HerdrWorkspace -SessionName $session -WorkspacePath $target' 'Start-BuzzOnboarding -StateFile $buzzStateFile'
require_before "$WINDOWS" 'Start-BuzzOnboarding -StateFile $buzzStateFile' 'Start-WayfinderOnboarding -StateFile $wayfinderStateFile -IssueTrackerUrl $IssueTrackerUrl -RepositoryName $RepositoryName'
require_before "$WINDOWS" 'Start-WayfinderOnboarding -StateFile $wayfinderStateFile -IssueTrackerUrl $IssueTrackerUrl -RepositoryName $RepositoryName' 'Ready: PRIME is running'
require_text "$WINDOWS" 'No issue was created or changed.'

# HERDR reports a successful `status server` command even when its output says
# "status: not running". Keep a real, isolated server bootstrap check for the
# actual detached command and require explicit opt-in outside supported Macs.
require_text "$ROOT/scripts/check-herdr-bootstrap.sh" "status: not running"
require_text "$ROOT/scripts/check-herdr-bootstrap.sh" "grep -qx 'status: running'"
require_text "$ROOT/scripts/check-herdr-bootstrap.sh" 'nohup herdr --session "$session" server'
require_text "$ROOT/scripts/check-herdr-bootstrap.sh" 'server_pid=$!'
require_text "$ROOT/scripts/check-herdr-bootstrap.sh" 'kill -0 "$server_pid"'
require_text "$ROOT/scripts/check-herdr-bootstrap.sh" 'workspace create --cwd "$workspace"'
require_text "$ROOT/scripts/check-herdr-bootstrap.sh" 'NO MISTAKES GATE — RESERVED (INACTIVE)'
require_text "$ROOT/scripts/check-prime-herdr-handoff.sh" 'pane run "$pane_id"'
require_text "$ROOT/scripts/check-prime-herdr-handoff.sh" 'pwd >'
require_text "$ROOT/scripts/check-prime-herdr-handoff.sh" 'NO MISTAKES GATE — RESERVED (INACTIVE)'
require_text "$ROOT/scripts/check-prime-herdr-handoff.sh" 'nohup wezterm start --cwd "$workspace" --workspace "$session"'
require_text "$ROOT/scripts/check-prime-herdr-handoff.sh" 'handoff_elapsed < 2'
if [[ "${OPNDRM_HERDR_INTEGRATION:-0}" == 1 ]]; then
  "$ROOT/scripts/check-herdr-bootstrap.sh"
  "$ROOT/scripts/check-prime-herdr-handoff.sh"
else
  printf 'HERDR lifecycle integration skipped (set OPNDRM_HERDR_INTEGRATION=1 to run it).\n'
fi

# Private lanes have exactly one GitHub CLI-owned flow, identify the account,
# preflight read access, and stop without cloning when read access is absent.
for script in "$MAC" "$WINDOWS"; do
  require_once "$script" "gh auth login --hostname github.com --git-protocol https --web"
  forbid_text "$script" "github.com/login/device"
  require_text "$script" "gh api --hostname github.com user --jq '.login'"
  require_text "$script" "normal collaborator"
  require_text "$script" "Stop here without cloning"
  require_text "$script" "GH_PROMPT_DISABLED"
  require_text "$script" "prime-agent package install git:github.com/opndrm/prime"
  require_text "$script" "Prime Agent starts or after /reload; setup will continue now."
  forbid_text "$script" "prime-agent package list"
  require_text "$script" "Workspace already exists at"
done
require_text "$MAC" "prime-agent --help >/dev/null 2>&1"
require_text "$WINDOWS" "\$primeAgentHelp = prime-agent --help 2>&1"
require_before "$MAC" "prime-agent package install git:github.com/opndrm/prime" "curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh"
require_before "$WINDOWS" "prime-agent package install git:github.com/opndrm/prime" "Write-Step 'Installing No Mistakes and Buzz'"
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
require_text "$ROOT/api/admin.js" 'class="installer-actions" role="group"'
require_text "$ROOT/api/admin.js" 'COPY INSTALLER COMMAND'
require_text "$ROOT/api/admin.js" '>CHANGE APP<'
forbid_text "$ROOT/api/admin.js" 'READ SELECTED APP GUIDE'
require_text "$ROOT/api/admin.js" "Copy the '+platform+' installer command for '+lane"
require_text "$ROOT/api/admin.js" "Open the '+lane+' guide for '+platform+' to change app"
require_text "$ROOT/api/admin.js" 'button:focus-visible,a.button:focus-visible'
require_text "$ROOT/api/admin.js" '.installer-actions{display:flex;flex-wrap:wrap;align-items:stretch;gap:1rem'
require_text "$ROOT/api/admin.js" '.installer-actions #copy{flex:0 1 auto;min-height:3.25rem;padding:0 1.125rem;font-size:.76rem;box-shadow:2px 2px 0 var(--ink)}'
require_text "$ROOT/api/admin.js" '@media(max-width:34rem){'
require_text "$ROOT/api/admin.js" '.installer-actions #copy,.installer-actions #guide{width:100%;min-height:3.25rem}'
for guide in "$ROOT/site/guide/index.html" "$ROOT/site/es/guide/index.html"; do
  require_text "$guide" "requestedLane"
  require_text "$guide" "FRNKLY.ONE"
  require_text "$guide" "opndrm/Frnkly.one"
  require_text "$guide" "Wayfinder"
  require_text "$guide" "No Mistakes"
done
for onboarding in "$ROOT/skills/opndrm-prime/references/onboarding-en.md" "$ROOT/skills/opndrm-prime/references/onboarding-es.md" "$ROOT/docs/GETTING-STARTED.en.md" "$ROOT/docs/EMPEZAR.es.md"; do
  require_text "$onboarding" "FRNKLY.ONE"
  require_text "$onboarding" "OPNDRM APP"
  require_text "$onboarding" "https://github.com/opndrm/Frnkly.one.git"
done
require_text "$ROOT/README.md" "https://github.com/opndrm/Frnkly.one.git"
require_text "$ROOT/README.md" "It prints \`Ready\` only after those local handoffs succeed"
require_text "$ROOT/skills/opndrm-prime/SKILL.md" "https://github.com/opndrm/Frnkly.one.git"
require_text "$ROOT/skills/opndrm-prime/SKILL.md" "do not rely on a shared HERDR server"
require_text "$ROOT/skills/opndrm-prime/SKILL.md" "Wayfinder is the per-lane GitHub Issues planning context"

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command '& { param([string]$scriptPath); $tokens = $null; $errors = $null; [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 } }' "$WINDOWS"
  printf 'PowerShell parser check passed.\n'
else
  printf 'PowerShell parser check skipped: pwsh is not available on this Mac.\n'
fi

printf 'Installer static checks passed.\n'
