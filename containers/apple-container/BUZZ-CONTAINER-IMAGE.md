# Buzz Container image and future task bootstrap

`BuzzContainerfile` defines the project-local, Linux arm64 image for a future
one-Buzz-agent/one-coding-issue task VM. It is an image build artifact only.
It does not create a VM, clone a repository, authenticate to GitHub, configure
a model, start an agent, start a gate, expose a port, mount a host directory,
or patch the installed Buzz app.

## Immutable image contract

The reviewed source of truth is
[`buzz-container-image-manifest.json`](buzz-container-image-manifest.json).
It records the platform, non-root runtime posture, exact official artifact
URLs, versions, and SHA-256 values. `build-buzz-container.sh` validates that
the definition matches the manifest and refuses to overwrite an existing image
tag. A change requires a reviewed manifest/Containerfile update and a new tag;
tags are retained as immutable local evidence. The verified tag in the current
manifest is the known local baseline.

`opndrm-prime/buzz-container:0.1.0` is retained as a failed, non-usable local
build artifact: its JCode binary required a newer glibc than the Debian 12
base. `:0.1.1` proved the newer base/tool compatibility but is superseded by
the current `:0.2.0` manifest, which also sets JCode's documented telemetry
opt-out and adds a static-only Prime Agent install. Do not use `:0.1.0`,
`:0.1.1`, or `:0.1.2` for a task.

```sh
./containers/apple-container/build-buzz-container.sh
./containers/apple-container/verify-buzz-container.sh
```

Building downloads only the pinned public release artifacts described in the
manifest. The verification command runs one short-lived **image smoke
container**, not a named task VM, with a read-only root, dropped capabilities,
temporary writable directories, no network or DNS, no ports, no SSH, and no
host mounts. It checks only command versions and local image metadata.

## Installed tools and deliberate omissions

| Tool | Image state | Truthful limitation |
| --- | --- | --- |
| HERDR | Installed from its official Linux aarch64 release | Available as a terminal program only after a future task lifecycle is approved. |
| JCode | Installed from its official Linux aarch64 release | No model route, provider, account, or task is configured. |
| WezTerm | Deferred | The established Captain `open-opndrm` HERDR/WezTerm daily driver remains host-local and untouched. This headless task image does not install, configure, or recreate a WezTerm GUI or session layout. |
| Prime Agent | Installed, static-only | Official `0.7.2` checksum-verified tarball on pinned Node.js `22.23.2` Linux arm64. Lifecycle scripts are disabled; the verifier does not execute Prime Agent, so no daemon, session, tool/kernel bootstrap, model route, or provider configuration is created. |
| No Mistakes | Deferred as an inactive gate | It is not installed or started. Its official Linux path must be reviewed for a non-starting, no-credential installation before inclusion. |

The image includes neither a model download nor an Ollama route. It contains no
repository content, GitHub configuration, credentials, SSH keys, tokens,
source mounts, ports, browser service, screen capture, OpenAdapt, CleanShot,
remote provider, desktop streaming layer, or a replacement Captain HERDR/WezTerm layout.
JCode's documented anonymous telemetry is disabled with `JCODE_NO_TELEMETRY=1`
and `DO_NOT_TRACK=1`.

Prime Agent is installed from the exact public release package and checksum
origin used by its [official installer](https://app.primeintellect.ai/prime-agent/install.sh).
The image pins its supported Node.js Linux arm64 runtime and verifies both
artifact SHA-256 values. Its `npm` installation uses `--ignore-scripts`; this
intentionally differs from an interactive bootstrap because the image must not
launch tools, a kernel, a daemon, a session, or a provider connection. The
verifier checks Node, launcher, syntax, and installed package metadata without
calling `prime-agent`.

## Future task-time fresh checkout boundary

The current [`task-vm.sh`](task-vm.sh) remains intentionally offline and does
not yet select this image or bootstrap code. A future approved lifecycle
extension must keep those defaults until all of the following are explicitly
authorized for one task:

1. The invoking Buzz agent supplies a bounded task descriptor: immutable
   repository identity, approved commit/branch/ref, Wayfinder issue identifier
   and read-only context, expected setup command, evidence expectation, bot,
   and unique task name.
2. A **fresh checkout happens inside** that task VM at a task-private path
   such as `/workspace/repository`. No host repository, host worktree, shared
   volume, cache, or `virtiofs` mount may be used or reused.
3. Before that clone, the owner approves one separate checkout authority:
   either a narrowly installed GitHub App that provides a short-lived,
   repository-scoped read-only checkout credential, or an owner-approved
   scoped checkout mechanism with equivalent limits. The image, task
   descriptor, source repository, git config, and logs must never contain a
   credential or token.
4. The lifecycle grants a temporary, narrowly scoped network exception only
   for the approved checkout/setup stage, verifies the expected repository
   identity and ref inside the VM, then removes checkout authority and returns
   the coding phase to the no-network/no-DNS baseline. This exception is not
   implemented today.
5. Task work, validation, and evidence occur only in that fresh VM checkout.
   Evidence transfer and any GitHub write remain separate owner-approved
   effects. Push is never performed from this image or task lifecycle.

This is a design contract, not a current GitHub integration. There is no
GitHub App, token broker, clone action, setup action, Wayfinder write,
credential injection, repository mount, or push implementation in this
project-local slice.

## Lifecycle truth

When a future task completes, its evidence must be handled and approved before
the existing explicit stop/teardown gates are used. Failure, restart, and
normal stop never delete a task implicitly. The next task must receive a new
unique task name and a clean task-private workspace. Apple Container remains a
local Linux lightweight VM runtime; there is no remote cloud VM, SSH entry,
browser/terminal stream, GUI desktop, WezTerm session layout, or live Buzz
integration. The established Captain local daily driver is out of scope.

The next proposed visual/recording work is planning only in
[`BUZZ-VISUAL-AGENT-COMPUTER-PLAN.md`](BUZZ-VISUAL-AGENT-COMPUTER-PLAN.md).
It is not supplied by this image and does not change its headless limits.

## Official references

- [HERDR Linux installation](https://herdr.dev/docs/install/)
- [JCode installation](https://jcode.sh/docs)
- [Prime Agent installer](https://app.primeintellect.ai/prime-agent/install.sh)
- [Node.js release checksums](https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt)
- [Apple Container command reference](https://github.com/apple/container/blob/main/docs/command-reference.md)
