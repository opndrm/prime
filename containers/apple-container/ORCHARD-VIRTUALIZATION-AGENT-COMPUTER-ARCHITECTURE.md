# Orchard Agent Computers — Apple Virtualization architecture

## Decision

The visible **Agent Computer** is a native Linux virtual machine (VM) owned by
the local Orchard build. It uses Apple's `Virtualization.framework`, not the
Apple Container PPM/Unix-socket frame bridge, as its display backend.

Orchard embeds the guest display with `VZVirtualMachineView`. This is the
Apple-supported path for a real resizable Linux desktop that can later receive
guest-only input. It is not a request for Apple Container to expose a display
and it does not expose the owner's Mac desktop.

The existing Apple Container lane remains intact and separate:

| Lane | Purpose | Lifetime | Display | Default authority |
| --- | --- | --- | --- | --- |
| **Agent Computer VM** | Visible Linux workspace: WezTerm and HERDR first | Explicit owner-managed VM | Native `VZVirtualMachineView` in Orchard | View-only |
| **Buzz Container task worker** | Locked-down, disposable coding task worker | One task, then teardown | No GUI requirement | No host mount, network, credentials, or input |

Do not turn a disposable Buzz Container worker into a persistent VM merely to
make it visual. Likewise, do not give the visual VM a repository checkout,
credentials, provider route, recording capability, or host mount by default.

The prior frame bridge is retained only as local proof-of-concept evidence. It
is not the product runtime, it is not a fallback that silently starts, and it
must not be described as the Apple-native visual path.

## Product boundary

`Compute → Agent Computers` in the local Orchard source owns:

- a named VM record, explicit owner start/stop, and truthful state;
- the native guest display embedded in the existing Orchard SwiftUI surface;
- a visible distinction between **Watch only** and a later **Take Control**
  lease; and
- safe metadata such as guest image version, VM state, and evidence state.

It does **not** own Orchard's generic Machines, Containers, Sandboxes, local
model configuration, or generic run forms. Those surfaces may allow mounts,
networking, providers, or interactive terminals that are outside the Agent
Computers contract.

The Captain's host `open-opndrm` HERDR/WezTerm daily driver is never read,
modified, mirrored, or controlled. The installed Buzz desktop app is also not
modified.

## Guest asset contract

The first supported guest is a pinned Linux arm64 GUI image. It needs a
dedicated VM asset set, not an OCI image or a host folder mount:

1. A verified arm64 Linux kernel and matching initramfs/root filesystem.
2. A local writable guest disk image created for this VM only.
3. A recorded kernel command line and an exact guest image/version manifest.
4. A Linux desktop session that starts WezTerm and one empty HERDR session for
   visual proof.

The VM launcher uses `VZLinuxBootLoader`, a virtual block-storage attachment,
virtio graphics, and a `VZVirtualMachineConfiguration`. Guest assets live in a
project-local owner-only state directory. No host repository folder is shared
with the guest. Initial builds must verify checksums and architecture before a
VM can be created.

The first visual proof opens only WezTerm into the named, empty HERDR session.
JCode, Prime Agent, No Mistakes, repository checkout, model/provider setup,
network access, and recording remain unavailable until separately approved and
verified. This prevents a visual proof from being misrepresented as a coding
task.

## Native Orchard implementation

### 1. Virtual-machine controller

Add a small, dedicated `AgentComputerVMController` to the local Orchard source
instead of routing through a generic shell command. It owns one
`VZVirtualMachine` per explicit Agent Computer record and exposes only:

`preflight → create/restore → start → pause/save → resume → stop →
owner-approved teardown`.

The controller validates the complete configuration before boot and publishes
only bounded state to SwiftUI. It must never put a VM state file, guest disk,
terminal content, credential, or raw error payload into the UI log.

### 2. SwiftUI display host

Wrap `VZVirtualMachineView` in an `NSViewRepresentable` (or an equivalent
AppKit-owned child view) and mount it only in the Agent Computers detail pane.
The wrapper assigns the exact `VZVirtualMachine` from the controller and does
not create one as a SwiftUI side effect.

The view is full-screen capable through Orchard's normal window controls. Set
`automaticallyReconfiguresDisplay = true` so the guest display can resize with
the visible Agent Computers pane. Preserve a clear letterboxed/availability
state while the guest has not produced its first desktop frame; never draw a
mock desktop or reuse a stale frame.

### 3. Graphics and resize readiness

The VM configuration includes a virtio graphics device and a display
configuration suitable for the selected guest. Automatic resize is enabled
only after the chosen Linux guest is proven to support the corresponding
virtual display behavior. If it is unsupported or fails, render the guest at
its configured resolution with explicit scroll/letterbox behavior rather than
stretching, blurring, or claiming resize worked.

### 4. VM state and persistence

The first visual proof is disposable: a fresh VM starts from the verified
guest assets and is explicitly destroyed after evidence is handled.

