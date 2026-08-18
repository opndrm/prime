#!/usr/bin/env bash
set -euo pipefail

LANE="${1:-}"
[[ "$LANE" == "OPNDRM-APP" ]] || {
  printf 'Usage: install-macos.sh OPNDRM-APP\n' >&2
  exit 2
}
[[ "$(uname -s)" == "Darwin" ]] || { printf 'Open Dream Prime is currently supported on macOS only.\n' >&2; exit 1; }

say() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nOpen Dream Prime stopped: %s\n' "$*" >&2; exit 1; }

ROOT="${OPNDRM_ROOT:-$HOME/Desktop/opndrm}"
SESSION="opndrm"
REPOSITORY="opndrm/prime"

require_clt() {
  xcode-select -p >/dev/null 2>&1 && return
  say 'Apple Command Line Tools are required'
  xcode-select --install >/dev/null 2>&1 || true
  open 'x-apple.systempreferences:com.apple.Software-Update-Settings.extension' >/dev/null 2>&1 || true
  fail 'Complete Apple Command Line Tools (and any required macOS update), then rerun this same command.'
}

require_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    say 'Installing Homebrew'
    [[ -r /dev/tty ]] || fail 'Homebrew needs an interactive Terminal for administrator approval.'
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
  command -v brew >/dev/null 2>&1 || fail 'Homebrew is unavailable in this Terminal. Open a new Terminal and rerun this command.'
}

herdr_running() { herdr --session "$1" status server 2>&1 | grep -qx 'status: running'; }
start_herdr() {
  local log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/opndrm/prime" log
  herdr_running "$SESSION" && return
  mkdir -p "$log_dir"; log="$log_dir/$SESSION.log"
  nohup herdr --session "$SESSION" server >"$log" 2>&1 </dev/null &
  for _ in {1..30}; do herdr_running "$SESSION" && return; sleep 1; done
  fail "HERDR did not start for $SESSION. See $log."
}



create_root() {
  if [[ -e "$ROOT" && ! -d "$ROOT" ]]; then
    fail "Workspace path exists but is not a directory: $ROOT"
  fi
  if [[ ! -d "$ROOT" ]]; then
    mkdir -p "$ROOT"
    printf '# Open Dream Prime workspace\n' > "$ROOT/README.md"
  fi
}

configure_ollama_for_prime() {
  say 'Configuring the existing Ollama route for Prime Agent'
  open -gja Ollama >/dev/null 2>&1 || true
  for _ in {1..30}; do curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break; sleep 1; done
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 || fail 'Ollama is not reachable. Configure it locally, then rerun this installer.'
  if ! python3 "$(dirname "$0")/configure-prime-ollama.py" "${PRIME_AGENT_CONFIG_DIR:-$HOME/.prime/agent}"; then
    printf 'Ollama is running without a configured model. Continuing without changing Prime Agent defaults; sign in to Ollama and rerun later to register the route.\n'
  fi
}

install_prime_buzz_bridge() {
  local bin_dir="$HOME/.local/bin" bridge state_dir
  bin_dir="$HOME/.local/bin"; bridge="$bin_dir/opndrm-prime-acp"; state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/opndrm/prime"
  mkdir -p "$bin_dir" "$state_dir"
  cat > "$bridge" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "${ROOT}"
exec prime-agent --mode acp "\$@"
EOF
  chmod 755 "$bridge"
  cat > "$state_dir/buzz-prime-agent-harness.json" <<EOF
{"agentCommand":"$bridge","agentArgs":[],"provider":"ollama","workspace":"$ROOT"}
EOF
  printf 'Buzz harness bridge installed at %s. Open Buzz and select its existing Prime Agent harness; personal sign-in and agent approval remain yours.\n' "$bridge"
}

install_buzz() {
  [[ -d /Applications/Buzz.app ]] && return
  local architecture pattern download_dir dmg mount_dir
  architecture="$(uname -m)"
  pattern='Buzz_*_x64.dmg'
  [[ "$architecture" == arm64 ]] && pattern='Buzz_*_aarch64.dmg'
  download_dir="$(mktemp -d)"; mount_dir="$(mktemp -d)"
  trap 'rm -rf "$download_dir" "$mount_dir"' RETURN
  gh release download --repo block/buzz --pattern "$pattern" --dir "$download_dir" --clobber || fail 'Buzz could not be downloaded from its official release.'
  dmg="$(find "$download_dir" -name 'Buzz_*.dmg' -print -quit)"
  [[ -n "$dmg" ]] || fail 'The official Buzz download was not found.'
  hdiutil attach "$dmg" -nobrowse -mountpoint "$mount_dir" >/dev/null
  cp -R "$mount_dir/Buzz.app" /Applications/
  hdiutil detach "$mount_dir" >/dev/null
}

