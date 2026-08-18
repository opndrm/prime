# First visual Linux boot handoff — owner-confirmed preparation

`prepare-first-visual-linux-boot.sh` is the narrow transition between verified
Ubuntu installer assets and Orchard's dedicated **Agent Computers** lifecycle.
It is not a VM launcher and it is not a generic Orchard machine command.

## What it does

After an explicit owner confirmation, it rechecks the signed, checksum-matching
project-local Ubuntu ARM64 installer, invokes the existing owner-confirmed state
provisioner for one fresh owner-only VM bundle, then writes one owner-only
handoff document naming only that bundle and the selected local Orchard build.

The handoff requires Orchard's dedicated `startUbuntuDesktopInstaller` and
`attachOwnerStartedInstallerMachine` path. It rejects generic Machine/Sandbox
controls and the Apple Container task-worker lifecycle.

## What it never does

It never starts a VM, starts an app, downloads an asset, opens a window, or
calls Apple Container. Network, DNS, host shares, clipboard, guest input, USB,
audio, credentials, model access, recording, OpenAdapt, and remote access stay
disabled. It creates no repository checkout and has no GitHub authority.

## Exact prerequisites for the actual one-command first visual boot

- The verified Ubuntu Desktop 24.04.4 ARM64 ISO and owner-created verification
  record are in the declared project-local asset area.
- The selected local Orchard `.app` is inside this checkout, not a symlink, has
  a valid executable, and carries the Apple Virtualization entitlement.
- The local Orchard source includes the dedicated Agent Computers lifecycle and
  native `VZVirtualMachineView` host.
- A reviewed local Orchard launch receiver exists for this handoff schema. It
  must offer a separate final owner start action and call only the dedicated
  installer start-and-attach path.

The current preparer intentionally stops before that final receiver. That keeps
an external shell script from silently starting a guest or opening Orchard.

## Owner command shape

```sh
prepare-first-visual-linux-boot.sh prepare \
  --confirm-first-visual-boot \
  --label first-linux-proof \
  --app /absolute/path/to/project-local/Orchard.app
```

This creates state and a handoff only. It is not a successful Linux boot or
visible proof.
