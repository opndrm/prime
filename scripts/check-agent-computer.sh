#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIFECYCLE="$ROOT/containers/apple-container/agent-computer.sh"
SERVER="$ROOT/containers/apple-container/agent-computer-server.mjs"
CONTRACT="$ROOT/containers/apple-container/agent-computer-contract.mjs"
TASK_VM="$ROOT/containers/apple-container/task-vm.sh"
CLEANSHOT="$ROOT/integrations/cleanshot-x/cleanshot-x-bridge.sh"
BUZZ_CONTAINER_BUILD="$ROOT/containers/apple-container/build-buzz-container.sh"
BUZZ_CONTAINER_VERIFY="$ROOT/containers/apple-container/verify-buzz-container.sh"
BUZZ_CONTAINER_MANIFEST="$ROOT/containers/apple-container/buzz-container-image-manifest.json"
BUZZ_CONTAINER_FILE="$ROOT/containers/apple-container/BuzzContainerfile"
BUZZ_CONTAINER_SKILL="$ROOT/skills/buzz-container/SKILL.md"

fail(){ printf 'agent computer check failed: %s\n' "$*" >&2; exit 1; }
require(){ rg -F --quiet -- "$2" "$1" || fail "missing $2 in ${1#$ROOT/}"; }
forbid(){ ! rg -i -F --quiet -- "$2" "$1" || fail "forbidden $2 in ${1#$ROOT/}"; }

bash -n "$LIFECYCLE"
bash -n "$TASK_VM"
bash -n "$CLEANSHOT"
bash -n "$BUZZ_CONTAINER_BUILD"
bash -n "$BUZZ_CONTAINER_VERIFY"
node --check "$SERVER"
node --check "$CONTRACT"
python3 -m json.tool "$BUZZ_CONTAINER_MANIFEST" >/dev/null
node --input-type=module - <<'NODE'
import { agentComputerContract, lifecycleStates } from './containers/apple-container/agent-computer-contract.mjs';
const contract = agentComputerContract({
  state: 'stopped', runtime: 'ready', image: 'ready',
  workspace: { path: '/tmp/workspace', state: 'persistent', metadataPath: '/tmp/metadata.json' },
});
if (!lifecycleStates.includes('ready')) throw new Error('ready lifecycle state is missing');
if (contract.activeProvider.kind !== 'local') throw new Error('local provider is not active');
const remote = contract.providers.find((provider) => provider.kind === 'remote');
if (!remote || remote.available || remote.state !== 'unavailable') throw new Error('remote provider must remain unavailable');
NODE
require "$LIFECYCLE" '--network none'
require "$LIFECYCLE" '--cap-drop ALL'
require "$LIFECYCLE" '--read-only'
require "$LIFECYCLE" 'opndrm-prime-agent-computer'
require "$LIFECYCLE" 'metadata.json'
forbid "$LIFECYCLE" '--publish'
forbid "$LIFECYCLE" '--ssh'
forbid "$LIFECYCLE" 'docker'
require "$TASK_VM" '--network none'
require "$TASK_VM" '--cap-drop ALL'
require "$TASK_VM" '--read-only'
require "$TASK_VM" '--evidence-handled'
forbid "$TASK_VM" '--mount'
forbid "$TASK_VM" '--publish'
forbid "$TASK_VM" '--ssh'
require "$CLEANSHOT" 'cleanshot://record-screen'
require "$CLEANSHOT" '--confirm-open-record-screen'
forbid "$CLEANSHOT" 'computer-use'
forbid "$CLEANSHOT" 'action=upload'
require "$BUZZ_CONTAINER_FILE" 'herdr-linux-aarch64'
require "$BUZZ_CONTAINER_FILE" 'jcode-linux-aarch64.tar.gz'
require "$BUZZ_CONTAINER_FILE" 'USER opndrm'
forbid "$BUZZ_CONTAINER_FILE" 'wezterm'
forbid "$BUZZ_CONTAINER_FILE" 'OPENAI_API_KEY'
forbid "$BUZZ_CONTAINER_FILE" 'GITHUB_TOKEN'
require "$BUZZ_CONTAINER_MANIFEST" '"network_at_task_runtime": "disabled"'
require "$BUZZ_CONTAINER_MANIFEST" '"host_mounts_at_task_runtime": "disabled"'
require "$BUZZ_CONTAINER_MANIFEST" '"credentials_in_image": "none"'
require "$BUZZ_CONTAINER_MANIFEST" '"model_route": "not configured"'
require "$BUZZ_CONTAINER_MANIFEST" '"jcode_telemetry": "disabled"'
require "$BUZZ_CONTAINER_MANIFEST" '"prime_agent_runtime": "installed-static-only"'
require "$BUZZ_CONTAINER_MANIFEST" '"status": "deferred-headless-gui"'
require "$BUZZ_CONTAINER_FILE" 'JCODE_NO_TELEMETRY=1'
require "$BUZZ_CONTAINER_FILE" 'DO_NOT_TRACK=1'
require "$BUZZ_CONTAINER_FILE" 'node-v${NODE_VERSION}-linux-arm64.tar.xz'
require "$BUZZ_CONTAINER_FILE" 'prime-agent-${PRIME_AGENT_VERSION}.tgz'
require "$BUZZ_CONTAINER_FILE" '--ignore-scripts'
require "$BUZZ_CONTAINER_FILE" 'NPM_CONFIG_IGNORE_SCRIPTS=true'
forbid "$BUZZ_CONTAINER_FILE" 'PRIME_AGENT_BOOTSTRAP_TOOLS_ON_INSTALL=1'
forbid "$BUZZ_CONTAINER_FILE" 'PRIME_AGENT_BOOTSTRAP_KERNEL_ON_INSTALL=1'
require "$BUZZ_CONTAINER_SKILL" 'fresh inside the VM'
require "$BUZZ_CONTAINER_SKILL" 'GitHub App checkout'
require "$BUZZ_CONTAINER_SKILL" 'open-opndrm'
forbid "$BUZZ_CONTAINER_SKILL" 'git clone '
printf 'OpenDream Prime agent computer checks passed.\n'
