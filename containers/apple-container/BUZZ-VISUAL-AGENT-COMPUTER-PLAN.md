# Buzz Container native window, Visual Agent Computer, and Buzz Record plan

## Status and scope

The project-local native window shell is now implemented under
`apps/buzz-container-window/`. It is a SwiftUI/AppKit shell that opens as a
lower-right bubble, expands to a truthful Agent Computer status panel, and
minimizes or closes back to the bubble without stopping a task. It has no
lifecycle, IPC, stream, Buzz, recording, or OpenAdapt integration.

The current Buzz Container image remains intentionally headless. It has no
graphical desktop, stream, browser/terminal view, owner input path, or
OpenAdapt capture.

The saved Captain `open-opndrm` HERDR/WezTerm daily driver is a separate,
host-local workflow and is never read, modified, mirrored, or replaced by this
plan. The installed Buzz macOS app is never modified, now or later.

## Permanent product-surface decision

**Buzz Container is a separate native macOS pop-up window.** It may float over
Buzz like a computer-use overlay, but it is not a child view, plugin panel,
webview, automation target, or modification of Buzz. It does not inspect Buzz
windows, capture Buzz, inject into its process, or depend on a `buzz://` URL
scheme.

It is also not a temporary localhost web page. A later native window can use a
strictly local IPC contract to receive already-authorized lifecycle state, but
its visible surface is a macOS window rather than a browser route. The existing
temporary Agent Computer website and routes remain out of product scope.

The current Buzz CLI has no command that registers a local tool with an
existing managed agent. Its documented local `pack` operations validate or
inspect packs; they do not install a callable task-computer skill. Its actual
future tool seam is the ACP harness's one external stdio MCP command. See
[`BUZZ-EXTENSION-INVESTIGATION.md`](BUZZ-EXTENSION-INVESTIGATION.md) for the
evidence and limitations.

## Product outcome

For a single owner-approved task VM, the future Buzz Container native window
should show a task-specific Linux desktop stream and safe lifecycle state. It
will have one **Buzz Record** control. The control is a request/consent gate
for a future OpenAdapt structured capture, not a hidden capture action. A later
explicit owner take-control capability is separate from view-only access.

```text
Future local MVP only

Future Buzz invocation (not implemented; no relay route today)
  -> allowlisted local Buzz Container MCP/bridge request
  -> native Buzz Container macOS window (view-only)
  -> loopback-only VM-view gateway, when separately proven
  -> explicit Buzz Record consent gate
  -> OpenAdapt structured recipe artifacts
```

No component above exists today beyond the headless task image and lifecycle
guardrails. In particular, a Buzz workflow or CLI cannot yet open a native
Buzz Container window.

## Native shell choice

This project currently has no Tauri, Electron, Wails, SwiftUI, or AppKit app
target. It is a Node/static-site project, but the local host has Xcode 26.5 and
Swift 6.3.2 on Apple Silicon. The smallest maintainable shell is therefore a
project-local **Swift Package Manager macOS app** using **SwiftUI** for content
and a narrowly configured **AppKit `NSPanel`** for the floating window. It
introduces no third-party runtime, browser engine, background helper, app
automation, or dependency on the installed Buzz app.

When implemented, its AppKit configuration must be deliberately modest:

- regular native panel/window, owned only by the Buzz Container process;
- floating only while the owner chooses it, never above all macOS content;
- no accessibility, screen-recording, input-monitoring, or automation APIs;
- a visible provider/state/evidence summary before any future stream surface;
- close/minimize behavior that disconnects any future viewer capability, never
  stops a VM or deletes artifacts.

No native project, window, or UI is created by this planning change.

## Prerequisites and decisions

1. Validate a Linux arm64 desktop/compositor and stream approach in Apple
   Container without adding host mounts, public ports, SSH, or a remote
   provider. The current Apple Container target has no verified graphics or
   streaming layer, so this is a blocking technical proof—not an assumed
   capability.
2. Define a task-specific desktop image separately from the immutable
   headless coding image. It must retain non-root execution, dropped
   capabilities, default no-network/no-DNS, no credentials, no model route,
   and no host repository mount.
3. Define an explicit, loopback-only local viewer session contract: VM id,
   state, owner approval receipt, short-lived viewer capability, and a clear
   expiry/stop state. No remote listener, relay, or account is allowed in the
   local MVP.
4. Agree on permitted evidence/artifact handling before recording: a
   project-local recipe directory, redaction rules, retention, owner review,
   and explicit export/teardown approval. Never capture credentials, secret
   prompts, host desktop content, or unrelated applications.
5. Keep the existing OpenAdapt Desktop repair as a future optional provider.
   Its pilot reliability is not yet proven for this product workflow. Do not
   start a recording, replay, run, or workflow during planning or prerequisite
   validation.
6. Define the native-window request boundary before allowing Buzz to invoke
   anything. A request can only open an inert status window; it cannot start a
   VM, grant input control, create a recording, open CleanShot, or make a
   network request. A remote relay event must not directly launch a host GUI.

## Phased implementation sequence

### Phase 0 — native shell and local request contract

This is the exact next implementation slice after owner approval. It is
intentionally independent of graphics, VM startup, Buzz relay credentials, and
OpenAdapt.

1. Add `apps/buzz-container-window/` as a Swift Package Manager macOS app with
   no third-party packages and no distribution/install step.
2. Define a versioned, Unix-domain-socket-only `WindowRequest`/`WindowState`
   JSON contract under `containers/apple-container/`. The socket must live
   under the project-local `.opndrm/` state directory, have owner-only
   permissions, bind no TCP port, and reject malformed/expired requests.
