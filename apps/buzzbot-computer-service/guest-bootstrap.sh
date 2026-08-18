#!/bin/bash
# BuzzBot Guest Bootstrap — provisions a fresh macOS VM with the full OPNDRM stack
#
# Inside the guest VM, this runs the real OPNDRM installer which sets up:
#   WezTerm → HERDR → Prime Agent → JCode → Buzz → Ollama
#
# Usage (inside the guest):
#   curl -fsSL https://opndrm.com/install-macos.sh | bash -s -- OPNDRM-APP
#
# Or if this script is already copied into the guest:
#   bash /usr/local/bin/buzzbot-guest-bootstrap

set -euo pipefail

echo "=== BuzzBot Guest Provisioning ==="
echo "Installing full OPNDRM stack: WezTerm, HERDR, Prime Agent, JCode, Buzz, Ollama"
echo ""

# Run the real OPNDRM installer — same command used on the host
exec curl -fsSL https://opndrm.com/install-macos.sh | bash -s -- OPNDRM-APP