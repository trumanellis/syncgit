#!/usr/bin/env bash
# Sample .syncgit/verify.sh — runs the project's test suite.
# Copy to your worktree's .syncgit/verify.sh and chmod +x.
# `syncgit verify` runs this from the worktree root with the working tree
# in the merged state. Exit 0 on success; non-zero halts the sync flow.

set -euo pipefail

# Replace with whatever proves your code works:
# - npm test
# - cargo test
# - python -m pytest
# - go test ./...
# - make test

if [[ -f package.json ]]; then
  npm test --silent
elif [[ -f Cargo.toml ]]; then
  cargo test --quiet
elif [[ -f pyproject.toml || -f setup.py ]]; then
  python3 -m pytest -q
else
  echo "verify: no recognized project config; treating as pass"
fi
