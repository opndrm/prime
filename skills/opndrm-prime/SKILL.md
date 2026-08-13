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
| ADAM | `~/OPNDRM/ADAM` | `%USERPROFILE%\\OPNDRM\\ADAM` | `opndrm-adam` |
| FRNKLY.ONE | `~/OPNDRM/FRNKLY.ONE` | `%USERPROFILE%\\OPNDRM\\FRNKLY.ONE` | `opndrm-frnkly-one` |

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

## OPNDRM Buzz

Buzz is the conversation layer for OPNDRM Prime. It supports people and named agents; it does not replace the repository, Wayfinder/GitHub Issues, Prime Agent, or the No Mistakes Gate.

1. During one-click setup, install and launch Buzz where the operating system supports it, then write a per-person onboarding record with the workspace, suggested agent name, role, and issue-tracker destination.
2. The teammate completes their own Buzz sign-in. After that owner action, create or connect only the named agent they approve—for example, `PRIME — ADAM`, `PRIME — FRNKLY.ONE`, or `PRIME — OPNDRM APP`.
3. Give each agent one bounded responsibility, a clear evidence source, read/write limits, an accountable human owner, and a safe first action. Treat its report as reviewable evidence, not official state.
4. Store the approved Buzz agent identifier only in that teammate’s Atomic Vault OPNDRM entry. Never write it to the repository, a shared file, a public website, or another person’s Vault.
5. Report the onboarding state plainly: **installed**, **waiting for owner**, **connected**, or **blocked**. “Connected” requires visible Buzz access, the approved named agent, and Vault confirmation.

### Private OPNDRM team access

The OPNDRM Buzz community is private. An approved teammate opens the OPNDRM Team page, authenticates, and selects **OPEN OPNDRM BUZZ**. They complete the invitation and Buzz sign-in on their own device before any agent setup begins.

- Treat a relay-membership denial as an access state: the identity has not joined the private OPNDRM community yet. Do not delete the profile, create a replacement identity, or retry agent setup until the person has joined through the approved Team invitation.
- Once the person can visibly open the private OPNDRM channel, confirm their human membership first. A human may participate without an AI agent.
- Only after the owner explicitly approves it, create or connect that person's named agent and store its approved identifier in that person's Atomic Vault entry.
- Never copy, reveal, request, embed, or use a Buzz invite URL, channel identifier, relay credential, API token, private key, or Vault value in a prompt, repository, installer, shared configuration, public page, or chat message. The Team page is the controlled handoff surface.

Use Buzz for discussion and handoffs; use Wayfinder/GitHub Issues for plan and decisions; use GitHub for code, branches, and reviews. Never post credentials, private keys, recovery codes, or Vault contents to Buzz.

## Onboarding rules

- Direct a new Mac teammate to the website-hosted Mac installer and guide at `opndrm.com`.
- If a Mac lacks Apple Command Line Tools, the installer opens Software Update directly. If Apple requires a macOS update first, the teammate completes it, restarts if asked, and reruns the same OPNDRM command. Otherwise they install Apple Command Line Tools there and the installer resumes automatically. Do not tell them to search for an invisible dialog.
- Treat Windows as a first-device preview until it passes a real-device health check. Do not describe it as equivalent to Mac before that evidence exists.
- If Windows lacks Windows App Installer, the installer opens Microsoft Store directly, then asks the teammate to reopen PowerShell and run the same command again. The official Buzz installer opens in a visible window; the teammate completes that window and the installer continues.
- Keep a named local HERDR workspace per teammate and repository. Never use a shared terminal session as team collaboration.
- Configure Ollama per person. DeepSeek Flash and MiniMax M3 may be ready; discover the teammate's installed local Ollama models before promising availability.
- Create No Mistakes as a visible, inactive Gate only. Never start, approve, rerun, abort, or repair it from onboarding.
- Install Atomic Vault and CBF Remote only through the approved package source. Never copy, request, expose, or share credentials; Vault trust is completed by the individual owner.
- Install Buzz in the same one-click setup and stage a local Buzz onboarding record. After the teammate completes their own Buzz sign-in, create or connect only their named Buzz agents. Store each approved agent identifier in that teammate’s Atomic Vault under an OPNDRM entry, never in a repository, shared configuration, or another person’s Vault. Report Buzz as **waiting for owner** until sign-in, visible named agents, and Vault confirmation are all complete.

## Decision and safety boundaries

- Do not overwrite a checkout, alter a credential, invite a Buzz member, create a shared identity, spend money, push code, deploy, or publish an official issue update without explicit approval. Do not create a Buzz account, agent, or Vault record until the teammate has completed their own sign-in and approves that exact action.
- Do not mix OPNDRM APP, ADAM, and FRNKLY.ONE repository evidence, branches, or release authority.
- Treat a child report as evidence to review, not proof.
- Explain blockers plainly and offer the smallest safe next step.

## Expected handoff

Return only the verified outcome, selected lane and work card, changed scope or read-only state, quality evidence and unresolved risk, and the next owner or decision.
