---
name: opndrm-prime
description: Open and operate the local-first OPNDRM workflow: WezTerm, HERDR, Prime Agent, JCode, Buzz, and the OPNDRM workspace.
---

# Open Dream Prime

Use the teammate's language. Open only the local OPNDRM workspace and confirm its root before acting.

## Local topology

One person → one `~/Desktop/opndrm` workspace → one `opndrm` HERDR session → exactly four ordered workspaces.

| Order | Workspace | Root | Client/state |
|---:|---|---|---|
| 1 | OFFLINE | home | Prime Agent |
| 2 | OPNDRM | `~/Desktop/opndrm` | Prime Agent |
| 3 | OPNDRM JC | `~/Desktop/opndrm` | JCode |
| 4 | OPNDRM NO-MISTAKES | `~/Desktop/opndrm` | inactive gate |

## Execution roles

- **Prime Agent:** orchestrates the work card, evidence review, and bounded delegation.
- **JCode:** primary coding executor. Load `opndrm-jcode` for an approved coding task.
- **Buzz:** personal coordination only after explicit owner approval.

## Workflow

1. Confirm the OPNDRM root, branch, and visible HERDR workspace.
2. Turn the request into one work card: outcome, write boundary, quality gate, evidence, and stop condition.
3. Run Prime Agent only in the OPNDRM root.
4. Use Buzz only after the teammate completes personal sign-in and explicitly approves the named agent. Keep GitHub as the code and review record.

## Hard boundaries

- Never overwrite a checkout, share a terminal session, handle a credential, or create a Buzz identity or agent without the owner’s explicit approval.
- Do not install, configure, download, expose, or claim a model provider from this package. Local model setups are personal and outside this workflow.
- Do not create a dashboard, remote-run service, or remote sandbox integration here.
- Never claim a visible workspace, Buzz connection, or gate result without current evidence.
