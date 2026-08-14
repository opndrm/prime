#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRIME_CONFIG_DIR="${PRIME_AGENT_CONFIG_DIR:-$HOME/.prime/agent}"
TEAM_CONFIG="${OPNDRM_TEAM_CONFIG:-$ROOT/config/team.json}"
LANE="${1:-}"
say() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nOpen Dream Prime stopped: %s\n' "$*" >&2; exit 1; }
case "$LANE" in ADAM|FRNKLY.ONE|OPNDRM-APP) ;; *) fail "Choose a valid Open Dream Prime workspace." ;; esac
[[ "$(uname -s)" == "Darwin" ]] || fail "This is the Mac installer."

case "$LANE" in
  ADAM) PRIVATE_REPOSITORY='opndrm/ADAM'; repository_name='opndrm/ADAM'; repo='https://github.com/opndrm/ADAM.git'; issue_tracker_url='https://github.com/opndrm/ADAM/issues'; target="${OPNDRM_PROJECTS_DIR:-$HOME/OPNDRM}/ADAM" ;;
  FRNKLY.ONE) PRIVATE_REPOSITORY='opndrm/Frnkly.one'; repository_name='opndrm/Frnkly.one'; repo='https://github.com/opndrm/Frnkly.one.git'; issue_tracker_url='https://github.com/opndrm/Frnkly.one/issues'; target="${OPNDRM_PROJECTS_DIR:-$HOME/OPNDRM}/FRNKLY.ONE" ;;
  OPNDRM-APP) PRIVATE_REPOSITORY=''; repository_name='opndrm/prime'; repo=''; issue_tracker_url='https://github.com/opndrm/prime/issues'; target="$HOME/Desktop/OPNDRM APP" ;;
esac

ensure_developer_tools() {
  xcode-select -p >/dev/null 2>&1 && return
  say "Starting Apple Command Line Tools installation"
  xcode-select --install 2>&1 || true
  open 'x-apple.systempreferences:com.apple.Software-Update-Settings.extension' >/dev/null 2>&1 || true
  printf 'Apple Software Update has been opened. If Apple requires a macOS update before Command Line Tools can install, complete that Apple update and restart if requested; then run this same OPNDRM command again. Otherwise, install Command Line Tools there and this window will continue automatically.\n'
  for _ in {1..1800}; do
    xcode-select -p >/dev/null 2>&1 && return
    sleep 1
  done
  fail "Apple Command Line Tools did not finish within 30 minutes. Run this installer again after the Apple install completes."
}

ensure_developer_tools
[[ -f "$TEAM_CONFIG" ]] || TEAM_CONFIG="$ROOT/config/team.example.json"
buzz_relay_url="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("buzzRelayUrl", ""))' "$TEAM_CONFIG")"
atomic_vault_url="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("atomicVaultInstallerUrl", ""))' "$TEAM_CONFIG")"

say "Installing WezTerm, HERDR, Git, GitHub CLI, and Ollama"
command -v brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif ! command -v brew >/dev/null 2>&1; then
  fail "Homebrew finished without becoming available in this Terminal. Open a new Terminal window and run the same OPNDRM command again."
fi
brew install git gh python herdr
brew install --cask wezterm ollama

ensure_github_access() {
  [[ "$LANE" == 'OPNDRM-APP' ]] && return
  if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    say "Sign in to your own GitHub account"
    printf "GitHub CLI will open GitHub's official device authorization flow. Sign in with your own GitHub account and enter the one-time code only at GitHub's official device page. No shared Open Dream credential, personal access token, or GitHub administrator repository access is used.\n"
    gh auth login --hostname github.com --git-protocol https --web || fail "GitHub sign-in was not completed. Sign in with your own GitHub account and run this installer again."
  fi
  gh auth status --hostname github.com >/dev/null 2>&1 || fail "GitHub is not signed in for this Mac account."
  github_username="$(gh api --hostname github.com user --jq '.login' 2>/dev/null || true)"
  [[ -n "$github_username" ]] || fail "GitHub could not identify the signed-in account. Sign in with your own GitHub account and run this installer again."
  printf 'GitHub is signed in as %s.\n' "$github_username"
  if ! gh api --hostname github.com "repos/$PRIVATE_REPOSITORY" --silent >/dev/null 2>&1; then
    fail "Your GitHub account cannot read $PRIVATE_REPOSITORY. Stop here without cloning. Ask the repository owner to invite this personal GitHub account as a normal collaborator with the repository access needed for $LANE, then run this installer again. No administrator role, shared account, token, or credential is required."
  fi
  gh auth setup-git --hostname github.com || fail "GitHub could not configure secure Git access for this Mac account."
}

