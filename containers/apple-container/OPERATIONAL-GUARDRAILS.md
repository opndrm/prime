# Apple Container task-VM guardrails

This is the operational plan for OpenDream Prime's local Apple Container workload boundary. It is not a remote-VM, cloud-hosting, GUI-streaming, or shared-terminal service.

## Immutable known baseline

The known baseline is the reviewed `Containerfile` and its resolved Rust manifest digest. Build it only with `./verify.sh`; record `container --version` and `container system status --format json` with build or smoke evidence. Do not modify the baseline from inside a running task VM.

## One bot, one named task VM

Use `task-vm.sh` for a fresh disposable task boundary:

```sh
./containers/apple-container/task-vm.sh create auditor review-001
./containers/apple-container/task-vm.sh status auditor review-001
./containers/apple-container/task-vm.sh terminal auditor review-001
```

The name is deterministic: `opndrm-prime-task-<bot>-<task>`. Names must be unique per bot/task, and the launcher rejects a second running task for the same bot. It permits at most two running task VMs. States are `absent`, `running`, `stopped`, or an explicit unexpected/failure state from Apple Container; an inspect record is not proof that a task passed.

## Default isolation

Task VMs run as the image's non-root `opndrm` user with a read-only root, dropped capabilities, no network or DNS, no published ports, no SSH forwarding, and no host mounts. `/workspace`, `/home/opndrm`, and `/tmp` are task-private temporary filesystems. No credential, model route, GitHub identity, or source checkout is injected.

The persistent PRIME computer has its separately documented, project-local workspace mount. It is not the default task-VM policy and must not be reused as an unattended multi-task runner.

## Visible evidence and owner gates

`status` prints inspect metadata including actual mount, network, port, SSH, capability, and root-filesystem state. It never captures task files or terminal output. Before any artifact export, repository change, GitHub action, or push, the owner must explicitly approve scope and destination. No script here can push to GitHub.

Stop a task explicitly after evidence is reviewed:

```sh
./containers/apple-container/task-vm.sh stop auditor review-001
```

Teardown is a separate action and refuses without `--evidence-handled`. No normal stop, failure, restart, or clean reset deletes a task VM implicitly. After confirmed evidence handling, tear down the stopped task and create a new unique task name for the next clean reset.

## Explicit limitations

Apple Container is local Linux in lightweight VMs. This project has no remote cloud VM provider, remote desktop, browser streaming, graphical WezTerm/HERDR desktop, external network, or live model route. Any of those capabilities needs a separate owner-approved design and validation.