Persistent Agent Computers are a later, explicit mode. They use their own
disk and metadata record, never a task-worker filesystem. When the selected
host/guest and framework APIs support saved machine state, the controller
pauses before saving and restores from the same validated configuration. VM
state files are sensitive, owner-only local artifacts. A restore failure
discards only the incompatible saved state after owner-visible evidence and
cold-boots the registered guest; it never reuses an unknown disk or task
workspace.

Do not promise Linux save/restore in the product until it has passed an
end-to-end Linux acceptance test on the supported macOS release. Cold boot
plus the VM's dedicated disk is the truthful fallback.

## Security defaults

The initial profile is deliberately a computer you can see, not a computer
that can reach your Mac or the internet.

| Capability | Initial state | Later change requires |
| --- | --- | --- |
| Host shared directory | Not configured | Separate owner approval, exact path, read/write mode, and threat review |
| Network device | Not configured | Separate owner approval and a declared endpoint/policy |
| Clipboard sharing | Not configured | Separate owner approval and guest-only acceptance tests |
| Guest keyboard/mouse | Not attached for watch-only proof | Per-session Take Control lease |
| Audio, camera, USB, serial ports | Not configured | Separate design and owner approval |
| Model/provider bridge | Not configured | Separate approved local-model lane |
| Repository/authentication | Not configured | Separate approved checkout authority |
| OpenAdapt/Buzz Record | Unavailable | Separate recording consent and acceptance proof |

Do not add a `VZVirtioFileSystemDeviceConfiguration`, network device,
clipboard configuration, input configuration, or host-side automation merely
because the framework supports it. The app must request each later capability
as an explicit, separately reviewable VM configuration change.

### Future guest-only Take Control

After watch-only acceptance, an owner may request a short-lived **Take
Control** lease for one identified VM. The controller first confirms the VM is
running, local, selected, and the exact session has a visible owner. It then
attaches only the guest keyboard and pointing-device configuration needed by
that VM view, shows a persistent control indicator, and expires control on
pause, stop, close, task transition, or timeout.

The lease grants no accessibility access, screen recording, input monitoring,
clipboard access, host terminal control, or control over the Captain's Mac.
An emergency **Disconnect control** action must immediately remove guest input
and preserve only safe lifecycle evidence.

## Implementation sequence and acceptance gates

1. **Foundation (no VM start).** Add the local Orchard entitlement and a
   configuration validator with fixture-only Linux asset metadata. Confirm the
   Agent Computers UI reports “VM not created” rather than a fake desktop.
2. **Boot proof.** Create one disposable Linux VM with no shared folders,
   network, clipboard, or input devices. The guest reaches its own GUI desktop
   and displays WezTerm plus one empty HERDR session.
3. **Native display proof.** Orchard embeds the same `VZVirtualMachine` in
   `VZVirtualMachineView`; verify the user sees current guest pixels directly,
   not a screenshot stream. Verify close/minimize never stops the VM unless
   the owner explicitly chooses Stop.
4. **Resize proof.** Confirm resize with the supported guest; otherwise retain
   the configured resolution honestly. Verify full screen and normal window
   modes preserve the guest display without a scaled placeholder.
5. **Lifecycle proof.** Verify explicit start, stop, teardown, and truthful
   error states. Add persistence only after the selected Linux guest passes
   save/restore testing.
6. **Control proof (later).** Add one owner-held, guest-only input lease and
   validate immediate expiry/disconnect. No agent receives this lease.
7. **Agent runtime and recording (later).** Only after the visual VM is proven:
   separately approve each tool runtime and the container-only OpenAdapt
   recording design.

At every gate, do not start a repository task, create credentials, connect a
model, or start No Mistakes. No commit, push, or deployment is part of this
architecture document.

## Required native application configuration

The local Orchard build requires the Apple Virtualization entitlement:

```text
com.apple.security.virtualization = true
```

It must be configured in the local Orchard target's signing/entitlements
before VM APIs are executed. The first code change must make entitlement
failure a visible **VM unavailable** state; it must not fall back to the old
frame bridge or a privileged command-line helper.

## Official Apple references

- [Virtualization framework overview](https://developer.apple.com/documentation/virtualization)
- [Running GUI Linux in a virtual machine on a Mac](https://developer.apple.com/documentation/virtualization/running-gui-linux-in-a-virtual-machine-on-a-mac)
- [VZVirtualMachine](https://developer.apple.com/documentation/virtualization/vzvirtualmachine)
- [VZVirtualMachineView](https://developer.apple.com/documentation/virtualization/vzvirtualmachineview)
- [Virtualization entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.virtualization)
- [WWDC23: Create seamless experiences with Virtualization](https://developer.apple.com/videos/play/wwdc2023/10007/)
- [WWDC22: Create macOS or Linux virtual machines](https://developer.apple.com/videos/play/wwdc2022/10002/)

The WWDC23 material demonstrates `VZVirtualMachineView` with automatic display
reconfiguration and describes pause/save/restore flow. Linux GUI boot assets
and guest display support must be verified against the dedicated Apple GUI
Linux guidance before implementation begins.
