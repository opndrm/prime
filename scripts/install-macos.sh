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

ensure_developer_tools() {
  xcode-select -p >/dev/null 2>&1 && return
  say "Starting Apple Command Line Tools installation"
  xcode-select --install 2>&1 || true
  open 'x-apple.systempreferences:com.apple.Software-Update-Settings.extension' >/dev/null 2>&1 || true
  printf 'Apple Software Update has been opened. Install Command Line Tools there, then this window will continue automatically.\n'
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
brew install git gh python herdr
brew install --cask wezterm ollama

say "Installing Prime Agent, No Mistakes, and Buzz"
curl -fsSL https://app.primeintellect.ai/prime-agent/install.sh | sh
prime-agent package install git:github.com/opndrm/prime
curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
arch="$(uname -m)"; [[ "$arch" == arm64 ]] && asset='Buzz_*_aarch64.dmg' || asset='Buzz_*_x64.dmg'
download_dir="$(mktemp -d)"; gh release download --repo block/buzz --pattern "$asset" --dir "$download_dir"
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

case "$LANE" in
  ADAM) repo='https://github.com/opndrm/ADAM.git'; target="${OPNDRM_PROJECTS_DIR:-$HOME/OpenDream}/ADAM" ;;
  FRNKLY.ONE) repo='https://github.com/frnklyone/frnkly-one-v2.git'; target="${OPNDRM_PROJECTS_DIR:-$HOME/OpenDream}/FRNKLY.ONE" ;;
  OPNDRM-APP) target="$HOME/Desktop/OPNDRM APP" ;;
esac
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
herdr --session "$session_name" workspace create --cwd "$target" --label "$LANE — PRIME" --focus
herdr --session "$session_name" tab create --cwd "$target" --label "NO MISTAKES GATE" --no-focus
open "$issue_tracker_url"
printf '\nReady. No Mistakes is installed but inactive. Atomic Vault/CBF Remote requires the employee to complete the official owner-trust step.\n'
