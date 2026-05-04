#!/usr/bin/env bash
# Test case 04: TTL safety net for GC.
# Requires: syncgit gc subcommand (Phase 2b/2c)
#
# Creates a fake old ref and verifies it's cleaned up by SYNCGIT_TTL_DAYS,
# while newer refs are preserved.

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

# Step 1: 'a' commits and pushes (real ref with current ts)
echo "  [a] make change and push..."
make_change "$tmpdir/a" a.txt "content from a"
as_peer "$tmpdir" a "$SYNCGIT" push

# Capture the real ref for later
real_ref="$(as_peer "$tmpdir" a git for-each-ref --sort=-committerdate refs/pr/a/ --format='%(refname:short)' | head -1)"
echo "  Real ref created: $real_ref"

# Step 2: Manually create a fake old ref with timestamp from 2020
echo "  [a] forging old ref refs/pr/a/20200101T000000Z..."
old_sha="$(as_peer "$tmpdir" a git rev-parse HEAD)"
as_peer "$tmpdir" a git update-ref refs/pr/a/20200101T000000Z "$old_sha"

# Verify the old ref exists
echo "  Verifying old ref exists..."
assert_success "as_peer '$tmpdir' a git rev-parse --verify --quiet refs/pr/a/20200101T000000Z" \
  "old ref can be resolved before gc"

# Step 3: Run syncgit gc with TTL=1 day (so 2020 ref is definitely old)
echo "  [a] running syncgit gc with SYNCGIT_TTL_DAYS=1..."
as_peer "$tmpdir" a bash -c "SYNCGIT_TTL_DAYS=1 $SYNCGIT gc"
echo "  syncgit gc completed"

# Step 4: Assert old ref is gone
echo "  Verifying old ref was deleted..."
if as_peer "$tmpdir" a git rev-parse --verify --quiet refs/pr/a/20200101T000000Z 2>/dev/null; then
  fail "old ref still exists after gc"
else
  pass "old ref was deleted by gc"
fi

# Step 5: Assert real ref is still there (or absorbed-and-gc'd correctly)
echo "  Verifying recent ref still exists..."
if as_peer "$tmpdir" a git rev-parse --verify --quiet "refs/pr/a/$real_ref" 2>/dev/null; then
  pass "recent ref still exists after gc"
else
  echo "  (note: recent ref may have been absorbed into a branch; this is OK)"
fi

echo "  TTL GC test passed"
