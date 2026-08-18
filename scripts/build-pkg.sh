#!/bin/bash
# Build OPNDRM VM.app as a .pkg installer for macOS.
# Usage: ./scripts/build-pkg.sh [output-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_DIR/apps/opndrm-vm"
OUTPUT_DIR="${1:-$REPO_DIR/dist}"
APP_NAME="OPNDRM VM"
BUNDLE_ID="com.opndrm.vm"
ENTITLEMENTS="/tmp/opndrm-vm-entitlements.plist"
VERSION="1.0.0"

mkdir -p "$OUTPUT_DIR"

echo "==> Building OPNDRM VM binary"
cd "$APP_DIR"
swift build -c release 2>&1 | tail -3

BINARY="$APP_DIR/.build/release/opndrm-vm"
[[ -f "$BINARY" ]] || { echo "Build failed"; exit 1; }

echo "==> Creating entitlements"
cat > "$ENTITLEMENTS" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.virtualization</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Code signing"
codesign --sign - --force --entitlements "$ENTITLEMENTS" "$BINARY"

echo "==> Building .app bundle"
APP_BUNDLE="$OUTPUT_DIR/OPNDRM VM.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/opndrm-vm"

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>opndrm-vm</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# PkgInfo
printf "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Copy guest helper and ff-record.sh to Resources
GUEST_HELPER="$APP_DIR/.build/release/opndrm-guest-helper"
if [[ -f "$GUEST_HELPER" ]]; then
    cp "$GUEST_HELPER" "$APP_BUNDLE/Contents/MacOS/opndrm-guest-helper"
    codesign --sign - --force --entitlements "$ENTITLEMENTS" "$APP_BUNDLE/Contents/MacOS/opndrm-guest-helper"
fi
if [[ -f "$APP_DIR/Sources/OPNDRMGuestHelper/ff-record.sh" ]]; then
    cp "$APP_DIR/Sources/OPNDRMGuestHelper/ff-record.sh" "$APP_BUNDLE/Contents/Resources/ff-record.sh"
    chmod +x "$APP_BUNDLE/Contents/Resources/ff-record.sh"
fi

# Copy first-boot script
if [[ -f "$REPO_DIR/guest-payloads/macos/first-boot-opndrm.sh" ]]; then
    cp "$REPO_DIR/guest-payloads/macos/first-boot-opndrm.sh" "$APP_BUNDLE/Contents/Resources/first-boot-opndrm.sh"
    chmod +x "$APP_BUNDLE/Contents/Resources/first-boot-opndrm.sh"
fi

echo "==> Building .pkg installer"
PKG_OUTPUT="$OUTPUT_DIR/OPNDRMVM-$VERSION.pkg"

# Use pkgbuild + productbuild for a proper installer
# Create a component package
COMPONENTS_DIR="$OUTPUT_DIR/components"
mkdir -p "$COMPONENTS_DIR"

# Create the root directory structure for the installer
INSTALL_ROOT="$OUTPUT_DIR/install-root"
mkdir -p "$INSTALL_ROOT/usr/local/bin"
mkdir -p "$INSTALL_ROOT/Applications"

# Copy the .app to /Applications
cp -R "$APP_BUNDLE" "$INSTALL_ROOT/Applications/"

# Create CLI symlink target
ln -sf "/Applications/OPNDRM VM.app/Contents/MacOS/opndrm-vm" "$INSTALL_ROOT/usr/local/bin/opndrm-vm"

# Build component package
pkgbuild \
    --root "$INSTALL_ROOT" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --scripts "$SCRIPT_DIR/pkg-scripts" \
    "$COMPONENTS_DIR/OPNDRMVM.pkg" 2>/dev/null || {

    # Fallback: simple pkgbuild without scripts
    pkgbuild \
        --root "$INSTALL_ROOT" \
        --identifier "$BUNDLE_ID" \
        --version "$VERSION" \
        "$PKG_OUTPUT"

    echo "==> Built: $PKG_OUTPUT"
    rm -rf "$INSTALL_ROOT" "$COMPONENTS_DIR" "$APP_BUNDLE"
    exit 0
}

# Build distribution with productbuild
productbuild \
    --package "$COMPONENTS_DIR/OPNDRMVM.pkg" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    "$PKG_OUTPUT"

echo "==> Built: $PKG_OUTPUT"

# Clean up
rm -rf "$INSTALL_ROOT" "$COMPONENTS_DIR" "$APP_BUNDLE"

echo ""
echo "  OPNDRM VM $VERSION"
echo "  Package: $PKG_OUTPUT"
echo "  Install: sudo installer -pkg \"$PKG_OUTPUT\" -target /"
echo ""
