#!/usr/bin/env bash
# Thin local macOS bridge for CleanShot X's official URL-scheme API.
# It never automates the screen, captures, uploads, opens CleanShot, or changes
# privacy permissions unless an owner explicitly invokes open-record-screen.

set -euo pipefail

COMMAND="${1:-status}"
CONFIRMATION="${2:-}"
APP_PATH=""
RECORD_URL="cleanshot://record-screen"
MINIMUM_RECORD_VERSION="3.5.1"

usage() {
  cat <<'EOF'
Usage: ./integrations/cleanshot-x/cleanshot-x-bridge.sh <command> [flag]

Commands:
  status                 Inspect the installed CleanShot X bundle without opening it.
  prepare-recording      Print the verified URL-scheme action without opening it.
  open-record-screen     Open CleanShot's Record Screen mode only with
                         --confirm-open-record-screen.

This bridge does not start a capture automatically, control the screen, use
CleanShot Cloud, upload files, read credentials, or integrate with Buzz.
EOF
}

find_app() {
  local candidate
  for candidate in "/Applications/CleanShot X.app" "$HOME/Applications/CleanShot X.app"; do
    if [[ -d "$candidate/Contents" ]]; then
      APP_PATH="$candidate"
      return 0
    fi
  done
  return 1
}

app_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
}

version_at_least() {
  python3 - "$1" "$2" <<'PY'
import sys
def version(value):
    return tuple(int(part) for part in value.split('.') if part.isdigit())
actual, minimum = map(version, sys.argv[1:])
raise SystemExit(0 if actual >= minimum else 1)
PY
}

status() {
  if [[ "$(uname -s)" != Darwin ]]; then
    printf 'CleanShot X bridge unavailable: this is macOS-only.\n' >&2
    return 1
  fi
  if ! find_app; then
    printf 'CleanShot X bridge unavailable: CleanShot X.app was not found. No app was opened.\n'
    return 0
  fi
  local bundle_id version recording
  bundle_id="$(app_value CFBundleIdentifier)"
  version="$(app_value CFBundleShortVersionString)"
  recording="unavailable"
  if [[ -n "$version" ]] && version_at_least "$version" "$MINIMUM_RECORD_VERSION"; then recording="available"; fi
  cat <<EOF
CleanShot X: detected
Path: $APP_PATH
Bundle: $bundle_id
Version: $version
Record Screen URL scheme: $recording ($RECORD_URL; requires $MINIMUM_RECORD_VERSION+)
URL scheme invocation: not tested; CleanShot was not opened.
Cloud/upload: not used.
Buzz integration: not configured.
EOF
}

prepare_recording() {
  status
  if [[ -z "$APP_PATH" ]]; then return 1; fi
  printf '\nPrepared action (not invoked): %s\n' "$RECORD_URL"
  printf 'To open CleanShot Record Screen, run: %s open-record-screen --confirm-open-record-screen\n' "$0"
}

open_record_screen() {
  [[ "$CONFIRMATION" == --confirm-open-record-screen ]] || {
    printf 'Refusing to open CleanShot without --confirm-open-record-screen.\n' >&2
    return 2
  }
  status
  [[ -n "$APP_PATH" ]] || return 1
  local version
  version="$(app_value CFBundleShortVersionString)"
  version_at_least "$version" "$MINIMUM_RECORD_VERSION" || {
    printf 'CleanShot X %s is too old for the official Record Screen URL scheme.\n' "$version" >&2
    return 1
  }
  open "$RECORD_URL"
  printf 'Requested CleanShot Record Screen through its official URL scheme. Capture remains owner-controlled in CleanShot.\n'
}

case "$COMMAND" in
  status) status ;;
  prepare-recording) prepare_recording ;;
  open-record-screen) open_record_screen ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
