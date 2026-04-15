---
description: SyncGit — stage judiciously, commit, absorb peer PRs, verify, broadcast.
---

You are the agent for this worktree. Run SyncGit end-to-end. The CLI is
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

3. **Absorb peer PRs.** Run `syncgit merge`. If it exits with conflicts:
   - Read the listed conflict files and resolve them to the best of your
     judgment (prefer keeping both changes' intent; don't just pick a side).
   - `git add` the resolved files and run `git rebase --continue`.
   - Re-run `syncgit merge` to process any remaining PRs.
   - If after 3 resolution attempts you still can't get clean, run
     `git rebase --abort` and stop with a summary of what blocked you.

4. **Verify working state.** Run `syncgit verify`. If it fails, attempt a fix
   (read the error, edit, re-run). If still failing after 3 attempts, stop.

5. **Broadcast.** Run `syncgit push`. This pushes your tip to every peer as a
   `refs/pr/<id>/<ts>` ref and GCs absorbed refs.

6. **Report.** Finish with one or two sentences: what you committed, how many
   peer PRs you absorbed, and whether the broadcast succeeded.
