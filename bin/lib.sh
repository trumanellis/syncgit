#!/usr/bin/env bash
# syncgit shared helpers

set -euo pipefail

# Validate a peer id against the canonical pattern.
# Usage: syncgit_validate_id <id> <context>
# Prints error and exits 1 on failure; silent on success.
syncgit_validate_id() {
  local id="$1"
  local ctx="${2:-init}"
  if [[ ! "$id" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]]; then
    echo "syncgit: $ctx: invalid peer id '$id' (must be 1-64 chars, alphanumeric + - + _, not starting with - or _)" >&2
    exit 1
  fi
}

# Logging helper. Levels: error (always stderr), info (normal+verbose stdout),
# debug (verbose-only stderr).
syncgit_log() {
  local level="$1"; shift
  case "$level" in
    error) echo "syncgit: $*" >&2 ;;
    info)  [[ "${SYNCGIT_VERBOSITY:-normal}" != "quiet" ]] && echo "syncgit: $*" ;;
    debug) [[ "${SYNCGIT_VERBOSITY:-normal}" == "verbose" ]] && echo "syncgit: [debug] $*" >&2 ;;
  esac
}

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

# Find the true parent root — the directory that *contains* the peer worktrees
# and holds the primary .git directory. Uses git's common-dir (the shared object
# store that all worktrees point back to) to locate it reliably.
#
# For a worktree at <root>/<id>, git-common-dir resolves to <root>/.git, so
# dirname of that gives <root>. For the main worktree (called from <root>
# directly), git-common-dir is just ".git" relative to <root>, same result.
syncgit_parent_root() {
  local common_dir abs_common
  common_dir="$(git rev-parse --git-common-dir)"
  # Make absolute (may be relative like ".git" or "../.git")
  if [[ "$common_dir" = /* ]]; then
    abs_common="$common_dir"
  else
    abs_common="$(cd "$(git rev-parse --show-toplevel)" && cd "$common_dir" && pwd)"
  fi
  dirname "$abs_common"
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

syncgit_ts() {
  # Append a 6-char random suffix so two pushes in the same UTC second don't collide.
  # Shape: YYYYMMDDTHHMMSSZ-XXXXXX  (still lexicographically sortable by time prefix).
  local stamp suffix
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  suffix="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 6 || echo "$$$$$$" | head -c 6)"
  printf '%s-%s\n' "$stamp" "$suffix"
}

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
