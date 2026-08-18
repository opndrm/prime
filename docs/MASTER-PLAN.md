# OPNDRM Prime — Master Plan

## What OPNDRM Prime Is

**UTM, but for AI control.**

A small, clean macOS app — like UTM — that creates, saves, restores, and
destroys VMs. But instead of just running an OS, every VM comes pre-loaded
with a full AI agentic workspace: WezTerm, HERDR, Prime Agent, JCode, Ollama,
oMLX, OpenAdapt, and Handy. Any AI agent — Buzz, Codex, OpenCode, Prime Agent,
or anything future — connects to the VM and works inside it as a safe sandbox.

The human manages VMs through a simple native UI (build, stop, save, restore,
destroy, clone). The AI works inside the VM. The host never runs AI.

**It is not about Buzz.** Buzz is one possible client. The product is the VM
and the management app around it.

## The Product

```
User installs OPNDRM VM.app
    ↓
Opens it → creates a VM (one click)
    ↓
VM boots with full AI stack pre-installed
    ↓
WezTerm → HERDR → four workspaces, all agents running
    ↓
Any AI connects via socket, uses the VM as its workspace
    ↓
Human observes via the VM window, records sessions, plays them back
```

## Architecture (Thin)

```
┌──────────────────────────────────────┐
│         OPNDRM VM.app (host)          │
│                                       │
│  VZ Window  │ Settings │ Socket:7777  │
│  (display)  │ (top bar)│ (any AI)     │
│       │       │              │        │
├───────┼───────┼──────────────┼────────┤
│       ▼       ▼              ▼        │
│  ┌──────────────────────────────────┐ │
│  │       macOS Guest VM             │ │
│  │                                   │ │
│  │  WezTerm → HERDR (auto on boot)   │ │
│  │  OFFLINE  → Prime Agent + oMLX    │ │
│  │  OPNDRM   → Prime Agent + Ollama  │ │
│  │  OPNDRM JC → JCode               │ │
│  │  OPNDRM NM → inactive             │ │
│  │                                   │ │
│  │  OpenAdapt (record/replay)        │ │
│  │  Guest Helper (vsock:2222)        │ │
│  └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

The host is a thin controller. It does not run AI. It does:
- Create, start, stop, destroy VMs
- Display the VM in a floating window
- Route socket commands from any AI client
- Show Record/Recordings/Settings/Check Guest controls
- Inject keyboard input to the VM (for automated control)

## What Ships in the VM

Pre-installed, auto-configured, no user setup needed:

| Tool | What it does |
|------|-------------|
| WezTerm | Terminal (WebGPU) |
| HERDR | Four-workspace layout, auto-starts on boot |
| Prime Agent | AI orchestrator (OFFLINE + OPNDRM) |
| JCode | Coding executor (OPNDRM JC) |
| Ollama | Cloud model gateway (all models) |
| oMLX | Local model runtime (Qwen3.8-27B-mxfp4) |
| OpenAdapt | Record and replay VM sessions |
| Handy | Speech-to-text |

## HERDR Layout (Fixed, Auto-Recovering)

```
OFFLINE       → Prime Agent + oMLX / Qwen3.8-27B-mxfp4
OPNDRM        → Prime Agent + Ollama Cloud (all models)
OPNDRM JC     → JCode
OPNDRM NM     → inactive shell
```

Every VM boot. Every time. No exceptions. The guest first-boot script
creates this session and a LaunchAgent keeps it alive.

## Naming

Everything is **OPNDRM VM**, not BuzzBot:

| From | To |
|------|-----|
| buzzbot-computer-service | opndrm-vm |
| BuzzBotComputerService | OPNDRMVM |
| BuzzBotProtocol | OPNDRMProtocol |
| BuzzBotGuestEngine | OPNDRMGuestEngine |
| BuzzBotGuestHelper | OPNDRMGuestHelper |
| buzzbot-mac-002 | opndrm-vm-001 |
| buzzbot CLI | opndrm-vm CLI |
| Window title | OPNDRM VM |

## Top Bar Controls

| Control | Action |
|---------|--------|
| Settings | AI config, VM lifecycle, recording, docs |
| Record | Start/stop OpenAdapt session recording |
| Recordings · state | Open recordings list |
| Check Guest | Verify guest helper |

## OpenAdapt Recording (P0 — the differentiator)

Record VM sessions → replay them → train AI agents on routines.

### Flow

Record → capture screen + input → Stop → finalize → list in Recordings →
click to play in guest browser → feed to AI as training material

### What's broken now

OpenAdapt's `video_writer` fails in Apple Virtualization guests. The
multiprocessing `spawn` path is not VM-compatible. Both standard and fork
launcher attempts failed.

### What to do

Write a guest-compatible video capture path. Options:
1. Direct FFmpeg pipe (CGDisplayStream → FFmpeg → MP4)
2. Swift ScreenCaptureKit recorder in the guest helper
3. Patch OpenAdapt's writer to use a process-safe path

The simplest is likely a direct FFmpeg capture script that the guest helper
launches instead of OpenAdapt's built-in writer. It records the guest screen
and saves to the same recording directory structure.

## Settings UI

A popover from the top bar:

1. **VM Management** — Build, destroy, save, restore, list VMs
   - **Build** — Create a new VM from IPSW or golden image
   - **Destroy** — Delete a VM and all its files (with confirmation)
   - **Save** — Snapshot the current VM state to disk
   - **Restore** — Restore a saved snapshot
   - **List** — Show all VMs with status, memory, disk usage
   - **Clone** — Duplicate an existing VM (fast, from saved state)
   - Memory slider (min 16 GB for Qwen3.8-27B), disk usage display
2. **AI** — Ollama Cloud API key, model selection per workspace, oMLX path
3. **Recording** — OpenAdapt status, quality, storage
4. **Docs** — Quick start, links to opndrm.com/docs

## Ollama Cloud

- User enters API key once via Settings → stored in guest keychain
- Prime Agent `models.json` includes the full cloud catalog (20+ models)
- JCode uses the same endpoint via OpenAI-compatible provider profile
- `/scoped-models` shows all cloud models

## VM Lifecycle Management (Our Own)

We need our own VM creation, save/restore, and destruction pipeline, not
dependent on any specific AI client. This lives in the Settings UI and the CLI.

### CLI

```
opndrm-vm create [name]           → create VM from IPSW, provision guest
opndrm-vm show [name]             → show VM window (boots if stopped)
opndrm-vm hide [name]             → hide window (VM keeps running)
opndrm-vm stop [name]             → stop VM (state preserved in disk image)
opndrm-vm destroy [name]          → delete VM and all files (confirmed)
opndrm-vm save [name] [label]     → snapshot current VM state to disk
opndrm-vm restore [name] [label]  → restore from a saved snapshot
opndrm-vm clone [src] [dst]       → duplicate a VM from saved state (fast)
opndrm-vm build-golden            → build a golden image with full stack
opndrm-vm list                    → list all VMs and snapshots
opndrm-vm status                  → daemon health + VM status
opndrm-vm settings [name]         → open settings UI for a VM
```

### Settings UI — VM Management tab

```
┌─────────────────────────────────────────────┐
│  VM Management                                │
│                                                │
│  Active VM: opndrm-vm-001    [Running]         │
│  Memory: 16 GB    Disk: 42 GB                 │
│                                                │
│  [Build New VM]  [Clone]  [Destroy]            │
│                                                │
│  Snapshots                                     │
│  ┌───────────────┬────────────┬──────────┐    │
│  │ clean-install  │ 2026-08-18 │ [Restore]│    │
│  │ after-setup    │ 2026-08-18 │ [Restore]│    │
│  │ pre-recording  │ 2026-08-18 │ [Restore]│    │
│  └───────────────┴────────────┴──────────┘    │
│                                                │
│  [Save Snapshot]                               │
│                                                │
│  Golden Image: opndrm-golden-1.0  [Build]      │
└─────────────────────────────────────────────┘
```

### Save / Restore

- **Save** snapshots the VM's disk image to a timestamped file in
  `~/Library/Application Support/OPNDRM-VM/Snapshots/<vm-name>/`
- **Restore** replaces the current disk image with a snapshot, stops and
  restarts the VM from that state
- Snapshots are full disk copies (simple, reliable). Future optimization:
  incremental/differential snapshots via Apple Virtualization APIs.
- The VM must be stopped before save or restore (no live snapshotting yet).

### Build / Destroy

- **Build** creates a new VM from IPSW, boots it, runs guest provisioning,
  and saves the first snapshot labeled `clean-install`
- **Destroy** stops the VM, deletes the disk image, snapshots, and all
  associated files. Requires confirmation in the Settings UI.
- **Clone** copies a saved snapshot to a new VM name — fast provisioning
  without re-running the full install

### Golden image

Build once, clone forever:
- All tools pre-installed (WezTerm, HERDR, Prime Agent, JCode, Ollama, oMLX)
- Qwen3.8-27B-mxfp4 model bundled (~14 GB)
- HERDR `opndrm` session pre-created with four workspaces
- All agents started and verified
- Clone from golden = seconds, not minutes
- Stored at `~/Library/Application Support/OPNDRM-VM/Golden/`

### Guest provisioning

When a new VM is created (build or clone):
1. Create from IPSW or golden image, boot
2. Guest auto-provisions via first-boot script:
   - Install Homebrew, WezTerm, HERDR, Prime Agent, JCode, Ollama, oMLX
   - Bundle Qwen3.8-27B-mxfp4 model
   - Create HERDR `opndrm` session with four workspaces
   - Start all agents
3. Save `clean-install` snapshot automatically
4. Ready — no manual steps

## Repository Thinning

**117 files now. Target: ~25.**

### Keep (core product only)

```
opndrm/prime/
├── README.md
├── package.json
├── vercel.json
├── config/herdr-layout.json
├── apps/opndrm-vm/
│   ├── Package.swift
│   ├── Sources/
│   │   ├── OPNDRMVM/          (6 Swift files — the controller)
│   │   ├── OPNDRMProtocol/    (1 file — guest command wire protocol)
│   │   ├── OPNDRMGuestEngine/ (1 file — OpenAdapt engine)
│   │   └── OPNDRMGuestHelper/ (1 file — guest-side vsock helper)
│   └── Tests/
├── guest-payloads/
│   └── macos/
│       └── first-boot-opndrm.sh  (simplified — no ACP gateway, no hooks)
├── scripts/
│   ├── install-macos.sh
│   ├── configure-prime-ollama.py
│   └── build-golden-image.sh
├── docs/
│   ├── MASTER-PLAN.md
│   ├── GETTING-STARTED.en.md
│   └── HERDR-WEZTERM-LAYOUT.md
├── site/
│   └── index.html
└── skills/
    └── opndrm-vm/SKILL.md
