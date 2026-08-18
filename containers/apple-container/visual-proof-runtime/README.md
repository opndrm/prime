# Disposable Buzz Container visual-profile launcher

This folder supplies the **only** lifecycle entry point for the planned
watch-only Linux desktop proof. It is not a task VM, coding environment, Buzz
integration, localhost page, or recording path.

`visual-profile.sh plan` is safe to run and prints the exact contract.
`preflight` checks the image and local owner-only socket location without
starting a container. A real proof requires the owner to provide a new one-line
token file owned by them with mode `0600`, then explicitly choose `start
--confirm-start --token-file ...`.

The proof uses only the dedicated visual image, runs as the image's non-root
`opndrm` user with a read-only root, drops all capabilities, and gives writable
state only to tmpfs paths. There are no host mounts, network, DNS, TCP/UDP
ports, SSH, repository content, credentials, host terminal access, or input
channel. The only egress is one project-private Unix socket. Its token is not
printed by the launcher or the inspector.

After a proof, `stop` preserves inspection metadata. Destruction requires the
owner to confirm `teardown --evidence-handled`; it removes the container and
its private socket.

Before a real first proof, the remaining work is a separate owner decision to
permit the explicit start and a reviewed native viewer that reads only token-
gated image frames from the socket. It must not be wired to Buzz, recording,
repository checkout, external models, or host applications.
