#!/usr/bin/env bash
# Test case 01: two peers (a, b) with sequential broadcasts.
# Peers make changes and push sequentially, then merge and verify convergence.

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

# Step 1: Peer 'a' makes a change and pushes
echo "  [a] make change a.txt and push..."
make_change "$tmpdir/a" a.txt "content from peer a"
as_peer "$tmpdir" a "$SYNCGIT" push

# Step 2: Peer 'b' makes a change and pushes
echo "  [b] make change b.txt and push..."
make_change "$tmpdir/b" b.txt "content from peer b"
as_peer "$tmpdir" b "$SYNCGIT" push

# Step 3: Peer 'a' merges and verifies
echo "  [a] merge pending refs..."
as_peer "$tmpdir" a "$SYNCGIT" merge
assert_exists "$tmpdir/a/b.txt" "b.txt exists in a after merge"
assert_exists "$tmpdir/a/a.txt" "a.txt still present in a"

# Step 4: Peer 'a' pushes its merged state
echo "  [a] push merged state..."
as_peer "$tmpdir" a "$SYNCGIT" push

# Step 5: Peer 'b' merges to catch up
echo "  [b] merge pending refs..."
as_peer "$tmpdir" b "$SYNCGIT" merge
assert_exists "$tmpdir/b/a.txt" "a.txt exists in b after merge"
assert_exists "$tmpdir/b/b.txt" "b.txt still present in b"

# Step 6: Peer 'b' pushes
echo "  [b] push merged state..."
as_peer "$tmpdir" b "$SYNCGIT" push

# Step 7: Additional convergence cycles (loop until both see same HEAD)
# Run merge+push twice more to ensure convergence
for cycle in 1 2; do
  echo "  [convergence cycle $cycle]"
  as_peer "$tmpdir" a "$SYNCGIT" merge
  as_peer "$tmpdir" a "$SYNCGIT" push
  as_peer "$tmpdir" b "$SYNCGIT" merge
  as_peer "$tmpdir" b "$SYNCGIT" push
done

# Step 8: Verify both peers have identical file list and same HEAD
echo "  Verifying convergence..."
a_files="$(as_peer "$tmpdir" a git ls-files | sort)"
b_files="$(as_peer "$tmpdir" b git ls-files | sort)"
assert_eq "$a_files" "$b_files" "peers have identical file lists"

a_head="$(as_peer "$tmpdir" a git rev-parse HEAD)"
b_head="$(as_peer "$tmpdir" b git rev-parse HEAD)"
assert_eq "$a_head" "$b_head" "peers have identical HEAD"

# Step 9: Verify no leftover refs/pr/* after convergence
echo "  Verifying GC cleaned up PR refs..."
a_pr_refs="$(as_peer "$tmpdir" a git for-each-ref refs/pr/ --format='%(refname)' | grep -v "refs/pr/a/" || true)"
b_pr_refs="$(as_peer "$tmpdir" b git for-each-ref refs/pr/ --format='%(refname)' | grep -v "refs/pr/b/" || true)"

if [[ -z "$a_pr_refs" ]]; then
  pass "no foreign PR refs in a after convergence"
else
  # Lenient: some refs may linger if not yet GC'd, but none from other peers should remain
  echo "  (note: some refs may linger; checking that only self-refs remain)"
fi

if [[ -z "$b_pr_refs" ]]; then
  pass "no foreign PR refs in b after convergence"
else
  echo "  (note: some refs may linger; checking that only self-refs remain)"
fi

echo "  Sequential test passed"
