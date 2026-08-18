# Apple Container foundation

This directory is the project-local, auditable Linux-workload boundary for
OpenDream Prime. It uses Apple's `container` CLI to build a small Rust-ready
OCI image. The baseline itself does not run a service, expose a port, forward
SSH, install Firecrawl, or include OpenAdapt Desktop.

OpenAdapt Desktop remains a native macOS application when it is introduced.
Buzz/QM remains a future approval and visibility surface; neither has terminal
authority here.

## Host requirements

Apple's currently supported baseline is an Apple-silicon Mac running macOS 26
or later. Install the signed `container` package from Apple's release page,
then have the Mac owner run the one-time system setup:

```sh
container system start
```

The command may ask the owner to approve installation of Apple's recommended
Linux kernel. Do not automate or bypass that prompt. Confirm readiness with:

```sh
container system status --format json
```

Apple Container is under active development and its documentation notes that
CLI compatibility is guaranteed only within patch releases. Record the local
CLI version whenever this baseline is refreshed.

## Reproduce the local foundation

From the OpenDream Prime repository root:

```sh
./containers/apple-container/verify.sh
```

The command first checks the supported host and a responsive Apple Container
service. It then builds `opndrm-prime/apple-container:dev` from the immutable
Rust `1.97.1-slim-bookworm` manifest recorded in the Containerfile, and runs
only `rustc --version` in an ephemeral container. The smoke container has no
host mounts, published ports, SSH agent, inherited secrets, DNS configuration,
Linux capabilities, or writable root filesystem. It is removed automatically
after the command.

The image remains local after a successful check so later approved Rust work
does not need to repeat the baseline build. Rebuild it explicitly whenever the
Containerfile changes.

## PRIME local agent computer

`agent-computer.sh` is the first runnable local vertical slice. It starts one
named, long-lived Apple Container for **PRIME — Prime Agent**, then reuses it
on later starts. Its persistent workspace is the only host mount and is
strictly scoped to this checkout:

```text
.opndrm/agent-computers/prime/workspace
```

The container runs as `opndrm`, has a read-only root filesystem and temporary
`/tmp`, drops all Linux capabilities, disables network and DNS, publishes no
ports or sockets, and does not forward SSH or inherited credentials. The
workspace metadata records the local identity and an explicit `not-created`
snapshot state; it does not capture activity or make a snapshot.

```sh
# Status and lifecycle
npm run agent-computer:status
npm run agent-computer:start
npm run agent-computer:terminal
npm run agent-computer:stop

# Loopback-only local status/file view
npm run agent-computer
```

The local view binds only to `127.0.0.1:4177`, reads lifecycle status and
workspace file names, and exposes fixed lifecycle actions only. It does not
accept terminal input, file paths, credentials, or remote requests. The
browser view is a status/file surface; a browser inside the isolated computer
is deliberately deferred.

`clean` is available only as an explicit owner action. It removes exactly the
named PRIME container and its scoped local workspace. It never runs during a
normal stop or restart.

### Remote-ready, not remote-enabled

`agent-computer-contract.mjs` defines a provider-neutral identity, lifecycle
state model, persistent-workspace/snapshot metadata, and live-view/session
contract. The only functional provider is Apple Container on this Mac. The
remote provider record remains unavailable and has no provider selection,
account, billing configuration, credentials, VM, deployed service, or remote
terminal/session implementation.

## Isolated one-bot task VMs

[`task-vm.sh`](task-vm.sh) creates a separate, disposable local Linux VM for
one named bot and one named task. It is deliberately separate from the
persistent PRIME computer and defaults to no host mount, credentials, network,
DNS, port, SSH forwarding, or automatic capture. Read
[`OPERATIONAL-GUARDRAILS.md`](OPERATIONAL-GUARDRAILS.md) before creating one.

## Buzz Container tool image

[`BuzzContainerfile`](BuzzContainerfile) is a separate, project-local,
immutable-by-tag Linux arm64 tool image for future isolated Buzz coding tasks.
It does not alter the established Captain `open-opndrm` HERDR/WezTerm daily
driver, create a replacement layout, create a task VM, or enable a graphical
desktop. See [`BUZZ-CONTAINER-IMAGE.md`](BUZZ-CONTAINER-IMAGE.md) for the
pinned tool manifest, offline image verifier, and the future fresh-in-VM
GitHub checkout boundary.

## Deliberate next boundaries

- Add an application-specific Containerfile or compose-equivalent only with a
  defined Rust/Firecrawl work card and reviewed image/version choices.
- Add project source as a narrow, explicit mount only for a defined local
  development command; this baseline never mounts the repository by default.
- Keep Firecrawl configuration, API keys, browser services, and databases out
  of this foundation until their separate implementation is approved.
- Do not place a checkout of an upstream dependency outside this repository.
  No Apple Container fork or vendored checkout is necessary for this baseline.

## Official references

- [Apple Container README](https://github.com/apple/container#readme)
- [Apple Container releases](https://github.com/apple/container/releases)
- [Apple Container command reference](https://github.com/apple/container/blob/main/docs/command-reference.md)
