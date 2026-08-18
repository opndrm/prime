#!/bin/sh
# Build and run the smallest safe Apple Container lifecycle for this project.
# It creates no ports, volumes, host mounts, SSH forwarding, or persistent
# application container. The built image remains local for later development.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
image_name="opndrm-prime/apple-container:dev"

if ! command -v container >/dev/null 2>&1; then
  echo "Apple Container CLI is not installed. See README.md in this directory." >&2
  exit 1
fi

host_arch=$(uname -m)
if [ "$host_arch" != "arm64" ]; then
  echo "Apple Container requires Apple silicon; detected architecture: $host_arch" >&2
  exit 1
fi

macos_major=$(sw_vers -productVersion | awk -F. '{ print $1 }')
if [ "$macos_major" -lt 26 ]; then
  echo "Apple Container is supported on macOS 26 or later; detected: $(sw_vers -productVersion)" >&2
  exit 1
fi

echo "Checking Apple Container service readiness..."
if ! container system status --format json; then
  cat >&2 <<'EOF'
Apple Container is installed but its system service is not ready for this user.
An owner must start it interactively with: container system start
That command may request permission to install Apple's recommended Linux kernel.
After the owner completes that system-owned step, rerun this script.
EOF
  exit 1
fi

echo "Building local Rust baseline: $image_name"
container build \
  --platform linux/arm64 \
  --file "$script_dir/Containerfile" \
  --tag "$image_name" \
  --progress plain \
  "$script_dir"

echo "Running isolated lifecycle smoke check..."
container run \
  --rm \
  --name opndrm-prime-container-smoke \
  --label org.opencontainers.image.title=opndrm-prime-container-smoke \
  --cpus 1 \
  --memory 512M \
  --cap-drop ALL \
  --read-only \
  --no-dns \
  "$image_name" \
  rustc --version

echo "Apple Container foundation is ready."
