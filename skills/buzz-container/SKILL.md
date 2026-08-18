---
name: buzzbot
description: >
  BuzzBot Agent Computer gives any AI agent its own private macOS VM via Apple Virtualization.
  Use /buzzbot to show, hide, stop, destroy, or list agent VMs. Each agent gets an isolated
  Mac with its own storage, network, and identity. The overlay window has a Record button
  for OpenAdapt and a Refresh button for display recovery.
---

# BuzzBot Agent Computer

BuzzBot creates and manages private macOS VMs for AI agents using Apple Virtualization.
Each agent gets its own isolated Mac — full guest OS, separate storage, network, and identity.
The human observes with `/buzzbot show`. The agent works inside its VM. Hide is not stop.

## Commands

When the user types `/buzzbot <action>`, run the matching shell command:

| Command | What it does |
|---------|-------------|
| `/buzzbot show` | Show the VM overlay (boots if stopped) |
| `/buzzbot hide` | Hide the overlay (VM keeps running) |
| `/buzzbot stop` | Stop the VM |
| `/buzzbot destroy` | Delete the VM and all files |
| `/buzzbot list` | List all agent VMs and status |

## Shell Commands

```bash
/Users/uoa/.local/bin/agent-computer show <agent-name>
/Users/uoa/.local/bin/agent-computer hide <agent-name>
/Users/uoa/.local/bin/agent-computer stop <agent-name>
/Users/uoa/.local/bin/agent-computer destroy <agent-name>
/Users/uoa/.local/bin/agent-computer list
```

Default agent VM: `buzzbot-mac-002`

## Overlay Window

The VM overlay is a floating NSPanel with:
- **Record button** (top right) — starts/stops OpenAdapt recording with red glow
- **Refresh button** (↻) — re-attaches the VZ display if frozen
- **Yellow minimize** — hides into Buzz, VM keeps running
- **Red close** — hides overlay, VM keeps running

## Rules

- The VM is always-on. The agent never types `/buzzbot` — it just works inside its VM.
- The human uses `/buzzbot show` to observe what the agent is doing.
- Hide is not stop: hiding only removes the visual overlay.
- Any AI agent can get its own VM — Buzz, Prime, Codex, JCode, or future ones.
- To create a new agent VM, the IPSW must be available (download with `softwareupdate --fetch-full-installer`).
- VM files live at `~/Library/Application Support/BuzzBot/AgentComputers/TrustedMacStates/<agent-name>/`
- The service binary is at `/Users/uoa/Desktop/opndrm_prime/apps/buzzbot-computer-service/.build/debug/buzzbot-computer-service`
- Must codesign with virtualization entitlement after every rebuild.
