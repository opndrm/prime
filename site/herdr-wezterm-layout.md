# Open Dream Prime: HERDR + WezTerm Layout

The one-command macOS installer creates exactly this four-workspace HERDR sidebar, in this order:

| Order | Workspace | Root | Client/state |
|---:|---|---|---|
| 1 | OFFLINE | home | Prime Agent |
| 2 | OPNDRM | OPNDRM workspace | Prime Agent |
| 3 | OPNDRM JC | OPNDRM workspace | JCode |
| 4 | OPNDRM NO-MISTAKES | OPNDRM workspace | inactive gate |

No Auditor, ADAM, FRNKLY.ONE, or General Research workspaces are created.

`OPNDRM NO-MISTAKES` is a reserved visible shell. Installation never initializes, starts, attaches, approves, reruns, aborts, or repairs a No Mistakes pipeline.

The portable machine-readable source of truth is `config/herdr-layout.json`. It records labels, order, root roles, and client roles without copying session IDs, credentials, provider configuration, local model configuration, sockets, logs, or terminal transcripts.
