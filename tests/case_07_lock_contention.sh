#!/usr/bin/env bash
# Test case 07: lock contention — second syncgit merge on same worktree exits 1
# with a "lock held" error and does not corrupt state.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

tmpdir="$(make_tmpdir)"
trap "rm -rf '$tmpdir'" EXIT

echo "  Initializing peers a, b..."
init_peers "$tmpdir" a b

# Step 1: a makes a commit and pushes so b has a pending ref
echo "  [a] make change and push..."
make_change "$tmpdir/a" a.txt "content from peer a"
as_peer "$tmpdir" a "$SYNCGIT" push

# Step 2: b makes a commit so it has work to absorb when merging
echo "  [b] make change..."
make_change "$tmpdir/b" b.txt "content from peer b"

# Step 3: Manually create the lock dir to simulate first call holding it
echo "  [b] simulating held lock..."
mkdir "$tmpdir/b/.syncgit/lock"

# Step 4: Run syncgit merge from b; it should exit 1 due to lock contention
echo "  [b] attempting merge with lock held (should fail)..."
set +e
lock_out="$(cd "$tmpdir/b" && "$SYNCGIT" merge 2>&1)"
lock_rc=$?
set -e

assert_eq "1" "$lock_rc" "merge exits 1 when lock is held"

if [[ "$lock_out" == *"lock held"* ]]; then
  pass "merge error mentions 'lock held'"
else
  fail "expected 'lock held' in output, got: $lock_out"
fi

# Step 5: Verify state was not corrupted — b.txt still exists, no partial merge
assert_exists "$tmpdir/b/b.txt" "b.txt still exists after failed merge (no corruption)"

# Step 6: Cleanup — remove lock dir and verify subsequent merge works
echo "  [b] releasing lock and retrying merge..."
rmdir "$tmpdir/b/.syncgit/lock"

as_peer "$tmpdir" b "$SYNCGIT" merge
assert_exists "$tmpdir/b/a.txt" "a.txt exists in b after successful merge"
assert_exists "$tmpdir/b/b.txt" "b.txt still present in b after successful merge"

echo "  Lock contention test passed"
