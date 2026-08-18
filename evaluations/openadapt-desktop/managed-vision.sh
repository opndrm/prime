#!/bin/sh
# Validate, or explicitly launch, OpenAdapt Desktop with Prime's local vision cache.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
runtime_root="$script_dir/managed-vision-runtime"
source_root="$project_dir/vendor/openadapt-desktop"
python_bin="$project_dir/evaluations/openadapt-cli/.venv/bin/python"
desktop_app='/Applications/OpenAdapt Desktop.app'
desktop_bin="$desktop_app/Contents/MacOS/openadapt-desktop"
offline_config="$script_dir/offline-pilot.toml"
pilot_data_dir="$script_dir/pilot-data"

if [ ! -d "$source_root" ]; then
  echo "Missing inspected OpenAdapt Desktop 0.15.0 source: $source_root" >&2
  exit 1
fi

if [ ! -x "$python_bin" ]; then
  echo "Missing project-local OpenAdapt CLI environment: $python_bin" >&2
  exit 1
fi

if [ ! -f "$offline_config" ]; then
  echo "Missing offline pilot configuration: $offline_config" >&2
  exit 1
fi

OPENADAPT_VISION_RUNTIME_ROOT="$runtime_root" \
PYTHONPATH="$source_root${PYTHONPATH:+:$PYTHONPATH}" \
"$python_bin" -c '
from engine.managed_vision import activate_provisioned_vision_runtime

path = activate_provisioned_vision_runtime()
if path is None:
    raise SystemExit("Managed vision runtime is absent or fails OpenAdapt integrity checks")

import cv2
import numpy
import rapidocr_onnxruntime

print(f"Managed vision runtime verified: {path}")
print(f"numpy={numpy.__version__} cv2={cv2.__version__} rapidocr import=ok")
'

case "${1:-}" in
  '')
    echo "No app was launched. Use --launch only for an idle, user-operated session."
    ;;
  --launch)
    if [ ! -x "$desktop_bin" ]; then
      echo "Installed OpenAdapt Desktop Beta is missing: $desktop_bin" >&2
      exit 1
    fi
    echo "Launching OpenAdapt Desktop with the project-local vision runtime and isolated air-gapped pilot data. No recording is started."
    exec env \
      OPENADAPT_CONFIG_TOML="$offline_config" \
      OPENADAPT_DATA_DIR="$pilot_data_dir" \
      OPENADAPT_VISION_RUNTIME_ROOT="$runtime_root" \
      "$desktop_bin"
    ;;
  *)
    echo "Usage: $0 [--launch]" >&2
    exit 2
    ;;
esac
