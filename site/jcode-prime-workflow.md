# Prime Agent + JCode Workflow

1. Install and sign in to JCode yourself; the Open Dream installer never handles a JCode account, provider, or credential.
2. Run the Open Dream installer for the selected lane.
3. HERDR opens two separate sidebar workspaces rooted at the same checkout: **JCODE — <LANE>** and **<LANE> — PRIME**.
4. Prime Agent plans, delegates bounded approved coding tasks, reviews evidence, and retains workflow context.
5. JCode is the primary coding executor. It performs only the approved work card in the named checkout.
6. GitHub remains the code/review record. Buzz is personal coordination only after owner approval.

Prime may delegate a non-interactive approved task with `jcode run -C <root> --tool-profile full --json "<work card>"`, or use JCode ACP when an ACP client explicitly needs it. Never change providers, credentials, push, deploy, or start a gate without separate owner approval.

## Standard HERDR layout

The installer preserves two General Research workspaces—**GENERAL RESEARCH** for Prime Agent and **JCODE — GENERAL RESEARCH** for JCode—then creates a separate **JCODE — <LANE>** and **PRIME — <LANE>** pair for the selected app. General Research JCode uses the owner-selected local Ollama route; this Mac uses DeepSeek V4 Flash with High effort.
