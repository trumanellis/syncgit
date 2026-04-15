# syncgit

A peer-to-peer VCS built on git worktrees. Each worktree is an equal peer tended by its own Claude Code agent — no `main`, no hub. Agents broadcast changes as "PRs" to every sibling over `refs/pr/*`, and each peer merges inbound PRs before it broadcasts its own.

The friction target: one keystroke (`/sync`) to stage sensibly, commit, absorb everything your peers have done, drive the tree back to green, and push your own work to all of them.

## How it works

```
~/Code/myproj/
  .git/                     shared object + ref store
  .syncgit/peers.json       [{id,path}, ...]
  agent1/   (branch: agent1)
  agent2/   (branch: agent2)
  agent3/   (branch: agent3)
```

- Each worktree adds every sibling as a local git remote (`peer-agent2 -> ../agent2`).
- The PR queue lives in git refs: `refs/pr/<peer-id>/<timestamp>`.
- Worktrees share a ref database, so a push to `peer-agent2` is visible to every peer immediately — no daemon, no central repo.
- `/sync` is a Claude Code slash command that orchestrates the whole flow: stage, commit, merge inbound PRs, verify, broadcast.

## Install

```sh
git clone https://github.com/<you>/syncgit ~/Code/syncgit
cd ~/Code/syncgit && ./install.sh
```

`install.sh` symlinks `bin/syncgit` into `~/.local/bin` and `commands/sync.md` into `~/.claude/commands/` (if Claude Code is installed). Make sure `~/.local/bin` is on your `PATH`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Verify with `syncgit help`. To uninstall: `./install.sh --uninstall`.

## Quick start

### New project

```sh
mkdir ~/Code/myproj && cd ~/Code/myproj
syncgit init --peers agent1 agent2 agent3
```

### Existing repo

```sh
cd ~/Code/myrepo
syncgit init --peers agent1 agent2 agent3   # adds worktrees inside the repo
```

Open one terminal per worktree and launch Claude in each:

```sh
cd ~/Code/myproj/agent1 && claude
cd ~/Code/myproj/agent2 && claude
cd ~/Code/myproj/agent3 && claude
```

Give each agent different work, then type `/sync` in any session to broadcast.

## CLI reference

```
syncgit init --peers a b c     create parent + N worktrees, wire remotes
syncgit peers list             list peers from .syncgit/peers.json
syncgit status                 show inbound/outbound PR queue
syncgit fetch                  fetch refs/pr/* from peers (no-op in local mode)
syncgit stage                  print a diff for the agent to review
syncgit merge                  rebase through pending peer PRs, oldest first
syncgit verify                 run .syncgit/verify.sh if present
syncgit push                   broadcast HEAD to every peer and GC absorbed refs
```

`--peers` accepts comma-separated (`a,b,c`), space-separated (`a b c`), or mixed.

## /sync flow

1. **Stage** — `syncgit stage` shows the agent what changed; the agent `git add`s only real work (never logs, `node_modules`, `dist`, `.env*`).
2. **Commit** — a short imperative message for this slice of work.
3. **Merge** — `syncgit merge` rebases through every pending peer PR, oldest first.
4. **Resolve** — on conflict, the agent edits files, runs `git rebase --continue`, and re-runs `syncgit merge`. After 3 failed attempts it aborts and stops with a summary.
5. **Verify** — `syncgit verify` runs `.syncgit/verify.sh` if you've put tests there.
6. **Broadcast** — `syncgit push` writes `refs/pr/<self>/<ts>` to every peer and GCs any of your own refs that every peer has already absorbed.

## Per-repo config (optional)

Inside any worktree:

- `.syncgit/ignore` — extra paths the agent should never stage
- `.syncgit/verify.sh` (executable) — gate broadcasts on a build/test command

## Design choices

- **No daemon, no server.** Pure git plus filesystem paths as remotes. Peer set is checked in as `.syncgit/peers.json`.
- **Rebase, not merge.** Linear history across N peers; merge commits would explode combinatorially.
- **Agent stages, script doesn't.** What counts as "real work" is judgment, so `syncgit stage` only surfaces evidence — the agent decides what to `git add`.
- **Halt over heuristic.** When the agent can't make something clean, it stops and writes `.syncgit/last-halt.md` rather than guessing.
- **Worktrees share refs.** Local mode exploits this: a push to a peer is immediately visible to every other peer without a fetch. `syncgit fetch` is kept as a seam for future network transport.

## Teardown

```sh
cd ~/Code/myproj
git worktree remove agent1 && git worktree remove agent2 && git worktree remove agent3
git branch -D agent1 agent2 agent3
rm -rf .syncgit
```

## Repo layout

```
syncgit/
  bin/syncgit      CLI entrypoint
  bin/lib.sh       shared helpers
  commands/sync.md /sync slash command (linked into ~/.claude/commands)
  install.sh       symlink installer
  README.md
  LICENSE
```
