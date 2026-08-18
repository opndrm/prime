# OPNDRM VM

**UTM, but for AI control.**

A macOS app that creates, manages, and displays private AI sandbox VMs. Any AI agent connects to a VM and works inside it as a safe sandbox. The human watches from the host.

## Install

```sh
curl -fsSL https://opndrm.com/install | bash
```

## What it does

- Creates Apple or Linux VMs (like UTM)
- Saves, restores, clones, and destroys VMs
- Displays multiple VMs simultaneously (quad/split/triple/single)
- Connects any AI agent via a socket (port 7777)
- Records VM sessions for AI training (OpenAdapt/FFmpeg)
- One-click Open Dream workflow install inside any VM

## The Open Dream Workflow

Inside any VM, run:

```sh
curl -fsSL https://opndrm.com/install | bash
```

This installs WezTerm, HERDR, Prime Agent, JCode, Ollama, oMLX, OpenAdapt, and Handy. Your HERDR session gets four workspaces:

| Workspace | Agent | Model |
|-----------|-------|-------|
| OFFLINE | Prime Agent | oMLX / Qwen3.8-27B |
| OPNDRM | Prime Agent | Ollama Cloud |
| OPNDRM JC | JCode | (user-selected) |
| OPNDRM NO-MISTAKES | inactive | - |

## Build

```sh
git clone https://github.com/opndrm/prime.git
cd prime/apps/opndrm-vm
swift build -c release
codesign --sign - --force --entitlements /tmp/ent.plist .build/release/opndrm-vm
```

## CLI

```sh
opndrm-vm show [name]        # show VM window
opndrm-vm stop [name]        # stop VM
opndrm-vm save [name] [label]    # snapshot VM
opndrm-vm restore [name] [label] # restore from snapshot
opndrm-vm clone [src] [dst]      # duplicate VM
opndrm-vm destroy [name]     # delete VM
opndrm-vm list               # list all VMs
opndrm-vm status             # daemon + VM status
opndrm-vm disk               # disk usage
```

## Architecture

```
OPNDRM VM.app (host)
  ├── Main Window (UTM-style: sidebar + VM list)
  ├── Multi-VM Layout (single/split/triple/quad)
  ├── Settings (VM, AI, Recording, Docs)
  ├── Socket Server (port 7777, any AI connects)
  └── VZ Virtual Machine View (Apple Virtualization)
      └── macOS Guest VM
          ├── WezTerm + HERDR (auto-starts)
          ├── Prime Agent, JCode, Ollama, oMLX
          ├── OpenAdapt (recording)
          └── Guest Helper (vsock:2222)
```

## License

MIT
