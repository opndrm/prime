# Apple Virtualization implementation map for Agent Computers

This map turns the owner-selected Apple reference, **WWDC22: Create macOS or
Linux virtual machines**, into the implementation sequence for **Orchard >
Compute > Agent Computers**. It is a design and acceptance map only. It does
not select or download a Linux installer, modify Orchard, create a VM bundle,
start a VM, or enable any device.

## The product split

| Job | Apple-native mechanism | Product boundary |
| --- | --- | --- |
| Visible Linux computer | `Virtualization.framework` and an Orchard-native `VZVirtualMachineView` | A local GUI Linux VM that the owner can watch. |
| Disposable coding worker | Apple Container | Remains a separate, locked-down task-worker lane. |
| Low-level CPU and memory virtualization | `Hypervisor.framework` | Not used for Agent Computers. It would require implementing VM-device behavior ourselves. |

Apple's WWDC22 session distinguishes these layers: Hypervisor is the low-level
CPU/memory API; Virtualization is the high-level API for complete operating
systems. Agent Computers needs a full guest, direct graphical display, storage,
and managed lifecycle, so it uses Virtualization.

## Implementation order

### 1. Establish an Orchard VM service

Create a small local service in the Orchard Agent Computers feature that owns
only this visual-VM profile. It must load the project manifest, require the
Apple Virtualization entitlement, and expose truthful unavailable states before
it can create a `VZVirtualMachine`.

The service must not route through Orchard's general container-machine,
sandbox, terminal, model, or mount forms. It must not fall back to the retired
container frame bridge.

### 2. Verify the guest installer before it becomes a device

The first guest is an owner-approved, official ARM64 Linux GUI installer ISO.
Before the ISO can be attached, record its exact distribution and release,
official release location, publisher checksum and signature provenance, and
the locally verified checksum. Reject a different architecture, an OCI image,
a mutable checkout, or an unsigned/unverifiable asset record.

The initial VM bundle is created only after that verification. Its guest disk,
EFI variable store, and generic machine identifier live together in one
owner-only VM bundle. No host home, repository, or selected source tree is
shared into the guest.

### 3. Build the minimum complete Linux VM configuration

Apple's configuration model maps directly to one
`VZVirtualMachineConfiguration`. The first profile contains only:

| VM concern | Implementation direction | First-profile rule |
| --- | --- | --- |
| Boot | `VZEFIBootLoader` plus the verified ARM64 installer media | Linux installation only; no automatic guest bootstrap. |
| CPU and memory | Bounded virtual CPU and memory allocation, then validation | Values are explicit and recorded, never inherited from an arbitrary host profile. |
| Disk | One guest-only virtual block disk in the VM bundle | No host volume or repository sharing. |
| Entropy | Virtual entropy device | Required guest device only. |
| Display | `VZVirtioGraphicsDeviceConfiguration` plus one display | The guest's own pixels are the source of truth. |
| Native view | `VZVirtualMachineView` in Agent Computers | Direct VM view, not screenshots, web streaming, or a host capture. |

Validate the full configuration before starting. A configuration containing a
forbidden device must fail closed rather than silently omit a warning or start
with a broader profile.

### 4. Render the guest directly in Orchard

Attach the exact running `VZVirtualMachine` to its
`VZVirtualMachineView` inside Agent Computers. The window can use normal macOS
resize, hide, minimize, and full-screen behavior without claiming guest display
resize until the selected Linux guest demonstrates it. Until then, preserve the
configured resolution with honest letterboxing or scrolling—never stretch,
blur, or substitute a cached image.

The first visible proof is the Linux GUI desktop opening WezTerm into one empty
HERDR session. That proves a separate guest display exists. It does not prove a
repository checkout, an agent runtime, model access, recording, or a coding
task.

### 5. Define persistence and lifecycle deliberately

The first proof VM is disposable. A later persistent mode may retain the guest
disk, EFI store, and machine identifier as one named bundle so an owner can
pause, resume, or reopen a session. The UI must make the mode visible.

Stop is explicit and preserves bounded evidence. Teardown is separately
confirmed after evidence handling, and removes only the selected VM bundle as
one unit. It never targets host source directories, another VM, or the Apple
Container worker image.

## Safety defaults: intentionally deferred

The video explains that a VM can be given devices. Agent Computers starts by
giving it only the devices needed for a watch-only graphical Linux computer.
The following are **not** configured in the first profile:

- Guest keyboard and pointing devices. A later owner-approved Take Control
  lease may connect them only to this VM and must visibly expire on stop,
  pause, close, or timeout.
- Network, DNS, shared directories, clipboard, USB, serial devices, audio
  input, camera, credentials, repository checkout, model routes, and external
  services.
- Screen recording, OpenAdapt capture, replay, or Buzz Record. Those require a
  separate VM-scoped consent and acceptance design after direct display proof.
- Host desktop capture or control. This is never a feature of Agent Computers.
- macOS guest support. The framework supports macOS guests under a separate
  Apple restore-image, entitlement, and licensing lane; it is not folded into
  the first Linux proof.

## Optional later capability: Rosetta in Linux

Rosetta is not part of the first GUI Linux VM. If a future approved Linux tool
requires x86_64 binaries on an Apple-silicon guest, evaluate Apple's Linux VM
Rosetta support as a separately pinned, tested capability. It must not become
a reason to install an x86_64 guest, enable host-directory sharing, or weaken
the ARM64-first installer verification.

## Acceptance evidence

The implementation is complete only when the existing visual-VM acceptance
gates have evidence: verified installer record, validated minimal
configuration, an owner-started VM, direct `VZVirtualMachineView` attachment,
visible guest desktop, one WezTerm-to-HERDR session, explicit stop, and bounded
teardown. The receipt contains metadata only; never guest pixels, terminal
text, credentials, host paths, socket material, repository data, or clipboard
contents.

## Authoritative references

- [WWDC22: Create macOS or Linux virtual machines](https://developer.apple.com/videos/play/wwdc2022/10002/)
- [Apple: Virtualization framework overview](https://developer.apple.com/documentation/virtualization)
- [Apple: Running GUI Linux in a virtual machine on a Mac](https://developer.apple.com/documentation/virtualization/running-gui-linux-in-a-virtual-machine-on-a-mac)
- [WWDC23: Create seamless experiences with Virtualization](https://developer.apple.com/videos/play/wwdc2023/10007/)