install_opndrm-vm() {
  local bin_dir="$HOME/.local/bin" repo_dir="$HOME/Desktop/opndrm_prime" service_src entitlements
  bin_dir="$HOME/.local/bin"
  repo_dir="$HOME/Desktop/opndrm_prime"
  service_src="$repo_dir/apps/opndrm-vm"
  entitlements="/tmp/opndrm-vm.entitlements"

  say 'Installing OPNDRM VM Agent Computer'
  mkdir -p "$bin_dir"

  # Clone or update the OPNDRM Prime repo (contains OPNDRM VM source)
  if [[ ! -d "$repo_dir/.git" ]]; then
    git clone https://github.com/opndrm/prime.git "$repo_dir" || fail 'Could not clone opndrm/prime for OPNDRM VM source.'
  else
    git -C "$repo_dir" pull --ff-only 2>/dev/null || true
  fi

  # Build the OPNDRM VM computer service
  if [[ -d "$service_src" ]]; then
    (cd "$service_src" && swift build -c release 2>&1 | tail -3) || fail 'OPNDRM VM service build failed.'

    cat > "$entitlements" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.virtualization</key>
    <true/>
</dict>
</plist>
EOF
    codesign --sign - --force --entitlements "$entitlements" "$service_src/.build/release/opndrm-vm" 2>/dev/null || true
    cp "$service_src/.build/release/opndrm-vm" "$bin_dir/opndrm-vm" 2>/dev/null || true
    echo 'OPNDRM VM service built and codesigned'
  else
    fail "OPNDRM VM source not found at $service_src"
  fi

  # Install guest bootstrap
  if [[ -f "$service_src/guest-bootstrap.sh" ]]; then
    cp "$service_src/guest-bootstrap.sh" "$bin_dir/opndrm-vm-guest-bootstrap" 2>/dev/null || true
    chmod +x "$bin_dir/opndrm-vm-guest-bootstrap" 2>/dev/null || true
  fi

  # Install opndrm-vm CLI if not present
  if [[ ! -f "$bin_dir/opndrm-vm" ]]; then
    cat > "$bin_dir/opndrm-vm" <<'BZ'
#!/bin/bash
set -e
PORT=7777
OPNDRM_VM_DIR="$HOME/Library/Application Support/OPNDRM-VM/AgentComputers"
SERVICE_BIN="$HOME/.local/bin/opndrm-vm"
ENTITLEMENTS="/tmp/opndrm-vm.entitlements"
usage() { echo "Usage: opndrm-vm <show|hide|stop|destroy|list|provision|status|ping> [agent]"; }
send_cmd() { echo "$1" | nc -w 3 localhost $PORT 2>/dev/null || echo "error: daemon not running"; }
ensure_entitlements() { cat > "$ENTITLEMENTS" << 'E'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>com.apple.security.virtualization</key><true/></dict></plist>
E
}
start_daemon() { local a="${1:-opndrm-vm-mac-002}"; pgrep -f opndrm-vm >/dev/null 2>&1 || { ensure_entitlements; codesign --sign - --force --entitlements "$ENTITLEMENTS" "$SERVICE_BIN" 2>/dev/null || true; "$SERVICE_BIN" --machine "$a" & sleep 2; }; }
CMD="${1:-}"; AGENT="${2:-opndrm-vm-mac-002}"
case "$CMD" in
  show) start_daemon "$AGENT"; send_cmd "show" ;;
  hide) send_cmd "hide" ;;
  stop) send_cmd "stop" ;;
  destroy) [ -d "$OPNDRM_VM_DIR/TrustedMacStates/$AGENT" ] && { send_cmd "stop"; sleep 2; rm -rf "$OPNDRM_VM_DIR/TrustedMacStates/$AGENT"; echo "Destroyed $AGENT"; } || echo "Not found" ;;
  list) [ -d "$OPNDRM_VM_DIR/TrustedMacStates" ] && ls -1 "$OPNDRM_VM_DIR/TrustedMacStates" || echo "(none)" ;;
  provision) echo "Run inside guest: curl -fsSL https://opndrm.com/install-macos.sh | bash -s -- OPNDRM-APP" ;;
  status) echo "Daemon: $(send_cmd ping)"; echo "VM: $(send_cmd status)" ;;
  connect) mkdir -p "$HOME/.${2:-buzz}/.agents/skills/opndrm-vm" 2>/dev/null; echo "Connected to $2" ;;
  ping) send_cmd "ping" ;;
  *) usage ;;
esac
BZ
    chmod +x "$bin_dir/opndrm-vm"
  fi
  echo 'OPNDRM VM CLI installed'
}