3. Implement an inert `open-status` request only. It opens the native panel
   with fixed truthful values: `provider: Apple Container local`,
   `state: unassigned`, `remote: unavailable`, `live view: unavailable`, and
   `Buzz Record: unavailable`. It must not run `task-vm.sh`, use the Container
   CLI, read credentials, connect a relay, launch another app, or request
   macOS privacy access.
4. Add deterministic unit/contract tests plus a manual owner-only launch test
   for opening and closing that inert panel. The test confirms no listener
   beyond the Unix socket, no VM process, no recording process, and no host
   application automation.
5. Leave Buzz invocation disconnected. The first allowed caller is a local,
   developer-run test command with a fixture request. A future Buzz ACP/MCP
   bridge may be wired only after separate approval and must use the same
   request schema.

This slice is the native shell foundation, not a visualizer. It does not
create a desktop stream, a browser/terminal surface, a Buzz Record button, or
any Buzz/relay integration.

### Phase 1 — local desktop-stream proof

- Add a separate, pinned Linux desktop-profile image definition only after the
  graphics/compositor choice and its arm64 support are documented.
- Start one disposable, named visual task VM only under a fresh owner-approved
  test. The default task image remains headless.
- Expose view-only pixels to the native Buzz Container window through a
  loopback-only gateway with no public port, no remote service, no SSH, no
  filesystem browsing, and no terminal input.
- The native window shows provider `Apple Container local`, task/bot
  assignment, image digest, view state, and the actual disabled/failed reason
  when desktop readiness is absent. It does not claim a remote computer or
  cloud desktop.

### Phase 2 — later owner take-control

- Keep control unavailable until view-only is independently accepted.
- Require a new owner confirmation for each control attachment and render a
  visible local-control indicator in both viewer and VM.
- Bind control to the exact one-task VM and expire it on stop, viewer close,
  task transition, or a short lease timeout. No Buzz agent, remote user, or
  background process receives keyboard/mouse control.
- Use a narrow input bridge only after its local authorization, focus,
  clipboard, and emergency-disconnect behavior have acceptance tests. It must
  not target the Captain desktop or any application outside the task VM.

### Phase 3 — Buzz Record structured recipe

- Add one `Buzz Record` button to the future native Buzz Container window, not
  the installed Buzz app. With no supported direct CLI registration seam, Buzz
  remains an invoking agent/context provider only until an explicitly approved
  ACP/MCP bridge is configured.
- Button press first opens a local consent/preflight state that names the exact
  VM, window/display scope, input scope, artifact directory, and stop action.
  It performs no capture, permission change, app launch, or network request.
- Only a second fresh owner confirmation may call the optional OpenAdapt
  provider. It must surface all macOS permission prerequisites and fail closed
  if any are absent. The feature remains disabled while OpenAdapt pilot
  reliability is unproven.
- A successful future recording produces a bounded reusable setup recipe:
  declared inputs, VM/image version, setup actions, app/terminal trace,
  stop/evidence markers, redaction report, and schema version. It is not a
  replay authorization. Replay requires separate owner approval and a clean
  task VM.
- CleanShot remains optional video evidence through its existing prepare-only
  bridge; it neither replaces the structured recipe nor starts automatically.

### Phase 4 — later remote and phone access

- Keep this out of the local MVP. It requires a selected remote provider,
  account/billing approval, identity/authentication design, encrypted relay,
  consent/audit model, revocation, region/retention policy, and a new threat
  review.
- Phone access begins as owner-approved view-only with a local/remote state
  distinction. It receives no control or recording authority until the same
  explicit capabilities have passed separately.

## Safety boundaries

- One bot and one unique task VM; concurrency and explicit evidence/teardown
  gates remain in force.
- No host mount, source/repository mount, shared desktop, credentials, model
  provider setup, model download, default network, DNS, public port, SSH, or
  remote terminal authority.
- No recording on page load, button render, health check, test, or Buzz agent
  request. A record action requires explicit owner scope confirmation.
- No OpenAdapt live recording/replay/workflow execution in this plan phase.
- No modification of the installed Buzz macOS app, Captain HERDR/WezTerm
  daily driver, CleanShot settings, TCC/privacy permissions, or existing
  OpenAdapt pilot.
- No GitHub/Wayfinder write, checkout, push, deployment, account, or payment
  action. Evidence handling precedes explicit teardown; nothing is deleted by
  a failed stream or recorder attempt.

## Acceptance tests before claiming a local MVP

1. A desktop-capable Apple Container Linux arm64 proof is independently
   validated; otherwise the visualizer stays `desktop unavailable`.
2. Viewer binds only to loopback and refuses LAN/remote reachability, SSH,
   host mounts, source mounts, and terminal-input routes.
3. View state accurately shows `unassigned`, `provisioning`, `ready`,
   `stopped`, or `failed`; it never reports remote, streamed, or controllable
   before the matching implementation exists.
4. The target is the exact named task VM; the saved Captain desktop and other
   apps cannot become a capture or control target.
5. Owner take-control is absent by default, requires a visible local consent,
   and disconnects on expiry/stop. A Buzz agent cannot obtain input control.
6. The Buzz Record control is inert without its second confirmation: tests
   verify no OpenAdapt launch, no macOS permission prompt, no capture event,
   no CleanShot opening, and no artifact write.
7. A later OpenAdapt readiness test is limited to prerequisite inspection.
   It must fail closed on missing permissions, unsupported version, or an
   unproven pilot; it must not create a recording or replay.
8. Recipe schema, redaction, evidence handoff, and explicit teardown gates are
   validated using fixtures only before any owner-approved live capture.

## Current outcome

The native shell is ready as an inert, separately owned macOS app. Visual
streaming, task lifecycle IPC, owner control, Buzz Record UI, OpenAdapt
capture/replay, remote provider, and phone access remain **unimplemented**.
The ready components are the local headless Buzz Container image and the
truthful native shell around its future view state.
