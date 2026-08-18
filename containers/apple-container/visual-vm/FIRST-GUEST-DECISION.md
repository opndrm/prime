# First GUI Linux guest decision

## Recommendation

Use **Ubuntu Desktop 24.04.4 LTS for ARM64** as the first GUI Linux guest for
**Orchard > Compute > Agent Computers**.

This is an EFI-bootable desktop installer ISO for 64-bit ARM (ARMv8/AArch64),
which matches the Apple-silicon host and the direct GUI Linux flow documented
by Apple for `Virtualization.framework`. Apple names Ubuntu, alongside Debian
and Fedora, as a suitable distribution family for its GUI Linux VM sample; the
sample accepts an owner-selected installer ISO, creates a generic machine
identifier and EFI variable store, and presents the installer in
`VZVirtualMachineView`.

Ubuntu 24.04 LTS is the first guest recommendation because it is a stable
desktop release with an official ARM64 desktop ISO and an official checksum
manifest plus detached signature. It is a choice for the first visual proof,
not a claim that it is the only Linux distribution Agent Computers can support.

## Required integrity record before any download

The owner-approved asset record must pin all of the following together:

1. Distribution: Ubuntu Desktop 24.04.4 LTS.
2. Architecture: `arm64` / `aarch64`; reject any `amd64`, Raspberry Pi
   preinstalled image, daily build, or torrent-derived file.
3. Exact official ISO filename and HTTPS release URL from Ubuntu's release
   directory.
4. The matching line from Ubuntu's official `SHA256SUMS` file.
5. The matching official `SHA256SUMS.gpg` detached signature and the Ubuntu
   signing-key fingerprint used to verify it.
6. The ISO byte size published by the same official release directory.
7. The locally computed SHA-256, which must equal the signed official value
   before the ISO can be attached to a VM.
8. Retrieval date and the local owner-only asset location, without putting the
   ISO, its contents, or an access token in the repository.

The launcher must fail closed when any item is absent, malformed, mismatched,
or does not describe the exact ARM64 desktop ISO. A successful checksum alone
is insufficient unless the checksum manifest's detached signature is also
verified against a trusted Ubuntu release key.

## First-boot boundary

The ISO is only the installer medium. The first VM configuration remains the
reviewed, watch-only profile: EFI boot, a guest-only disk, entropy, virtio
graphics, and `VZVirtualMachineView`. It deliberately has no network device,
host directory, clipboard, keyboard/pointer attachment, audio input, USB
passthrough, credentials, repository, model connection, or recording.

The visual acceptance test is a separate Linux desktop inside Orchard with
WezTerm opening one empty HERDR session. It must not be called a task worker
or agent runtime proof.

## Owner-approved installer asset

The owner approved **Ubuntu Desktop 24.04.4 LTS for ARM64** as the first GUI
Linux installer. Its exact official ISO, signed checksum manifest, detached
signature, and Ubuntu CD Image Automatic Signing Key fingerprint are recorded
in `visual-linux-vm-manifest.json` before download. The installer can be
attached only after its completed local SHA-256 equals that signed record.

This approval covers asset acquisition and verification only. It does not
approve creating a VM bundle, configuring devices, starting a VM, or enabling
networking, host shares, clipboard, guest input, credentials, models, or
recording.

## Official references

- [Apple: Running GUI Linux in a virtual machine on a Mac](https://developer.apple.com/documentation/virtualization/running-gui-linux-in-a-virtual-machine-on-a-mac)
- [Apple: Virtualization framework](https://developer.apple.com/documentation/virtualization)
- [Ubuntu 24.04.4 LTS official release directory](https://releases.cdimage.ubuntu.com/ubuntu/releases/24.04/release/)
