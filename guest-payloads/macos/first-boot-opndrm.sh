#!/bin/bash
# OPNDRM VM guest first-boot provisioning.
# Installs the Open Dream AI workflow inside a macOS VM.
# Run inside the guest after first boot.

set -euo pipefail

ROOT="${OPNDRM_ROOT:-$HOME/Desktop/opndrm}"
SESSION="opndrm"

echo "==> Installing Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"

echo "==> Installing WezTerm, HERDR, Git, GitHub CLI"
brew install git gh python herdr
[[ -d /Applications/WezTerm.app ]] || brew install --cask wezterm

echo "==> Installing Handy"
brew install --cask handy 2>/dev/null || true

echo "==> Installing Prime Agent"
command -v prime-agent >/dev/null 2>&1 || curl -fsSL https://app.primeintellect.ai/prime-agent/install.sh | sh

echo "==> Installing JCode"
command -v jcode >/dev/null 2>&1 || curl -fsSL https://jcode.sh/install | bash

echo "==> Configuring Ollama"
brew install --cask ollama 2>/dev/null || true
open -gja Ollama 2>/dev/null || true
for _ in {1..30}; do curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break; sleep 1; done

echo "==> Creating workspace"
mkdir -p "$ROOT"

echo "==> Creating HERDR session with four workspaces"
herdr --session "$SESSION" workspace list >/dev/null 2>&1 || {
  herdr --session "$SESSION" server &
  for _ in {1..15}; do herdr --session "$SESSION" status server 2>&1 | grep -q running && break; sleep 1; done
}
herdr --session "$SESSION" workspace list 2>/dev/null | grep -q OFFLINE ||   herdr --session "$SESSION" workspace create --cwd "$HOME" --label "OFFLINE" --no-focus
herdr --session "$SESSION" workspace list 2>/dev/null | grep -q OPNDRM || {
  R=$(herdr --session "$SESSION" workspace create --cwd "$ROOT" --label "OPNDRM" --focus)
  P=$(echo "$R" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])')
  herdr --session "$SESSION" pane run "$P" "exec prime-agent --cwd $(printf '%q' "$ROOT")"
}
herdr --session "$SESSION" workspace list 2>/dev/null | grep -q "OPNDRM JC" || {
  R=$(herdr --session "$SESSION" workspace create --cwd "$ROOT" --label "OPNDRM JC" --no-focus)
  P=$(echo "$R" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])')
  herdr --session "$SESSION" pane run "$P" "exec jcode -C $(printf '%q' "$ROOT")"
}
herdr --session "$SESSION" workspace list 2>/dev/null | grep -q "OPNDRM NO-MISTAKES" ||   herdr --session "$SESSION" workspace create --cwd "$ROOT" --label "OPNDRM NO-MISTAKES" --no-focus

echo "==> Starting OFFLINE Prime Agent"
OFFLINE_PANE=$(herdr --session "$SESSION" workspace list 2>/dev/null | python3 -c '
import json,sys
data=json.load(sys.stdin)
for w in data["result"]["workspaces"]:
    if w.get("label")=="OFFLINE":
        print(w.get("root_pane_id",""))
' 2>/dev/null)
[[ -n "$OFFLINE_PANE" ]] && herdr --session "$SESSION" pane run "$OFFLINE_PANE" "exec prime-agent --cwd $(printf '%q' "$HOME")"

echo "==> Opening WezTerm with HERDR"
nohup wezterm start --cwd "$ROOT" --workspace "$SESSION" -- herdr --session "$SESSION" >"$HOME/.local/state/opndrm/prime/$SESSION-wezterm.log" 2>&1 </dev/null &

echo "==> Done. Open Dream workflow is ready in your VM."
