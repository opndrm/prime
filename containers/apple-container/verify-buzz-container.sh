#!/usr/bin/env bash
# Verify a prebuilt Buzz Container image without creating a task VM.

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
manifest="$script_dir/buzz-container-image-manifest.json"
image_name="$(python3 - "$manifest" <<'PY'
import json, sys
image = json.load(open(sys.argv[1], encoding="utf-8"))["image"]
print(f'{image["name"]}:{image["tag"]}')
PY
)"

if ! command -v container >/dev/null 2>&1; then
  printf 'Apple Container CLI is not installed.\n' >&2
  exit 1
fi

if ! container system status --format json >/dev/null 2>&1; then
  printf 'Apple Container service is not running.\n' >&2
  exit 1
fi

if ! container image inspect "$image_name" >/dev/null 2>&1; then
  printf 'Buzz Container image is missing: %s\n' "$image_name" >&2
  printf 'Build it explicitly with ./containers/apple-container/build-buzz-container.sh first.\n' >&2
  exit 1
fi

python3 - "$manifest" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1], encoding="utf-8"))
tools = {tool["name"]: tool.get("status") for tool in manifest["tools"]}
required = {"HERDR": "installed", "JCode": "installed", "Prime Agent": "installed-static-only", "WezTerm": "deferred-headless-gui"}
if {name: tools.get(name) for name in required} != required:
    raise SystemExit("Buzz Container manifest does not describe the required installed tools")
if manifest["runtime"].get("graphics_streaming") != "unavailable":
    raise SystemExit("The headless graphics limitation must remain explicit")
if manifest["runtime"].get("jcode_telemetry") != "disabled":
    raise SystemExit("JCode telemetry must remain disabled")
if manifest["runtime"].get("prime_agent_runtime") != "installed-static-only":
    raise SystemExit("Prime Agent must remain static-only")
PY

printf 'Running isolated, offline image smoke check: %s\n' "$image_name"
container run \
  --rm \
  --name opndrm-prime-buzz-container-image-smoke \
  --label org.opencontainers.image.title=opndrm-prime-buzz-container-image-smoke \
  --cpus 1 \
  --memory 768M \
  --cap-drop ALL \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /workspace \
  --tmpfs /home/opndrm \
  --network none \
  --no-dns \
  "$image_name" \
  bash -euc 'test "$(id -un)" = opndrm; test -w /workspace; test -w /tmp; test -w /home/opndrm; test "$JCODE_NO_TELEMETRY" = 1; test "$DO_NOT_TRACK" = 1; herdr --version; jcode --version; test "$(node --version)" = v22.23.2; test -x /usr/local/bin/prime-agent; node --check "$(readlink -f /usr/local/bin/prime-agent)"; node --input-type=module -e "import fs from \"node:fs\"; const p = JSON.parse(fs.readFileSync(\"/usr/local/lib/node_modules/prime-agent/package.json\", \"utf8\")); if (p.name !== \"prime-agent\" || p.version !== \"0.7.2\") process.exit(1)"; test -f /usr/local/share/buzz-container/manifest.json; ! command -v wezterm >/dev/null; echo buzz-container-image-smoke-ok'

printf 'Buzz Container image verification passed. This did not create a task VM, repository checkout, credential, network route, port, or graphical session.\n'
