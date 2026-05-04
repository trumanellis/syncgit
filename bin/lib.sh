#!/usr/bin/env bash
# syncgit shared helpers

set -euo pipefail

# Find the syncgit root: the directory containing .syncgit/peers.json, walking
# up from CWD. For a worktree, this is the parent dir of the worktrees.
syncgit_root() {
  local dir
  dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.syncgit/peers.json" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo "syncgit: no .syncgit/peers.json found in any parent" >&2
  return 1
}

# Current worktree id. Reads <worktree-toplevel>/.syncgit/self if present
# (written by cmd_init); otherwise falls back to basename of the toplevel dir.
syncgit_self_id() {
  local top
  top="$(git rev-parse --show-toplevel)"
  if [[ -f "$top/.syncgit/self" ]]; then
    cat "$top/.syncgit/self"
  else
    basename "$top"
  fi
}

# Advisory lock using mkdir as atomic primitive (portable, no flock needed).
# On success installs an EXIT trap to remove the lock dir.
# On failure prints an error and exits 1.
syncgit_lock() {
  local top lockdir
  top="$(git rev-parse --show-toplevel)"
  lockdir="$top/.syncgit/lock"
  if ! mkdir "$lockdir" 2>/dev/null; then
    echo "syncgit: another agent is running here (lock held at $lockdir)" >&2
    exit 1
  fi
  # shellcheck disable=SC2064
  trap "rm -rf '$lockdir'" EXIT INT TERM HUP
}

# Iterate peers from peers.json as "id<TAB>path" lines, excluding self.
syncgit_peers() {
  local root self
  root="$(syncgit_root)"
  self="$(syncgit_self_id)"
  # peers.json: [{"id":"a","path":"a"}, ...]  (path relative to root)
  python3 - "$root/.syncgit/peers.json" "$self" <<'PY'
import json, sys
path, self_id = sys.argv[1], sys.argv[2]
with open(path) as f:
    peers = json.load(f)
for p in peers:
    if p["id"] == self_id:
        continue
    print(f"{p['id']}\t{p['path']}")
PY
}

syncgit_ts() { date -u +%Y%m%dT%H%M%SZ; }

syncgit_halt() {
  local root msg="$1"
  root="$(syncgit_root)" || root="$(pwd)"
  mkdir -p "$root/.syncgit"
  {
    echo "# syncgit halt — $(date -u +%FT%TZ)"
    echo
    echo "$msg"
    echo
    echo "## git status"
    git status --short || true
  } > "$(git rev-parse --show-toplevel)/.syncgit/last-halt.md"
  echo "syncgit: halted — see .syncgit/last-halt.md" >&2
  exit 2
}
