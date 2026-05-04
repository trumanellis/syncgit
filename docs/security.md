# Security

## Trust model

syncgit is a local-only tool today. All peer worktrees live on the same filesystem and are expected to be owned by the same user. Peers trust each other implicitly — this is intentional for the single-developer, multi-agent use case.

## Attack surface

**What a peer can do:** Any process with write access to your repository can push to your `refs/pr/*` namespace (the same access git itself requires). A malicious peer could broadcast a ref pointing to any commit object — including one that modifies history or introduces unwanted content.

**What a peer cannot do:** Modify your worktree files directly. Broadcasts only update refs. Your working tree and branch are not touched until you explicitly run `syncgit merge`.

**Inspect before absorbing:** Use `syncgit show <ref>` to review a pending peer ref's log and diffstat before running `syncgit merge`. `syncgit status` lists all pending inbound refs.

## The verify.sh hook

`.syncgit/verify.sh` runs as the local user with full shell access during `syncgit verify`. Only commit a `verify.sh` you have reviewed. Do not copy an unreviewed script from a peer worktree into your `.syncgit/` directory.

## peers.json

`.syncgit/peers.json` is plaintext JSON with no authentication. This is appropriate for local-only use where all peers are trusted. A networked transport (planned for v1.0) would require an explicit auth model.

## Peer-id validation

`syncgit init` rejects peer ids that do not match `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`. This blocks path-traversal patterns (`..`, `/`, leading dashes or underscores) that could be used to escape the worktree directory structure.

## Planned network transport

Network transport is not implemented in v0.1. When it is, the following decisions will need to be made explicitly:

- Authentication: SSH keys tied to git remote URLs, scoped to `refs/pr/*` push-only access
- Per-peer ACLs: which peers may broadcast to which namespaces
- Ref validation on receipt: reject refs whose tip is not signed or is not reachable from a trusted root

## Reporting vulnerabilities

Open a private [GitHub Security Advisory](https://github.com/trumanellis/syncgit/security/advisories/new) rather than a public issue. Include reproduction steps, affected version (`syncgit --version`), and impact assessment.
