---
name: opndrm-prime
description: "Open and operate Open Dream Prime workspaces on Mac or Windows: OPNDRM APP, ADAM, or FRNKLY.ONE; restore their named HERDR sessions; and guide bilingual team onboarding."
---

# Open Dream Prime

Use one skill for both English- and Spanish-speaking teammates. Reply in the language the teammate uses. If the language is unclear, begin with a short English and Spanish choice, then continue in the selected language. Read [English onboarding](references/onboarding-en.md) or [guía de incorporación en español](references/onboarding-es.md) before explaining a first-time setup.

## Quick language choice / Idioma rápido

- **English:** Say “open ADAM,” “open FRNKLY.ONE,” “open OPNDRM APP,” or “open the last ADAM/FRNKLY.ONE/OPNDRM APP session.” The skill opens only that app’s named workspace.
- **Español:** Di “abre ADAM,” “abre FRNKLY.ONE,” “abre OPNDRM APP” o “abre la última sesión de ADAM/FRNKLY.ONE/OPNDRM APP.” La habilidad abre solamente el espacio con nombre de esa app.

The same session names and workflow apply on Mac and Windows. / Los mismos nombres de sesión y flujo se aplican en Mac y Windows.

## Open a workspace or restore the last session

When the teammate says “open ADAM,” “open FRNKLY.ONE,” “open OPNDRM APP,” “new app,” or “open the last session,” do this before discussing work cards:

| Request | Mac folder | Windows folder | HERDR session |
| --- | --- | --- | --- |
| OPNDRM APP / new app | `~/Desktop/OPNDRM APP` | Desktop `OPNDRM APP` | `opndrm-opndrm-app` |
| ADAM | `~/OpenDream/ADAM` | `%USERPROFILE%\\OpenDream\\ADAM` | `opndrm-adam` |
| FRNKLY.ONE | `~/OpenDream/FRNKLY.ONE` | `%USERPROFILE%\\OpenDream\\FRNKLY.ONE` | `opndrm-frnkly-one` |

1. Confirm the named folder exists. Never overwrite it or rerun an installer as a daily-start action.
2. Attach the matching named HERDR session. This restores the last saved workspace for that app on both Mac and Windows.
3. If the named session or workspace does not exist, create it only in that app’s existing folder, name the main workspace `APP — PRIME`, and add an inactive `NO MISTAKES GATE` tab. Do not start a Gate run.
4. If the request is “open the last session,” ask which app only when no app is named. “Last ADAM session,” “last FRNKLY.ONE session,” and “last OPNDRM APP session” map directly to the rows above.
5. State which app and last session were opened. Do not imply that one app upgrades, replaces, or changes another.

Mac and Windows use the same HERDR session names after installation. The Windows path remains a first-device preview until it passes a real-device health check.

## Core workflow after opening the workspace

1. Confirm the teammate's own checkout, branch, credentials, and local HERDR session.
2. Turn the request into one work card: outcome, write boundary, quality gate, evidence, and stop condition.
3. Run one root **PRIME** session for that card. Create a child only for genuinely independent work.
4. Use Buzz for conversation, Wayfinder/GitHub Issues for plan and decisions, and GitHub for branches, reviews, and code.
5. Record verified result, uncertainty, and next owner before moving to another card.

## Onboarding rules

- Direct a new Mac teammate to the website-hosted Mac installer and guide at `opndrm.com`.
- If a Mac lacks Apple Command Line Tools, the installer opens Software Update directly. The teammate installs Apple Command Line Tools there, leaves the original Terminal window open, and the installer resumes automatically. Do not tell them to search for an invisible dialog.
- Treat Windows as a first-device preview until it passes a real-device health check. Do not describe it as equivalent to Mac before that evidence exists.
- If Windows lacks Windows App Installer, the installer opens Microsoft Store directly, then asks the teammate to reopen PowerShell and run the same command again. The official Buzz installer opens in a visible window; the teammate completes that window and the installer continues.
- Keep a named local HERDR workspace per teammate and repository. Never use a shared terminal session as team collaboration.
- Configure Ollama per person. DeepSeek Flash and MiniMax M3 may be ready; discover the teammate's installed local Ollama models before promising availability.
- Create No Mistakes as a visible, inactive Gate only. Never start, approve, rerun, abort, or repair it from onboarding.
- Install Atomic Vault and CBF Remote only through the approved package source. Never copy, request, expose, or share credentials; Vault trust is completed by the individual owner.

## Decision and safety boundaries

- Do not overwrite a checkout, alter a credential, invite a Buzz member, create a shared identity, spend money, push code, deploy, or publish an official issue update without explicit approval.
- Do not mix OPNDRM APP, ADAM, and FRNKLY.ONE repository evidence, branches, or release authority.
- Treat a child report as evidence to review, not proof.
- Explain blockers plainly and offer the smallest safe next step.

## Expected handoff

Return only the verified outcome, selected lane and work card, changed scope or read-only state, quality evidence and unresolved risk, and the next owner or decision.
