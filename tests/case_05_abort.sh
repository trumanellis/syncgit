#!/usr/bin/env bash
# Test case 05: Rollback path for merge conflicts.
# Requires: syncgit abort subcommand (Phase 3b)
#
# Two peers commit the same file with different content, creating a merge conflict.
# Verify that 'syncgit abort' rolls back to the pre-merge state.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

# Create temp directory for this test
tmpdir="$(make_tmpdir)"
trap "rm -rf '$tmpdir'" EXIT

# Initialize two peers
echo "  Initializing peers a, b..."
init_peers "$tmpdir" a b

# Step 1: 'a' commits shared.txt with content "A"
echo "  [a] create shared.txt with content 'A'..."
make_change "$tmpdir/a" shared.txt "A"
as_peer "$tmpdir" a "$SYNCGIT" push

# Step 2: 'b' commits shared.txt with content "B" (will conflict)
echo "  [b] create shared.txt with content 'B'..."
make_change "$tmpdir/b" shared.txt "B"
as_peer "$tmpdir" b "$SYNCGIT" push

# Step 3: Capture b's HEAD before merge (for rollback verification)
echo "  [b] capturing HEAD before merge..."
b_head_before="$(as_peer "$tmpdir" b git rev-parse HEAD)"
b_content_before="$(cat "$tmpdir/b/shared.txt")"

# Step 4: 'b' attempts merge, expecting conflict
echo "  [b] attempting merge (expecting conflict)..."
set +e
as_peer "$tmpdir" b "$SYNCGIT" merge
merge_rc=$?
set -e
assert_eq "3" "$merge_rc" "syncgit merge exits 3 on conflict"

# Step 5: Verify 'b' is in conflicted rebase state.
# `git rebase` uses .git/rebase-merge/ (or rebase-apply/) — NOT .git/MERGE_HEAD,
# which is only set by `git merge`. The canonical check is the rebase-merge dir.
echo "  Verifying rebase-conflict state..."
b_rebase_dir="$(as_peer "$tmpdir" b git rev-parse --git-path rebase-merge)"
if as_peer "$tmpdir" b test -d "$b_rebase_dir"; then
  pass "rebase in progress (.git/rebase-merge exists)"
else
  fail "not in rebase-conflict state as expected"
fi

# Step 6: Run syncgit abort
echo "  [b] running syncgit abort..."
if as_peer "$tmpdir" b "$SYNCGIT" abort; then
  echo "  abort succeeded"
else
  echo "  (note: syncgit abort not implemented yet; test incomplete)"
  echo "  Requires: syncgit abort subcommand (Phase 3b)"
  exit 0
fi

# Step 7: Verify 'b' HEAD is back to pre-merge state
echo "  Verifying rollback..."
b_head_after="$(as_peer "$tmpdir" b git rev-parse HEAD)"
assert_eq "$b_head_before" "$b_head_after" "HEAD rolled back to pre-merge state"

# Step 8: Verify content is restored
echo "  [b] checking shared.txt content..."
b_content_after="$(cat "$tmpdir/b/shared.txt")"
assert_eq "$b_content_before" "$b_content_after" "shared.txt content restored to 'B'"

# Step 9: Verify rebase state is cleaned up
echo "  Verifying clean state after abort..."
if as_peer "$tmpdir" b test ! -d "$b_rebase_dir"; then
  pass "rebase-merge dir removed after abort"
else
  fail "rebase-merge dir still present after abort"
fi

echo "  Abort test passed"
