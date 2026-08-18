# OPNDRM Prime guest workflow — inert payload plan

## Scope and non-action guarantee

This directory is a **guest-only, declarative pre-installation plan** for a
prepared macOS guest. It supplies validation hooks for the intended workflow:

- WezTerm/HERDR (`hooks/wezterm-herdr.sh`)
- Prime Agent (`hooks/prime-agent.sh`)
- JCode (`hooks/jcode.sh`)
- Wayfinder (`hooks/wayfinder.sh`)
- No Mistakes (`hooks/no-mistakes.sh`), whose desired state is **installed but
  inactive**.

It does **not** contain a product artifact, installer, package-manager command,
repository URL, network operation, credential, service command, launch command,
or activation command. Nothing here claims that WezTerm, HERDR, Prime Agent,
JCode, Wayfinder, or No Mistakes is installed or available.

The hooks only read and hash owner-provided files. They do not write receipts or
state, create directories, install, configure, start, activate, download, or
delete anything. `--install`, `--activate`, and every other unlisted mode are
refused by argument validation.

## Hard guest boundary

Run a hook only **inside the intended macOS guest**, as its non-root normal
user. Every hook fails closed unless all of these are true:

1. `OPNDRM_GUEST_CONTEXT=macos-guest` is present.
2. The runtime is Darwin, is not root or `sudo`, and `$HOME` is the regular
   `/Users/<guest-user>` home directory.
3. The image has already provisioned a non-symlink
   `$HOME/.opndrm-guest-context` file containing exactly `macos-guest`. Hooks
   never make this marker.
4. No declared `OPNDRM_HOST_BRIDGE` or `OPNDRM_BRIDGE_CONTEXT` exists and no
   common shared/bridged filesystem is detected.
5. The guest owner supplies both the exact confirmation environment value and
   `--guest-owner-confirmed` on this invocation.
6. A complete, guest-local approved-artifact lock exists and all five local
   artifacts match their locked SHA-256 values.

These checks are a conservative boundary, not proof that every possible host
bridge can be discovered by a shell script. A failed or unavailable check is a
refusal. Do not run this directory from the host, through a shared mount, or
with guest or host credentials.

## Guest owner approval lock

Before a separately reviewed installer may do any actual installation, the
**guest owner** must prepare, review, and retain only guest-local inputs below:

```text
$HOME/.config/opndrm-prime/prime-workflow/
├── approved-artifacts.tsv
└── artifacts/
    ├── wezterm-herdr/<one regular file>
    ├── prime-agent/<one regular file>
    ├── jcode/<one regular file>
    ├── wayfinder/<one regular file>
    └── no-mistakes/<one regular file>
```

No payload script creates this tree or copies files into it. The owner must
place only reviewed, regular, non-symlink files there. Each parent and artifact
must remain under the verified guest home; symlinks, missing paths, extra lock
entries, duplicate components, URLs, and hash mismatches are rejected.

Use `approved-artifacts.tsv.template` only as a field-format reference. It is
intentionally invalid and is not a lock. The live lock must contain exactly one
tab-separated line for each required component:

```text
component  approved-source-id  owner-approval-id  artifact-relative-path  sha256-lowercase  desired-state
```

`approved-source-id` and `owner-approval-id` are required owner-reviewed opaque
identifiers (letters, digits, `.`, `_`, `-` only); they are not URLs, commands,
or credentials. SHA-256 must be 64 lowercase hexadecimal characters and must
match the corresponding guest-local artifact. Required desired states are
`install-plan-only` for WezTerm/HERDR, Prime Agent, JCode, and Wayfinder, and
`install-inactive-only` for No Mistakes.

`install-inactive-only` describes a future approved end state only. It does not
state that No Mistakes is currently installed. Any future installer must leave
No Mistakes stopped, with no service, gate, pipeline, or activation action. No
activation authority is granted by this payload or a passing validation.

## Validation invocation

After the owner has prepared all five approved guest-local artifacts and the
complete lock, validate the desired component immediately before a separately
reviewed guest-local installation step:

```sh
OPNDRM_GUEST_CONTEXT=macos-guest \
OPNDRM_GUEST_OWNER_CONFIRMATION='I CONFIRM THIS GUEST-ONLY PRIME WORKFLOW PLAN' \
./hooks/prime-agent.sh --validate-plan --guest-owner-confirmed
```

Substitute one of `wezterm-herdr`, `prime-agent`, `jcode`, `wayfinder`, or
`no-mistakes` for the hook name. Each hook validates the *entire* five-component
lock, then reports only that its selected component has a matching local
artifact. A success explicitly says that no software was installed or started.

A later installer is outside this payload and must be separately owner-approved,
guest-local, source-pinned, and must call the relevant validation hook again
immediately before acting. It must refuse if validation does not exit
successfully. This plan provides no fallback source, network path, privilege,
credential, or implied approval.

## No Mistakes inactive contract

The No Mistakes hook validates only the `install-inactive-only` declaration and
its local artifact hash. It has no code path for installation or activation.
Future guest-local work may install it only after the same fresh owner
confirmation and complete lock validation, and must leave it inactive. Starting
a service, running a gate/pipeline, or changing that desired state requires a
new explicit guest-owner approval outside this payload.

## Files

| File | Purpose |
| --- | --- |
| `hooks/lib/guest-plan-common.sh` | Shared read-only guest-boundary, confirmation, lock, and SHA-256 validation. |
| `hooks/wezterm-herdr.sh` | Validation entry point for the combined WezTerm/HERDR plan. |
| `hooks/prime-agent.sh` | Validation entry point for the Prime Agent plan. |
| `hooks/jcode.sh` | Validation entry point for the JCode plan. |
| `hooks/wayfinder.sh` | Validation entry point for the Wayfinder plan. |
| `hooks/no-mistakes.sh` | Validation entry point for the installed-but-inactive No Mistakes plan. |
| `approved-artifacts.tsv.template` | Deliberately invalid documentation template; never an approved lock. |

## Remaining owner/guest actions

1. Prepare and identify the intended guest; provision its immutable guest marker
   as part of image preparation, not from this payload.
2. In that guest, obtain the owner’s fresh explicit confirmation for the named
   workflow action.
3. Independently review and approve each source, place only the approved files
   in the guest-local artifact tree, compute/review their SHA-256 values, and
   create the complete live lock from the template.
4. Run the relevant validation hook in the guest immediately before any
   separately approved installer. Stop on any refusal.
5. If an installation is later authorized, perform it only with a separately
   reviewed guest-local installer. Keep No Mistakes installed but inactive; do
   not start it or its service/pipeline.

No host, Buzz, Orchard, website, credential, or external tool action is
requested or performed by this payload plan.
