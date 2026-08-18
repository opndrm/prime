# First GUI Linux VM launch readiness — owner-invoked only

This checklist is for the first direct GUI Linux virtual machine shown in
**Orchard > Compute > Agent Computers**. It is not a launcher. It does not
download an asset, start a VM, open Orchard, or change the separate Apple
Container task-worker lane.

Use it only after the selected **official Ubuntu arm64 GUI installer asset**
has been approved and verified. A completed checklist permits the owner to
invoke one disposable proof VM; it does not create a persistent machine or
enable a general-purpose VM manager.

## Gated sequence

1. **Confirm the local Orchard build and entitlement.** Confirm that the
   selected local Orchard build contains the Agent Computers view and the
   `com.apple.security.virtualization` entitlement. It must surface a truthful
   unavailable state if the entitlement or required VM capability is absent; it
   must not use `Hypervisor.framework` or fall back to the retired
   container-frame viewer.
2. **Validate the boot manifest and immutable asset record.** Confirm the
   manifest identifies Ubuntu, its exact arm64 release, official publisher URL,
   checksum and signature provenance, then compare the local installer SHA-256
   against the recorded publisher value. Confirm the required installer boot
   details are present. A mutable file, OCI image, unverified download, or an
   asset outside the manifest record fails this gate.
3. **Create disposable state only in project-local VM storage.** Create a new
   proof bundle only under the project-local visual-VM storage area. The bundle
   contains only that proof VM's guest disk, EFI variable store, and machine
   identifier. It must be owner-only, uniquely labelled, and disposable. No
   repository, home directory, host folder, existing VM state, or Apple
   Container worker state may be mounted, copied, or reused.
4. **Build and validate the direct GUI VM configuration.** Configure the
   verified guest with its required boot loader, disk, entropy, virtio graphics,
   and direct display. The configuration validator must reject the launch when
   it finds a network device, host share, clipboard, guest keyboard or pointer,
   USB, serial device, audio input, credentials, model route, repository,
   recorder, or any Apple Container worker integration.
5. **Attach the exact VM to Orchard.** Only after the owner explicitly starts
   the proof, attach the exact `VZVirtualMachine` instance to
   `VZVirtualMachineView` in Agent Computers. The display must come directly
   from the guest; screenshot relays, browser streams, mock pixels, stale
   frames, and host desktop capture fail this gate.
6. **Verify visible guest pixels and the first workspace.** Prove that the
   pixels belong to the new Linux guest rather than the Mac, then reach the
   guest GUI desktop and open one empty WezTerm-to-HERDR session. Do not start
   Prime Agent, JCode, No Mistakes, a repository checkout, model provider, or
   Buzz Record during first proof.
7. **Stop and clean up safely.** Explicit Stop powers down only the selected
   proof VM and writes bounded lifecycle evidence. Teardown happens only after
   the owner confirms evidence handling, and removes only that proof bundle's
   guest disk, EFI store, and machine identifier together. It must preserve all
   host files, other VM bundles, Orchard source, and Apple Container workers.

## Explicitly prohibited in first launch

- Network or DNS
- Host shares, host folders, or repository mounts
- Clipboard, keyboard, pointer, USB, serial devices, audio input, camera, or
  host desktop capture/control
- Credentials, tokens, model servers, local AI routes, Prime Agent runtime,
  JCode runtime, No Mistakes, or GitHub access
- Recording, OpenAdapt, Buzz Record, replay, remote access, or external
  publication
- Any start, change, reuse, or teardown of an Apple Container task worker

## Readiness outcome

The first launch is blocked only while the guest installer asset or its
provisioning record fails verification, or while the local Orchard build lacks
the required entitlement/direct-view implementation. Once those are verified,
the owner may invoke the gated disposable proof sequence above. This checklist
does not make the visual VM persistent, interactive, networked, or recorded.
