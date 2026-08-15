#!/usr/bin/env bash
set -euo pipefail

LANE="${1:-}"
case "$LANE" in
  OPNDRM-APP|ADAM|FRNKLY.ONE) ;;
  *) printf 'Usage: install-macos.sh OPNDRM-APP|ADAM|FRNKLY.ONE\n' >&2; exit 2 ;;
esac
[[ "$(uname -s)" == "Darwin" ]] || { printf 'Open Dream Prime is currently supported on macOS only.\n' >&2; exit 1; }

say() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nOpen Dream Prime stopped: %s\n' "$*" >&2; exit 1; }

case "$LANE" in
  OPNDRM-APP)
    ROOT="$HOME/Desktop/OPNDRM APP"
    SESSION="opndrm-opndrm-app"
    REPOSITORY="opndrm/prime"
    ;;
  ADAM)
    ROOT="${OPNDRM_PROJECTS_DIR:-$HOME/OPNDRM}/ADAM"
    SESSION="opndrm-adam"
    REPOSITORY="opndrm/ADAM"
    ;;
  FRNKLY.ONE)
    ROOT="${OPNDRM_PROJECTS_DIR:-$HOME/OPNDRM}/FRNKLY.ONE"
    SESSION="opndrm-frnkly-one"
    REPOSITORY="opndrm/Frnkly.one"
    ;;
esac

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
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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

require_github_for_private_lane() {
  [[ "$LANE" == OPNDRM-APP ]] && return
  if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    say 'Sign in to GitHub with your own account'
    gh auth login --hostname github.com --git-protocol https --web || fail 'GitHub sign-in was not completed.'
  fi
  gh api --hostname github.com "repos/$REPOSITORY" --silent >/dev/null 2>&1 || fail "Your GitHub account cannot read $REPOSITORY. Stop here and request normal collaborator access."
  gh auth setup-git --hostname github.com
}

create_root() {
  [[ ! -e "$ROOT" ]] || fail "Workspace already exists at $ROOT. It was not changed."
  if [[ "$LANE" == OPNDRM-APP ]]; then
    mkdir -p "$ROOT"
    printf '# Open Dream Prime workspace\n' > "$ROOT/README.md"
  else
    mkdir -p "$(dirname "$ROOT")"
    git clone "https://github.com/$REPOSITORY.git" "$ROOT"
  fi
}

configure_ollama_for_prime() {
  say 'Configuring the existing Ollama route for Prime Agent'
  open -gja Ollama >/dev/null 2>&1 || true
  for _ in {1..30}; do curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break; sleep 1; done
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 || fail 'Ollama is not reachable. Configure it locally, then rerun this installer.'
  python3 "$(dirname "$0")/configure-prime-ollama.py" "${PRIME_AGENT_CONFIG_DIR:-$HOME/.prime/agent}"
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

start_prime() {
  local result pane command
  result="$(herdr --session "$SESSION" workspace create --cwd "$ROOT" --label "$LANE — PRIME" --focus)" || fail 'HERDR could not create the PRIME workspace.'
  pane="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])' <<<"$result")" || fail 'HERDR did not return a PRIME pane.'
  command="exec prime-agent --cwd $(printf '%q' "$ROOT")"
  herdr --session "$SESSION" pane run "$pane" "$command" >/dev/null || fail 'HERDR could not launch Prime Agent.'
}

open_visible_workspace() {
  nohup wezterm start --cwd "$ROOT" --workspace "$SESSION" -- herdr --session "$SESSION" >"${XDG_STATE_HOME:-$HOME/.local/state}/opndrm/prime/$SESSION-wezterm.log" 2>&1 </dev/null &
}

require_clt
require_brew
say 'Installing or verifying workflow tools'
brew install git gh python herdr
brew install --cask wezterm ollama
require_github_for_private_lane
say 'Installing or verifying Prime Agent and Buzz'
command -v prime-agent >/dev/null 2>&1 || curl -fsSL https://app.primeintellect.ai/prime-agent/install.sh | sh
prime-agent --help >/dev/null 2>&1 || fail 'Prime Agent is unavailable after installation.'
prime-agent package install git:github.com/opndrm/prime || fail 'The Open Dream Prime package could not be installed.'
configure_ollama_for_prime
install_prime_buzz_bridge
install_buzz
create_root
start_herdr
start_prime
open_visible_workspace
open -a Buzz >/dev/null 2>&1 || fail 'Buzz could not open. Your workspace was preserved; no Ready claim is made.'
printf '\nReady: %s is open in WezTerm. PRIME is rooted at %s. Buzz is waiting for your own sign-in. The existing local Ollama route was registered without downloading a model or changing the selected default.\n' "$SESSION" "$ROOT"
