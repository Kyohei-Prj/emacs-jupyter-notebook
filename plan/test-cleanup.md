# Test Suite Cleanup Plan

Restructure the test suite from task-ID-driven granularity to a cleaner, module-organized layout with shared fixtures and consolidated tests.

**Current state:** 9,814 lines, 438 tests, 1,092 assertions, 3.2:1 test-to-source ratio.

**Target:** ~5,500-6,000 lines (~40% reduction), tests organized by module/function, shared fixtures, no redundant structure.

---

## Phase 1: Remove Structural Bloat

### T1 — Strip section headers and doc strings from all test files

Each test currently has a `;;; Tests — P2-T8: ...` header + blank line + redundant doc string. Test names are descriptive enough to stand alone.

**Changes per file:**
- Remove all `;;; Tests —` comment headers and their trailing blank lines
- Remove all doc strings from `ert-deftest` forms
- Keep one blank line between test forms for readability

**Files:** All 7 test files.

**Expected savings:** ~1,500 lines (headers + doc strings + extra blanks).

### T2 — Deduplicate file headers

Every test file repeats the same GPL header (16 lines) and load-path setup (4 lines). Factor these into a single shared include or minimize the per-file boilerplate.

**Changes:**
- Reduce per-file header to 3-4 lines (just `require`, minimal comment, load-path)
- Keep copyright on first line as comment

**Files:** All 7 test files.

**Expected savings:** ~80 lines.

---

## Phase 2: Introduce Test Fixtures

### T3 — Create `test/ejn-test-fixtures.el`

Shared fixture library with helper functions for creating common test objects. Eliminates 701 repetitive `make-instance` calls.

**Functions to define:**
- `ejn-test--make-cell` — creates an `ejn-cell` with defaults `:type 'code`, `:source ""`, accepts `&rest` initargs to override
- `ejn-test--make-notebook` — creates an `ejn-notebook` with a temp file path, accepts `&rest` initargs
- `ejn-test--make-notebook-with-cells` — creates notebook + N cells in one call
- `ejn-test--with-temp-notebook` — macro that creates a temp notebook dir, runs body, then cleans up

**File:** `test/ejn-test-fixtures.el` (~80 lines new).

### T4 — Migrate cell and core tests to fixtures

Replace inline `make-instance` calls in `ejn-cell-tests.el` and `ejn-core-tests.el` with fixture helpers.

**Before:**
```elisp
(let* ((cell (make-instance 'ejn-cell
                            :type 'code
                            :source "pass"))
       (nb (make-instance 'ejn-notebook
                          :path "/tmp/test-notebook.ipynb"
                          :cells nil)))
```

**After:**
```elisp
(let* ((cell (ejn-test--make-cell :source "pass"))
       (nb (ejn-test--make-notebook)))
```

**Files:** `test/ejn-cell-tests.el`, `test/ejn-core-tests.el`.

**Expected savings:** ~300 lines.

### T5 — Migrate remaining test files to fixtures

Apply same fixture migration to `ejn-lsp-tests.el`, `ejn-master-tests.el`, `ejn-network-tests.el`, `ejn-ui-tests.el`, `ejn-notebook-tests.el`.

**Files:** Remaining 5 test files.

**Expected savings:** ~200 lines.

---

## Phase 3: Consolidate Tests

### T6 — Merge ejn-core EIEIO slot tests

The 19 tests for P2-T1 contain 6 "has-slot-default-nil" tests and 5 "has-slot-type" tests for `ejn-notebook`/`ejn-cell` that are trivially combinable.

**Consolidation:**
- 6 `ejn-notebook` default-nil slot tests → 1 test checking all defaults
- 7 `ejn-cell` default-nil/type slot tests → 1 test checking all slots
- 2 "is-class" tests → keep as-is (structural)
- 2 "instantiate-with" tests → merge with slot tests
- 2 "id is generated/unique" → keep as-is

**Result:** 19 tests → ~7 tests.

**File:** `test/ejn-core-tests.el`.

### T7 — Merge ejn-lsp parameterized tests

Several LSP tests differ only in input values and could use `ert-deftest` with `dolist`/`should` tables:

