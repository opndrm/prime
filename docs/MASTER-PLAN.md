# OPNDRM Prime — Master Plan

## What OPNDRM Prime Is

**UTM, but for AI control.**

A small, clean macOS app — like UTM — that creates, saves, restores, destroys,
and lays out VMs on your screen. Apple VMs or Linux VMs. One at a time, or
multiple in a quad/tile view where you can watch several VMs running
side by side, each with its own AI agent working inside it.

Any AI agent connects to any VM. One agent per VM — no agent runs two VMs
at the same time. You watch the AI work inside the VM from your Mac.

The Open Dream workflow (WezTerm, HERDR, Prime Agent, JCode, Ollama, oMLX,
Qwen3.8) is not baked in. It's an optional one-click install: the user opens
a VM, copies a command from the in-app docs, and pulls the full workflow from
GitHub. The VM is clean until they choose to install it.

## Priority Order

1. **First class — the VM manager.** Create, save, restore, destroy, lay out
   VMs. Apple or Linux. Multi-VM quad view. Disk management. AI connection.
   This is the product.

2. **Second class — the Open Dream workflow.** An optional one-click install
   inside any VM. Documented in the UI. Pulled from GitHub. Not required, not
   pre-baked. The VM works fine without it.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                  OPNDRM VM.app (host)                   │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Main Window (like UTM)                           │  │
│  │                                                    │  │
│  │  Sidebar: VM list        │  Content: VM display    │  │
│  │  ● opndrm-vm-001  Running│  ┌────┬────┐           │  │
│  │  ● opndrm-vm-002  Running│  │ VM1 │ VM2 │  Quad   │  │
│  │  ○ opndrm-vm-003  Stopped│  ├────┼────┤  view     │  │
│  │  + New VM                │  │ VM3 │ VM4 │           │  │
│  │                          │  └────┴────┘           │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  Top bar per VM: Settings │ Record │ Recordings │ Check │
│  Socket server: localhost:7777 (any AI connects here)  │
└──────────────────────────────────────────────────────┘
        │ Apple Virtualization Framework
        ▼
┌──────────┬──────────┬──────────┬──────────┐
│  VM 1    │  VM 2    │  VM 3    │  VM 4    │
│ (Apple)  │ (Apple)  │ (Linux)  │ (Apple)  │
│          │          │          │          │
│ Agent A  │ Agent B  │ Agent C  │ (idle)   │
│ works    │ works    │ works    │          │
│ inside   │ inside   │ inside   │          │
└──────────┴──────────┴──────────┴──────────┘
```

## First Class: The VM Manager

### VM Types

The user chooses when creating a VM:

| Type | Engine | Use case |
|------|--------|----------|
| Apple VM | Apple Virtualization Framework | macOS guest, full GUI, OpenAdapt recording |
| Linux VM | Apple Virtualization Framework (Linux) | lightweight, headless, faster boot |

Both use Apple's native virtualization — no third-party hypervisor.

### Creating a VM

1. Click **+ New VM** in the sidebar
2. Choose type: Apple or Linux
3. Name it
4. Set memory (default 16 GB for Apple, 4 GB for Linux)
5. Click **Create**
6. VM boots, clean OS, ready for any AI to connect

No pre-installed workflow. The VM is a blank slate.

### Saving and Restoring

Like UTM:

- **Save** — snapshot the VM disk to a timestamped file. VM must be stopped.
  Stored at `~/Library/Application Support/OPNDRM-VM/Snapshots/<vm>/`
- **Restore** — swap the disk image with a saved snapshot, restart the VM
- **Clone** — copy a snapshot to a new VM name (fast, no re-provisioning)
- Snapshots are full disk copies — simple, reliable, like UTM

### Destroying

- Stop VM, delete disk + snapshots + all files
- Confirmation dialog required
- Cannot be undone

### Multi-VM Layout (Quad View)

The content area supports layout modes:

| Mode | Layout | Use case |
|------|--------|----------|
| Single | One VM fills the area | Focused work |
| Split | Two VMs side by side | Compare two agents |
| Triple | Three VMs (one large, two small) | Primary + monitoring |
| Quad | Four VMs in a 2×2 grid | Watch four agents at once |

Like WezTerm panes — drag to resize, click to focus, rearrange. Each VM
tile shows the live VM display. Click a tile to bring that VM's controls
(Record, Settings, etc.) to the top bar.

One agent per VM. The app enforces this: a connected AI is bound to one
VM at a time. No agent controls two VMs simultaneously.

### Disk Space Management

A visual disk usage panel:

```
┌─────────────────────────────────────────┐
│  Disk Usage                               │
│                                           │
│  ████████████████░░░░░░░░░  64 GB / 128 GB│
│                                           │
│  VMs                                      │
│  opndrm-vm-001   42 GB   [Manage]        │
│  opndrm-vm-002   22 GB   [Manage]        │
│  Snapshots       18 GB                   │
│  Golden Images    4 GB                   │
│                                           │
│  Available: 64 GB                         │
│  [Clean Up Snapshots]  [Destroy VM]      │
└─────────────────────────────────────────┘
```

### AI Connection

Any AI agent connects to a VM through the socket server:

```
AI agent (any) → localhost:7777 → OPNDRM VM.app → specific VM
```

- The socket server routes commands to the selected VM
- Commands: show, hide, stop, focus, key input, mouse input, status
- An agent binds to one VM; the app tracks which agent is in which VM
- The agent can inject keyboard/mouse input to control the VM
- The human watches via the VM display tile

Connection is simple from the agent's side — one socket, one command set.
No SDK required. Any agent that can open a TCP socket can connect.

### CLI

```
opndrm-vm create [name] [--type apple|linux] [--memory GB]
opndrm-vm show [name]             → show VM in window
opndrm-vm hide [name]             → hide (VM keeps running)
opndrm-vm stop [name]             → stop VM
opndrm-vm destroy [name]          → delete VM and all files
opndrm-vm save [name] [label]     → snapshot VM state
opndrm-vm restore [name] [label]  → restore from snapshot
opndrm-vm clone [src] [dst]       → duplicate from snapshot
opndrm-vm list                    → list all VMs
opndrm-vm status                  → daemon + all VM status
opndrm-vm layout [single|split|triple|quad]  → set display layout
opndrm-vm connect [vm]            → bind current AI session to a VM
opndrm-vm disk                    → show disk usage
```

## Second Class: The Open Dream Workflow (Optional Install)

The Open Dream workflow is NOT pre-baked into VMs. It's a one-click install
that the user runs inside any VM after it opens.

### How it works

1. User creates a VM (Apple type, at least 16 GB memory)
2. User opens the VM, sees a clean macOS desktop
3. In the OPNDRM VM app's **Docs** tab, the user sees:

```
Install the Open Dream AI Workflow
─────────────────────────────────────
Open Terminal in your VM and run:

  curl -fsSL https://opndrm.com/install | bash

