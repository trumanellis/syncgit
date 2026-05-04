#!/usr/bin/env bash
# Test case 03: Verify that after full convergence, no foreign refs/pr/* remain.
# Two peers: a and b. After both merge and push twice, check ref cleanup.

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

# Step 1: 'a' commits and pushes
echo "  [a] make change and push..."
make_change "$tmpdir/a" a.txt "content from a"
as_peer "$tmpdir" a "$SYNCGIT" push

# Step 2: 'b' merges and pushes
echo "  [b] merge and push..."
as_peer "$tmpdir" b "$SYNCGIT" merge
as_peer "$tmpdir" b "$SYNCGIT" push

# Step 3: 'a' merges and pushes
echo "  [a] merge and push..."
as_peer "$tmpdir" a "$SYNCGIT" merge
as_peer "$tmpdir" a "$SYNCGIT" push

# Step 4: 'b' merges and pushes again (final convergence)
echo "  [b] merge and push (final cycle)..."
as_peer "$tmpdir" b "$SYNCGIT" merge
as_peer "$tmpdir" b "$SYNCGIT" push

# Step 5: Check for leftover refs/pr/*
echo "  Checking for leftover PR refs in a..."
a_all_refs="$(as_peer "$tmpdir" a git for-each-ref refs/pr/ --format='%(refname)')"
if [[ -z "$a_all_refs" ]]; then
  pass "no refs/pr/* found in a"
else
  # Be lenient: print what's there for diagnostic
  echo "  PR refs in a after convergence:"
  echo "$a_all_refs" | sed 's/^/    /'
  # Verify they're all self-refs (refs/pr/a/*)
  a_foreign_refs="$(echo "$a_all_refs" | grep -v '^refs/pr/a/' || echo "")"
  if [[ -z "$a_foreign_refs" ]]; then
    pass "only self-refs remain in a (absorbed foreign refs)"
  else
    fail "foreign PR refs still present in a: $a_foreign_refs"
  fi
fi

echo "  Checking for leftover PR refs in b..."
b_all_refs="$(as_peer "$tmpdir" b git for-each-ref refs/pr/ --format='%(refname)')"
if [[ -z "$b_all_refs" ]]; then
  pass "no refs/pr/* found in b"
else
  # Be lenient: print what's there for diagnostic
  echo "  PR refs in b after convergence:"
  echo "$b_all_refs" | sed 's/^/    /'
  # Verify they're all self-refs (refs/pr/b/*)
  b_foreign_refs="$(echo "$b_all_refs" | grep -v '^refs/pr/b/' || echo "")"
  if [[ -z "$b_foreign_refs" ]]; then
    pass "only self-refs remain in b (absorbed foreign refs)"
  else
    fail "foreign PR refs still present in b: $b_foreign_refs"
  fi
fi

echo "  Inbound GC test passed"
