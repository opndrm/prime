# Open Dream Prime

A local-first workflow installer for one person, one repository, and one visible workspace.

**WezTerm → HERDR → Prime Agent → reserved No Mistakes Gate → Buzz → GitHub**

Prime is not a dashboard, remote-run service, model host, or shared terminal. It is the public installer and guide for a calm, recoverable local workflow.

## Install on macOS

```sh
curl -fsSL https://opndrm.com/install-macos.sh | bash -s -- OPNDRM-APP
```

Choose `ADAM` or `FRNKLY.ONE` only when you have been assigned that private repository and can authenticate with your own GitHub account.

## What the installer does

- verifies Apple Command Line Tools and Homebrew;
- installs or verifies WezTerm, HERDR, Git, GitHub CLI, Prime Agent, No Mistakes, and Buzz;
- creates one named HERDR session for the selected lane;
- starts one Prime Agent workspace in the exact selected root;
- creates a visible **NO MISTAKES GATE — RESERVED (INACTIVE)** tab in that root;
- opens Buzz for the person’s own sign-in; and
- stops clearly if a prerequisite, checkout, visible workspace, or authentication step fails.

The installer never starts a No Mistakes run, creates a Buzz account or agent, edits GitHub work, handles credentials, or overwrites an existing checkout.

## Explicit exclusions

This repository and installer do **not** install or configure local model software, model downloads, model API keys, model providers, a dashboard, remote runs, or a shared terminal service. Any local model setup is personal, private, and outside this package.

## Daily workflow

1. Open the selected HERDR session in WezTerm.
2. Give Prime Agent one bounded work card: outcome, write boundary, quality gate, evidence, and stop condition.
3. Use Buzz for human/agent conversation after personal sign-in.
4. Keep code, reviews, and decisions in the selected repository’s GitHub workflow.
5. Use No Mistakes only when the repository-authorized workflow calls for it.

## Validation

```sh
npm run check
```

The public production target is the CREW Vercel team’s `opndrm_prime` project at `opndrm.com`.
