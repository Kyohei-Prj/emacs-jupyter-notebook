# ejn.el — Developer Instructions

## Project status
Greenfield. No `.el` source exists yet. The architecture, phases, and implementation
specs are in `plan/roadmap.md` — treat it as the single source of truth.

## Repo structure
```
ejn.el              # package entry point (to be created)
lisp/ejn-*.el       # modules (to be created)
test/ejn-*-test.el  # buttercup tests (to be created)
fixtures/*.ipynb    # notebook fixtures (to be created)
plan/roadmap.md     # 10-phase development plan — read before implementing anything
Makefile            # Cask-based build (to be created)
Cask                # dependency manifest (to be created)
```

## Before implementing
1. Read `SPEC.md` — every phase has exact function signatures, struct slots,
   and test requirements.
2. Each `lisp/ejn-*.el` stub must `require` only `ejn-util` to avoid circular deps at
   early phases.

## Build and test
- `make install` — `cask install`
- `make compile` — byte-compile with `--eval "(setq byte-compile-error-on-warn t)"`
- `make test` — `cask exec buttercup` (full suite)
- `make lint` — `package-lint` + `checkdoc`
- `make all` — install → compile → lint → test

## Conventions
- All `.el` files: `-*- lexical-binding: t; -*-`
- License header: `SPDX-License-Identifier: GPL-3.0-or-later`
- Commentary block after header: package description (3–5 sentences)
- Footer: `(provide 'ejn-<module>)` followed by `;;; ejn-<module>.el ends here`
- File naming: `ejn-<domain>.el` (e.g. `ejn-data.el`, `ejn-kernel.el`)
- Test naming: `ejn-<domain>-test.el` matching its module
- Cell UUIDs use the `id` slot; nbformat 4.5 requires them
- Never use the raw `cl-defstruct` constructor in public API — wrap with a named
  constructor like `ejn-make-cell`
- All user-facing settings must be `defcustom` with `:group 'ejn`
- All display faces must be `defface` with light/dark defaults
- Cell indirect buffers are invisible (leading space in name: `*ejn-cell-<uuid>*`)
- `.ipynb` parsing uses `(json-parse-string ... :object-type 'hash-table)`

## Generated files (gitignored)
`*.elc`, `-autoloads.el`, `-pkg.el`, `.eask/`, `dist/`, `_test/`, `bin/ellsp`

## Framework dependencies
Requires: Emacs 29.1+, `jupyter.el`, `lsp-mode`, `dash`, `s`
Dev-only: `buttercup`, `el-mock`, `undercover`

## Key architecture facts
- Each notebook cell gets an **indirect buffer** (not a separate buffer) for LSP compatibility
- A **shadow buffer** concatenates same-language cells for cross-cell LSP features
- Position translation between shadow and cell buffers is the hardest part of Phase 6
- `ewoc` drives the read-only display layer (Phase 7)
- Tree-sitter `*-ts-mode` is selected per cell language (Phase 8)
- Output rendering (Phase 9) is incremental — rendered as it arrives from kernel
