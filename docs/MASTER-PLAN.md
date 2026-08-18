# OPNDRM Prime — Master Plan

> The thinnest possible slice: one app, one VM, the full agentic stack, ready to work.

## Product Definition

**OPNDRM Prime** is a downloadable macOS application that creates and manages a
private Apple Virtualization Framework VM pre-loaded with a complete AI agentic
workflow. The user installs it like any Mac app, clicks to open a VM, and gets a
visible WezTerm/HERDR session with all tools running — no manual setup.

The VM is a **safe area**: AI agents work inside it, the human observes and
controls from the host, and nothing leaks to the desktop. The host is a thin
lifecycle/display controller — not another agent runtime.

The product is AI-agnostic. It works with Buzz, Prime Agent, JCode, Codex,
Ollama, oMLX, OpenCode, or any future agent. The VM is the sandbox; the host
app is the remote control.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│              OPNDRM VM.app (host)                 │
│                                                   │
│  ┌───────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ VZ Window │  │ Settings │  │ Socket Server │  │
│  │ (display) │  │ (top bar)│  │  (port 7777)  │  │
│  └─────┬─────┘  └──────────┘  └───────────────┘  │
│        │ Apple Virtualization Framework           │
├────────┼─────────────────────────────────────────┤
│        ▼                                          │
│  ┌──────────────────────────────────────────────┐ │
│  │          macOS Guest VM                       │ │
│  │                                               │ │
│  │  ┌─────────────────────────────────────────┐ │ │
│  │  │ WezTerm → HERDR (auto-starts on boot)    │ │ │
│  │  │                                           │ │ │
│  │  │  OFFLINE    → Prime Agent + oMLX/Qwen3.8  │ │ │
│  │  │  OPNDRM     → Prime Agent + Ollama Cloud  │ │ │
│  │  │  OPNDRM JC  → JCode                       │ │ │
│  │  │  OPNDRM NM  → inactive shell              │ │ │
│  │  └─────────────────────────────────────────┘ │ │
│  │                                               │ │
│  │  OpenAdapt (recording)                        │ │
│  │  Guest Helper (vsock port 2222)               │ │
│  └──────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────┘
```

---

## Pre-Installed Guest Stack

Every VM build ships with these tools pre-installed and auto-configured:

| Tool | Purpose | Workspace |
|------|---------|-----------|
| WezTerm | Terminal emulator with WebGPU | Host window |
| HERDR | Workspace multiplexer for AI agents | Guest, session `opndrm` |
| Handy | Local speech-to-text | Guest, global |
| Prime Agent | AI orchestrator (Ollama + oMLX) | OFFLINE, OPNDRM |
| JCode | Primary coding executor | OPNDRM JC |
| No Mistakes | Code validation gate (inactive) | OPNDRM NO-MISTAKES |
| Ollama | Cloud model gateway | Guest, localhost:11434 |
| oMLX | Local model runtime (Qwen3.8-27B-mxfp4) | OFFLINE |
| OpenAdapt | Session recording + replay | Guest, on-demand |
| Buzz | Human/agent conversation | Host, separate app |

### Ollama Cloud integration

- The Ollama provider in Prime Agent is configured to reach both local models
  and the full Ollama Cloud catalog (authenticated via user-supplied API key).
- The API key is entered once through the Settings UI and stored in the guest's
  secure credential store — never in the repo, never in logs, never handled
  by the installer.
- JCode uses the same Ollama Cloud endpoint via its OpenAI-compatible provider
  profile.

### oMLX offline model

- Qwen3.8-27B-mxfp4 runs locally inside the guest via oMLX.
- This is the OFFLINE workspace's model — no cloud dependency.
- The model file is bundled into the VM image (not downloaded at runtime).

### Buzz harness bridge

- Prime Agent runs as a harness inside Buzz via the `opndrm-prime-acp` bridge.
- The bridge config (`buzz-prime-agent-harness.json`) is pre-installed in the
  guest so Buzz can discover and connect to the in-VM Prime Agent.

---

## HERDR Auto-Setup (Guaranteed On Every Boot)

When the guest VM boots and WezTerm launches, HERDR attaches to the persistent
`opndrm` session with exactly four workspaces in this fixed order:

| # | Workspace | Agent | Model/Provider | Auto-start |
|---|-----------|-------|-----------------|------------|
| 1 | OFFLINE | Prime Agent | oMLX / Qwen3.8-27B-mxfp4 | Yes |
| 2 | OPNDRM | Prime Agent | Ollama Cloud (all models) | Yes |
| 3 | OPNDRM JC | JCode | (user-selected model) | Yes |
| 4 | OPNDRM NO-MISTAKES | inactive shell | — | No |

This layout is defined in `config/herdr-layout.json` and enforced by the
guest first-boot provisioning script. It must survive VM reboots, controller
restarts, and guest process restarts. The HERDR server runs as a guest
LaunchAgent so the session persists.

---

## Host App: OPNDRM VM

### Naming

The product is **OPNDRM VM** (not BuzzBot). All references, window titles,
process names, CLI commands, and documentation use this name.

- Binary: `opndrm-vm`
- CLI: `opndrm-vm show|hide|stop|status|settings`
- Window title: `OPNDRM VM` (not `buzzbot-mac-002`)
- Socket: `localhost:7777` (unchanged)
- VM state directory: `~/Library/Application Support/OPNDRM-VM/`

### Top Bar Controls

The VM window title bar contains:

| Control | Action |
|---------|--------|
| **Settings** | Opens the Settings panel (see below) |
| **Record** | Starts/stops an OpenAdapt recording session |
| **Recordings · \<state\>** | Opens the recordings list overlay |
| **Check Guest** | Verifies guest helper connectivity |

### Settings Panel

A popover panel accessible from the title bar. It provides:

1. **AI Configuration**
   - Ollama Cloud API key entry (stored in guest keychain)
   - Model selection for each workspace (OFFLINE, OPNDRM, OPNDRM JC)
   - oMLX model path display
   - JCode provider profile management

2. **VM Lifecycle**
   - Start, stop, pause, resume
   - Memory allocation slider (minimum 16 GB for Qwen3.8-27B)
   - Disk usage display
   - Factory reset (destroys VM, recreates from image)

3. **Recording**
   - OpenAdapt status (installed, version, permissions)
   - Recording quality settings
   - Recording storage location

4. **Documentation**
   - Quick-start guide
   - Link to https://opndrm.com/docs
   - HERDR layout reference
   - OpenAdapt recording guide

---

## OpenAdapt Recording Loop

The Record button is the product's differentiator. It captures the VM session
(screen + input events) so recordings can be replayed to train AI agents on
repeated routines.

### Flow

```
User clicks Record
    ↓
