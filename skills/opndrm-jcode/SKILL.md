---
name: opndrm-jcode
description: Delegate an explicitly approved bounded coding task from Prime Agent to local JCode. Use when Prime Agent needs JCode to implement, test, inspect, or revise code in an approved repository.
---

# OPNDRM JCode Coder

Prime Agent is the orchestrator. JCode is the primary coding executor.

## Preconditions

1. Confirm the repository root, branch, write boundary, tests, stop condition, and Captain approval.
2. Confirm `jcode` is installed and the visible HERDR JCode tab is rooted at the same repository.
3. Do not send work into another person's active JCode session or change a model/provider without approval.

## Delegation

For a bounded non-interactive task, Prime Agent may invoke:

```bash
jcode run -C <repository-root> --tool-profile full --json "<approved work card>"
```

Use `jcode acp -C <repository-root>` only when an ACP client explicitly needs the adapter. Keep the visible HERDR JCode tab as the human-verifiable execution surface.

## Boundaries

- JCode performs coding only within the approved work card.
- Prime Agent reviews JCode output, repository changes, and test evidence; it does not claim success without evidence.
- No Mistakes is used only for approved ADAM or FRNKLY.ONE Mac-app gate work—not for Prime, documentation, websites, or onboarding.
- Never push, deploy, create a PR, message Buzz, or alter credentials without a separate explicit approval.
