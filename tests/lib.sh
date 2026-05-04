#!/usr/bin/env bash
# syncgit test helpers

set -euo pipefail

SYNCGIT="${SYNCGIT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/syncgit}"

# Color codes for output (disable if NO_COLOR is set)
RED=''
GREEN=''
YELLOW=''
NC=''
if [[ -z "${NO_COLOR:-}" ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  NC=$'\033[0m'
fi

# Create a temporary directory and print the path.
# Caller is responsible for cleanup — typically:
#     tmpdir="$(make_tmpdir)"
#     trap "rm -rf '$tmpdir'" EXIT
# (We can't trap here because make_tmpdir is invoked inside $(), which is a
# subshell — its trap would fire immediately on subshell exit, deleting the dir
# before the caller could use it.)
make_tmpdir() {
  mktemp -d "${TMPDIR:-/tmp}/syncgit-test.XXXXXX"
}

# Initialize N peers in PARENT via 'syncgit init --peers <csv>'.
# If PARENT is not a git repo, creates one with an empty seed commit.
# Usage: init_peers /tmp/parent peer1 peer2 [peer3...]
init_peers() {
  local parent="$1"
  shift
  local peers_csv
  peers_csv="$(IFS=','; echo "$*")"

  # Ensure parent is a git repo with a seed commit
  if [[ ! -d "$parent/.git" ]]; then
    (cd "$parent" && git init -q && git commit --allow-empty -q -m "syncgit: init")
  fi

  # Run syncgit init
  (cd "$parent" && "$SYNCGIT" init --peers "$peers_csv")
}

# Run a command inside a peer's worktree.
# Usage: as_peer /tmp/parent peer_id git status
as_peer() {
  local parent="$1"
  local peer_id="$2"
  shift 2
  (cd "$parent/$peer_id" && "$@")
}

# Make a change in a worktree: write CONTENT to FILENAME, git add + commit.
# Usage: make_change /tmp/parent/a myfile.txt "hello world"
make_change() {
  local worktree="$1"
  local filename="$2"
  local content="$3"

  printf '%s' "$content" > "$worktree/$filename"
  (cd "$worktree" && git add "$filename" && git commit -q -m "edit $filename")
}

# Print a green pass message and return 0.
pass() {
  echo "${GREEN}✓ pass${NC}: $*"
  return 0
}

# Print a red fail message and return 1.
fail() {
  echo "${RED}✗ fail${NC}: $*" >&2
  return 1
}

# Assert condition (boolean or exit code).
# Usage: assert 0 "description" or assert "bash condition" "description"
# If the condition fails, prints a red message and returns 1.
assert() {
  local cond="$1"
  local msg="$2"

  if [[ "$cond" == "0" || "$cond" == "true" ]]; then
    pass "$msg"
    return 0
  elif [[ "$cond" == "1" || "$cond" == "false" ]]; then
    fail "$msg"
    return 1
  else
    # Treat as a bash command: evaluate and check exit code
    if eval "$cond" >/dev/null 2>&1; then
      pass "$msg"
      return 0
    else
      fail "$msg"
      return 1
    fi
  fi
}

# Assert equality.
# Usage: assert_eq "a" "b" "description"
assert_eq() {
  local a="$1"
  local b="$2"
  local msg="$3"

  if [[ "$a" == "$b" ]]; then
    pass "$msg"
    return 0
  else
    fail "$msg (expected '$a', got '$b')"
    return 1
  fi
}

# Assert a file exists.
# Usage: assert_exists /path/to/file "description"
assert_exists() {
  local path="$1"
  local msg="$2"

  if [[ -e "$path" ]]; then
    pass "$msg"
    return 0
  else
    fail "$msg (file does not exist: $path)"
    return 1
  fi
}

# Assert a file does NOT exist.
# Usage: assert_not_exists /path/to/file "description"
assert_not_exists() {
  local path="$1"
  local msg="$2"

  if [[ ! -e "$path" ]]; then
    pass "$msg"
    return 0
  else
    fail "$msg (file should not exist: $path)"
    return 1
  fi
}

# Assert a command succeeds (exit code 0).
# Usage: assert_success "command args" "description"
assert_success() {
  local cmd="$1"
  local msg="$2"

  if eval "$cmd" >/dev/null 2>&1; then
    pass "$msg"
    return 0
  else
    fail "$msg (command failed: $cmd)"
    return 1
  fi
}

# Assert a command fails (non-zero exit code).
# Usage: assert_failure "command args" "description"
assert_failure() {
  local cmd="$1"
  local msg="$2"

  if ! eval "$cmd" >/dev/null 2>&1; then
    pass "$msg"
    return 0
  else
    fail "$msg (command should have failed: $cmd)"
    return 1
  fi
}