herdr_session_running() {
  herdr --session "$1" status server 2>&1 | grep -qx 'status: running'
}

ensure_herdr_session() {
  local session_name="$1"
  local herdr_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/opndrm/prime"
  local herdr_log="$herdr_state_dir/${session_name}-herdr.log"

  # HERDR workspace and tab commands use the named session socket. They do not
  # start that socket themselves, so every lane needs its own server first.
  if herdr_session_running "$session_name"; then
    return
  fi

  say "Starting the local HERDR session: $session_name"
  mkdir -p "$herdr_state_dir"
  nohup herdr --session "$session_name" server >"$herdr_log" 2>&1 </dev/null &
  for _ in {1..30}; do
    if herdr_session_running "$session_name"; then
      return
    fi
    sleep 1
  done

  fail "HERDR could not start or attach the $session_name session. The selected workspace at $target was kept, but no PRIME workspace or No Mistakes Gate was created. Setup is not complete. Open WezTerm and run 'herdr --session $session_name' to retry the personal session, or inspect $herdr_log."
}

launch_herdr_workspace() {
  local session_name="$1"
  local workspace_path="$2"
  local herdr_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/opndrm/prime"
  local wezterm_log="$herdr_state_dir/${session_name}-wezterm.log"
  local wezterm_pid

  command -v wezterm >/dev/null 2>&1 || fail "WezTerm is not available to display the HERDR workspace. Setup is not complete and no Ready message was shown."
  say "Opening WezTerm in the $session_name HERDR workspace"
  mkdir -p "$herdr_state_dir"
  # `wezterm start -- herdr …` stays attached to the HERDR client on its first
  # launch. Detach the GUI handoff so the originating installer can report its
  # verified result instead of waiting for the teammate to close WezTerm.
  nohup wezterm start --cwd "$workspace_path" --workspace "$session_name" -- herdr --session "$session_name" >"$wezterm_log" 2>&1 </dev/null &
  wezterm_pid=$!
  sleep 1
  if ! kill -0 "$wezterm_pid" 2>/dev/null && grep -qiE '(^|[^a-z])(error|failed)([^a-z]|$)' "$wezterm_log" 2>/dev/null; then
    fail "HERDR workspace was created, but WezTerm could not attach it visibly. Setup is not complete and no Ready message was shown. Open WezTerm and run 'herdr --session $session_name' from $workspace_path after fixing WezTerm."
  fi
  printf 'WezTerm handoff opened for %s; this installer will now finish without waiting for that window to close.\n' "$session_name"
}

prime_pane_id_from_workspace() {
  python3 - "$1" <<'PY'
import json, sys
payload = json.loads(sys.argv[1])
pane_id = payload.get("result", {}).get("root_pane", {}).get("pane_id", "")
if not pane_id:
    raise SystemExit(1)
print(pane_id)
PY
}

prime_agent_running_in_root() {
  local session_name="$1"
  local pane_id="$2"
  local workspace_path="$3"
  local process_info
  process_info="$(herdr --session "$session_name" pane process-info --pane "$pane_id" 2>/dev/null || true)"
  python3 - "$workspace_path" "$process_info" <<'PY'
import json, sys
workspace_path, raw = sys.argv[1:]
try:
    processes = json.loads(raw)["result"]["process_info"]["foreground_processes"]
except (IndexError, KeyError, TypeError, ValueError):
    raise SystemExit(1)
for process in processes:
    command = " ".join(str(value) for value in (process.get("argv") or [])) + " " + str(process.get("cmdline", ""))
    if process.get("cwd") == workspace_path and "prime-agent" in command:
        raise SystemExit(0)
raise SystemExit(1)
PY
}

