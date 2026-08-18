#!/bin/bash
# OPNDRM VM - One-click Open Dream workflow installer
# Run inside any macOS VM after it boots.
# Usage: curl -fsSL https://opndrm.com/install | bash

set -euo pipefail

ROOT="${OPNDRM_ROOT:-$HOME/Desktop/opndrm}"
SESSION="opndrm"

echo ""
echo "  ╔═══════════════════════════════════════════════╗"
echo "  ║        Open Dream AI Workflow Installer        ║"
echo "  ╚═══════════════════════════════════════════════╝"
echo ""

# Homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "==> Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"

# Core tools
echo "==> Installing WezTerm, HERDR, Git, GitHub CLI, Python"
brew install git gh python herdr
[[ -d /Applications/WezTerm.app ]] || brew install --cask wezterm

# Handy (speech-to-text)
echo "==> Installing Handy"
brew install --cask handy 2>/dev/null || true

# Prime Agent
echo "==> Installing Prime Agent"
command -v prime-agent >/dev/null 2>&1 || curl -fsSL https://app.primeintellect.ai/prime-agent/install.sh | sh

# JCode
echo "==> Installing JCode"
command -v jcode >/dev/null 2>&1 || curl -fsSL https://jcode.sh/install | bash

# Ollama
echo "==> Installing Ollama"
brew install --cask ollama 2>/dev/null || true
open -gja Ollama 2>/dev/null || true
for _ in {1..30}; do curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break; sleep 1; done

# Prime Agent package
echo "==> Installing OPNDRM Prime package"
prime-agent package install git:github.com/opndrm/prime 2>/dev/null || true

# Configure Ollama for Prime Agent
echo "==> Configuring Ollama for Prime Agent"
python3 "$(curl -fsSL https://raw.githubusercontent.com/opndrm/prime/main/scripts/configure-prime-ollama.py -o /tmp/configure-prime-ollama.py && echo /tmp/configure-prime-ollama.py)" "$HOME/.prime/agent" 2>/dev/null || true

# Workspace
echo "==> Creating workspace at $ROOT"
mkdir -p "$ROOT"

# HERDR session
echo "==> Creating HERDR session with four workspaces"
herdr --session "$SESSION" workspace list >/dev/null 2>&1 || {
  herdr --session "$SESSION" server &
  for _ in {1..15}; do herdr --session "$SESSION" status server 2>&1 | grep -q running && break; sleep 1; done
}

# OFFLINE workspace
herdr --session "$SESSION" workspace list 2>/dev/null | grep -q OFFLINE ||   herdr --session "$SESSION" workspace create --cwd "$HOME" --label "OFFLINE" --no-focus

# OPNDRM workspace
herdr --session "$SESSION" workspace list 2>/dev/null | grep -q OPNDRM || {
  R=$(herdr --session "$SESSION" workspace create --cwd "$ROOT" --label "OPNDRM" --focus)
  P=$(echo "$R" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])')
  herdr --session "$SESSION" pane run "$P" "exec prime-agent --cwd $(printf '%q' "$ROOT")"
}

# OPNDRM JC workspace
herdr --session "$SESSION" workspace list 2>/dev/null | grep -q "OPNDRM JC" || {
  R=$(herdr --session "$SESSION" workspace create --cwd "$ROOT" --label "OPNDRM JC" --no-focus)
  P=$(echo "$R" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])')
  herdr --session "$SESSION" pane run "$P" "exec jcode -C $(printf '%q' "$ROOT")"
}

# OPNDRM NO-MISTAKES workspace
herdr --session "$SESSION" workspace list 2>/dev/null | grep -q "OPNDRM NO-MISTAKES" ||   herdr --session "$SESSION" workspace create --cwd "$ROOT" --label "OPNDRM NO-MISTAKES" --no-focus

# Start OFFLINE Prime Agent
OFFLINE_PANE=$(herdr --session "$SESSION" workspace list 2>/dev/null | python3 -c '
import json,sys
data=json.load(sys.stdin)
for w in data["result"]["workspaces"]:
    if w.get("label")=="OFFLINE":
        print(w.get("root_pane_id",""))
' 2>/dev/null)
[[ -n "$OFFLINE_PANE" ]] && herdr --session "$SESSION" pane run "$OFFLINE_PANE" "exec prime-agent --cwd $(printf '%q' "$HOME")"

# Buzz harness bridge
echo "==> Installing Buzz harness bridge"
mkdir -p "$HOME/.local/bin" "$HOME/.config/opndrm/prime"
cat > "$HOME/.local/bin/opndrm-prime-acp" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "$ROOT"
exec prime-agent --mode acp "\$@"
EOF
chmod 755 "$HOME/.local/bin/opndrm-prime-acp"
cat > "$HOME/.config/opndrm/prime/buzz-prime-agent-harness.json" <<EOF
{"agentCommand":"$HOME/.local/bin/opndrm-prime-acp","agentArgs":[],"provider":"ollama","workspace":"$ROOT"}
EOF

# Open WezTerm with HERDR
echo "==> Opening WezTerm with HERDR"
mkdir -p "$HOME/.local/state/opndrm/prime"
nohup wezterm start --cwd "$ROOT" --workspace "$SESSION" -- herdr --session "$SESSION" >"$HOME/.local/state/opndrm/prime/$SESSION-wezterm.log" 2>&1 </dev/null &

echo ""
echo "  ╔═══════════════════════════════════════════════╗"
echo "  ║  Open Dream workflow is ready in your VM!      ║"
echo "  ║                                                ║"
echo "  ║  OFFLINE     → Prime Agent + oMLX               ║"
echo "  ║  OPNDRM      → Prime Agent + Ollama             ║"
echo "  ║  OPNDRM JC   → JCode                            ║"
echo "  ║  OPNDRM NM   → inactive                         ║"
echo "  ╚═══════════════════════════════════════════════╝"
echo ""
