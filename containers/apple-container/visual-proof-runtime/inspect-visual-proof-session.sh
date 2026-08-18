#!/usr/bin/env bash
# Inspection-only acceptance check for a running Buzz Container visual proof.
# It never invokes lifecycle commands, reads a frame, or prints a view token.

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)"
CONTAINER_NAME="opndrm-prime-buzz-container-visual-proof"
IMAGE_NAME="opndrm-prime/buzz-container-visual-proof:0.2.6"
SOCKET_DIR="$PROJECT_ROOT/.opndrm/buzz-container-view/visual-proof"
HOST_SOCKET="$SOCKET_DIR/view.sock"

fail() { printf 'Visual proof session check failed: %s\n' "$*" >&2; exit 1; }

command -v container >/dev/null 2>&1 || fail 'Apple Container CLI is not installed.'
container system status --format json >/dev/null 2>&1 || fail 'Apple Container service is not running.'
[[ -d "$SOCKET_DIR" ]] || fail 'Visual socket directory is absent.'
[[ -O "$SOCKET_DIR" ]] || fail 'Visual socket directory is not owned by the current Mac user.'
[[ "$(stat -f '%Lp' "$SOCKET_DIR")" == 700 ]] || fail 'Visual socket directory must have mode 0700.'
[[ -S "$HOST_SOCKET" ]] || fail 'Expected private Unix socket is absent.'
[[ -O "$HOST_SOCKET" ]] || fail 'Private Unix socket is not owned by the current Mac user.'

socket_count="$(find "$SOCKET_DIR" -maxdepth 1 -type s -print | wc -l | tr -d ' ')"
[[ "$socket_count" == 1 ]] || fail 'Exactly one Unix socket is required in the visual socket directory.'

inspected="$(container inspect "$CONTAINER_NAME" 2>/dev/null)" || fail 'Visual proof container is absent.'

# Keep the output to a pass/fail summary. The decoder intentionally omits
# environment values, process arguments, frames, terminal output, and tokens.
printf '%s' "$inspected" | python3 -c '
import json
import sys

expected_image, host_socket = sys.argv[1:]
record = json.load(sys.stdin)[0]
cfg = record.get("configuration", {})
status = record.get("status", {})
mounts = cfg.get("mounts", []) or []

def fail(message):
    print(f"Visual proof session check failed: {message}", file=sys.stderr)
    raise SystemExit(1)

if status.get("state") != "running":
    fail("visual proof container must be running")
if (cfg.get("image") or {}).get("reference") != expected_image:
    fail("visual proof image does not match the approved visual image")
if cfg.get("initProcess", {}).get("user", {}).get("raw", {}).get("userString") != "opndrm":
    fail("container user is not the approved non-root user")
if not cfg.get("readOnly"):
    fail("root filesystem is not read-only")
if set(cfg.get("capDrop", []) or []) != {"ALL"}:
    fail("all Linux capabilities must be dropped")
if cfg.get("networks", []) not in ([], None):
    fail("network attachments are present")
if cfg.get("publishedPorts", []) not in ([], None):
    fail("published TCP or UDP ports are present")
if cfg.get("ssh") not in (None, False, {}, []):
    fail("SSH configuration is present")

host_mounts = [m for m in mounts if (m.get("type") or {}).get("virtiofs")]
if host_mounts:
    fail("host mounts are present")

tmpfs_targets = {m.get("destination") for m in mounts if (m.get("type") or {}).get("tmpfs")}
required_tmpfs = {"/tmp", "/workspace", "/home/opndrm", "/run/buzz-container"}
if tmpfs_targets != required_tmpfs:
    fail("writable paths must be exactly the approved tmpfs targets")

print(json.dumps({
    "state": "running",
    "image": "approved visual proof image",
    "user": "opndrm",
    "readOnlyRoot": True,
    "capDrop": ["ALL"],
    "tmpfsPaths": sorted(tmpfs_targets),
    "hostMounts": 0,
    "networks": 0,
    "publishedPorts": 0,
    "ssh": False,
    "unixSockets": 1,
    "evidence": "inspection metadata only; no frames, terminal output, files, or tokens returned",
}))
' "$IMAGE_NAME" "$HOST_SOCKET"
