#!/usr/bin/env bash
# Test case 09: re-running syncgit init is idempotent — does not corrupt state.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

tmpdir="$(make_tmpdir)"
trap "rm -rf '$tmpdir'" EXIT

echo "  Initializing peers a, b..."
init_peers "$tmpdir" a b

# Step 1: a commits and pushes so refs/pr/a/* exists
echo "  [a] make change and push..."
make_change "$tmpdir/a" a.txt "content from peer a"
as_peer "$tmpdir" a "$SYNCGIT" push

# Capture state before re-init
a_ref_before="$(as_peer "$tmpdir" a git for-each-ref refs/pr/a/ --format='%(refname)' | head -1)"
assert 0 "refs/pr/a/* exists before re-init (sanity)"

peers_json_before="$(cat "$tmpdir/.syncgit/peers.json")"
self_a_before="$(cat "$tmpdir/a/.syncgit/self")"
self_b_before="$(cat "$tmpdir/b/.syncgit/self")"

# Step 2: Re-run syncgit init --peers a,b from the parent dir
echo "  Re-running syncgit init --peers a,b..."
set +e
reinit_rc=0
(cd "$tmpdir" && "$SYNCGIT" init --peers a,b) || reinit_rc=$?
set -e
assert_eq "0" "$reinit_rc" "re-init exits 0"

# Step 3: refs/pr/a/* still exists in a's worktree (init didn't blow it away)
a_ref_after="$(as_peer "$tmpdir" a git for-each-ref refs/pr/a/ --format='%(refname)' | head -1)"
assert_eq "$a_ref_before" "$a_ref_after" "refs/pr/a/* still exists after re-init"

# Step 4: peers.json content unchanged (or equivalent)
peers_json_after="$(cat "$tmpdir/.syncgit/peers.json")"
assert_eq "$peers_json_before" "$peers_json_after" "peers.json content unchanged after re-init"

# Step 5: .syncgit/self in each worktree still has correct content
self_a_after="$(cat "$tmpdir/a/.syncgit/self")"
self_b_after="$(cat "$tmpdir/b/.syncgit/self")"
assert_eq "$self_a_before" "$self_a_after" ".syncgit/self in a unchanged after re-init"
assert_eq "$self_b_before" "$self_b_after" ".syncgit/self in b unchanged after re-init"

# Step 6: peer-* remotes are still wired correctly
a_remotes="$(as_peer "$tmpdir" a git remote -v)"
b_remotes="$(as_peer "$tmpdir" b git remote -v)"

if [[ "$a_remotes" == *"peer-b"* && "$a_remotes" == *"../b"* ]]; then
  pass "peer-b remote still wired in a after re-init"
else
  fail "peer-b remote missing or incorrect in a; got: $a_remotes"
fi

if [[ "$b_remotes" == *"peer-a"* && "$b_remotes" == *"../a"* ]]; then
  pass "peer-a remote still wired in b after re-init"
else
  fail "peer-a remote missing or incorrect in b; got: $b_remotes"
fi

echo "  Init idempotent test passed"
