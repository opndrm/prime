# Normative guest-local ACP gateway contract (v1)

The keywords **MUST**, **MUST NOT**, and **REFUSE** are normative.

## Boundary and authority

1. This is a contract/payload, not an executable gateway. It MUST NOT be read
   as approval to install, invoke, or configure Prime or any binary.
2. A future implementation MUST run only in a prepared macOS guest, as its
   normal non-root `/Users/<guest-user>` owner, and MUST require both the
   runtime environment confirmation and the matching owner-consent record
   described below. `sudo`, root, host/bridge declarations, and symlinked
   paths MUST be refused.
3. It MUST use stdio inherited from its guest-local parent only. It MUST NOT
   bind, listen, connect, proxy, publish, expose, or discover any network or
   IPC endpoint (including TCP, UDP, Unix sockets, named pipes, SSH, and HTTP).
   It MUST NOT interact with the host, Buzz, or Orchard.
4. It MUST use exactly
   `/Users/<guest-user>/.local/share/opndrm-prime/acp-gateway/work` as its
   current directory and the sole workspace authority. The directory MUST
   already exist, be owned by `<guest-user>`, be a non-symlink, and have mode
   `0700`. Its containing `acp-gateway`, `bin`, `consent`, and `receipts`
   directories MUST also be guest-owned non-symlink directories with mode `0700`.
   No caller-controlled cwd, path, environment path, mount, source, executable,
   tool, or plugin is permitted.
5. It MUST NOT offer generic command execution or accept command text, shell
   syntax, executable paths, arguments, environment changes, tool calls, MCP
   servers, file-transfer requests, or arbitrary JSON-RPC/ACP methods.

## Exactly one lifecycle

The normative frame/order limits are in `payload/acp-session-lifecycle.json`.
A conforming future implementation MUST accept exactly three inbound framed
JSON-RPC 2.0 requests, in this exact sequence and with the exact fixed IDs:

1. `initialize`, ID `init-1`;
2. `session/new`, ID `new-1`, with the fixed work directory and an empty MCP
   server set;
3. `session/prompt`, ID `prompt-1`, bound to the one returned session ID and
   containing byte-for-byte the `payload/restricted-prompt.json` content.

It MUST allow at most 32 KiB per inbound frame, three inbound frames total, 32
KiB per outbound frame, and 16 outbound frames total. Frames are UTF-8 JSON,
one JSON object per newline-delimited stdio frame. Any parse failure,
notification, batch, duplicate, unknown method, wrong ID/order, second
session, second prompt, extra frame, oversized frame, or post-result input MUST
be refused without forwarding it. After the prompt result, it MUST close its
stdio streams and terminate; it MUST NOT retain, resume, cancel/retry, or reuse
the session. It MUST fail closed if the ACP peer emits a frame above the stated
outbound bounds.

The one permitted prompt has no action, tool, command, path, or parameter. Its
only allowed response is the stated acknowledgement. The contract intentionally
provides no capability for an ACP agent to perform guest work.

## Explicit owner consent record

Before every prospective lifecycle, the fixed file
`.../consent/owner-consent.tsv` MUST be an owned, non-symlink regular file with
mode `0600` and exactly one tab-separated line:

```text
acp-gateway-v1<TAB>CONSENT_ID<TAB>GUEST_OWNER_ID<TAB>I-CONSENT-TO-ONE-GUEST-LOCAL-ACP-SESSION
```

`CONSENT_ID` and `GUEST_OWNER_ID` are 3–128 characters of letters, digits,
period, underscore, or hyphen, beginning with a letter or digit. The literal
consent scope is required. At runtime, the guest owner MUST also supply exactly
`OPNDRM_ACP_GATEWAY_OWNER_CONFIRMATION='I CONSENT TO ONE GUEST-LOCAL ACP SESSION'`
and `--guest-owner-confirmed`. The validation script requires those two fresh
signals and refuses a mismatched record. Consent is one-lifecycle only; no
standing, host, or delegated consent exists here.

## Guest-local Prime ACP checksum receipt

Before every prospective lifecycle, the fixed file
`.../receipts/prime-agent-acp.sha256.tsv` MUST be an owned, non-symlink regular
file with mode `0600` and exactly one tab-separated line:

```text
acp-gateway-v1<TAB>CONSENT_ID<TAB>bin/prime-agent-acp<TAB>SHA256_LOWERCASE
```

Its `CONSENT_ID` MUST exactly equal the consent record’s ID. `SHA256_LOWERCASE`
must be 64 lowercase hexadecimal characters and match the fixed guest-local
regular non-symlink binary at `.../bin/prime-agent-acp`. This is a guest-local
checksum receipt only; the validator reads and hashes the binary but MUST NOT
execute it. Missing, extra, malformed, symlinked, foreign-owned, group/world
writable, or mismatching records/binary MUST be refused.

## Validation limits

The included validators are deliberately inert. They do not launch Prime, pass
frames, create directories, write receipts, change permissions, install
packages, delete files, or use network operations. A successful validator does
not authorize a future gateway. Any implementation, installation, or invocation
would require new separately reviewed guest-owner authorization outside this
payload.
