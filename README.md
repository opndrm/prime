# Open Dream Prime

A local-first workflow installer for one person, one repository, and one visible workspace.

**WezTerm → HERDR → Prime Agent → JCode → Buzz → GitHub**

Prime is not a dashboard, remote-run service, model host, or shared terminal. It is the public installer and guide for a calm, recoverable local workflow.

## Install on macOS

```sh
curl -fsSL https://opndrm.com/install-macos.sh | bash -s -- OPNDRM-APP
```

The public installer creates only the OPNDRM lane shown below.

## What the installer does

- verifies Apple Command Line Tools and Homebrew;
- installs or verifies WezTerm, HERDR, Git, GitHub CLI, Prime Agent, and Buzz;
- creates one `opndrm` HERDR session with exactly four ordered workspaces;
- starts Prime Agent in **OFFLINE** and **OPNDRM**, and JCode in **OPNDRM JC**;
- leaves **OPNDRM NO-MISTAKES** as an inactive visible shell;
- opens Buzz for the person’s own sign-in; and
- stops clearly if a prerequisite, checkout, visible workspace, or authentication step fails.

The installer never creates a Buzz account or agent, edits GitHub work, handles credentials, downloads a model, changes the selected default model, or overwrites an existing checkout.

## Explicit exclusions

The installer registers an existing local Ollama route with Prime Agent and the Buzz bridge without downloading a model or changing a default. It does not include personal model software, API keys, private local models, a dashboard, remote runs, or a shared terminal service.

## Daily workflow

1. Open the selected HERDR session in WezTerm.
2. Give Prime Agent one bounded work card: outcome, write boundary, quality gate, evidence, and stop condition.
3. Use Buzz for human/agent conversation after personal sign-in.
4. Keep code, reviews, and decisions in the selected repository’s GitHub workflow.
5. Keep code, reviews, and decisions in the selected repository’s GitHub workflow.

## Validation

```sh
npm run check
```

The public production target is the CREW Vercel team’s `opndrm_prime` project at `opndrm.com`.

## Execution roles

Prime Agent orchestrates approved work; JCode is installed from its official installer, then becomes the primary coding executor through its visible HERDR tab and bounded `jcode run`/ACP delegation.

## Standard HERDR layout

The installer creates exactly four workspaces in order: **OFFLINE**, **OPNDRM**, **OPNDRM JC**, and **OPNDRM NO-MISTAKES**. It creates no Auditor, ADAM, FRNKLY.ONE, or General Research workspaces. The No Mistakes workspace remains inactive during installation.

## Handy dictation

The macOS installer installs [Handy](https://handy.computer/), a local speech-to-text app. It does not grant Microphone or Accessibility permissions and does not download or select a transcription model; each owner completes those choices locally.

## Apple Container foundation

The isolated Linux foundation for later approved Rust/Firecrawl work lives in
[`containers/apple-container/`](containers/apple-container/). It is separate
from the Prime installer and intentionally contains no OpenAdapt Desktop,
approval tooling, JCode, or pipeline integration.

## PRIME local agent computer

The first agent computer is a local Apple Container-backed workspace for
**PRIME — Prime Agent**. It is persistent only inside this checkout at
`.opndrm/agent-computers/prime/`, runs as the image's non-root `opndrm` user,
and has no network, DNS, published ports, SSH forwarding, inherited
credentials, or writable root filesystem. Its one writable mount is the
project-local PRIME workspace.

First validate the baseline, then start the loopback-only view:

```sh
./containers/apple-container/verify.sh
npm run agent-computer
```

Open the printed `http://127.0.0.1:4177` address. From that local page, the
owner can see the true lifecycle state and scoped file index, start, stop,
restart, explicitly clean the PRIME workspace, and copy the command for a
real interactive container terminal. No terminal transcript or file contents
are exposed in the page. Browser control is intentionally not included yet.

The remote provider contract is present only as an unavailable placeholder.
No remote provider, account, billing setup, credential, VM, deployment, or
remote session is configured or created by this repository.

## CleanShot X local bridge

The optional [CleanShot X bridge](integrations/cleanshot-x/) is a fixed macOS
host adapter for CleanShot's official Record Screen URL scheme. It can inspect
the local bundle and prepare the action without launching CleanShot. Opening
the native Record Screen requires an explicit confirmation flag and never
starts a capture, uploads a file, or uses CleanShot Cloud. Buzz wiring is not
configured or claimed as live. OpenAdapt remains a separate optional pilot.

## Future recording providers

CleanShot is optional native video evidence through its local URL-scheme
bridge. OpenAdapt remains in the product architecture as the future optional
structured record/compile/replay provider; the existing local pilot is
preserved but its reliability is **not yet proven**. Neither provider is wired
to Buzz, and no OpenAdapt Vision/runtime investigation or implementation is
part of the current build.
