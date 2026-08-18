# Buzz Container native window

This is the permanent standalone macOS shell for **Buzz Container**. It is not
a website, localhost server, Buzz app modification, extension, or automation
target. It does not inspect Buzz or the Captain's WezTerm/HERDR workflow.

## Current behavior

- Starts as a small lower-right floating bubble.
- Click the bubble to open the native Agent Computer panel.
- Hovering the bubble reveals the truthful current state.
- Minimize or close returns to the bubble. It never stops a task.
- Expand the panel to full screen when a future desktop view needs more room.
- Shows only fixed, safe state: Apple Container is local; no task is assigned;
  no VM, live view, recording, remote connection, or Buzz Record capability is
  active.

The shell does **not** create a VM, read task state, call Apple Container,
open a port, contact Buzz, use a credential, open another app, or invoke
OpenAdapt/CleanShot. It intentionally has no Stop action because it does not
own a task lifecycle yet.

## Future watch-only frame contract

The app remains inert by default. A separately approved local visual bridge may
opt in with an absolute owner-only Unix socket path and a short-lived view
token when launching this app. The client verifies that both the socket and its
parent directory belong to the current macOS user and are not group/world
accessible, sends only that token, and receives one bounded PPM frame per
connection at no more than one frame per second. A timeout or invalid frame
returns the UI to **Live view unavailable**. This protocol has no keyboard,
mouse, clipboard, file, shell, recording, or lifecycle input.

## Local build and manual preview

From this directory, build with `swift build` and run manually with
`swift run buzz-container-window`. Launching is an owner action and only opens
this app's own native window; it does not launch or control any other app.

## Future boundary

The future local bridge may request an inert status panel only after a separate
reviewed contract exists. Live VM pixels, Take Control, and Buzz Record remain
separate phases and must stay disabled until their own safety proofs pass.
