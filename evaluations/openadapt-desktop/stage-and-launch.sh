#!/bin/sh
# Stage only a checksum-verified official DMG, then launch it without capture.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
artifacts_dir="$script_dir/artifacts"
staged_app="$script_dir/app/OpenAdapt Desktop.app"
mount_dir="$script_dir/.mount"

if [ ! -d "$artifacts_dir" ]; then
  echo "Missing $artifacts_dir. Follow README.md to add the official DMG and SHA256SUMS." >&2
  exit 1
fi

dmg_count=$(find "$artifacts_dir" -maxdepth 1 -type f -name '*.dmg' | wc -l | tr -d ' ')
if [ "$dmg_count" -ne 1 ]; then
  echo "Expected exactly one DMG in $artifacts_dir; found $dmg_count." >&2
  exit 1
fi

dmg=$(find "$artifacts_dir" -maxdepth 1 -type f -name '*.dmg' -print -quit)
checksums="$artifacts_dir/SHA256SUMS"
if [ ! -f "$checksums" ]; then
  echo "Missing official SHA256SUMS beside the DMG." >&2
  exit 1
fi

dmg_name=$(basename "$dmg")
expected=$(awk -v name="$dmg_name" '$2 == name || $2 == "*" name { print $1; exit }' "$checksums")
if [ -z "$expected" ]; then
  echo "SHA256SUMS has no entry for $dmg_name." >&2
  exit 1
fi

actual=$(shasum -a 256 "$dmg" | awk '{ print $1 }')
if [ "$actual" != "$expected" ]; then
  echo "Checksum mismatch for $dmg_name." >&2
  exit 1
fi

if [ -e "$staged_app" ]; then
  echo "Refusing to overwrite existing staged app: $staged_app" >&2
  exit 1
fi

mkdir -p "$mount_dir" "$(dirname "$staged_app")"
cleanup() {
  hdiutil detach "$mount_dir" >/dev/null 2>&1 || true
  rmdir "$mount_dir" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

hdiutil attach -readonly -nobrowse -mountpoint "$mount_dir" "$dmg" >/dev/null
app_count=$(find "$mount_dir" -maxdepth 1 -type d -name '*.app' | wc -l | tr -d ' ')
if [ "$app_count" -ne 1 ]; then
  echo "Expected exactly one app bundle in the verified DMG; found $app_count." >&2
  exit 1
fi

source_app=$(find "$mount_dir" -maxdepth 1 -type d -name '*.app' -print -quit)
ditto "$source_app" "$staged_app"

codesign --verify --deep --strict --verbose=2 "$staged_app"
if spctl --assess --type execute --verbose=4 "$staged_app"; then
  echo "Gatekeeper assessment passed."
else
  echo "Gatekeeper did not accept the beta app automatically; use the attended Finder Open flow only after this verified checksum." >&2
fi

echo "Launching idle OpenAdapt Desktop pilot. No recording or workflow is started."
open -n "$staged_app"
