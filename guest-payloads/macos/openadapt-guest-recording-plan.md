# OpenAdapt guest-local screen-recording consent plan

## Purpose and boundary

This is a **plan-only artifact** for a separately reviewed OpenAdapt integration
inside a prepared macOS guest. It does not install, launch, configure, capture,
upload, download, transmit, or delete anything. It does not include an OpenAdapt
adapter, screen API, audio API, microphone API, host path, host automation, or
network operation.

The future integration must operate only after the guest identity checks and
visible, task-specific owner consent described below succeed. It must never
record a host display or create host screenshots. Audio and microphone capture
are permanently out of scope for this plan.

## Visible consent text

Present this text in the guest before any future recording capability is
requested. The control which accepts it must be separate from any preselected
or implied option.

> **Guest screen-recording request**  
> You are in macOS guest `<guest-id>`. For this named task only, may OpenAdapt
> record the visible **guest display**? No host display, host screenshots,
> microphone, audio, keyboard input, mouse input, network upload, or automatic
> sharing is included. You will be asked to review and delete the guest-local
> recording before any certification.  
> Choose **I CONSENT TO GUEST-ONLY SCREEN RECORDING** to continue, or **Decline**
> to stop.

Required acceptance rules:

1. Display the full text in the guest and identify the task and guest ID.
2. Start with **Decline** selected; do not use a prechecked acceptance control.
3. Record a fresh affirmative choice for the named task. A missing, blank,
   malformed, expired, or declined choice is a refusal.
4. Do not treat a shell flag, prior task, login, or system permission as consent.
5. Surface a persistent in-guest recording indicator during any future capture.

## Guest-local lifecycle

1. **Plan** — validate the macOS guest context and show the visible consent
   text. No recording starts at this stage.
2. **Consent** — accept only a fresh explicit affirmation for the named task.
   No capability is enabled by this artifact.
3. **Future recording (not implemented)** — a separately approved integration
   may record only the active guest display, with audio and microphone disabled.
   It must store temporary output solely in a reviewed guest-local location.
4. **Review** — show the owner the guest-local recording and its basic metadata
   in the guest. The owner may decline certification.
5. **Delete** — provide an in-guest, affirmative delete control for the
   guest-local recording and derivative temporary files. The future integration
   must verify deletion before reporting completion. It must never delete host
   files.
6. **Certify** — only after review, the owner explicitly selects certification,
   and deletion choices are resolved, create a guest-local certification record
   with no media payload. This skeleton cannot certify a recording.

## Refusal and fail-closed rules

Refuse without side effects when any of these is true:

- the runtime is not a verified non-root macOS guest;
- the image-provisioned guest marker is absent or malformed;
- a host/bridge context is declared or a common shared filesystem is detected;
- the owner did not supply the exact explicit consent phrase for this invocation;
- the requested lifecycle stage is not `plan`, `review`, `delete`, or `certify`;
- any future request enables audio, microphone, host capture, host screenshots,
  input capture, a host path, or a network operation.

## Companion skeleton

`openadapt-guest-recording-consent.sh` is an inert, guest-guarded command-line
representation of the consent gate and four lifecycle stages. It prints plans
only: it creates no recording, files, receipts, certificates, processes, or
network requests. It is deliberately not an OpenAdapt launcher.
