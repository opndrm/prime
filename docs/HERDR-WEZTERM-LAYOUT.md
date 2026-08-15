# Open Dream Prime: Standard HERDR + WezTerm Layout

This is the portable macOS layout installed with Open Dream Prime. It reflects the current nine-space operating setup without copying a person’s session IDs, credentials, provider configuration, or local model configuration.

| Order | Workspace | Root role | Client/state |
|---:|---|---|---|
| 1 | OFFLINE | home | Prime Agent |
| 2 | AUDITOR PRIME | home | Prime Agent |
| 3 | AUDITOR JCODE | home | JCode |
| 4 | ADAM PRIME | ADAM checkout | Prime Agent |
| 5 | ADAM JCODE | ADAM checkout | JCode |
| 6 | ADAM NO-MISTAKES | ADAM checkout | inactive gate |
| 7 | FRNKLY PRIME | FRNKLY.ONE checkout | Prime Agent |
| 8 | FRNKLY JCODE | FRNKLY.ONE checkout | JCode |
| 9 | FRNKLY NO-MISTAKES | FRNKLY.ONE checkout | inactive gate |

Run the macOS installer once for each approved app checkout. It creates only roots the owner has locally; it never clones a private app without access, overwrites a checkout, starts a gate, handles credentials, or sets model configuration.

Prime Agent orchestrates approved work. JCode is the primary coding executor. The portable machine-readable layout is `config/herdr-layout.json`.

## Handy dictation

The macOS installer installs [Handy](https://handy.computer/), a local speech-to-text app. It does not grant Microphone or Accessibility permissions and does not download or select a transcription model; each owner completes those choices locally.
