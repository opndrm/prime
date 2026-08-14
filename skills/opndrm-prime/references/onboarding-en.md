# Open Dream Prime onboarding — English

Use this sequence with a new teammate.

1. Ask which workspace they need: OPNDRM APP for a new build, ADAM, or FRNKLY.ONE.
2. Have them use the installer from opndrm.com. On a Mac without Apple Command Line Tools, it opens Software Update directly. If Apple requires a macOS update first, complete it, restart if asked, and rerun the same OPNDRM command; otherwise install the Apple tools and the original Terminal continues. On Windows, clearly identify the installer as a first-device preview. If Windows App Installer is missing, it opens Microsoft Store and the person reruns the same command after that prerequisite is installed. The official Buzz installer appears in its own visible window. For ADAM or FRNKLY.ONE, GitHub CLI—not a separate browser action—runs one personal device authorization before cloning: the teammate signs in with their own GitHub account and enters its one-time code only at GitHub’s official device page. No shared Open Dream login, token, credential, or GitHub administrator repository access is used. The installer displays the signed-in username and checks private repository read access before it clones. If access is missing, the repository owner must invite that personal account as a normal collaborator with the needed repository access; FRNKLY.ONE always requires that invitation. FRNKLY.ONE is the Rust rebuild at `https://github.com/opndrm/Frnkly.one.git`; its local lane remains FRNKLY.ONE. OPNDRM APP never opens GitHub device authorization.
3. Confirm that their checkout is their own and has not overwritten another project.
4. The installer creates or reuses the matching personal HERDR session only after the selected root exists, then opens WezTerm attached to `opndrm-opndrm-app`, `opndrm-adam`, or `opndrm-frnkly-one`. It stops without a Ready claim if that session cannot start or attach.
5. Explain the visible roles: PRIME builds; `NO MISTAKES GATE — RESERVED (INACTIVE)` remains idle; Buzz is conversation; Wayfinder is the GitHub Issue plan; GitHub is the code record.
6. The installer prepares and opens that employee’s local Buzz onboarding record in the selected workspace context with a suggested named PRIME agent. It remains waiting for the employee’s own Buzz sign-in; the employee then creates or connects the agent and stores its approved identifier in their own Atomic Vault OPNDRM entry.
7. Let the employee complete their own Atomic Vault sign-in and trust step. Do not handle or request their credentials.
8. Start the first task from one Wayfinder issue. State its outcome, scope, quality check, and stop condition.

If setup stops, report the plain blocker. Never ask a teammate to paste a password, token, recovery code, or private key.