```

### Remove (90 files)

| Directory | Reason |
|-----------|--------|
| `apps/buzz-container-window/` | Separate product |
| `containers/` (30+ files) | Linux foundation, separate future product |
| `integrations/` | Not core product |
| `evaluations/` | Research artifacts |
| `api/` | Admin endpoints, not product |
| `guest-payloads/macos/prime-workflow/acp-gateway/` | Over-engineered consent system |
| `guest-payloads/macos/prime-workflow/hooks/` | Over-engineered hook system |
| `guest-payloads/macos/openadapt-guest-coordinator.py` | Replace with simpler script |
| `guest-payloads/macos/openadapt-guest-recording-consent.sh` | Replace with inline consent |
| `guest-payloads/macos/openadapt-guest-recording-plan.md` | Planning doc, not product |
| `skills/buzz-container/` | Buzz-specific |
| `skills/buzz-record/` | Buzz-specific |
| `docs/BUZZBOT_FINAL_PRODUCT_PLAN.md` | Superseded by this plan |
| `docs/buzzbot-agent-workflow.md` | Buzz-specific |
| `scripts/check-agent-computer.sh` | Buzz container check |
| `scripts/check-installers.sh` | Over-engineered validation |
| `brand/buzzbot-computer/` | Renamed or removed |

### Simplify first-boot-opndrm.sh

Current: 200 lines with receipts, hooks, ACP gateway, buzz identity, wayfinder.
Target: ~50 lines that:
1. Install tools (brew, wezterm, herdr, prime-agent, jcode, ollama, omlx)
2. Create HERDR session with four workspaces
3. Start agents
4. Done

No receipts. No hooks. No ACP gateway. No buzz identity. No wayfinder.

## Phases

### Phase 1 — Recording loop (P0)
Fix OpenAdapt video capture for VM guests. Record → Stop → Playback.

### Phase 2 — Rename and thin
BuzzBot → OPNDRM VM everywhere. Remove 90 files. Simplify first-boot script.

### Phase 3 — Settings UI
Top bar Settings popover. AI config, VM lifecycle, recording, docs.

### Phase 4 — Guest auto-provision
Simplified first-boot script. Golden image build. One-click VM creation.

### Phase 5 — Ollama Cloud
Settings → enter key → both agents see all cloud models.

### Phase 6 — Package
.pkg installer. opndrm.com/install. One command → working VM.

## Swarm Execution

After approval, parallelize with Ollama agent swarms:

| Swarm | Branch | Task |
|-------|--------|------|
| recording | fix/openadapt-vm | Guest-compatible video capture |
| rename | refactor/rename | BuzzBot → OPNDRM VM across all files |
| thin | refactor/thin | Remove 90 non-product files |
| settings | feature/settings-ui | Settings popover in Swift |
| provision | feature/guest-provision | Simplified first-boot + golden image |
| ollama | feature/ollama-cloud | Cloud catalog in guest agents |
| package | feature/packaging | .pkg installer + landing page |

Each swarm writes to its branch → PR → review → merge. No direct writes to main.
