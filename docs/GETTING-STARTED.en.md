# Open Dream Prime — Getting started

Run the Mac or Windows installer with the one project you are assigned: `ADAM` or `FRNKLY.ONE`.

Before a private project is cloned, GitHub CLI runs exactly one web/device authorization. Sign in with **your own GitHub account** and enter the one-time code only at GitHub’s official device page. The installer shows the signed-in username, then verifies that account can read the selected repository. It does not use an Open Dream shared login, a token, another credential, or GitHub administrator repository access. If it stops for missing access, ask the repository owner to invite your personal account as a normal collaborator with the needed repository access, then run the installer again. **FRNKLY.ONE requires that personal collaborator invitation.** Public **OPNDRM APP** does not start GitHub device authorization.

FRNKLY.ONE is the Rust rebuild. Its canonical private checkout is [`opndrm/Frnkly.one`](https://github.com/opndrm/Frnkly.one.git), while the installed workspace remains named `FRNKLY.ONE`.

When it finishes, open WezTerm. Your workspace has two simple areas:

- **PRIME** — start here. Tell Prime Agent what you want to build.
- **NO MISTAKES GATE** — this stays idle until you intentionally use it to check a finished branch.

Prime Agent starts with Ollama. DeepSeek V4 Flash is the default. MiniMax M3 and every installed Ollama model can be selected when needed.

Buzz is the team conversation space. Use it to discuss the work and link the relevant GitHub issue. Wayfinder keeps the GitHub issue plan. GitHub remains the official place for code, branches, reviews, and pull requests.

Atomic Vault is personal. Do not share credentials, private keys, or Vault access. If Vault trust is waiting, ask the team lead for the official owner-approved step.

The installer confirms that the Open Dream Prime GitHub package is installed and discoverable by Prime Agent. If that check fails, use `/reload` in Prime Agent; if it remains unavailable, check the local Prime Agent setup and run the installer again.
