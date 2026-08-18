# Buzz extension and native-window investigation

## Decision

OpenDream Prime will **not modify the Buzz macOS app**. The permanent product
surface for a future Agent Computer is a separate, native **Buzz Container**
window. It may float above Buzz, but it is independently owned and does not
embed in, automate, inspect, or extend the installed app.

No project-local bridge is implemented by this document.

## Verified local facts

- The installed Buzz Desktop app is version `0.5.14`, signed by Block, Inc.,
  and its bundle declares the `buzz://` URL scheme. That is not a documented
  panel/plugin surface.
- The installed CLI is `/Users/uoa/.local/bin/buzz`. `buzz --version` is not a
  supported flag. Its local-only commands are `buzz pack validate` and
  `buzz pack inspect`; both operate on a supplied persona-pack directory.
- `buzz agents` exposes owner-reviewed Desktop drafts and archive operations.
  `buzz workflows` creates and triggers relay YAML workflows. Neither command
  registers a host-local skill/tool with an existing managed agent.
- The installed `buzz-acp` help exposes one external stdio MCP command through
  `--mcp-command`. That is the supported agent-tool boundary discovered here.
  It was inspected only; no harness, relay, credentials, model provider, or
  agent process was started.

## Supported future tool seam and its current limitation

The eventual local Buzz Container lifecycle tool should be a narrowly scoped
stdio MCP server, not a generic shell or a web page. Its future allowlist can
contain only lifecycle requests such as preflight, status, evidence handoff,
owner-approved provision request, and teardown request. It must preserve the
project's no-host-mount, no-credentials, no-network, no-ports, and explicit
owner-approval boundaries.

Today this is a **harness configuration seam, not a CLI registration API**:
`buzz-acp --mcp-command <project-local-server>` would require an explicitly
approved, separately configured agent harness and relay identity. It cannot be
silently attached to the existing Buzz Desktop agent. The currently documented
harness accepts one MCP command, so using a dedicated Buzz Container MCP server
would displace `buzz-dev-mcp` unless upstream provides multi-server support or
an explicitly approved composite server is designed. No such configuration or
server exists in this project.

Persona packs are not a substitute for this. The CLI can validate/inspect a
pack and bundled parsing recognizes `SKILL.md`, `plugin.json`, and MCP metadata,
but no verified current path installs that project-local pack as a callable tool
on the existing managed agent. The existing
[`../../skills/buzz-container/SKILL.md`](../../skills/buzz-container/SKILL.md)
remains a project-local instruction artifact, not a Buzz-installed extension.

## Native-window trigger model

The desired permanent path is intentionally separated into two contracts:

```text
future Buzz ACP/MCP request
  -> local, allowlisted Buzz Container bridge
  -> project-local Unix-domain-socket WindowRequest
  -> separate native Buzz Container panel
  -> future loopback-only task-VM viewer
```

The native panel never receives raw relay content or credentials. The bridge
must validate a schema version, task identity, intent, expiry, and local owner
approval state before it can request a window. The first allowed intent is
`open-status`; it is inert and cannot start a VM, control input, record, or
open another application. A remote workflow must never be able to directly
spawn a host GUI.

Until that bridge is separately approved and implemented, Buzz cannot trigger
the window. A manual local fixture request is the only appropriate first test.

## Sources

- [Buzz agent architecture](https://github.com/block/buzz/blob/main/VISION_AGENT.md)
  documents ACP-over-stdio for `buzz-agent` and MCP-over-stdio for tools.
- [Buzz ACP one-MCP limitation](https://github.com/block/buzz/issues/2899)
  documents the current one-server configuration limitation.
- [Buzz persona-pack gap](https://github.com/block/buzz/issues/3628) documents
  that pack validation and runtime consumption are currently disconnected.