Guest helper starts OpenAdapt capture (guest-local, vsock command)
    ↓
OpenAdapt records screen + input events → recording.db + video
    ↓
User clicks Stop
    ↓
Recording finalized in guest ~/Recordings/<name>/
    ↓
Recordings list updates (title bar shows count)
    ↓
User clicks a recording → plays inside VM browser (guest-local viewer.html)
    ↓
Recording can be fed to an AI agent as training material
``### Current Status

- **Working**: Guest helper vsock communication, consent dialog, readiness check
- **Blocked**: OpenAdapt's macOS `video_writer` fails in Apple Virtualization
  guests. The `spawn` multiprocessing path is not validated for VM guests.
- **Needed**: A guest-compatible video writer fix or replacement. This is the
  highest-priority engineering task.

### Success Criteria

1. Click Record → recording starts, Record button turns red
2. Perform actions in the VM
3. Click Stop → recording is finalized
4. Click the recording in the list → it plays in the guest browser
5. The recording file can be referenced by an AI agent as training material

---

## Packaging

### Install experience

```bash
# One command
curl -fsSL https://opndrm.com/install | bash
```

This installs:
- `opndrm-vm` binary (codesigned with virtualization entitlement)
- `opndrm` CLI to `~/.local/bin/`
- LaunchAgent plist for daemon auto-start
- Downloads IPSW and creates first VM
- VM boots, guest auto-provisions the full stack
- Prints: "OPNDRM VM ready. Run `opndrm-vm show` to open your workspace."

