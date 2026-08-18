#!/bin/bash
# BuzzBot Agent Computer — Installer
# Usage: curl -fsSL https://opndrm.com/buzzbot/install | bash

set -e

BOLD="\033[1m"
GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

BUZZBOT_DIR="$HOME/Library/Application Support/BuzzBot/AgentComputers"
INSTALL_DIR="/usr/local/bin"
SERVICE_SRC="$HOME/Desktop/opndrm_prime/apps/buzzbot-computer-service"
ENTITLEMENTS="/tmp/buzzbot.entitlements"

echo -e "${BOLD}=== BuzzBot Agent Computer Installer ===${RESET}"
echo ""

# 1. Check macOS version
echo -n "Checking macOS version... "
MACOS_VER=$(sw_vers -productVersion)
echo "$MACOS_VER"
if [[ "$MACOS_VER" < "14.0" ]]; then
    echo -e "${RED}BuzzBot requires macOS 14.0 or later${RESET}"
    exit 1
fi

# 2. Check for Xcode command line tools
if ! xcode-select -p &> /dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    echo "Please re-run this installer after Xcode tools installation completes."
    exit 1
fi

# 3. Create directory structure
echo "Creating BuzzBot directories..."
mkdir -p "$BUZZBOT_DIR/TrustedMacStates"
mkdir -p "$BUZZBOT_DIR/Recordings"
mkdir -p "$BUZZBOT_DIR/TrustedStateRecords"
chmod 700 "$BUZZBOT_DIR"

# 4. Build the service
if [ -d "$SERVICE_SRC" ]; then
    echo "Building buzzbot-computer-service..."
    cd "$SERVICE_SRC"
    swift build -c release 2>&1 | tail -3

    # Codesign with virtualization entitlement
    echo "Codesigning with virtualization entitlement..."
    cat > "$ENTITLEMENTS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.virtualization</key>
    <true/>
</dict>
</plist>
EOF
    codesign --sign - --force --entitlements "$ENTITLEMENTS" .build/release/buzzbot-computer-service

    # Copy service binary
    cp .build/release/buzzbot-computer-service "$INSTALL_DIR/buzzbot-computer-service"
    echo -e "${GREEN}✓ Service installed${RESET}"
else
    echo -e "${RED}Service source not found at $SERVICE_SRC${RESET}"
    echo "Clone the repo first: git clone https://github.com/opndrm/prime.git ~/Desktop/opndrm_prime"
    exit 1
fi

# 5. Install buzzbot CLI
echo "Installing buzzbot CLI..."
cp "$HOME/.local/bin/buzzbot" "$INSTALL_DIR/buzzbot" 2>/dev/null || true
chmod +x "$INSTALL_DIR/buzzbot" 2>/dev/null || true
echo -e "${GREEN}✓ CLI installed${RESET}"

# 6. Install guest bootstrap
cp "$SERVICE_SRC/guest-bootstrap.sh" "$INSTALL_DIR/buzzbot-guest-bootstrap" 2>/dev/null || true
chmod +x "$INSTALL_DIR/buzzbot-guest-bootstrap" 2>/dev/null || true

# 7. Create launchd plist for auto-start
echo "Creating launchd plist..."
cat > "$HOME/Library/LaunchAgents/com.opndrm.buzzbot.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.opndrm.buzzbot</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/buzzbot-computer-service</string>
        <string>--machine</string>
        <string>buzzbot-mac-002</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
PLIST
echo -e "${GREEN}✓ LaunchAgent created${RESET}"

# 8. Check for existing VM
if [ -d "$BUZZBOT_DIR/TrustedMacStates/buzzbot-mac-002" ]; then
    echo -e "${GREEN}✓ VM buzzbot-mac-002 found${RESET}"
else
    echo ""
    echo -e "${BOLD}No VM found. To create one:${RESET}"
    echo "  1. Download IPSW: softwareupdate --fetch-full-installer --full-installer-version 26.6.1"
    echo "  2. Run: buzzbot create buzzbot-mac-002"
fi

# 9. Connect to harnesses
echo ""
echo -e "${BOLD}Connecting to harnesses...${RESET}"
for harness in buzz prime; do
    buzzbot connect $harness 2>/dev/null && echo -e "${GREEN}✓ Connected to $harness${RESET}" || true
done

echo ""
echo -e "${BOLD}=== BuzzBot Install Complete ===${RESET}"
echo ""
echo "Commands:"
echo "  buzzbot show              Show the VM overlay"
echo "  buzzbot hide              Hide the overlay (VM keeps running)"
echo "  buzzbot stop              Stop the VM"
echo "  buzzbot list              List all VMs"
echo "  buzzbot status            Check daemon + VM status"
echo "  buzzbot connect <harness> Connect to an AI harness"
echo ""
echo -e "Run ${BOLD}buzzbot show${RESET} to see your agent computer."
