# Open Dream Prime — Getting started

Run the Mac or Windows installer with the one project you are assigned: `ADAM` or `FRNKLY.ONE`.

Before a private project is cloned, GitHub CLI runs exactly one web/device authorization. Sign in with **your own GitHub account** and enter the one-time code only at GitHub’s official device page. The installer shows the signed-in username, then verifies that account can read the selected repository. It does not use an Open Dream shared login, a token, another credential, or GitHub administrator repository access. If it stops for missing access, ask the repository owner to invite your personal account as a normal collaborator with the needed repository access, then run the installer again. **FRNKLY.ONE requires that personal collaborator invitation.** Public **OPNDRM APP** does not start GitHub device authorization.

FRNKLY.ONE is the Rust rebuild. Its canonical private checkout is [`opndrm/Frnkly.one`](https://github.com/opndrm/Frnkly.one.git), while the installed workspace remains named `FRNKLY.ONE`.

On a successful install, WezTerm opens attached to your own named HERDR session for the selected workspace. The installer creates that personal session only after the selected root exists, and it stops without a `Ready` claim if HERDR cannot start or attach. Your workspace has two simple areas:

- **PRIME** — start here. Tell Prime Agent what you want to build.
- **NO MISTAKES GATE — RESERVED (INACTIVE)** — this stays idle until you intentionally use it to check a finished branch.

Prime Agent starts with Ollama. DeepSeek V4 Flash is the default. MiniMax M3 and every installed Ollama model can be selected when needed.

Buzz is the team conversation space. The installer visibly opens it and prepares its local onboarding context for the selected workspace, but it remains waiting for your own sign-in. Use it to discuss the work and link the relevant GitHub issue. Wayfinder opens only that selected repository’s GitHub Issues plan and records a local waiting-for-owner context; it creates or changes no issue, map, receipt, assignment, label, or decision. GitHub remains the official place for code, branches, reviews, and pull requests.

Atomic Vault is personal. Do not share credentials, private keys, or Vault access. If Vault trust is waiting, ask the team lead for the official owner-approved step.

The installer accepts a successful Open Dream Prime GitHub package install, then verifies that Prime Agent still responds. The package loads when Prime Agent starts or after `/reload`; a running Prime Agent does not need to list the package before setup continues.