### VM Image

- Built from a golden macOS IPSW image
- Guest provisioning runs automatically on first boot
- oMLX model (Qwen3.8-27B-mxfp4, ~14 GB) is bundled into the image
- All tools (WezTerm, HERDR, Prime Agent, JCode, Ollama, OpenAdapt, Handy) are
  pre-installed so the user never runs a manual setup step
- HERDR session `opndrm` with the four-workspace layout is pre-created

### .pkg distribution

- Signed `.pkg` installer for macOS
- Hosted at `opndrm.com/install`
- Vercel landing page at `opndrm.com`

---

## Repository Thinning

The repo must be surgical. Only files that serve the product stay.

### Keep

```
opndrm/prime/
├── README.md
├── package.json
├── vercel.json
├── config/
│   └── herdr-layout.json
├── apps/
│   └── opndrm-vm/              (renamed from buzzbot-computer-service)
│       ├── Package.swift
│       ├── Sources/
│       │   ├── OPNDRMVMApp.swift         (renamed)
│       │   ├── OPNDRMVMWindow.swift      (renamed, has Settings + Record + Recordings)
│       │   ├── VirtualMachineController.swift
│       │   ├── GuestSocketClient.swift
│       │   ├── MacStateAdoption.swift
│       │   ├── AgentComputerStore.swift
│       │   ├── GuestControlState.swift
│       │   ├── OPNDRMProtocol/          (renamed from BuzzBotProtocol)
│       │   │   └── GuestCommandProtocol.swift
│       │   ├── OPNDRMGuestEngine/       (renamed from BuzzBotGuestEngine)
│       │   │   └── OpenAdaptGuestEngine.swift
│       │   └── OPNDRMGuestHelper/       (renamed from BuzzBotGuestHelper)
│       │       └── OPNDRMGuestHelper.swift
│       └── Tests/
├── guest-payloads/
│   └── macos/
│       ├── first-boot-opndrm.sh
│       ├── prime-workflow/
│       └── openadapt-guest-coordinator.py
├── scripts/
│   ├── install-macos.sh
│   ├── configure-prime-ollama.py
│   └── build-vm-image.sh           (new — builds the golden VM image)
├── docs/
│   ├── MASTER-PLAN.md              (this file)
│   ├── GETTING-STARTED.en.md
│   └── HERDR-WEZTERM-LAYOUT.md
├── site/                           (Vercel landing page)
│   └── index.html
└── skills/
    └── opndrm-vm/                  (agent skill for controlling the VM)
```

### Remove

- `apps/buzz-container-window/` — separate product, not part of OPNDRM VM
- `containers/apple-container/` — Linux foundation, separate future product
- `integrations/cleanshot-x/` — not part of the core product
- `integrations/orchard/` — not part of the core product
- `evaluations/` — research artifacts, not product code
- `api/` — admin endpoints, not part of the product
- `brand/buzzbot-computer/` — renamed to `brand/opndrm-vm/`
- All `buzzbot` naming references → `opndrm-vm`

### Rename

| From | To |
|------|-----|
| `buzzbot-computer-service` | `opndrm-vm` |
| `BuzzBotComputerService` | `OPNDRMVM` |
| `BuzzBotProtocol` | `OPNDRMProtocol` |
| `BuzzBotGuestEngine` | `OPNDRMGuestEngine` |
| `BuzzBotGuestHelper` | `OPNDRMGuestHelper` |
| `buzzbot-mac-002` (default VM name) | `opndrm-vm-001` |
| `~/Library/Application Support/BuzzBot/` | `~/Library/Application Support/OPNDRM-VM/` |
| `com.opndrm.buzzbot-guest-helper` | `com.opndrm.vm-guest-helper` |
| Window title `buzzbot-mac-002` | `OPNDRM VM` |
| CLI `buzzbot` | `opndrm-vm` |

---

## Implementation Priorities

