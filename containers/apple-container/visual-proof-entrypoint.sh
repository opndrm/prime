#!/usr/bin/env bash
set -euo pipefail
: "${BUZZ_CONTAINER_VIEW_TOKEN:?A short-lived local viewer token is required}"
export DISPLAY=:99
# The visual proof owns an empty, container-local HERDR state directory.  This
# makes the workspace shown in WezTerm a real HERDR session without reading or
# mirroring the Captain's host configuration or layout.
export HERDR_CONFIG_PATH=/home/opndrm/.config/herdr/config.toml
export HERDR_SESSION=BUZZ-CONTAINER-VISUAL-PROOF
umask 077
mkdir -p "$(dirname "$HERDR_CONFIG_PATH")"
Xvfb :99 -screen 0 1024x640x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
fluxbox >/tmp/fluxbox.log 2>&1 &
# Do not accept a view request until the private X display is ready. Without
# this bounded readiness gate, an early screenshot request can make ImageMagick
# fail before the native viewer retries.
for _ in $(seq 1 50); do
  if xdpyinfo -display :99 >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
xdpyinfo -display :99 >/dev/null 2>&1
# This opens one empty, container-local HERDR session in WezTerm. It must not
# start Prime Agent, JCode, No Mistakes, an auth flow, or any task work. HERDR
# documents --session as its named persistent-session create/attach mode; the
# proof container's tmpfs-only home makes this state disposable with the VM.
wezterm start --always-new-process --config enable_wayland=false --config enable_tab_bar=false --config font_size=13 -- \
  bash -lc 'printf "Buzz Container visual workspace\\nWatch-only proof: isolated HERDR session.\\n"; herdr --version; exec herdr --session "$HERDR_SESSION"' \
  >/tmp/wezterm.log 2>&1 &
exec python3 /usr/local/lib/buzz-container/visual-frame-server.py
