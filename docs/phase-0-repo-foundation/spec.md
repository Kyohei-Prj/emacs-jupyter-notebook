# Specification — phase-0-repo-foundation

## Goal
Create a compilable, loadable, testable repository skeleton with CI that passes on Emacs 30+ (Ubuntu, GUI and TTY), enabling all subsequent phases to begin development immediately.

## In scope
- Full directory skeleton for all planned modules (core, model, transactions, events, sync, backend, scheduler, render, lang, serializer, ui, plugin)
- Main package file (`ejn.el`) with package metadata
- Minimal stub files for each module (byte-compilable, no logic)
- `Makefile` with targets: compile, lint, test, clean
- GitHub Actions CI workflow (compile, lint, test on Emacs 30+, Ubuntu, GUI + TTY)
- `use-package` declaration for development dependencies
- `.gitignore` entries for Emacs artifacts
- Test directory structure with minimal stub test file
- Scripts directory structure
- Documentation skeleton under `docs/`

## Out of scope
- Production Elisp logic
- GitHub issue/PR templates
- README (beyond developer onboarding in docs)
- Package release infrastructure (MELPA, Straight)
- User-facing documentation

## Functional requirements
1. `make compile` byte-compiles all `.el` files in `eln/` to `.elc`.
2. `make lint` runs `elint` on all `.el` files with zero errors.
3. `make test` runs the ERT test suite with zero failures.
4. `make clean` removes all `.elc` and `eln/eln/` (byte-compile output directory).
5. The package loads without error: `(require 'ejn)`.
6. Each module directory contains at least one `.el` file that byte-compiles cleanly.
7. GitHub Actions CI runs on push and pull_request to `main`.
8. CI matrix covers Emacs 30, Emacs 31 (if available), and `master` on Ubuntu.
9. CI tests both GUI (`emacs`) and TTY (`emacs -nw`) modes.
10. Test directory contains `helpers/`, `contracts/`, `integration/`, `performance/` subdirectories per `docs/test_strategy.md`.

## Non-functional requirements
- **Performance:** Build (compile + lint + test) completes in under 2 minutes on GitHub Actions.
- **Reliability:** CI is deterministic — same commit always produces same result.
- **Extensibility:** Adding a new module in Phase 3+ requires creating one directory and one `.el` file — no Makefile or CI changes needed.

## Acceptance criteria
- [ ] `make compile` succeeds with zero byte-compile warnings.
- [ ] `make lint` succeeds with zero elint errors.
- [ ] `make test` runs ERT with zero failures (stub test passes).
- [ ] `make clean` removes all build artifacts.
- [ ] `(require 'ejn)` loads without error in a fresh Emacs 30 session.
- [ ] All module directories exist under `eln/` with at least one compilable `.el` file.
- [ ] GitHub Actions CI passes on push to `main` with full matrix (Emacs versions × GUI/TTY).
- [ ] Test directory structure matches Phase 1 requirements in `docs/roadmap.md`.

## Constraints / assumptions
- Repository already initialized with `.git/`, `AGENTS.md`, `docs/`, `LICENSE`.
- `elint` is available as a built-in Emacs command (`M-x elint`).
- GitHub Actions uses `purcell/setup-elixir` or similar Emacs action for setup.
- No external packages are installed in CI (Phase 0 has no runtime deps yet).
- All `.el` files use `lexical-binding: t`.
