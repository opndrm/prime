# Buzz Record for visual Agent Computers

## Current capability

Buzz Record is an intentionally inert contract. Its guard can report the
unavailable state and can prove that a record request is blocked without a
validated visual session. It cannot start, stop, inspect, export, replay, or
store a recording.

This is deliberate: no OpenAdapt engine, Orchard session adapter, recording
button action, host permission, task VM, visual container, or application is
started by the contract.

## Future state machine

| State | Entry rule | Permitted result |
| --- | --- | --- |
| `unavailable` | Current release | Status only; no capture exists. |
| `blocked` | Missing/mismatched/failed visual validation or missing consent | Return safe reason only; do not create or restart anything. |
| `ready-for-owner-start` | Validated, already-running visual session plus task, scope, artifact, evidence, and start consent | Future recorder may be armed, not auto-started. |
| `recording` | Future in-container OpenAdapt adapter accepts explicit start | Container display/input trace only; task-private artifact. |
| `stopped-pending-evidence` | Explicit owner stop | Safe metadata only; artifact remains task-private until separately handled. |
| `evidence-handled` | Owner confirms evidence handling | The visual-session lifecycle may be independently stopped or torn down. |

`recording` is not implemented. The state table is a design constraint, not a
claim of current functionality.

## Validation requirements for a future `ready-for-owner-start`

The Orchard Agent Computers adapter must bind one record request to one
already-running visual session and prove all of the following for that exact
session:

- approved disposable visual image and non-root user;
- read-only root, dropped capabilities, and only task-private tmpfs writable
  paths;
- no host mounts, repository mounts, public network, DNS, published ports, or
  SSH;
- exactly one owner-only local visual-view socket, with no control/input path;
- same task identifier, visual-session identifier, and validated session epoch;
- explicit owner start consent, a recording scope, stop condition, and
  task-private artifact/evidence policy.

The adapter must reject stale status, a restarted/reused session, unknown
image, missing validation, or a session that has stopped. It must never start
or repair a container to satisfy a recording request.

## Capture and artifact boundary

The only allowable future source is the Linux display and input trace inside
the selected visual Agent Computer. Capturing the host Mac display, any host
app, host microphone, clipboard, host files, or the viewing socket is
forbidden.

A future recorder may write only inside a task-private container location such
as `/workspace/buzz-record/`. No artifact is mounted onto the host, copied to a
clipboard, uploaded, cloud-synced, or sent to a model. Artifact preview, export,
retention, encryption, and deletion require a separate owner-approved design.

## OpenAdapt boundary

OpenAdapt is the prospective in-container structured trace, compile, replay,
review, and repair provider. Its reliability is not yet proven. The current
contract neither installs, configures, launches, nor invokes it.

## Non-goals

- recording a visible Orchard window or any part of the host Mac;
- generic video capture, CleanShot control, browser automation, or a cloud
  recorder;
- remote access, model access, input control, clipboard/file transfer, SSH,
  ports, DNS, credentials, repository access, or GitHub effects;
- changing the visual Agent Computer lifecycle or the task VM baseline.
