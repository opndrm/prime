# BuzzBot — Final Product Plan

## What BuzzBot Is

A private macOS agent-computer service. Any AI agent gets its own isolated Mac VM
with the full OPNDRM workflow stack pre-installed. The human sees what the agent
is doing via a floating overlay. One terminal command installs everything.

## Architecture

```
┌─────────────────────────────────────────┐
│  Any AI Agent (Buzz, Prime, Codex, etc)  │
│          talks via `buzzbot` CLI         │
└──────────────────┬──────────────────────┘
                   │ Unix socket localhost:7777
┌──────────────────▼──────────────────────┐
│  buzzbot-computer-service (daemon)       │
│  - VM lifecycle (create/boot/stop/destroy)│
│  - Guest auto-provisioning (SSH bootstrap)│
│  - Overlay window + Record + Recordings   │
│  - Socket server for CLI                  │
└──────────────────┬──────────────────────┘
                   │ Apple Virtualization (VZ)
┌──────────────────▼──────────────────────┐
│  Private macOS Guest VM                  │
│  ┌──────────────────────────────────┐    │
│  │ WezTerm + HERDR layout           │    │
│  │ Prime Agent                      │    │
│  │ JCode                            │    │
│  │ OpenAdapt (recording)            │    │
│  │ ~/opndrm/ workspace              │    │
│  └──────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## One-Command Install

```bash
curl -fsSL https://opndrm.com/buzzbot/install | bash
```

This:
1. Downloads `buzzbot-computer-service` binary (codesigned with VZ entitlement)
2. Installs `buzzbot` CLI to `/usr/local/bin/buzzbot`
3. Starts the daemon (launchd plist)
4. Creates `~/Library/Application Support/BuzzBot/` structure
5. Downloads IPSW + creates first VM
6. VM boots, guest auto-provisions (WezTerm, HERDR, Prime Agent, JCode)
7. Prints: "BuzzBot ready. Run `buzzbot show` to see your agent computer."

## CLI

```bash
buzzbot show [agent-name]          # show VM overlay (boots if stopped)
buzzbot hide [agent-name]          # hide overlay (VM keeps running)
buzzbot stop [agent-name]          # stop VM
buzzbot destroy [agent-name]       # delete VM and all files
buzzbot list                       # list all VMs and status
buzzbot create [agent-name]        # create VM + auto-provision guest
buzzbot create [name] --base golden # clone from golden image (fast)
buzzbot provision [agent-name]     # re-run guest bootstrap
buzzbot ssh [agent-name]           # SSH into the guest VM
buzzbot recordings [agent]          # list recordings
buzzbot play [recording-id]        # replay a recording
buzzbot copy [id] [dest]           # copy recording
buzzbot move [id] [dest]           # move recording
buzzbot status                     # daemon health + VM status
buzzbot connect [harness]          # register with harness (buzz/prime/codex)
```

## Guest Auto-Provisioning

When a new VM is created, the host runs guest-bootstrap.sh over SSH:

1. Create VM from IPSW, boot it
2. Enable SSH in guest (via VZ input injection: open Terminal, paste command)
3. SSH into guest, run bootstrap:
   - Install Homebrew
   - Install WezTerm (`brew install --cask wezterm`)
   - Install Prime Agent (`curl -fsSL https://opndrm.com/prime-agent/install | bash`)
   - Install JCode (`curl -fsSL https://opndrm.com/jcode/install | bash`)
   - Set up HERDR WezTerm workspace layout
   - Create ~/opndrm/ workspace directories
   - Mark as provisioned
4. Print "Agent computer ready"

## Recordings Panel (Bottom Right of Overlay)

Collapsible panel in the overlay window:
- **Collapsed**: thin bar "Recordings (3) ▲"
- **Expanded**: grid of recording thumbnails
  - Timestamp, duration, thumbnail
  - Right-click: Copy, Move, Delete, Play
  - Double-click: Play in QuickLook
  - Drag: Move to Finder
- Dark theme, clean, minimal

## Buzz Connection

- `buzzbot connect buzz` → updates managed agent system prompt, adds skill
- `buzzbot connect prime` → copies SKILL.md to Prime Agent skills dir
- `buzzbot connect codex` → copies SKILL.md to Codex skills dir
- User types `@BuzzBot show` in Buzz → agent runs `buzzbot show`

## What Gets Removed (Thin)

Delete: all authority/lease/crypto code, MCP overlay proposals, ChoiceB coordinator,
GuestProof, Admission, Cutover, OverlayCommand, BuzzIngress, VZIdentity packages,
all tests for deleted modules, all docs except SKILL.md.

Keep only 5 Swift files:
1. BuzzBotComputerServiceApp.swift — daemon + socket server
2. BuzzBotVirtualMachineWindow.swift — overlay + Record + Refresh + Recordings
3. VirtualMachineController.swift — VM lifecycle
4. MacStateAdoption.swift — VM file loading (stat-based)
5. AgentComputerStore.swift — directory structure

Add: socket server, recordings panel, buzzbot CLI, install.sh, launchd plist,
guest-bootstrap.sh, buzzbot connect.

## Build Order

1. Thin the codebase
2. Add socket server (localhost:7777)
3. Build `buzzbot` CLI
4. Write guest-bootstrap.sh
5. Implement guest SSH enable
6. Wire `buzzbot create` with auto-provision
7. Add recordings panel
8. Write install.sh
9. Write `buzzbot connect [harness]`
10. Create launchd plist
11. Build golden VM image
12. Package as .pkg for opndrm.com
13. Vercel landing page

## Consumer Experience

```bash
curl -fsSL https://opndrm.com/buzzbot/install | bash
```
→ Installs, creates VM, provisions guest with full OPNDRM stack
→ `buzzbot show` → floating Mac VM, ready to work
→ `buzzbot connect buzz` → skill added to Buzz
→ Agent works inside its VM, human observes via overlay

Second agent:
```bash
buzzbot create agent-2 --base golden
```
→ Clones golden image, ready in seconds
