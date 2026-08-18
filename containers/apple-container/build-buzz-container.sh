#!/usr/bin/env bash
# Build the project-local, immutable-by-tag Buzz Container image.
# This is an image build, not a task VM creation or task bootstrap.

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
manifest="$script_dir/buzz-container-image-manifest.json"

image_name="$(python3 - "$manifest" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1], encoding="utf-8"))
image = manifest["image"]
print(f'{image["name"]}:{image["tag"]}')
PY
)"

if ! command -v container >/dev/null 2>&1; then
  printf 'Apple Container CLI is not installed.\n' >&2
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  printf 'Buzz Container requires an Apple-silicon host; detected: %s\n' "$(uname -m)" >&2
  exit 1
fi

if ! container system status --format json >/dev/null 2>&1; then
  printf 'Apple Container service is not running. An owner must start it interactively.\n' >&2
  exit 1
fi

python3 - "$manifest" "$script_dir/BuzzContainerfile" <<'PY'
import json, re, sys
manifest_path, containerfile_path = sys.argv[1:]
manifest = json.load(open(manifest_path, encoding="utf-8"))
containerfile = open(containerfile_path, encoding="utf-8").read()
if manifest.get("schema_version") != "1.0":
    raise SystemExit("Unsupported Buzz Container image manifest schema")
if manifest["image"].get("platform") != "linux/arm64":
    raise SystemExit("Buzz Container image must target linux/arm64")
if manifest["runtime"].get("credentials_in_image") != "none":
    raise SystemExit("Buzz Container image must not include credentials")
if manifest["runtime"].get("model_route") != "not configured":
    raise SystemExit("Buzz Container image must not configure a model route")
if manifest["runtime"].get("jcode_telemetry") != "disabled":
    raise SystemExit("Buzz Container image must disable JCode telemetry")
if manifest["runtime"].get("prime_agent_runtime") != "installed-static-only":
    raise SystemExit("Buzz Container image must keep Prime Agent static-only")
if manifest["base"].get("reference") not in containerfile:
    raise SystemExit("Containerfile base does not match the manifest")
for tool in manifest["tools"]:
    if tool.get("status", "").startswith("installed"):
        for key in ("name", "version", "source", "sha256", "install_path"):
            if not tool.get(key):
                raise SystemExit(f'Missing {key} for installed tool {tool.get("name", "unknown")}')
        if not re.fullmatch(r"[0-9a-f]{64}", tool["sha256"]):
            raise SystemExit(f'Invalid SHA-256 for {tool["name"]}')
        if tool["version"] not in containerfile or tool["sha256"] not in containerfile:
            raise SystemExit(f'Containerfile does not pin {tool["name"]} to the manifest')
        if tool["name"] == "Prime Agent":
            runtime = tool.get("runtime", {})
            if tool.get("install_mode") != "official-verified-tarball-npm-ignore-scripts":
                raise SystemExit("Prime Agent must use the non-launching official package install mode")
            for key in ("name", "version", "source", "sha256", "checksum_source"):
                if not runtime.get(key):
                    raise SystemExit(f'Missing Prime Agent runtime {key}')
            if not re.fullmatch(r"[0-9a-f]{64}", runtime["sha256"]):
                raise SystemExit("Invalid Node.js SHA-256")
            if runtime["version"] not in containerfile or runtime["sha256"] not in containerfile:
                raise SystemExit("Containerfile does not pin the Prime Agent Node.js runtime")
            if "--ignore-scripts" not in containerfile:
                raise SystemExit("Prime Agent installation must disable lifecycle scripts")
PY

if container image inspect "$image_name" >/dev/null 2>&1; then
  printf 'Refusing to overwrite immutable Buzz Container tag: %s\n' "$image_name" >&2
  printf 'Review the manifest and use a new version tag for a new image.\n' >&2
  exit 2
fi

printf 'Building local Buzz Container image: %s\n' "$image_name"
container build \
  --platform linux/arm64 \
  --file "$script_dir/BuzzContainerfile" \
  --tag "$image_name" \
  --progress plain \
  "$script_dir"

printf 'Built immutable-by-tag local image: %s\n' "$image_name"
printf 'Run ./containers/apple-container/verify-buzz-container.sh for the offline image smoke check.\n'
