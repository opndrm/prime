---
name: buzz-record
description: Governs an owner-explicit recording request for one already-validated visual Agent Computer, with host capture and external effects blocked.
---

# Buzz Record

Use Buzz Record only for an explicitly assigned visual Agent Computer that is
already live and has passed its watch-only validation. It is a future
container-only recording contract for OpenAdapt. It is not a host screen
recorder, a generic video tool, or an authority to start an Agent Computer.

## Required inputs

Before proposing a recording, obtain all of these exact inputs:

1. The assigned task identifier and the visual-session identifier.
2. A fresh validation result for that same session showing the approved visual
   image, non-root execution, read-only root, dropped capabilities, tmpfs-only
   writable paths, no host mounts, no public network or DNS, no ports, and no
   SSH.
3. An owner-visible statement of what workflow may be recorded and why.
4. Separate explicit owner confirmation to start, and later to stop, recording.
5. The task-private artifact policy, evidence status, and explicit stop
   condition.

If any input is missing, stale, mismatched, or fails validation, return
**recording blocked**. Do not start a VM, connect a model, or substitute host
screen capture.

## Allowed future target

The only future target is the already-validated Linux display of that visual
Agent Computer. Capture remains inside the container and may write only to a
task-private recording area, such as `/workspace/buzz-record/`. The host Mac,
its applications, its screen, its microphone, its clipboard, and its files are
always out of scope.

The frame-view socket is watch-only. It is not a recording source, input
channel, file-export path, or bypass for this contract.

## Lifecycle contract

The project-local guard is:

```sh
./containers/apple-container/buzz-record/buzz-record.sh status
./containers/apple-container/buzz-record/buzz-record.sh preflight --session-id <assigned-visual-session>
./containers/apple-container/buzz-record/buzz-record.sh start --session-id <assigned-visual-session> --confirm-start-recording
./containers/apple-container/buzz-record/buzz-record.sh stop --session-id <assigned-visual-session> --confirm-stop-recording
```

Today, `status` truthfully reports an unavailable recorder; `preflight` and
`start` intentionally block. No recorder adapter has been implemented. The
confirmation flags are retained to make future consent explicit, not to imply
that a capture can currently start.

After future stop, report only safe metadata: task/session association,
recording state, local artifact state, validation state, and evidence status.
Never return video frames, terminal text, files, tokens, prompts, credentials,
or a host path. Artifact review/export, if ever added, is a separate
owner-approved design; no host mount, clipboard, upload, cloud sync, or
automatic export is authorized by Buzz Record.

## OpenAdapt boundary

OpenAdapt is the future structured recorder, compiler, replay, review, and
repair provider. It is not installed, started, configured, or proven by this
skill. Do not launch OpenAdapt, change macOS privacy permissions, invoke a
browser, or claim that a recording is available.

## Hard boundaries

- Never capture the host Mac or a host application.
- Never start a visual container, viewer, model, network route, or task VM.
- No keyboard, mouse, clipboard, terminal, file transfer, browser automation,
  SSH, TCP/UDP ports, DNS, remote access, repository access, credentials, or
  external effects.
- A stop or teardown of the visual session is not recording consent. A recording
  request never changes the task lifecycle.
- Treat a missing live visual session as a hard block, never as an invitation to
  recreate one.