- `ejn-lsp-sentinel-line` (2 tests for index 0 and 42) → 1 test with loop
- `ejn-lsp-cell-line-count` (7 tests for different strings) → 1 test with data table
- `ejn-lsp-composite-path` (2 tests for different paths) → 1 test with loop

**File:** `test/ejn-lsp-tests.el`.

**Result:** ~20 tests → ~8 tests.

### T8 — Merge ejn-master repetitive setup tests

The `ejn-master-p2-t10` and `ejn-master-p2-t11` groups each have 7 tests with identical `make-temp-file` + `make-instance` + `unwind-protect` setup. Tests that check related properties of the same function call can be merged.

**Consolidation:**
- 7 tests for `ejn--create-master-view` creation → 2 tests (buffer/mode + hooks/backpointers)
- 7 tests for poly-ejn-mode → 3 tests (mode setup + buffer contents + cleanup)

**File:** `test/ejn-master-tests.el`.

### T9 — Merge ejn-cell open-buffer tests

The 7 tests for `ejn-cell-open-buffer` (P2-T8) check buffer creation, mode, back-pointers, buffer slot, kill-hook, and idempotency. Most share identical cell creation setup.

**Consolidation:**
- 5 "creates buffer with X properties" tests → 2 tests
- 1 "returns existing buffer" test → keep
- 1 "registers kill-hook" → merge with first test

**File:** `test/ejn-cell-tests.el`.

### T10 — Merge ejn-network kernel operation tests

Many network tests follow the pattern: create notebook, start kernel, call operation, check result. Tests for `returns-nil`, `signals-error-when-no-kernel`, and `calls-X-with-correct-args` can be grouped per function into a single test.

**Consolidation per function:** 3 tests → 1 test with multiple `should` assertions.

Functions affected: `ejn-kernel-restart`, `ejn-kernel-interrupt`, `ejn-kernel-reconnect`, `ejn-kernel-shutdown`.

**File:** `test/ejn-network-tests.el`.

---

## Phase 4: Restructure by Module

### T11 — Reorganize test files by tested function, not task ID

Remove the task-ID-based grouping (`;;; Tests — P2-T8: ...`) and group tests under `;;; <function-name>` sections. Tests for the same function should appear together regardless of which task ID introduced them.

**Example for `ejn-cell-tests.el`:**
```
;;; ejn-cell-open-buffer
;;; ejn-cell-refresh-buffer
;;; ejn--record-structural-change
;;; ejn--make-cell
;;; ejn:worksheet-cut-cell
;;; ejn:worksheet-copy-cell
;;; ejn:worksheet-paste-cell
;;; ejn:worksheet-yank-cell
;;; ejn:worksheet-delete-cell
;;; ejn:worksheet-move-cell-up
;;; ejn:worksheet-move-cell-down
;;; ejn:worksheet-merge-cell
;;; ejn:worksheet-split-cell
```

**Files:** All test files.

### T12 — Strip task IDs from test names

Rename test functions from `ejn-cell-p2-t8--open-buffer-creates-buffer-with-source` to `ejn-cell--open-buffer-creates-buffer-with-source`. The task ID prefix served the old 1:1 traceability model; the new grouping by function makes it redundant.

**Pattern:** `ejn-<module>-<phase>-<task>--<function>--<description>` → `ejn-<module>--<function>--<description>`

**Files:** All 7 test files.

---

## Phase 5: Verify

### T13 — Full regression pass

Run `make check` to ensure all tests still pass after restructuring. Fix any broken tests from the consolidation and renaming.

### T14 — Line count audit

Verify final line count is within target range (~5,500-6,000 lines). Document before/after metrics.

---

## Execution Order

Tasks within a phase are independent and can run in parallel. Phases must run sequentially:

1. Phase 1 (T1, T2) — safe, cosmetic only
2. Phase 2 (T3-T5) — introduces new code, no test behavior change
3. Phase 3 (T6-T10) — merges tests, may lose individual failure granularity
4. Phase 4 (T11, T12) — reorganization, no behavior change
5. Phase 5 (T13, T14) — verification

Run `make check` after each phase to catch regressions early.
