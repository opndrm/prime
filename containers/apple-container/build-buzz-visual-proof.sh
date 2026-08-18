#!/usr/bin/env bash
# Deliberately build-only: no container, stream, app, or task lifecycle starts.
set -euo pipefail
root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
image="opndrm-prime/buzz-container-visual-proof:0.2.6"
container image inspect "$image" >/dev/null 2>&1 && { echo "Refusing immutable tag overwrite: $image" >&2; exit 2; }
container image inspect opndrm-prime/buzz-container:0.2.0 >/dev/null
container build --platform linux/arm64 --file "$root/containers/apple-container/BuzzVisualContainerfile" --tag "$image" "$root/containers/apple-container"
"$root/containers/apple-container/verify-buzz-visual-proof.sh"
