#!/usr/bin/env bash
# Test case 06: syncgit squash — collapse self-authored commits since last push.
#
# Covers:
#   - Happy path: 3 self commits → squashed to 1
#   - All files preserved after squash
#   - Squash commit message format
#   - Idempotent: squash on already-squashed range reports "nothing to squash"
#   - Dirty working tree → exit 1
#   - Mixed range (peer commit present) → exit 1

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

tmpdir="$(make_tmpdir)"
trap "rm -rf '$tmpdir'" EXIT

echo "  Initializing peers a, b..."
init_peers "$tmpdir" a b

# ── Happy path ──────────────────────────────────────────────────────────────

echo "  [a] making 3 commits..."
make_change "$tmpdir/a" file1.txt "content1"
make_change "$tmpdir/a" file2.txt "content2"
make_change "$tmpdir/a" file3.txt "content3"

# Verify 3 commits exist above seed before squash
commit_count_before="$(as_peer "$tmpdir" a git rev-list --count HEAD)"
assert_eq "4" "$commit_count_before" "4 commits exist before squash (seed + 3 changes)"

echo "  [a] running syncgit squash..."
as_peer "$tmpdir" a "$SYNCGIT" squash

# After squash: seed + 1 squash commit = 2 total
commit_count_after="$(as_peer "$tmpdir" a git rev-list --count HEAD)"
assert_eq "2" "$commit_count_after" "exactly 2 commits after squash (seed + squash)"

# All files still present with correct content
assert_eq "content1" "$(cat "$tmpdir/a/file1.txt")" "file1.txt content preserved"
assert_eq "content2" "$(cat "$tmpdir/a/file2.txt")" "file2.txt content preserved"
assert_eq "content3" "$(cat "$tmpdir/a/file3.txt")" "file3.txt content preserved"

# Commit message starts with "syncgit: squash"
squash_subject="$(as_peer "$tmpdir" a git log -1 --format=%s)"
if [[ "$squash_subject" == syncgit:\ squash* ]]; then
  pass "squash commit subject starts with 'syncgit: squash'"
else
  fail "squash commit subject is '$squash_subject', expected 'syncgit: squash ...'"
fi

# ── Idempotent: squash again → nothing to squash ─────────────────────────────

echo "  [a] running squash again (should report nothing to squash)..."
set +e
squash_again_out="$(as_peer "$tmpdir" a "$SYNCGIT" squash 2>&1)"
squash_again_rc=$?
set -e
assert_eq "0" "$squash_again_rc" "second squash exits 0"
if [[ "$squash_again_out" == *"only one"* || "$squash_again_out" == *"nothing to squash"* ]]; then
  pass "second squash reports nothing to do"
else
  fail "second squash output was: $squash_again_out"
fi

# ── Dirty working tree ────────────────────────────────────────────────────────

echo "  [a] testing dirty working tree guard..."
# Make a new commit first so there's something to squash
make_change "$tmpdir/a" file4.txt "content4"
make_change "$tmpdir/a" file5.txt "content5"
# Now dirty the tree without committing
printf 'dirty' >> "$tmpdir/a/file4.txt"
set +e
dirty_out="$(as_peer "$tmpdir" a "$SYNCGIT" squash 2>&1)"
dirty_rc=$?
set -e
assert_eq "1" "$dirty_rc" "squash exits 1 on dirty working tree"
if [[ "$dirty_out" == *"dirty"* ]]; then
  pass "squash reports dirty working tree message"
else
  fail "expected dirty message, got: $dirty_out"
fi
# Restore clean state
(cd "$tmpdir/a" && git checkout -- file4.txt)

# ── Mixed range: peer commit present → refuse ────────────────────────────────

echo "  [b] pushing a commit for a to absorb..."
make_change "$tmpdir/b" peer_file.txt "peer content"
as_peer "$tmpdir" b "$SYNCGIT" push

echo "  [a] absorbing peer commit via merge..."
as_peer "$tmpdir" a "$SYNCGIT" merge
# After merge a has peer commit in range; make one more self commit
make_change "$tmpdir/a" file6.txt "content6"

echo "  [a] attempting squash over mixed range (should refuse)..."
set +e
mixed_out="$(as_peer "$tmpdir" a "$SYNCGIT" squash 2>&1)"
mixed_rc=$?
set -e
assert_eq "1" "$mixed_rc" "squash exits 1 on mixed range"
if [[ "$mixed_out" == *"peer or merge commits"* ]]; then
  pass "squash refuses mixed range with clear message"
else
  fail "expected 'peer or merge commits' message, got: $mixed_out"
fi

# Verify no pre-squash snapshot left behind after refusal
set +e
has_snap="$(as_peer "$tmpdir" a git rev-parse --verify --quiet refs/syncgit/pre-squash 2>/dev/null)"
set -e
if [[ -z "$has_snap" ]]; then
  pass "no pre-squash snapshot left after refused squash"
else
  fail "pre-squash snapshot unexpectedly present after refused squash"
fi

echo "  Squash test passed"
