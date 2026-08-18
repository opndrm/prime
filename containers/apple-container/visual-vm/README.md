# Direct GUI Linux VM lane — design only

This directory records the approved next visual architecture for **Orchard >
Compute > Agent Computers**. It replaces the experimental container-frame
viewer as the display backend for the visual workspace. It does **not** replace
the separate Apple Container images or their disposable task-worker lifecycle.

## Chosen Apple-native architecture

The local Orchard build will use `Virtualization.framework`, not the lower-level
Hypervisor framework, to create an arm64 Linux virtual machine. The first VM
will follow Apple's GUI Linux sample shape:

1. `VZEFIBootLoader` boots an owner-approved arm64 Linux installer ISO.
2. `VZVirtioGraphicsDeviceConfiguration` supplies the guest display.
3. `VZVirtualMachineView` displays that guest desktop directly in Agent
   Computers, with native resize support.
4. A new VM bundle retains only the guest disk, EFI variable store, and machine
   identifier after the owner elects persistent mode.

Apple's required entitlement for this framework is
`com.apple.security.virtualization`. The lower-level Hypervisor framework and
its entitlement are not needed for this design.

## What must be supplied before implementation can start

No Linux image has been selected or downloaded. A future owner-approved
bootstrap must provide one **official** arm64 / aarch64 installer ISO and record:

- the distribution and exact release;
- the official release URL;
- the publisher's SHA-256 and signature provenance; and
- the verified local SHA-256 after the owner downloads it.

The initial install needs a VM disk image, EFI variable store, and generic
machine identifier. They must live only inside the selected VM bundle; the
repository and any host directory remain unshared.

## Owner-confirmed state locations

After a downloaded installer has a matching local SHA-256 and an owner-created
`installer-verification.json` record, the project-local state utility can make
an empty, owner-only bundle for one VM label. It creates locations only for the
guest installation disk, EFI variable store, and generic machine identifier.
The native helper creates a private sparse guest disk, a valid EFI variable
store, and a valid generic machine identity using Apple's Virtualization
framework. Orchard later consumes the exact resulting paths with its
installer-manifest schema; this utility does not boot a VM.

The utility fails closed until the manifest state is
`installer-downloaded-local-hash-verified`, the ISO is in the declared
project-local asset directory, its SHA-256 matches the pinned official value,
and the verification record confirms the pinned signing-key provenance. It
requires the exact owner confirmation flag before writing any state. It never
creates a host mount, network device, shared directory, clipboard, guest input,
USB attachment, recording setup, or external connection.

## Deliberate first-release boundary

The direct VM display is watch-only initially. No guest keyboard/pointer,
network, shared directory, clipboard, USB passthrough, audio input, credential,
repository, model route, recording, or host desktop capture is configured.

After a successful visual boot and a visible **WezTerm → HERDR** session, a
separate owner-approved Take Control design may add guest-only input. Buzz
Record/OpenAdapt remains a later, explicit container/VM-scoped feature and is
not enabled by this VM design.

## Viable next implementation step

Create a small Orchard-local VM service that loads
`visual-linux-vm-manifest.json`, refuses to run without a verified asset record,
and builds a `VZVirtualMachineConfiguration` with only EFI boot, disk, entropy,
graphics, and a display. Add `com.apple.security.virtualization` to the local
Orchard target. Do not add guest input or any sharing device in that slice.

## Owner-invoked first launch

After the approved Ubuntu arm64 GUI asset is verified, follow
[FIRST-LAUNCH-READINESS.md](FIRST-LAUNCH-READINESS.md). It records the exact
gated proof order: entitlement/build, immutable asset record, project-local
disposable VM state, direct `VZVirtualMachineView` attachment, non-host guest
pixels, and explicit stop/teardown. It is not a launcher and adds no sharing,
network, input, recording, model, credential, or Apple Container authority.

## Owner-confirmed first-boot handoff

`prepare-first-visual-linux-boot.sh` now creates the narrow owner-only handoff
between a verified Ubuntu installer and Orchard's dedicated Agent Computers
start-and-attach path. It invokes the existing state provisioner only after the
exact confirmation flag, then writes a private handoff document. It does not
boot a VM or launch Orchard. See
[FIRST-VISUAL-BOOT-HANDOFF.md](FIRST-VISUAL-BOOT-HANDOFF.md) for the exact
prerequisites before a later reviewed one-command visual boot can be added.

## Official references

- [Apple: Running GUI Linux in a virtual machine on a Mac](https://developer.apple.com/documentation/virtualization/running-gui-linux-in-a-virtual-machine-on-a-mac)
- [Apple: Creating and running a Linux virtual machine](https://developer.apple.com/documentation/virtualization/creating-and-running-a-linux-virtual-machine)
- [Apple: Adding the Virtualization entitlement](https://developer.apple.com/documentation/virtualization/adding-the-virtualization-entitlement-to-your-project)
