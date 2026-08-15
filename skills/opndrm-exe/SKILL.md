---
name: opndrm-exe
description: Register and use Exe.dev private task sandboxes for ADAM or FRNKLY.ONE app work with Prime Agent. Use when a teammate asks to set up Exe, create an ADAM or FRNKLY.ONE sandbox, run Prime Agent in an isolated VM, or prepare a Mac-app No Mistakes gate.
---

# OPNDRM Exe Sandboxes

Use Exe only as a **private, disposable Linux builder** for one bounded ADAM or FRNKLY.ONE task. It does not replace the Mac/Xcode validation lane.

## One-time teammate registration

1. Ask the teammate to run `ssh exe.dev` in their own Terminal and complete Exe registration.
2. Before accepting a first connection, verify the displayed host fingerprint is exactly:
   `SHA256:JJOP/lwiBGOMilfONPWZCXUrfK154cnJFXcqlsi6lPo`
3. Verify registration without changing anything: `ssh exe.dev whoami` and `ssh exe.dev ls -l`.
4. Never disable host-key checking or accept an unverified fingerprint.

## Per-repository access

- Ask the repository owner to install/authorize the Exe GitHub App for only the needed repository.
- Create a separate, least-privilege GitHub integration for `opndrm/ADAM` or `opndrm/Frnkly.one`. Use read-only unless the owner explicitly approves branch pushes.
- Use an attached Exe LLM integration. Do not copy API keys, expose local Ollama, or attach personal Buzz credentials.

## Create a task sandbox

First confirm the lane, repository, branch, task name, intended writes, tests, and stop condition. Then use a unique lowercase name such as `opndrm-adam-login-test` or `opndrm-frnkly-one-profile-fix`:

```bash
ssh exe.dev new --name <task-name> --cpu=4 --memory=8G --disk=25G \
  --tag opndrm,<adam-or-frnkly-one>,task --integration <repo-integration> --integration <llm-integration>
```

Inside the VM, clone only through the attached integration hostname, install Prime Agent normally, and run Prime Agent headlessly in that task checkout. Keep the VM proxy private. Never expose a port publicly unless the owner explicitly approves it.

## Gate boundary for Mac apps

Exe can run Linux-safe analysis, code generation, unit tests, lint, and review. It cannot be the authoritative gate for Xcode, iOS Simulator/device, signing, notarization, or macOS packaging.

Use **No Mistakes only for ADAM or FRNKLY.ONE Mac-app work**, after the sandbox task produces a branch. Run the native build/test/signing gate on the controlled Mac/Apple-capable lane. Do not invoke No Mistakes for Prime, websites, docs, or general workflow setup.

## Completion

Report the VM name, repository, branch, checks run, limitations requiring Mac validation, and next owner. Do not delete a VM, publish a proxy, or change integrations without explicit approval.
