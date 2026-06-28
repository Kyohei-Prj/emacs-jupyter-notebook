#!/usr/bin/env bash
# test_test.sh — Verify that `make test` runs ERT correctly
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

# --- Test 1: `make test` target exists ---
make -C "$ROOT_DIR" -n test > /dev/null 2>&1
report $? "make test target exists"

# --- Test 2: `make test` invokes emacs in batch mode ---
dry_run=$(make -C "$ROOT_DIR" -n test 2>&1 || true)
if echo "$dry_run" | grep -q 'emacs -batch'; then
  report 0 "make test invokes emacs -batch"
else
  report 1 "make test invokes emacs -batch"
  echo "  dry-run output: $dry_run"
fi

# --- Test 3: `make test` loads ert ---
if echo "$dry_run" | grep -q '\-l ert'; then
  report 0 "make test loads ert with -l ert"
else
  report 1 "make test loads ert with -l ert"
  echo "  dry-run output: $dry_run"
fi

# --- Test 4: `make test` includes -L eln/ for load path ---
if echo "$dry_run" | grep -q '\-L eln'; then
  report 0 "make test includes -L eln/ for load path"
else
  report 1 "make test includes -L eln/ for load path"
  echo "  dry-run output: $dry_run"
fi

# --- Test 5: `make test` calls ert-run-tests-batch-and-exit ---
if echo "$dry_run" | grep -q 'ert-run-tests-batch-and-exit'; then
  report 0 "make test calls ert-run-tests-batch-and-exit"
else
  report 1 "make test calls ert-run-tests-batch-and-exit"
  echo "  dry-run output: $dry_run"
fi

# --- Test 6: `make test` actually runs and exits 0 ---
output=$(make -C "$ROOT_DIR" test 2>&1)
report $? "make test exits with code 0"

# --- Test 7: ERT reports tests run ---
if echo "$output" | grep -qiE 'ran [0-9]+ test'; then
  report 0 "make test output shows ERT test results"
else
  report 1 "make test output shows ERT test results"
  echo "  output: $output"
fi

# --- Summary ---
echo ""
echo "Results: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
