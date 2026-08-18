# OpenAdapt Desktop local pilot

This is a contained local evaluation surface for the official OpenAdapt Desktop
Beta. It is not an OpenDream product integration and it does not operate
OpenAdapt's capture, cloud, tray, or workflow runtime.

OpenAdapt Desktop is currently a Beta cockpit. Its official `desktop-v0.15.0`
release provides an Apple-silicon DMG for this Mac, but the macOS package is
ad-hoc signed rather than Developer ID notarized. Treat a successful launch as
package/host evidence only, not as workflow qualification.

## Stage a verified local app

1. Download the Apple-silicon DMG and its `SHA256SUMS` asset from the official
   [`desktop-v0.15.0` release](https://github.com/OpenAdaptAI/openadapt-desktop/releases/tag/desktop-v0.15.0).
2. Place both files in `evaluations/openadapt-desktop/artifacts/`. The artifacts
   remain local and ignored by Git.
3. From this repository root, run:

   ```sh
   ./evaluations/openadapt-desktop/stage-and-launch.sh
   ```

The script refuses an unverified DMG, mounts it read-only, copies its app only
to `evaluations/openadapt-desktop/app/`, verifies its code signature, reports
Gatekeeper's assessment without bypassing it, and launches the staged app.
It does not install to `/Applications`, change privacy settings, open a browser,
sign in, configure credentials, start a recording, or run a workflow.

If macOS shows the expected publisher warning after the checksum matches, use
the official, attended Finder path: Control-click the staged app, choose
**Open**, then confirm. Do not bypass that warning before the checksum check.

## Managed-vision recovery

The installed `desktop-v0.15.0` Beta defers its separately licensed vision
runtime until the first native/Flow recording attempt. This Mac's first
attempt could not provision that runtime: the OpenAdapt data directory had no
capture or `recording_started` audit event, and its runtime cache had no
validated payload. The engine's generic UI error hid that underlying startup
failure.

`managed-vision-runtime/` is an ignored, project-local repair cache. It
contains only the exact manifest-pinned NumPy, OpenCV, and RapidOCR runtime
that the installed `0.15.0` engine verifies. No user capture is stored there.

Run the following before a future, separately authorized recording:

```sh
./evaluations/openadapt-desktop/managed-vision.sh
```

The command validates the cache with OpenAdapt's own manifest rules and makes
no macOS permission request, recording, workflow, sign-in, or network call.
To launch the installed Beta with that cache for a user-operated session, use:

```sh
./evaluations/openadapt-desktop/managed-vision.sh --launch
```

The launcher passes `OPENADAPT_VISION_RUNTIME_ROOT`, a project-local data
directory, and the checked-in `offline-pilot.toml` only to that app process.
That configuration keeps storage air-gapped, uploads manual/review-gated, and
the experimental runner disabled. It does not change `/Applications`, the
existing `~/.openadapt` profile, TCC/privacy settings, or credentials.
Launching remains idle. Starting a recording is a separate, explicit user
action.

The normal installed profile currently has no valid managed-vision payload, so
launching OpenAdapt directly cannot pass the first Flow-recording prerequisite.
Use this project-local launcher for the pilot instead; its verified cache is
process-scoped and does not copy or modify the installed app.

## Safe pilot boundary

After launch, stop at the idle/onboarding surface. Do not press any recording,
replay, run, teach, cloud connection, or authentication control. Any later
capture requires a new, explicit user action even when macOS Screen Recording
and Accessibility permissions have been granted for this pilot.

The eventual permission check is limited to the OpenAdapt app itself:

- **Screen Recording** for display capture.
- **Accessibility** for keyboard/mouse capture.
- **Input Monitoring** for keyboard/mouse event capture.

The official `openadapt-desktop==0.15.0` Python source is present only under
`vendor/openadapt-desktop/` for read-only release behavior inspection. It is
not a fork and the installed app is not patched.

## Official references

- [OpenAdapt download page](https://openadapt.ai/download)
- [OpenAdapt Desktop repository](https://github.com/OpenAdaptAI/openadapt-desktop)
- [OpenAdapt Desktop lifecycle](https://docs.openadapt.ai/packages/openadapt-desktop/)
