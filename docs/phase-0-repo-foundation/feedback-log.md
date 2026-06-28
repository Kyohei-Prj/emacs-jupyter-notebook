# Feedback Log — phase-0-repo-foundation

<!-- Append one entry per reviewed phase. Never delete prior entries. -->

## Phase 1 — 2026-06-28
- All 6 smoke tasks passed. Zero blocking issues.
- Non-blocking findings:
  - Require stubs in `eln/ejn.el` are commented out. Works for now; Phase 2 Makefile should handle compilation order.
  - `AGENTS.md` added out of scope (process doc, not a Phase 1 deliverable).
  - Duplicate `*~` in `.gitignore` (pre-existing, cosmetic).
- Risks for future phases:
  - Phase 2 compile target needs dependency ordering if require stubs get uncommented.
  - Task 2.5 test file location (`eln/ejn-test.el` vs `test/ejn-test.el`) is unconventional.
  - Verify Emacs 30 availability in CI setup action for Phase 3.

## Phase 2 — 2026-06-28
- 5/6 tasks passed on first run. 1 blocking issue found and fixed.
- **Blocking (FIXED):** compile target missed top-level .el files (ejn-test.el). Fixed by adding TOP_LEVEL_EL_FILES variable and third compilation step. All 3 compile tests now pass.
- **Non-blocking findings:**
  - test target hardcodes `ejn-test` instead of using TEST_FILES variable. New test files won't auto-discover.
  - Lint spawns a fresh Emacs per file (slow, will degrade with more modules).
  - `eln/eln/` directory doesn't exist on this system (native compilation only).
  - Placeholder author/version in ejn.el.
  - No `.dir-locals.el` for consistent formatting.
- **Risks for future phases:**
  - Test file discovery fragile — conflicts with spec FR#10 (no Makefile changes needed for new modules).
  - Lint performance bottleneck as modules grow.
  - `make test` runs against .el sources, not .elc — won't catch byte-compile-only bugs.
