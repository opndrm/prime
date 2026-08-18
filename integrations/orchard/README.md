# Orchard Agent Computers integration

This directory records the OpenDream Prime integration boundary for the local
Orchard source checkout in `vendor/orchard/`.

## Scope of the first slice

The local Orchard checkout adds **Agent Computers** under Orchard's **Compute**
navigation. It is an intentionally inert, read-only state:

- no container discovery, start, stop, create, delete, or attachment;
- no reuse of Orchard's model-connected Sandbox chat or terminal surface;
- no model/provider route, Web/TCP socket, remote connection, recording,
  clipboard, terminal input, or file transfer;
- no host credentials, repository checkout, or task assignment.

It preserves the OpenDream Prime Apple Container visual-profile and native
Unix-socket receiver as future implementation references. A later, separately
approved slice may connect one explicitly assigned task to a bounded,
watch-only local visual session.

## Maintainership boundary

`vendor/orchard/` is a clean clone of the public MIT-licensed Orchard source,
with local OpenDream Prime changes visible as an ordinary git diff. It is not
an installed-app patch, GitHub fork, deployment, or vendor replacement. Before
maintaining a distribution, the owner must choose a maintained fork/release
identity and separately review Orchard's upstream updates and licensing.
