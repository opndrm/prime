# Guest-local Prime ACP gateway — inert contract payload

## Scope

This directory is a **declarative, guest-only ACP gateway contract**. It is not
a gateway implementation. It does not install or run Prime, invoke the listed
binary, start a listener, open a socket, expose a port, contact a network, or
alter the host, Buzz, or Orchard. Its scripts only read static files and,
optionally, hash an already-present guest-local binary. They never create a
work directory, receipt, consent record, process, or network connection.

The contract applies only after a guest owner has separately reviewed it and
has explicitly consented. A passing validation is a receipt-format and hash
check, **not permission to launch anything**.

## Fixed guest-local locations

For the non-root macOS guest user `<guest-user>`, these paths are fixed; a
caller may not override, expand, or substitute them:

```text
/Users/<guest-user>/.local/share/opndrm-prime/acp-gateway/work
/Users/<guest-user>/.local/share/opndrm-prime/acp-gateway/bin/prime-agent-acp
/Users/<guest-user>/.local/share/opndrm-prime/acp-gateway/consent/owner-consent.tsv
/Users/<guest-user>/.local/share/opndrm-prime/acp-gateway/receipts/prime-agent-acp.sha256.tsv
```

`work` is the only allowed ACP `cwd`. It must already be a real directory,
owned by the guest user, with no symlink in its path and mode `0700`. The
contract has no filesystem authority outside it. The binary, consent, and
receipt are input records only. No script here makes them.

## Exact allowed lifecycle

`payload/acp-session-lifecycle.json` is the normative machine-readable
contract. It permits exactly one stdio-only JSON-RPC/ACP lifecycle: `initialize`
then `session/new` then one `session/prompt`, followed by EOF after the prompt
result. The three client frames, their IDs, order, `cwd`, and prompt payload
are fixed. The prompt is a non-operative acknowledgement, not a command.

There is no TCP/Unix listener, reconnect, retry, session reuse, second prompt,
MCP server, tool registration, file transfer, generic command, shell, process,
or arbitrary ACP method. An implementation must fail closed before forwarding
any non-conforming frame. This contract authorizes neither Prime nor an ACP
implementation to execute anything.

## Owner inputs and validation

Templates are deliberately invalid. The guest owner must separately create the
fixed local consent and checksum receipt as single TSV lines matching the
formats documented in `CONTRACT.md`. The receipt SHA-256 must match the fixed
regular, non-symlink binary. A receipt only records a hash; it does not attest
to provenance, safety, installation, or authorization to execute the binary.

In a prepared guest only, a read-only format/hash check may be requested with:

```sh
OPNDRM_GUEST_CONTEXT=macos-guest \
OPNDRM_ACP_GATEWAY_OWNER_CONFIRMATION='I CONSENT TO ONE GUEST-LOCAL ACP SESSION' \
./scripts/validate-owner-records.sh --validate-owner-records --guest-owner-confirmed
```

`validate-acp-gateway-contract.sh --validate-static` validates only this
payload bundle and requires no owner files. Neither validation script runs
Prime or the binary. Both reject every other mode.

## Files

- `CONTRACT.md` — normative restrictions and TSV schemas.
- `payload/acp-session-lifecycle.json` — fixed lifecycle/frame/payload contract.
- `payload/restricted-prompt.json` — the only allowed prompt content.
- `payload/*.template` — invalid owner-record examples.
- `scripts/validate-acp-gateway-contract.sh` — static, read-only bundle check.
- `scripts/validate-owner-records.sh` — read-only guest context, owner consent,
  path/mode, and SHA-256 receipt check.

No host, Buzz, Orchard, website, credential, installation, activation, or
network action is requested or performed by this payload.
