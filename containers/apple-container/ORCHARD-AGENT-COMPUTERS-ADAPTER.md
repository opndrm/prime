# Orchard Agent Computers visual adapter

This document is a migration contract, not an Orchard implementation or a
general-purpose launcher. It lets a future **Agent Computers** view consume an
*already running*, disposable Buzz Container visual-proof session without
changing the container's isolation boundary.

## Narrow lifecycle handoff

`orchard-agent-computers-lifecycle.sh` is the sole project-local, owner-invoked
handoff for this exact visual proof. It delegates to the existing guarded
visual-proof lifecycle; it is not a generic Orchard machine, image, sandbox,
or container control surface.

It offers only `preflight`, `status`, `start --confirm-start`,
`inspect-before-view`, `stop`, and `teardown --evidence-handled`. On an
explicit start it creates a fresh owner-only token file inside the private
session directory, passes it directly to the approved visual-profile launcher,
and never prints the token. The file survives only for that running proof and
is removed during evidence-handled teardown. A future Orchard receiver must
receive it in memory from a separately reviewed local handoff; neither Orchard
settings nor project records may persist it.

`inspect-before-view` is mandatory before any receiver may connect. It runs
the inspection-only session checker and refuses a missing or improperly
permissioned private token. The lifecycle adapter does not launch Orchard,
open a viewer, read a frame, or expose the socket/token through a command
result.

It refuses all generic image names and generic shell/container controls by not
accepting such arguments at all. Its delegated profile keeps host/repository
mounts, credentials, network/DNS, TCP/UDP ports, SSH, model bridges, remote
services, recording, OpenAdapt, CleanShot, browser automation, terminal/chat
input, keyboard/mouse input, clipboard, and files outside this phase.

The current native Buzz Container viewer is the reference consumer for this
contract. Orchard may reuse its narrow receive-only behavior, but Orchard
source, its installed application, and its ordinary container-management flows
are deliberately out of scope here.

## End-to-end local proof handoff

`orchard-agent-computers-visual-proof.sh` is the later owner-invoked proof
orchestrator. It is deliberately separate from the lifecycle adapter. It
accepts only a project-local custom Orchard `.app` path and an exact
`--confirm-visual-proof` confirmation. After lifecycle preflight, it delegates
the disposable start to this adapter, makes the published Unix socket
owner-only, and requires `inspect-before-view` before launching the local
Orchard executable.

The executable receives the socket path, short-lived token, and an owner-only
receipt path in its inherited process environment only. The token is never a
command-line argument, preference, log, or receipt value. The proof succeeds
only when the local Orchard Agent Computers view writes a bounded owner-only
receipt confirming it rendered a nonblank native-pixel frame. Until that
receipt seam exists in the locally built Orchard app, the script fails closed
and does not claim a frame reached the UI. Explicit `finish
--evidence-handled` stops and tears down the disposable proof.

## What an Agent Computers view may receive

For one owner-started visual-proof session, the view may receive only:

- one absolute, project-private Unix-domain-socket path;
- one short-lived, in-memory view token; and
- a sequence of one-frame **8-bit RGB PPM** replies, at no more than one frame
  per second.

The token is sent as one line to request a frame. It is never written to an
Orchard project record, log, command line, preference, crash report, or user
interface. The view does not persist the socket path or automatically reconnect
after the owner ends the session.

There is no HTTP, TCP, UDP, WebSocket, remote service, or cloud relay in this
adapter. It must not call a generic host-shell, container, or Orchard launch
command. Lifecycle ownership stays with the separately reviewed visual-proof
launcher; this adapter is a consumer only.

## Preconditions the view must verify

Before connecting, the receiving process verifies all of the following:

1. The socket path is absolute and resolves to a Unix stream socket owned by
   the current macOS user.
2. The socket's parent directory is owned by that same user and has mode
   `0700` or stricter.
3. The socket is owned by that same user and has no group or world permissions
   (`mode & 0077 == 0`).
4. The supplied session has independently passed the inspection-only visual
   proof check: approved visual image, non-root user, read-only root,
   capability drop, the four approved tmpfs targets only, zero host mounts,
   zero networks, zero published ports, and SSH disabled.

If any prerequisite fails, the view shows **Live view unavailable** and clears
any prior frame. It must not relax a permission check merely to make a mapped
socket work.

## One-way frame protocol

The client sends exactly the token plus a newline. The server closes the
connection after one reply. The client accepts a frame only when all limits
hold:

| Property | Required bound |
| --- | --- |
| Encoding | PPM P6, RGB, maximum value 255 |
| Dimensions | positive, at most 3840 by 2160 |
| Payload | exactly `width × height × 3` bytes, at most 24 MiB |
| Timing | bounded read timeout; at most one request per second |
| Direction | container to viewer image bytes only after the token |

The protocol provides no messages for keyboard, mouse, touch, clipboard,
files, terminal input, process control, browser control, task assignment,
recording, OpenAdapt, CleanShot, or microphone/camera access. **Buzz Record**
remains unavailable in this phase.

## Pixel-accurate rendering rule

The supplied PPM pixels are the visual proof. An Orchard view displays them at
their native pixel aspect ratio, centered with letterboxing when its viewport
does not match. It must use nearest-neighbor/no interpolation and must not
silently upscale, downscale, crop, blur, sharpen, alter colors, or synthesize a
frame. If the view cannot display the frame within its safe bounds, it reports
unavailable rather than substituting a degraded image.

The truthful active labels are:

- **Visual proof · disposable** for the task state;
- **Watch-only · local container** for the viewer state; and
- **Inside Apple Container — not this Mac** next to the displayed frame.

This is a visual proof of WezTerm showing one empty, disposable HERDR session.
It is not a coding task, Prime Agent session, JCode session, No
Mistakes run, model connection, repository checkout, or remote computer.

## Required acceptance evidence

Before an Orchard Agent Computers view is described as live, retain only safe
metadata proving:

1. the inspection-only session checker passes;
2. an authenticated, bounded 8-bit PPM frame was decoded;
3. the rendered view preserved the source dimensions/aspect ratio without
   interpolation; and
4. the view exposed no input, recording, lifecycle, or remote-control action.

The evidence must not include the view token, frame bytes, terminal contents,
repository data, credentials, or host files.
