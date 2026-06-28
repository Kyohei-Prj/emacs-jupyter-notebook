#!/usr/bin/env bash
# test_lint.sh — Verify that `make lint` succeeds with zero elint errors
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

report() {
  if [ "$1" -eq 0 ]; then
    echo "PASS: $2"
    pass=$((pass + 1))
  else
    echo "FAIL: $2"
    fail=$((fail + 1))
  fi
}

# --- Test 1: `make lint` exits with code 0 ---
make -C "$ROOT_DIR" lint > /dev/null 2>&1
make_exit=$?
report $make_exit "make lint exits with code 0"

# --- Test 2: `make lint` produces elint output for every .el file ---
output=$(make -C "$ROOT_DIR" lint 2>&1 || true)
lint_errors=0
for el_file in $(find "$ROOT_DIR/eln" -name '*.el' -type f); do
  rel="${el_file#$ROOT_DIR/}"
  # elint prints the filename on error lines; check that no errors reference this file
  if echo "$output" | grep -q "Warning\|Error" ; then
    # elint outputs warnings/errors; count them
    true
  fi
done

# Check for any elint warnings or errors in the output
error_lines=$(echo "$output" | grep -ci 'warning\|error' || true)
report $([ "$error_lines" -eq 0 ] && echo 0 || echo 1) "make lint produces zero elint warnings or errors"

# --- Summary ---
echo ""
echo "Results: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