### Phase 1 — Fix the recording loop (highest priority)

The Record button must work. Without it, the product's differentiator doesn't
exist.

1. Diagnose OpenAdapt `video_writer` failure in Apple Virtualization guests
2. Implement a guest-compatible video writer (FFmpeg pipe or CGDisplayStream)
3. Test the full loop: Record → Stop → Playback in guest browser
4. Verify recordings are listed in the title-bar Recordings overlay

### Phase 2 — Rename and restructure

1. Rename all `BuzzBot` → `OPNDRM VM` across Swift, scripts, configs, docs
2. Remove non-product directories (containers, evaluations, integrations, api)
3. Update CLI, LaunchAgent, socket commands, window title
4. Rebuild and test

### Phase 3 — Settings UI

1. Add Settings button to VM window title bar
2. Build the Settings popover panel:
   - AI configuration (Ollama Cloud key, model selection)
   - VM lifecycle controls
   - Recording settings
   - Documentation links
3. Wire Settings to guest-side configuration via vsock commands

### Phase 4 — Guest auto-provisioning

1. Build a golden VM image with all tools pre-installed:
   - WezTerm, HERDR, Prime Agent, JCode, Ollama, oMLX, OpenAdapt, Handy
   - Qwen3.8-27B-mxfp4 model bundled
   - HERDR `opndrm` session pre-created with four workspaces
   - Ollama Cloud catalog enrolled (key entered by user via Settings)
2. Guest first-boot script configures everything automatically
3. Verify: VM boots → WezTerm opens → HERDR attaches → all four spaces live

### Phase 5 — Ollama Cloud integration

1. Configure Prime Agent `models.json` in the guest with the full cloud catalog
2. Configure JCode's OpenAI-compatible provider for Ollama Cloud
3. Settings UI lets user enter API key once → both agents pick it up
4. Verify `/scoped-models` shows all 20+ cloud models

### Phase 6 — Packaging

1. Build `.pkg` installer
2. Create golden VM image build script
3. Host installer at `opndrm.com/install`
4. Vercel landing page
5. Test: clean install on a fresh Mac → working VM with full stack

---

## Milestones

| Milestone | Success criteria | Priority |
|-----------|-----------------|----------|
| M1: Recording works | Record → Stop → Playback in guest | P0 |
| M2: Renamed | No `buzzbot` references remain in product code | P1 |
| M3: Settings UI | User can configure AI from the top bar | P1 |
| M4: Auto-provision | VM boots with full stack, zero manual setup | P1 |
| M5: Ollama Cloud | All cloud models visible in both agents | P2 |
| M6: Packaged | One-command install, `.pkg` distribution | P2 |
| M7: Thin repo | Only product files remain, tests pass | P2 |

---

## Constraints

- Host is a thin lifecycle/display controller — never an agent runtime
- All AI work happens inside the guest VM
- No host capture, no host agent processes, no credential handling
- VM state is persistent (survives controller restarts)
- One VM per machine (single canonical instance)
- HERDR layout is fixed and auto-recovering
- The repo stays thin — every file must earn its place
- English-only documentation and artifacts
- No Spanish content
- No Valo products

---

## Swarm Execution

Once this plan is approved, implementation can be parallelized using Ollama
agent swarms:

| Swarm | Task | Model |
|-------|------|-------|
| recording-fix | Diagnose and fix OpenAdapt video_writer for VM guests | oMLX/Qwen3.8 or Ollama Cloud |
| rename | Rename all BuzzBot → OPNDRM VM across the repo | Ollama Cloud (fast model) |
| settings-ui | Build the Settings popover panel in Swift | Ollama Cloud (code model) |
| guest-provision | Build golden VM image and first-boot script | Ollama Cloud |
| ollama-cloud | Configure cloud catalog in guest agents | Ollama Cloud |
| packaging | Build .pkg installer and landing page | Ollama Cloud |
| repo-thin | Remove non-product files, verify tests pass | Ollama Cloud |

Each swarm writes to a separate branch and opens a PR. The Captain reviews and
merges. No swarm writes to `main` directly.
