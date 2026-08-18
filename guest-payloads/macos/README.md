# macOS guest first-boot payload

`first-boot-opndrm.sh` is a **guest-only skeleton**. It is intended to be run
inside a prepared macOS Agent Computer only after the owner explicitly
confirms that run. It is not a host bootstrapper, bridge utility, image
builder, downloader, or installer bundle.

## Invocation boundary

From inside the guest, the owner must provide the guest context assertion, a
safe VM identifier, and the confirmation flag:

```sh
OPNDRM_GUEST_CONTEXT=macos-guest \
OPNDRM_GUEST_VM_IDENTIFIER=<vm-id> \
./first-boot-opndrm.sh --owner-confirmed
```

Before it creates any roots, the payload requires all of the following:

- macOS/Darwin, a non-root non-`sudo` user, and a matching guest home;
- an image-provisioned `$HOME/.opndrm-guest-context` file containing exactly
  `macos-guest` (the script never creates this marker);
- no declared bridge environment; and
- no detected common shared/bridged filesystem mount.

Those checks fail closed. They are a boundary check, not a claim that a host
can safely execute this payload or that every virtualization arrangement can
be detected by shell alone.

## Ordered reconciliation contract

The stages intentionally mirror `AgentComputerGuestBootstrap`'s guest manifest:

1. `guest-local-directories` — ensure guest roots under the verified `$HOME`.
2. `opndrm-prime` — reconcile via a guest-local component hook.
3. `wezterm` — reconcile via a guest-local component hook.
4. `herdr` — reconcile via a guest-local component hook.
5. `prime-agent` — reconcile via a guest-local component hook.
6. `jcode` — reconcile via a guest-local component hook.
7. `no-mistakes-workspace` — explicitly mark inactive; never install or start it.
8. `buzz-identity` — ensure exactly `buzz-<vm-id>`.
9. `wayfinder-worktree` — ensure exactly `issue-<vm-id>` for that Buzz lane.
10. `openadapt` — reconcile via a guest-local component hook.

Each stage is idempotent: roots and state files are reconciled atomically;
reruns retain the one canonical Buzz identity and one Wayfinder worktree.
If another identity or worktree is present, the payload refuses to merge,
delete, or replace it.

## Component-source boundary

No component source, package, installer, repository, checksum, credential, or
network endpoint is included or assumed. In particular, this directory does
**not** claim that Open Dream Prime, WezTerm, HERDR, Prime Agent, JCode, or
OpenAdapt is available in the guest.

A later separately reviewed guest preparation may place an executable local
hook at:

```text
$HOME/.config/opndrm-prime/component-hooks/<component>.sh
```

The skeleton calls a supplied hook only with `--reconcile --component …
--directory …`; it never downloads a hook or falls back to a package manager.
Absent hooks produce a bounded `blocked` receipt and stop the reconciliation.
Review and owner approval of each component source remain separate from this
payload.

## Receipts and inactivity

Receipts are guest-local JSONL at
`$HOME/.config/opndrm-prime/receipts/first-boot/receipts.jsonl`. They contain
only fixed stage/outcome/detail values and timestamps—never paths, arguments,
environment values, credentials, or hook output. The log retains at most 40
records. No Mistakes has only an `inactive` state marker; this payload never
runs its installer, service, gate, pipeline, or any other activation action.

Do not run this payload from the host, through a bridge, or without the
owner-confirmation flag. Do not add host mounts, host repository paths,
checkout authority, credentials, network operations, or external side effects
to it.
