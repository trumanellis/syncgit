#!/usr/bin/env bash
# Test case 08: smoke test for syncgit status and syncgit show.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

tmpdir="$(make_tmpdir)"
trap "rm -rf '$tmpdir'" EXIT

echo "  Initializing peers a, b..."
init_peers "$tmpdir" a b

# Step 1: a commits and pushes so b has an inbound ref
echo "  [a] make change and push..."
make_change "$tmpdir/a" a.txt "content from peer a"
as_peer "$tmpdir" a "$SYNCGIT" push

# Step 2: Run syncgit status from b and capture stdout
echo "  [b] running syncgit status..."
status_out="$(as_peer "$tmpdir" b "$SYNCGIT" status)"

# Step 3: Assert expected sections present
if [[ "$status_out" == *"self: b"* ]]; then
  pass "status contains 'self: b'"
else
  fail "status missing 'self: b'; got: $status_out"
fi

if [[ "$status_out" == *"peers:"* ]]; then
  pass "status contains 'peers:'"
else
  fail "status missing 'peers:'; got: $status_out"
fi

if [[ "$status_out" == *"inbound PRs"* ]]; then
  pass "status contains 'inbound PRs'"
else
  fail "status missing 'inbound PRs'; got: $status_out"
fi

# Step 4: Capture the inbound ref via git for-each-ref
echo "  [b] capturing inbound ref..."
inbound_ref="$(as_peer "$tmpdir" b git for-each-ref refs/pr/a/ --format='%(refname)' | head -1)"
if [[ -z "$inbound_ref" ]]; then
  fail "no inbound ref found under refs/pr/a/ in b"
else
  pass "inbound ref found: $inbound_ref"
fi

# Step 5: Run syncgit show <ref> and assert expected output sections
echo "  [b] running syncgit show $inbound_ref..."
show_out="$(as_peer "$tmpdir" b "$SYNCGIT" show "$inbound_ref")"

if [[ "$show_out" == *"# Log of"* ]]; then
  pass "show output contains '# Log of'"
else
  fail "show output missing '# Log of'; got: $show_out"
fi

if [[ "$show_out" == *"# Diffstat:"* ]]; then
  pass "show output contains '# Diffstat:'"
else
  fail "show output missing '# Diffstat:'; got: $show_out"
fi

# Step 6: Run syncgit show with no args; assert exit 1 with "show: ref required"
echo "  [b] running syncgit show with no args (should fail)..."
set +e
noargs_out="$(as_peer "$tmpdir" b "$SYNCGIT" show 2>&1)"
noargs_rc=$?
set -e

assert_eq "1" "$noargs_rc" "syncgit show exits 1 with no args"

if [[ "$noargs_out" == *"show: ref required"* ]]; then
  pass "show prints 'show: ref required' with no args"
else
  fail "expected 'show: ref required', got: $noargs_out"
fi

# Step 7: Assert new status format: version line and pending count
if [[ "$status_out" == *"version:"* ]]; then
  pass "status contains 'version:'"
else
  fail "status missing 'version:'; got: $status_out"
fi

if [[ "$status_out" == *"inbound PRs ("* ]]; then
  pass "status contains enhanced inbound PRs header with count"
else
  fail "status missing enhanced inbound PRs header; got: $status_out"
fi

echo "  Status/show test passed"
