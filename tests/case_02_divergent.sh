#!/usr/bin/env bash
# Test case 02: three peers (a, b, c) all broadcast simultaneously without merging between.
# Verifies that merge can absorb multiple pending refs and that EVERY peer's original
# broadcast SHA survives in the merger's history (Phase 4 property — preserved by the
# default `merge` strategy via merge-commit chain).

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

# Create temp directory for this test
tmpdir="$(make_tmpdir)"
trap "rm -rf '$tmpdir'" EXIT

# Initialize three peers
echo "  Initializing peers a, b, c..."
init_peers "$tmpdir" a b c

# Step 1-3: All three peers commit and push without merging in between
echo "  [a] make change a.txt and push..."
make_change "$tmpdir/a" a.txt "content from peer a"
as_peer "$tmpdir" a "$SYNCGIT" push

echo "  [b] make change b.txt and push..."
make_change "$tmpdir/b" b.txt "content from peer b"
as_peer "$tmpdir" b "$SYNCGIT" push

# Capture b's broadcast ref SHA for later assertion (push wrote refs/pr/b/<ts>)
b_ref="$(as_peer "$tmpdir" b git for-each-ref --sort=-committerdate refs/pr/b/ --format='%(refname)' | head -1)"
b_broadcast_sha="$(as_peer "$tmpdir" b git rev-parse "$b_ref")"

echo "  [c] make change c.txt and push..."
make_change "$tmpdir/c" c.txt "content from peer c"
as_peer "$tmpdir" c "$SYNCGIT" push

# Capture c's broadcast ref SHA for later assertion (push wrote refs/pr/c/<ts>)
c_ref="$(as_peer "$tmpdir" c git for-each-ref --sort=-committerdate refs/pr/c/ --format='%(refname)' | head -1)"
c_broadcast_sha="$(as_peer "$tmpdir" c git rev-parse "$c_ref")"

# Step 4: Peer 'a' merges all pending refs (from b and c)
echo "  [a] merge pending refs from b and c..."
as_peer "$tmpdir" a "$SYNCGIT" merge

# Step 5: Verify 'a' has all three files
echo "  Verifying a has all files..."
assert_exists "$tmpdir/a/a.txt" "a.txt exists in a"
assert_exists "$tmpdir/a/b.txt" "b.txt exists in a"
assert_exists "$tmpdir/a/c.txt" "c.txt exists in a"

# Step 6: Verify BOTH b's and c's original SHAs survived in a's history.
# The default `merge` strategy builds a peer-chain via merge commits so every
# peer's broadcast SHA is reachable (either on the chain or as a merge parent).
echo "  Checking that b's and c's original SHAs survived in a's history..."
a_log="$(as_peer "$tmpdir" a git log --all --format=%H)"
a_log_has_b_sha="$(echo "$a_log" | grep -c "$b_broadcast_sha" || true)"
a_log_has_c_sha="$(echo "$a_log" | grep -c "$c_broadcast_sha" || true)"
assert "[[ $a_log_has_b_sha -gt 0 ]]" "b's original SHA ($b_broadcast_sha) is in a's history"
assert "[[ $a_log_has_c_sha -gt 0 ]]" "c's original SHA ($c_broadcast_sha) is in a's history"

echo "  Divergent test passed"