This installs:
  WezTerm → HERDR → Prime Agent → JCode → Ollama → oMLX → OpenAdapt → Handy

Your HERDR session will have four workspaces:
  OFFLINE     → Prime Agent + oMLX / Qwen3.8-27B
  OPNDRM      → Prime Agent + Ollama Cloud
  OPNDRM JC   → JCode
  OPNDRM NM   → inactive

Works on Apple VMs with 16+ GB memory.
```

4. User copies the command, pastes it into the VM's Terminal, presses Return
5. The installer does everything: installs tools, creates HERDR session,
   starts agents, bundles the model
6. When it finishes, WezTerm opens with the full four-workspace layout

### Why this is better

- The VM manager (the product) stays clean and small
- The workflow (the add-on) evolves independently on GitHub
- Users who just want a VM for AI control don't get a bloated image
- Users who want the full Open Dream workflow get it in one command
- We can update the workflow without rebuilding VM images
- Linux VMs work too (different installer, same pattern)

### Golden image (optional)

For users who want the workflow pre-baked:
- Build a golden Apple VM image with the workflow pre-installed
- `opndrm-vm create my-vm --golden opndrm-golden-1.0`
- This is an option, not the default

## Settings UI

Like UTM — a small, clean native Mac window with a sidebar:

```
┌──────────────┬──────────────────────────────────┐
│  SIDEBAR      │  CONTENT                          │
│               │                                    │
│  ● VMs        │  ┌──────────────────────────────┐ │
│    Disk        │  │ opndrm-vm-001   [Running] ● │ │
│    AI          │  │ Apple macOS  16 GB   42 GB  │ │
│    Recording   │  │ [Stop] [Save] [Clone] [💀]  │ │
│    Docs        │  └──────────────────────────────┘ │
│               │                                    │
│               │  ┌──────────────────────────────┐ │
│               │  │ opndrm-vm-002   [Stopped] ○  │ │
│               │  │ Apple macOS  16 GB   38 GB  │ │
│               │  │ [Start] [Save] [Clone] [💀]  │ │
│               │  └──────────────────────────────┘ │
│               │                                    │
│               │  [+ New VM]                         │
│               │                                    │
│               │  Layout: [Single|Split|Triple|Quad] │
└──────────────┴──────────────────────────────────┘
```

### VMs tab

The default view. All VMs as cards. Each: Start/Stop, Save, Clone, Destroy.
Layout selector at the bottom. + New VM button. Snapshots under each VM.

### Disk tab

Visual disk usage. Per-VM breakdown. Snapshot sizes. Clean up button.
Shows total used, total available, and warns when low.

### AI tab

- Which AI is connected to which VM (binding display)
- Ollama Cloud API key (for the Open Dream workflow, if installed)
- Model selection per workspace (if workflow is installed)

### Recording tab

- OpenAdapt status in each VM
- Recording list with play/delete
- Quality and storage settings

### Docs tab

- One-click install command for the Open Dream workflow
- VM type guide (Apple vs Linux)
- Quick-start for connecting an AI agent
- Link to opndrm.com/docs

## Naming

Everything is **OPNDRM VM**:

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
| ~/Library/Application Support/BuzzBot/ | ~/Library/Application Support/OPNDRM-VM/ |

## OpenAdapt Recording (P0)

The Record button is the differentiator. Record a VM session, replay it,
feed it to an AI as training material.

### Flow

Record → capture screen + input → Stop → finalize → list in Recordings →
click to play in VM browser → feed to AI as training material

### What's broken

OpenAdapt's `video_writer` fails in Apple Virtualization guests.
Multiprocessing `spawn` path is not VM-compatible.

### What to do

Write a guest-compatible capture path. Simplest: a direct FFmpeg capture
script that the guest helper launches. Records the guest screen, saves to
the same recording directory structure.

## Repository Thinning

**117 files now. Target: ~20.**

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
│   │   ├── OPNDRMVM/              (VM manager + window + socket + lifecycle)
│   │   ├── OPNDRMProtocol/        (guest command wire protocol)
│   │   ├── OPNDRMGuestEngine/     (OpenAdapt engine)
│   │   └── OPNDRMGuestHelper/     (guest-side vsock helper)
│   └── Tests/
├── guest-payloads/
│   └── macos/
│       └── first-boot-opndrm.sh   (simplified)
├── scripts/
│   ├── install-macos.sh          (the one-click Open Dream workflow installer)
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

### Remove (90+ files)

| Directory | Reason |
|-----------|--------|
| apps/buzz-container-window/ | Separate product |
| containers/ (30+ files) | Linux foundation, separate future product |
| integrations/ | Not core product |
| evaluations/ | Research artifacts |
| api/ | Admin endpoints |
| guest-payloads/macos/prime-workflow/acp-gateway/ | Over-engineered |
| guest-payloads/macos/prime-workflow/hooks/ | Over-engineered |
| skills/buzz-container/ | Buzz-specific |
| skills/buzz-record/ | Buzz-specific |
| docs/BUZZBOT_FINAL_PRODUCT_PLAN.md | Superseded |
| docs/buzzbot-agent-workflow.md | Buzz-specific |
| scripts/check-agent-computer.sh | Buzz container check |
| scripts/check-installers.sh | Over-engineered validation |
| brand/buzzbot-computer/ | Renamed |

## Phases

### Phase 1 — Rename and thin (P0)
BuzzBot → OPNDRM VM everywhere. Remove 90+ non-product files. Simplify
first-boot script. Get the repo to ~20 files.

### Phase 2 — Multi-VM + layout (P0)
Support multiple VMs. Quad/split/triple/single layout. VM type selection
(Apple or Linux). One agent per VM binding.

### Phase 3 — VM lifecycle (P0)
Create, save, restore, destroy, clone. Disk space management UI. Golden
image build (optional).

### Phase 4 — Recording loop (P1)
Fix OpenAdapt video capture for VM guests. Record → Stop → Playback.

### Phase 5 — Settings UI (P1)
UTM-style sidebar + content. VMs tab, Disk tab, AI tab, Recording tab,
Docs tab. One-click workflow install command in Docs.

### Phase 6 — Open Dream workflow installer (P1)
The `curl | bash` one-click that installs the full stack inside any VM.
HERDR four-workspace layout. Ollama Cloud. oMLX + Qwen3.8.

### Phase 7 — Packaging (P2)
.pkg installer. opndrm.com/install. One command → working VM manager.

## Swarm Execution

After approval, parallelize with Ollama agent swarms:

| Swarm | Branch | Task |
|-------|--------|------|
| rename-thin | refactor/rename-thin | Rename + remove 90 files |
| multi-vm | feature/multi-vm | Multiple VMs + quad layout |
| lifecycle | feature/lifecycle | Save/restore/destroy/clone/disk |
| recording | fix/openadapt-vm | Guest-compatible video capture |
| settings-ui | feature/settings-ui | UTM-style Settings window |
| workflow-installer | feature/one-click-install | curl|bash Open Dream workflow |
| packaging | feature/packaging | .pkg + landing page |

Each swarm writes to its branch → PR → review → merge. No direct writes to main.
