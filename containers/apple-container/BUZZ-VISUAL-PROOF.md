# Visual Agent Computer proof

This separate build-only desktop proof image never replaces the headless coding
image or runs through `task-vm.sh`. It contains a pinned official Linux arm64
WezTerm package and the inherited pinned HERDR binary. Its entrypoint opens a
single empty, named HERDR session through the documented `--session` mode,
inside the container's disposable tmpfs-only home. It does not run Prime
Agent, JCode, No Mistakes, a provider/model, repository, authentication flow,
or task.

An explicit future proof must use a disposable container with non-root execution, read-only root, tmpfs-only writable paths, no host mounts, no network/DNS, no TCP ports, SSH, repository, or credentials. The only visual egress is Apple Container's Unix `--publish-socket` mapping for a private frame socket. A short-lived token gates PPM screenshots; the protocol has no mouse, keyboard, clipboard, terminal, browser, recording, OpenAdapt, or CleanShot capability.

No visual container, local server, or native app is started by these files.

## Visual workspace contract

When an owner later starts a disposable visual proof under the guardrails, the
only visual workspace is **WezTerm → HERDR** inside that isolated Linux
container. The window is watch-only: no keyboard, mouse, clipboard, terminal
command, browser, recording, or task-repository control is exposed through the
frame socket. WezTerm is intentionally installed only in this visual proof
image, never in the headless task image and never on the Captain's Mac.

The image keeps vendor provenance and license notices at
`/usr/local/share/buzz-container/licenses/`; the versioned manifest records
the verified artifact sources and SHA-256 values.
