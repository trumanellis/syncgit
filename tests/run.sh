#!/usr/bin/env bash
# syncgit test runner — iterate case_*.sh in sort order, report PASS/FAIL summary

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'

passed=0
failed=0
failed_cases=()

# Find and run all case_*.sh files in sort order
for case_file in $(find "$here" -name 'case_*.sh' -type f | sort); do
  case_name="$(basename "$case_file" .sh)"

  echo
  echo "=== $case_name ==="

  # Run in a subshell so 'set -e' failures don't kill the runner
  if (bash "$case_file"); then
    echo "${GREEN}PASS${NC}: $case_name"
    ((passed++)) || true
  else
    echo "${RED}FAIL${NC}: $case_name"
    ((failed++)) || true
    failed_cases+=("$case_name")
  fi
done

# Summary
echo
echo "======================================"
echo "Test Summary:"
echo "  Passed: $passed"
echo "  Failed: $failed"
if [[ ${#failed_cases[@]} -gt 0 ]]; then
  echo "  Failed cases:"
  for case in "${failed_cases[@]}"; do
    echo "    - $case"
  done
fi
echo "======================================"

# Exit non-zero if any tests failed
if [[ $failed -gt 0 ]]; then
  exit 1
else
  exit 0
fi
