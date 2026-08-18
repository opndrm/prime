# Buzz-to-CleanShot X local adapter

This is a thin, project-local macOS host bridge around CleanShot X's official
URL-scheme API. It is not a screen-clicking agent, browser automation surface,
CleanShot Cloud connector, or live Buzz integration.

## Current contract

| Action | Command | Effect |
| --- | --- | --- |
| Inspect | `cleanshot-x-bridge.sh status` | Reads the local app bundle only; does not open CleanShot. |
| Prepare | `cleanshot-x-bridge.sh prepare-recording` | Prints `cleanshot://record-screen`; does not open CleanShot or capture. |
| Explicit launch | `cleanshot-x-bridge.sh open-record-screen --confirm-open-record-screen` | Opens CleanShot's native Record Screen mode through its official URL scheme. It does not start a recording, choose a region, or upload. |

The record command is intentionally named `open-record-screen`: CleanShot's
documented `cleanshot://record-screen` action opens its Record Screen mode.
Actual capture remains a visible owner action inside CleanShot.

## Safety boundaries

- No command runs automatically during checks or server start.
- `status` and `prepare-recording` do not launch external applications.
- No CleanShot Cloud account, upload action, credential, file path, or capture
  result is passed to the bridge.
- No TCC, Screen Recording, Microphone, Accessibility, or notification
  permission is requested or changed by this project.
- OpenAdapt remains an independent optional pilot under
  `evaluations/openadapt-desktop/`. In the product architecture, OpenAdapt is
  the future structured record/compile/replay provider, while CleanShot is
  optional native video evidence. The pilot's reliability is **not yet
  proven**; this adapter neither launches, configures, investigates, nor
  modifies it.
- Buzz wiring is **not configured**. A later local loopback provider may call
  only these fixed actions after a separate owner-approved design and live
  validation. Until then, do not report Buzz-to-CleanShot as connected.

## Official capability source

CleanShot documents `cleanshot://record-screen` as its Record Screen URL-scheme
action, available from CleanShot 3.5.1. The bridge never uses an `upload`
parameter or a Cloud API. See the [CleanShot X URL-scheme API](https://cleanshot.com/docs-api).