workspace_exists() {
  herdr --session "$SESSION" workspace list | python3 -c 'import json,sys; label=sys.argv[1]; print(any(w.get("label")==label for w in json.load(sys.stdin)["result"]["workspaces"]))' "$1" | grep -qx True
}

create_workspace() {
  local label="$1" cwd="$2" command="$3" focus="$4" result pane
  workspace_exists "$label" && return
  if [[ "$focus" == "focus" ]]; then
    result="$(herdr --session "$SESSION" workspace create --cwd "$cwd" --label "$label" --focus)" || fail "HERDR could not create $label."
  else
    result="$(herdr --session "$SESSION" workspace create --cwd "$cwd" --label "$label" --no-focus)" || fail "HERDR could not create $label."
  fi
  [[ -n "$command" ]] || return
  pane="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])' <<<"$result")" || fail "HERDR did not return a pane for $label."
  herdr --session "$SESSION" pane run "$pane" "$command" >/dev/null || fail "HERDR could not launch $label."
}

ensure_exact_opndrm_layout() {
  create_workspace 'OFFLINE' "$HOME" "exec prime-agent --cwd $(printf '%q' "$HOME")" no-focus
  create_workspace 'OPNDRM' "$ROOT" "exec prime-agent --cwd $(printf '%q' "$ROOT")" focus
  create_workspace 'OPNDRM JC' "$ROOT" "exec jcode -C $(printf '%q' "$ROOT")" no-focus
  create_workspace 'OPNDRM NO-MISTAKES' "$ROOT" '' no-focus
}


open_visible_workspace() {
  nohup wezterm start --cwd "$ROOT" --workspace "$SESSION" -- herdr --session "$SESSION" >"${XDG_STATE_HOME:-$HOME/.local/state}/opndrm/prime/$SESSION-wezterm.log" 2>&1 </dev/null &
}

require_clt
require_brew
say 'Installing or verifying WezTerm, Ollama, and Handy'
brew install git gh python herdr
[[ -d /Applications/WezTerm.app ]] || brew install --cask wezterm
[[ -d /Applications/Ollama.app ]] || brew install --cask ollama
[[ -d /Applications/Handy.app ]] || brew install --cask handy
install_jcode() {
  command -v jcode >/dev/null 2>&1 && return
  say 'Installing JCode'
  curl -fsSL https://jcode.sh/install | bash
  export PATH="$HOME/.local/bin:$PATH"
  command -v jcode >/dev/null 2>&1 || fail 'JCode installed but is unavailable in this Terminal. Open a new Terminal and rerun this command.'
}

setup_handy() {
  local handy_models superwhisper_turbo handy_turbo
  handy_models="$HOME/Library/Application Support/com.pais.handy/models"
  superwhisper_turbo="$HOME/Library/Application Support/superwhisper/ggml-large-v3-turbo.bin"
  handy_turbo="$handy_models/ggml-large-v3-turbo.bin"
  mkdir -p "$handy_models"
  if [[ -f "$superwhisper_turbo" && ! -e "$handy_turbo" ]]; then
    ln -s "$superwhisper_turbo" "$handy_turbo"
    printf 'Handy will reuse the existing Superwhisper Turbo model without a duplicate download.\n'
  fi
  open /Applications/Handy.app >/dev/null 2>&1 || fail 'Handy could not open.'
  printf 'Handy is open. Its owner must approve Microphone and Accessibility permissions and select a transcription model.\n'
}

say 'Installing or verifying Prime Agent, JCode, and Buzz'
install_jcode
command -v prime-agent >/dev/null 2>&1 || curl -fsSL https://app.primeintellect.ai/prime-agent/install.sh | sh
prime-agent --help >/dev/null 2>&1 || fail 'Prime Agent is unavailable after installation.'
prime-agent package install git:github.com/opndrm/prime || fail 'The Open Dream Prime package could not be installed.'
configure_ollama_for_prime
install_prime_buzz_bridge
install_buzz
install_opndrm-vm
create_root
start_herdr
ensure_exact_opndrm_layout
open_visible_workspace
open -a Buzz >/dev/null 2>&1 || fail 'Buzz could not open. Your workspace was preserved; no Ready claim is made.'
printf '\nReady: %s is open in WezTerm with exactly OFFLINE, OPNDRM, OPNDRM JC, and OPNDRM NO-MISTAKES. OPNDRM is rooted at %s. The No Mistakes workspace is an inactive shell. Buzz is waiting for your own sign-in. Handy is installed; its owner grants permissions and chooses its model.\n' "$SESSION" "$ROOT"
printf 'OPNDRM VM is installed. Run opndrm-vm show to manage agent VMs.\n'
