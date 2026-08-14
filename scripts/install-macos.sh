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
  ADAM) PRIVATE_REPOSITORY='opndrm/ADAM'; repo='https://github.com/opndrm/ADAM.git'; target="${OPNDRM_PROJECTS_DIR:-$HOME/OPNDRM}/ADAM" ;;
  FRNKLY.ONE) PRIVATE_REPOSITORY='opndrm/Frnkly.one'; repo='https://github.com/opndrm/Frnkly.one.git'; target="${OPNDRM_PROJECTS_DIR:-$HOME/OPNDRM}/FRNKLY.ONE" ;;
  OPNDRM-APP) PRIVATE_REPOSITORY=''; repo=''; target="$HOME/Desktop/OPNDRM APP" ;;
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
issue_tracker_url="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["issueTrackerUrl"])' "$TEAM_CONFIG")"
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

  command -v wezterm >/dev/null 2>&1 || fail "WezTerm is not available to display the HERDR workspace. Setup is not complete and no Ready message was shown."
  say "Opening WezTerm in the $session_name HERDR workspace"
  if ! wezterm start --cwd "$workspace_path" --workspace "$session_name" -- herdr --session "$session_name"; then
    fail "HERDR workspace was created, but WezTerm could not attach it visibly. Setup is not complete and no Ready message was shown. Open WezTerm and run 'herdr --session $session_name' from $workspace_path after fixing WezTerm."
  fi
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
if ! herdr --session "$session_name" workspace create --cwd "$target" --label "$LANE — PRIME" --focus; then
  fail "HERDR could not create the PRIME workspace. Setup is not complete and no Ready message was shown. The selected workspace at $target was kept untouched."
fi
if ! herdr --session "$session_name" tab create --cwd "$target" --label "NO MISTAKES GATE — RESERVED (INACTIVE)" --no-focus; then
  fail "HERDR could not create the reserved inactive No Mistakes Gate. Setup is not complete and no Ready message was shown. No Gate run was started."
fi
say "Preparing personal Buzz onboarding"
buzz_state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/opndrm/prime"
mkdir -p "$buzz_state_dir"
python3 - "$buzz_state_dir/${session_name}-buzz-onboarding.json" "$LANE" "$issue_tracker_url" "$buzz_relay_url" "$target" "$PRIVATE_REPOSITORY" <<'PY'
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
launch_herdr_workspace "$session_name" "$target"
open -gja Buzz >/dev/null 2>&1 || printf 'Buzz is installed. Open it when ready to complete your personal sign-in.\n'
printf "Buzz onboarding is prepared for %s at %s and is waiting for that person's own sign-in.\n" "$LANE" "$buzz_state_dir/${session_name}-buzz-onboarding.json"
printf "\nReady: WezTerm is attached to the %s HERDR workspace rooted at %s. PRIME is the main workspace and NO MISTAKES GATE is reserved and inactive. No Gate run was started. Buzz onboarding is waiting for the employee's personal sign-in and Vault approval. Atomic Vault/CBF Remote requires the employee to complete the official owner-trust step.\n" "$session_name" "$target"
