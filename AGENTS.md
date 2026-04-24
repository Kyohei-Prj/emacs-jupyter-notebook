# ejn.el — Developer Instructions

## Current state
Phase 1 scaffolding is complete. All 11 `lisp/ejn-*.el` modules and 7 test files exist as stubs (`;; TODO: implementation`). Only `ejn-util.el` has real code (debug logger, UUID generator, assertion helper).

## Before implementing
1. Read `plan/roadmap.md` — 10-phase architecture spec with exact function signatures, struct slots, and test requirements. Treat it as the single source of truth.
2. Module dependency order: `ejn-util` has zero inter-module deps. Every other module `require`s only `ejn-util`. Do not add cross-module requires until the corresponding phase specifies them.
3. Use MCP tool `elisp-dev` for Emacs Lisp development.

## Build and test
- `make install` — `cask install`
- `make compile` — byte-compile `lisp/*.el` and `ejn.el` with `byte-compile-error-on-warn t`
- `make test` — runs `test/test-runner.el` which auto-loads all `test/ejn-*-test.el` via buttercup
- `make lint` — runs `package-lint` (tolerates warnings for bundled Emacs packages like `jupyter`) + `checkdoc` on `ejn.el`
- `make clean` — removes `*.elc`, `.eask/`, `dist/`, `_test/`
- `make all` — install → compile → lint → test

## Architecture facts
- Each notebook cell gets an **indirect buffer** (name: ` *ejn-cell-<uuid>*`, leading space = invisible in `C-x b`)
- A **shadow buffer** (` *ejn-shadow-<basename>*`) concatenates same-language cells for cross-cell LSP
- Position translation between shadow and cell buffers (Phase 6) is the hardest part
- `ewoc` drives the read-only display layer (Phase 7)
- Tree-sitter `*-ts-mode` selected per cell language (Phase 8)
- Output rendering (Phase 9) is incremental as it arrives from kernel

## Conventions
- All `.el` files: `-*- lexical-binding: t; -*-`
- License header: `SPDX-License-Identifier: GPL-3.0-or-later`
- Commentary block after header: 3–5 sentence package description
- Footer: `(provide 'ejn-<module>)` then `;;; ejn-<module>.el ends here`
- File naming: `ejn-<domain>.el` (e.g. `ejn-data.el`, `ejn-kernel.el`)
- Test naming: `ejn-<domain>-test.el` matching its module
- Cell UUIDs use the `id` slot; nbformat 4.5 requires them
- Never use raw `cl-defstruct` constructor in public API — wrap with named constructor like `ejn-make-cell`
- All user-facing settings must be `defcustom` with `:group 'ejn`
- All display faces must be `defface` with light/dark defaults
- `.ipynb` parsing uses `(json-parse-string ... :object-type 'hash-table)`
- Fixtures live in `fixtures/`; use `ejn-test--fixture-path` from `test-helper.el` instead of hardcoding paths

## Generated files (gitignored)
`*.elc`, `-autoloads.el`, `-pkg.el`, `.eask/`, `dist/`, `_test/`, `bin/ellsp`, `.DS_Store`

## Framework dependencies
Requires: Emacs 29.1+, `jupyter.el`, `lsp-mode`, `dash`, `s`
Dev-only: `buttercup`, `el-mock`, `undercover`, `package-lint`

## CI
Matrix: Emacs 29.1, 29.4, 30.1 via `purcell/setup-emacs` on `ubuntu-latest`.
