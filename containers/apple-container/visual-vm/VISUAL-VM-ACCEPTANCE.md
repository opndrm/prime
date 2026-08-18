# Direct GUI Linux VM acceptance gates

This is the evidence checklist for the direct Linux VM shown in **Orchard >
Compute > Agent Computers**. It is deliberately separate from the Apple
Container task-worker lane and from the retired frame-bridge proof.

Do not call the visual Agent Computer successful until every required gate has
evidence from the selected local Orchard build. A static contract check is
available in `check-visual-linux-vm-contract.sh`; it validates the design
boundary only and cannot satisfy any runtime gate.

## Gate 0 — before boot

- The local Orchard target has the Apple Virtualization entitlement enabled and
  reports a truthful **VM unavailable** state when it is absent.
- A signed, official arm64 Linux GUI boot asset is recorded in the manifest:
  distribution, exact release, official source, publisher checksum/signature
  provenance, and the locally verified SHA-256.
- The boot asset architecture and its kernel/initramfs/rootfs set are verified
  before a VM disk is created. An OCI image, a mutable host checkout, or an
  unverified download cannot stand in for this asset record.
- The VM disk, EFI variable store, and machine identifier are new artifacts
  inside the selected owner-only VM bundle. No repository, home directory, or
  host folder is shared.

## Gate 1 — safe configuration

The exact `VZVirtualMachineConfiguration` evidence must show these are present:

- EFI or Linux boot loader appropriate for the verified guest;
- virtual block storage, entropy, virtio graphics, and one direct display; and
- no network device, shared-directory device, clipboard configuration,
  keyboard/pointer attachment, USB, serial, audio input, camera, model route,
  repository, credential, or recording device.

The configuration validator must reject a start if any forbidden device is
present. It must not silently fall back to the container-frame bridge or a
privileged helper.

## Gate 2 — direct native display

- Orchard starts exactly the selected disposable VM only after an explicit
  owner action.
- The exact `VZVirtualMachine` is attached to `VZVirtualMachineView` in the
  Agent Computers pane; the view must not synthesize a separate machine.
- The first visible pixels are from the Linux guest itself, not a screenshot,
  mock desktop, stale frame, browser stream, or host desktop capture.
- The guest reaches its GUI desktop and visibly opens WezTerm into one empty
  HERDR session. Prime Agent, JCode, No Mistakes, a repository, a model route,
  and Buzz Record are not started by this proof.

## Gate 3 — window and lifecycle behavior

- Normal window, full screen, resize, hide, and minimize preserve the selected
  VM state. They never stop it unless the owner explicitly chooses **Stop**.
- Automatic display resize is claimed only after the selected Linux guest
  demonstrates it. Otherwise the UI preserves the configured resolution with
  honest letterbox or scroll behavior; it never stretches or substitutes an
  image.
- Explicit Stop powers down the VM and reports bounded lifecycle evidence.
- Explicit Teardown removes only the selected disposable VM bundle after the
  owner confirms evidence handling. It must remove the guest disk, EFI store,
  and machine identifier together, and it must never remove a host checkout or
  another VM's state.

## Gate 4 — later capabilities stay separate

Before a pass at these gates, there is no Take Control lease. After the
watch-only proof, guest-only keyboard and pointer support requires a separate
owner-approved design, visible active-control state, expiry on stop/pause/close
or timeout, and immediate disconnect. Shared folders, network, clipboard,
recording, OpenAdapt, model access, and repository checkout each require their
own independent approval and acceptance evidence.

## Minimum evidence receipt

The implementation should write an owner-only, bounded receipt for a passing
proof. It may record the verified guest release, local checksum match, VM
identifier label, lifecycle transitions, direct-view attachment, first-guest-
frame time, and forbidden-device assertions. It must not record pixels,
terminal text, credentials, socket tokens, host paths, repository content, or
clipboard data.
