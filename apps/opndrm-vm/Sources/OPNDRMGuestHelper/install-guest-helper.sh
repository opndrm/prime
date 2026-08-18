#!/bin/bash
set -euo pipefail

# This installer is intentionally per-user: it needs neither sudo nor a
# writable machine-wide /usr/local/bin directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SERVICE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"

LABEL="com.opndrm.opndrm-guest-helper"
PLIST_NAME="${LABEL}.plist"
PLIST_SRC="${SCRIPT_DIR}/${PLIST_NAME}"
LAUNCH_AGENT_DIR="${HOME}/Library/LaunchAgents"
PLIST_DEST="${LAUNCH_AGENT_DIR}/${PLIST_NAME}"
USER_BIN_DIR="${HOME}/.local/bin"
BIN_DEST="${USER_BIN_DIR}/opndrm-guest-helper"
LOG_DIR="${HOME}/Library/Logs/BuzzBot"
RECORDINGS_DIR="${HOME}/Library/Application Support/BuzzBot/OpenAdapt/Recordings"

find_openadapt() {
    local discovered=""
    local candidate=""

    # Honour an explicitly supplied executable first, then the user's current
    # shell PATH, followed by common user and Apple Silicon package locations.
    if [[ -n "${OPENADAPT_PATH:-}" ]]; then
        discovered="${OPENADAPT_PATH}"
    else
        discovered="$(command -v openadapt 2>/dev/null || true)"
    fi

    local candidates=(
        "${discovered}"
        "${HOME}/.local/bin/openadapt"
        "/opt/homebrew/bin/openadapt"
    )
    for candidate in "${candidates[@]}"; do
        [[ -n "${candidate}" ]] || continue
        [[ "${candidate}" = /* ]] || candidate="$(cd "$(dirname "${candidate}")" && pwd -P)/$(basename "${candidate}")"
        if [[ -f "${candidate}" && -x "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    return 1
}

if ! OPENADAPT_CLI="$(find_openadapt)"; then
    cat >&2 <<'EOF'
error: OpenAdapt CLI was not found in PATH, ~/.local/bin, or /opt/homebrew/bin.
Install the CLI in this guest (not OpenAdapt Desktop), or rerun with
OPENADAPT_PATH set to its absolute executable path.
EOF
    exit 1
fi

printf '==> Using guest OpenAdapt CLI: %s\n' "${OPENADAPT_CLI}"
if ! "${OPENADAPT_CLI}" capture start --help >/dev/null 2>&1 || \
   ! "${OPENADAPT_CLI}" capture view --help >/dev/null 2>&1; then
    cat >&2 <<'EOF'
error: the selected executable does not expose the supported OpenAdapt
`capture start` and `capture view` CLI surfaces. No Desktop/dashboard fallback
will be installed or launched.
EOF
    exit 1
fi
echo "==> Building guest helper (release)..."
swift build --package-path "${SERVICE_DIR}" -c release
BUILD_BIN_DIR="$(swift build --package-path "${SERVICE_DIR}" -c release --show-bin-path)"
BIN_SRC="${BUILD_BIN_DIR}/opndrm-guest-helper"
[[ -x "${BIN_SRC}" ]] || { echo "error: built helper not found at ${BIN_SRC}" >&2; exit 1; }
echo "   [OK] Build complete: ${BIN_SRC}"

echo "==> Installing user binary to ${BIN_DEST}..."
mkdir -p "${USER_BIN_DIR}" "${LAUNCH_AGENT_DIR}" "${LOG_DIR}" "${RECORDINGS_DIR}"
chmod 0700 "${RECORDINGS_DIR}"
/usr/bin/install -m 0755 "${BIN_SRC}" "${BIN_DEST}"

echo "==> Installing user LaunchAgent to ${PLIST_DEST}..."
PLIST_TMP="${PLIST_DEST}.tmp.$$"
trap 'rm -f "${PLIST_TMP}"' EXIT
cp "${PLIST_SRC}" "${PLIST_TMP}"
/usr/bin/plutil -replace ProgramArguments.0 -string "${BIN_DEST}" "${PLIST_TMP}"
/usr/bin/plutil -replace EnvironmentVariables.OPENADAPT_PATH -string "${OPENADAPT_CLI}" "${PLIST_TMP}"
/usr/bin/plutil -replace EnvironmentVariables.OPENADAPT_RECORDINGS_DIR -string "${RECORDINGS_DIR}" "${PLIST_TMP}"
/usr/bin/plutil -replace StandardErrorPath -string "${LOG_DIR}/guest-helper.err.log" "${PLIST_TMP}"
/usr/bin/plutil -replace StandardOutPath -string "${LOG_DIR}/guest-helper.out.log" "${PLIST_TMP}"
/usr/bin/plutil -lint "${PLIST_TMP}" >/dev/null
chmod 0644 "${PLIST_TMP}"
mv "${PLIST_TMP}" "${PLIST_DEST}"
trap - EXIT

USER_ID="$(id -u)"
if launchctl print "gui/${USER_ID}" >/dev/null 2>&1; then
    echo "==> Loading user LaunchAgent..."
    launchctl bootout "gui/${USER_ID}/${LABEL}" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/${USER_ID}" "${PLIST_DEST}"
    launchctl kickstart -k "gui/${USER_ID}/${LABEL}"
    echo "   [OK] LaunchAgent loaded."
else
    echo "   [NOTE] No GUI launchd domain is active; the LaunchAgent will load at the next login."
fi

echo
echo "   BuzzBot guest helper installed for user $(id -un)."
