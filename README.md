# Open Dream Prime

A local-first workflow installer for one person, one repository, and one visible workspace.

**WezTerm → HERDR → Prime Agent → JCode → Buzz → GitHub**

Prime is not a dashboard, remote-run service, model host, or shared terminal. It is the public installer and guide for a calm, recoverable local workflow.

## Install on macOS

```sh
curl -fsSL https://opndrm.com/install-macos.sh | bash -s -- OPNDRM-APP
```

Choose `ADAM` or `FRNKLY.ONE` only when you have been assigned that private repository and can authenticate with your own GitHub account.

## What the installer does

- verifies Apple Command Line Tools and Homebrew;
- installs or verifies WezTerm, HERDR, Git, GitHub CLI, Prime Agent, and Buzz;
- creates one named HERDR session for the selected lane;
- starts one Prime Agent workspace in the exact selected root;
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

Prime Agent orchestrates approved work; JCode is the primary coding executor through its visible HERDR tab and bounded `jcode run`/ACP delegation.

## Standard HERDR layout

The installer preserves two General Research workspaces—**GENERAL RESEARCH** for Prime Agent and **JCODE — GENERAL RESEARCH** for JCode—then creates a separate **JCODE — <LANE>** and **PRIME — <LANE>** pair for the selected app. General Research JCode uses the owner-selected local Ollama route; this Mac uses DeepSeek V4 Flash with High effort.

## Handy dictation

The macOS installer installs [Handy](https://handy.computer/), a local speech-to-text app. It does not grant Microphone or Accessibility permissions and does not download or select a transcription model; each owner completes those choices locally.
