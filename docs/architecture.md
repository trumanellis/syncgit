# Architecture: merge-commit-chain and SHA preservation

## The peer-broadcast model

Each git worktree is an equal peer. There is no central branch and no hub. When a peer broadcasts work, it pushes its HEAD to every other peer's repository as a ref under `refs/pr/<id>/<ts>`, where `<id>` is the broadcasting peer's identity and `<ts>` is a UTC timestamp with a random suffix (e.g. `20260504T143012Z-a3f2c1`).

Because all worktrees in a single `syncgit init` setup share one git object store (they are git worktrees of the same repo), a push to one peer's ref namespace is instantly visible to every other peer — no fetch step, no daemon, no server.

## Why peer SHAs must survive verbatim

`syncgit push` runs `syncgit_gc` after a successful broadcast. GC pass 1 checks whether your own outbound refs (`refs/pr/<self>/*`) have been absorbed by every peer — it does this by testing whether the broadcast SHA is an ancestor of each peer's branch tip (`refs/heads/<id>`).

This detection relies on the SHA being reachable in the receiver's history. If a receiver's merge strategy rewrites the peer's commit (as `git rebase` does), the original SHA is gone, and the receiver can never signal "absorbed" back to the sender. The result is that absorbed refs are never cleaned up and the ref namespace grows unbounded.

The `merge` strategy (default) exists specifically to prevent this.

## The `rebase` strategy

```
Before:
  A---B---C  (HEAD, local commits)
        \
         P1---P2  (peer PRs, oldest first)

After rebase strategy:
  A---B---P1'--P2'--C'  (P1 and P2 replayed; only P2's original SHA survives if C was empty)
```

Simple and produces strictly linear history. The cost: only the last peer's commit SHA survives intact in a multi-peer merge. Earlier peers' commits are replayed onto subsequent peer tips and receive new SHAs. Set `SYNCGIT_MERGE_STRATEGY=rebase` to use this strategy.

## The `merge` strategy (default)

```
Before:
  A---B---C  (HEAD)
      |
      +--P1  (peer 1's broadcast)
      |
      +--P2  (peer 2's broadcast, divergent from P1)

After merge strategy (divergent case):
  A---B---P1---M---C'
                \
                 P2

  M = merge commit absorbing P2 onto P1
  C' = local commits rebased onto M
```

The merge strategy has two sub-cases:

**Linear case** (each pending peer SHA is an ancestor of the next): the chain tip is simply the last peer SHA. No merge commits are created. Local commits are rebased onto that tip. All peer SHAs are reachable in the resulting linear history.

**Divergent case**: syncgit builds a merge-commit chain starting at the first (oldest) pending peer ref, then merges each subsequent peer ref onto it with `git merge --no-ff`. The original SHA of each absorbed peer is preserved as either a direct ancestor or a merge parent. Local commits are then rebased onto the chain tip.

If the chain-merge itself hits a conflict (two peer branches edited the same lines in incompatible ways), syncgit rolls back atomically to the pre-merge snapshot and tells the caller to retry with `SYNCGIT_MERGE_STRATEGY=rebase`, which surfaces per-peer conflicts one at a time through the standard `git rebase --continue` flow.

## The cost of the merge strategy

Non-linear history in divergent cases: one merge commit per absorbed peer beyond the first. This is intentional and necessary for SHA preservation. If strict linearity is required and SHA-preservation can be sacrificed, use the rebase strategy.

## Conflict rollback

Both strategies record a pre-merge snapshot before touching the working tree:

```
refs/syncgit/pre-merge       — SHA of HEAD before merge began
.syncgit/pre-merge-branch    — branch name, for re-attaching after a detached-HEAD conflict
```

`syncgit abort` resets hard to the snapshot ref, aborts any in-progress rebase, re-attaches the original branch, and removes the snapshot. `syncgit squash` uses the same mechanism under `refs/syncgit/pre-squash`.

`syncgit merge` refuses to run if a previous snapshot already exists, preventing mid-flight merges from being silently clobbered.
