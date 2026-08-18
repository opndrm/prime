# Prime Agent + JCode Workflow

1. Install and sign in to JCode yourself; the Open Dream installer never handles a JCode account, provider, or credential.
2. Run the Open Dream installer for `OPNDRM-APP`.
3. HERDR opens exactly four ordered sidebar workspaces: **OFFLINE**, **OPNDRM**, **OPNDRM JC**, and **OPNDRM NO-MISTAKES**.
4. Prime Agent plans, delegates bounded approved coding tasks, reviews evidence, and retains workflow context.
5. JCode is the primary coding executor. It performs only the approved work card in the named checkout.
6. GitHub remains the code/review record. Buzz is personal coordination only after owner approval.

Prime may delegate a non-interactive approved task with `jcode run -C <root> --tool-profile full --json "<work card>"`, or use JCode ACP when an ACP client explicitly needs it. Never change providers, credentials, push, deploy, or start a gate without separate owner approval.

## Standard HERDR layout

The installer creates only **OFFLINE**, **OPNDRM**, **OPNDRM JC**, and **OPNDRM NO-MISTAKES**, in that order. The final workspace is an inactive visible shell; installation never starts or controls a No Mistakes pipeline.

## Handy dictation

The macOS installer installs [Handy](https://handy.computer/), a local speech-to-text app. It does not grant Microphone or Accessibility permissions and does not download or select a transcription model; each owner completes those choices locally.