launch_prime_agent() {
  local session_name="$1"
  local pane_id="$2"
  local workspace_path="$3"
  local prime_command

  # HERDR creates a root shell by design. Prime Agent's documented `--cwd`
  # option makes the selected checkout explicit, while `exec` replaces that
  # shell instead of leaving the visible PRIME tab at a prompt.
  prime_command="exec prime-agent --cwd $(printf '%q' "$workspace_path")"
  if ! herdr --session "$session_name" pane run "$pane_id" "$prime_command" >/dev/null; then
    fail "HERDR created PRIME, but it could not start Prime Agent in $workspace_path. Setup is not complete and no Ready message was shown. The reserved inactive Gate was not started."
  fi
  for _ in {1..10}; do
    if prime_agent_running_in_root "$session_name" "$pane_id" "$workspace_path"; then
      printf 'Prime Agent is running in the selected %s workspace root.\n' "$LANE"
      return
    fi
    sleep 1
  done
  fail "HERDR created PRIME, but Prime Agent did not stay running in $workspace_path. Setup is not complete and no Ready message was shown. The reserved inactive Gate was not started."
}

launch_buzz_onboarding() {
  local buzz_state_file="$1"

  say "Opening Buzz for personal onboarding"
  open -a Buzz >/dev/null 2>&1 || fail "Buzz could not open for personal onboarding. Setup is not complete and no Ready message was shown. No Buzz sign-in was completed in this installer; reopen Buzz after fixing the application."
  for _ in {1..10}; do
    if pgrep -f '/Buzz.*\.app/Contents/MacOS/buzz-desktop' >/dev/null 2>&1; then
      printf "Buzz is open for %s. It is waiting for that person's own sign-in; no account or agent was connected.\n" "$LANE"
      printf 'Buzz onboarding context: %s\n' "$buzz_state_file"
      return
    fi
    sleep 1
  done
  fail "Buzz was installed but did not open for personal onboarding. Setup is not complete and no Ready message was shown. No Buzz account or agent was connected."
}

prepare_wayfinder_onboarding() {
  local state_file="$1"

  say "Preparing the lane-specific Wayfinder issue context"
  open "$issue_tracker_url" >/dev/null 2>&1 || fail "Wayfinder/GitHub Issues could not open for $LANE. Setup is not complete and no Ready message was shown. No issue was created or changed."
  printf 'Wayfinder/GitHub Issues opened for %s at %s. It is scoped only to %s and is waiting for any personal browser sign-in GitHub requires.\n' "$LANE" "$issue_tracker_url" "$repository_name"
  printf 'Wayfinder context: %s\n' "$state_file"
}

ensure_github_access
# The public OPNDRM-APP lane never starts device authorization. Later public
# GitHub downloads must fail with guidance instead of opening a sign-in prompt.
export GH_PROMPT_DISABLED=1

say "Installing Prime Agent, No Mistakes, and Buzz"
curl -fsSL https://app.primeintellect.ai/prime-agent/install.sh | sh
if ! prime-agent package install git:github.com/opndrm/prime; then
  fail "The Open Dream Prime GitHub package did not install. Check your network and Prime Agent setup, then run this installer again."
fi
if ! prime-agent --help >/dev/null 2>&1; then
  fail "Prime Agent stopped responding after the Open Dream Prime package install. Restart Prime Agent, then run this installer again."
fi
printf 'Open Dream Prime GitHub package installed successfully. It loads when Prime Agent starts or after /reload; setup will continue now.\n'
curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
arch="$(uname -m)"; [[ "$arch" == arm64 ]] && asset='Buzz_*_aarch64.dmg' || asset='Buzz_*_x64.dmg'
download_dir="$(mktemp -d)"; GH_PROMPT_DISABLED=1 gh release download --repo block/buzz --pattern "$asset" --dir "$download_dir"
buzz_dmg="$(find "$download_dir" -name 'Buzz_*.dmg' -print -quit)"; [[ -n "$buzz_dmg" ]] || fail "Buzz download was not found."
mount_dir="$(mktemp -d)"; hdiutil attach "$buzz_dmg" -nobrowse -mountpoint "$mount_dir" >/dev/null; cp -R "$mount_dir/Buzz.app" /Applications/; hdiutil detach "$mount_dir" >/dev/null
[[ -z "$buzz_relay_url" ]] || launchctl setenv BUZZ_RELAY_URL "$buzz_relay_url"

say "Checking Atomic Vault"
if [[ -n "$atomic_vault_url" ]]; then
  curl -fsSL "$atomic_vault_url" | bash
else
  printf 'Atomic Vault package source is not configured. It remains a protected owner setup step.\n'
fi

say "Creating the Ollama provider configuration"
open -gja Ollama
for _ in {1..30}; do curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break; sleep 1; done
curl -fsS http://127.0.0.1:11434/api/tags >/dev/null || fail "Ollama did not become available."
python3 "$ROOT/scripts/configure-ollama.py" "$ROOT/config/ollama-models.json" "$PRIME_CONFIG_DIR"

