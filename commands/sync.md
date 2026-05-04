---
description: syncgit — stage judiciously, commit, absorb peer PRs, verify, broadcast.
---

You are the agent for this worktree. Run syncgit end-to-end. The CLI is
`~/.claude/scripts/syncgit/syncgit` (add it to PATH if convenient, or call
directly). Do not skip steps. If any step fails in a way not covered below,
stop and report — do not improvise around the protocol.

1. **Review and stage.** Run `syncgit stage`. From the output, `git add` only
   files that are real work (source, configs, fixtures you created/edited).
   Exclude: logs, build output, `node_modules/`, `dist/`, `.env*`, editor
   scratch, credentials, large binaries, anything in `.syncgit/ignore`. If in
   doubt, skip it.

2. **Commit.** If anything is staged, write a short commit message (one line,
   imperative) describing the slice of work. Skip if nothing is staged.

2.5. *(Optional)* **Squash.** If you've made many small commits since your last
   push, run `syncgit squash` to collapse them into one. Skip if your
   work-in-progress is just a single commit, or if peer PRs are pending in the
   range — squash will refuse in that case (push first, then squash on the next
   round).

3. **Absorb peer PRs.** Before merging, optionally inspect each pending ref with
   `syncgit show <ref>` (run `syncgit status` first to list them). This lets you
   spot peer changes that interact with your in-flight work. Then run `syncgit merge`.
   If `syncgit merge` reports a chain-merge conflict and rolls back, retry with
   `SYNCGIT_MERGE_STRATEGY=rebase syncgit merge` for per-peer linear conflict
   resolution. After resolving each conflict with `git add <files> && git
   rebase --continue`, re-run `syncgit merge` only if more peer PRs are pending.
   - Read the listed conflict files and resolve them to the best of your
     judgment (prefer keeping both changes' intent; don't just pick a side).
   - If after 3 resolution attempts you still can't get clean, run
     `syncgit abort` to roll back to the pre-merge snapshot, then stop with a summary of what blocked you.

4. **Verify working state.** Run `syncgit verify`. If it fails, attempt a fix
   (read the error, edit, re-run). If verify fails after 3 attempts, run
   `syncgit abort` to roll back to the pre-merge snapshot, then stop with a summary.
   The snapshot was created automatically when `syncgit merge` started.

5. **Broadcast.** Run `syncgit push`. This pushes your tip to every peer as a
   `refs/pr/<id>/<ts>` ref and GCs absorbed refs.

6. **Report.** Finish with one or two sentences: what you committed, how many
   peer PRs you absorbed, and whether the broadcast succeeded.
