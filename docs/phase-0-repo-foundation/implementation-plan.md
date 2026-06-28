# Implementation Plan — phase-0-repo-foundation

## Phase 1 — Directory Skeleton & Package Header
**Goal:** Create the full directory structure and main package file so the project is byte-compilable and loadable.

**Tasks:**
- [x] Task 1.1: Create all module directories under `eln/` (core, model, transactions, events, sync, backend, scheduler, render, lang, serializer, ui, plugin) [type: smoke]
- [x] Task 1.2: Create test directory structure (`test/helpers/`, `test/contracts/`, `test/integration/`, `test/performance/`) [type: smoke]
- [x] Task 1.3: Create `scripts/` directory [type: smoke]
- [x] Task 1.4: Write `eln/ejn.el` with package header (name: ejn, version: 0.0.0, Emacs 30.1+), lexical-binding, minimal `require` stubs for all modules [type: smoke]
- [x] Task 1.5: Write minimal stub `.el` files for each module (one per module directory, with lexical-binding and a single commented placeholder) [type: smoke]
- [x] Task 1.6: Update `.gitignore` with Emacs artifacts (`*.elc`, `eln/eln/`, `#*#`, `auto-save-list`) [type: smoke]

**Acceptance:** `(require 'ejn)` loads without error. All directories exist. All `.el` files have `lexical-binding: t`.

---

## Phase 2 — Build System (Makefile)
**Goal:** Provide `make compile`, `make lint`, `make test`, `make clean` targets that work end-to-end.

**Tasks:**
- [x] Task 2.1: Write `Makefile` with `compile` target using `emacs -batch -f batch-byte-compile` on all `eln/*.el` files [type: tdd]
- [x] Task 2.2: Write `Makefile` with `lint` target running `elint` on all `.el` files [type:tdd]
- [x] Task 2.3: Write `Makefile` with `clean` target removing `.elc` files and byte-compile output directory [type: smoke]
- [x] Task 2.4: Write `Makefile` with `test` target running `emacs -batch -f ert-run-tests-batch-and-exit` [type: tdd]
- [x] Task 2.5: Write `eln/ejn-test.el` stub test file with one passing ERT test [type: tdd]
- [x] Task 2.6: Verify full build: `make clean && make compile && make lint && make test` passes locally [type: tdd]

**Acceptance:** `make clean && make compile && make lint && make test` completes with zero errors and zero warnings.

---

## Phase 3 — GitHub Actions CI
**Goal:** CI pipeline that compiles, lints, and tests on Emacs 30+ (Ubuntu, GUI + TTY) on push and PR.

**Tasks:**
- [ ] Task 3.1: Create `.github/workflows/ci.yml` with `setup-elixir`-style Emacs setup action [type: smoke]
- [ ] Task 3.2: Configure CI matrix: Emacs versions (30, 31 if available, master) × display mode (GUI, TTY) [type: smoke]
- [ ] Task 3.3: Add CI jobs: compile, lint, test [type: smoke]
- [ ] Task 3.4: Verify CI passes on a test branch push [type: tdd]

**Acceptance:** GitHub Actions CI passes on push to any branch with full matrix coverage. Build completes in under 2 minutes.

---

## Phase 4 — use-package & Developer Onboarding
**Goal:** Development dependency declarations and minimal developer onboarding documentation.

**Tasks:**
- [ ] Task 4.1: Add `use-package` declarations in `eln/ejn.el` or separate dev config for development dependencies (emacs-jupyter, transient, lsp-mode) [type: smoke]
- [ ] Task 4.2: Write `docs/DEVELOP.md` with developer onboarding instructions (setup, build, test, run) [type: smoke]

**Acceptance:** Developer can clone repo and follow `docs/DEVELOP.md` to run `make compile && make lint && make test` successfully.

---

## Dependencies between phases
- Phase 1 must complete before Phase 2 (needs `.el` files to compile).
- Phase 2 must complete before Phase 3 (CI runs `make` targets).
- Phase 4 can run in parallel with Phase 3 (independent work).
