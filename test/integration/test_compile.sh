#!/usr/bin/env bash
# test_compile.sh — Verify that `make compile` succeeds and produces .elc files
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

# Clean any previous .elc files
find "$ROOT_DIR/eln" -name '*.elc' -type f -delete 2>/dev/null || true

# --- Test 1: `make compile` exits with code 0 ---
make -C "$ROOT_DIR" compile > /dev/null 2>&1
make_exit=$?
report $make_exit "make compile exits with code 0"

# --- Test 2: All .el files have corresponding .elc files ---
missing=0
for el_file in $(find "$ROOT_DIR/eln" -name '*.el' -type f); do
  elc_file="${el_file%.el}.elc"
  if [ ! -f "$elc_file" ]; then
    echo "  missing: $elc_file"
    missing=1
  fi
done
report $missing "All .el files have corresponding .elc files"

# --- Test 3: Compilation produces zero warnings ---
# Re-run compilation and capture stderr; batch-byte-compile prints warnings to stderr
output=$(make -C "$ROOT_DIR" compile 2>&1 || true)
warning_count=$(echo "$output" | grep -ic 'warning' || true)
report $([ "$warning_count" -eq 0 ] && echo 0 || echo 1) "Compilation produces zero warnings"

# --- Summary ---
echo ""
echo "Results: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