[[ ! -e "$target" ]] || fail "Workspace already exists at $target."
if [[ "$LANE" == 'OPNDRM-APP' ]]; then
  say "Creating a fresh Open Dream App workspace on the Desktop"
  mkdir -p "$target"
  printf '# Open Dream App\n\nA fresh Open Dream Prime workspace.\n' > "$target/README.md"
else
  say "Cloning the selected team project"
  mkdir -p "$(dirname "$target")"
  git clone "$repo" "$target"
fi
say "Creating the visible PRIME workspace and reserved Gate"
session_name="opndrm-$(printf '%s' "$LANE" | tr '[:upper:].' '[:lower:]-')"
ensure_herdr_session "$session_name"
if ! prime_workspace_result="$(herdr --session "$session_name" workspace create --cwd "$target" --label "$LANE — PRIME · WAYFINDER: $repository_name" --focus)"; then
  fail "HERDR could not create the PRIME workspace. Setup is not complete and no Ready message was shown. The selected workspace at $target was kept untouched."
fi
prime_pane_id="$(prime_pane_id_from_workspace "$prime_workspace_result" || true)"
[[ -n "$prime_pane_id" ]] || fail "HERDR created PRIME but did not return its root pane. Setup is not complete and no Ready message was shown. The selected workspace at $target was kept untouched."
if ! herdr --session "$session_name" tab create --cwd "$target" --label "NO MISTAKES GATE — RESERVED (INACTIVE) · ROOT: $target" --no-focus; then
  fail "HERDR could not create the reserved inactive No Mistakes Gate. Setup is not complete and no Ready message was shown. No Gate run was started."
fi
launch_prime_agent "$session_name" "$prime_pane_id" "$target"
say "Preparing personal Buzz onboarding"
buzz_state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/opndrm/prime"
mkdir -p "$buzz_state_dir"
python3 - "$buzz_state_dir/${session_name}-buzz-onboarding.json" "$LANE" "$issue_tracker_url" "$buzz_relay_url" "$target" "$repository_name" <<'PY'
import json, pathlib, sys
path, lane, issue_tracker, relay, workspace_path, repository = sys.argv[1:]
record = {
    "status": "waiting-for-owner",
    "workspace": lane,
    "workspace_path": workspace_path,
    "repository": repository or None,
    "suggested_agent_name": f"PRIME — {lane}",
    "suggested_agent_role": "root workspace agent",
    "issue_tracker": issue_tracker,
    "buzz_relay": relay or None,
    "next_owner_action": "Sign in to Buzz, create or connect the named agent, then save its approved identifier in your Atomic Vault OPNDRM entry.",
}
pathlib.Path(path).write_text(json.dumps(record, indent=2) + "\n")
PY
wayfinder_state_file="$buzz_state_dir/${session_name}-wayfinder-onboarding.json"
python3 - "$wayfinder_state_file" "$LANE" "$issue_tracker_url" "$target" "$repository_name" <<'PY'
import json, pathlib, sys
path, lane, issue_tracker, workspace_path, repository = sys.argv[1:]
record = {
    "status": "waiting-for-owner",
    "workspace": lane,
    "workspace_path": workspace_path,
    "repository": repository,
    "issue_tracker": issue_tracker,
    "workflow": "Use only this repository's existing GitHub Issues/Wayfinder workflow. Onboarding created, assigned, labelled, edited, or published no issue, map, dependency, receipt, or decision.",
    "next_owner_action": "Open the selected repository's existing issue workflow. Complete any personal GitHub browser sign-in it requires before taking an owner-authorized issue action.",
}
pathlib.Path(path).write_text(json.dumps(record, indent=2) + "\n")
PY
launch_herdr_workspace "$session_name" "$target"
launch_buzz_onboarding "$buzz_state_dir/${session_name}-buzz-onboarding.json"
prepare_wayfinder_onboarding "$wayfinder_state_file"
printf "\nReady: PRIME is running in the %s HERDR workspace rooted at %s. WezTerm was opened without blocking this Terminal; NO MISTAKES GATE is reserved and inactive, and no Gate run was started. Buzz is open but waiting for the employee's personal sign-in and Vault approval. Wayfinder/GitHub Issues is open only for %s. Atomic Vault/CBF Remote requires the employee to complete the official owner-trust step.\n" "$session_name" "$target" "$repository_name"
