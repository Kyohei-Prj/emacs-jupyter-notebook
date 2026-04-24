# SPEC.md — emacs-jupyter-notebook (ejn.el)

> **Status:** Phase 1 scoped. The build loop runs Phase 1 in isolation; remaining phases
> are tracked in `plan/roadmap.md` and will be pulled into SPEC.md incrementally.

---

## Goal

Establish a complete, runnable project skeleton for the `ejn.el` package: a directory tree,
a package entry point, stub module files with a foundational utility module, a Cask-based
test harness, three notebook fixtures, a Makefile with install/compile/lint/test/clean/all
targets, skeleton buttercup tests, a GitHub Actions CI workflow, `.dir-locals.el`, and a
skeleton README. At the end of this phase the project compiles cleanly, runs an empty test
suite (placeholder tests only), and is loadable in a bare Emacs 29.1 instance.

---

## Features

1. Create directory tree (`ejn.el`, `lisp/`, `test/`, `fixtures/`, `docs/`,
   `.github/workflows/`) plus config files (`.elpaignore`, `.dir-locals.el`) → every listed
   file exists and every directory is non-empty
2. Write `ejn.el` package entry point → file contains an ELPA package header with
   `Package-Requires: ((emacs "29.1") (jupyter) (lsp-mode) (dash) (s))`, a commentary block
   of 3–5 sentences, guarded `(require ...)` calls for each `lisp/ejn-*.el`, a
   `(provide 'ejn)` form, and a `;;; ejn.el ends here` footer; no functional code
3. Write 10 stub module files (`ejn-data.el` through `ejn-util.el` excluded) → each stub
   uses `lexical-binding: t`, requires only `ejn-util`, has a correct `provide` and footer
   comment, and contains `(require 'ejn-util)` followed by `;; TODO: implementation`
4. Write `ejn-util.el` with `ejn--debug-p`, `ejn--log`, `ejn--uuid`, `ejn--assert` → all
   four symbols are defined and importable; `ejn--uuid` returns a 36-character hyphenated
   UUID-like string; `(require 'ejn-util)` succeeds without requiring any other `ejn-*` module
5. Write `Cask` dependency manifest → file declares `(source gnu)`, `(source melpa)`,
   `(package-file "ejn.el")`, runtime depends-on (emacs 29.1, jupyter, lsp-mode, dash, s),
   and development depends-on (buttercup, el-mock, undercover)
6. Write `Makefile` with 6 targets (install, compile, test, lint, clean, all) → each target
   has a documented comment; `make compile` uses `cask exec emacs --batch --eval` with
   `byte-compile-error-on-warn t` and `batch-byte-compile lisp/*.el ejn.el`; all targets are
   declared `.PHONY`
7. Write `test/test-helper.el` → adds `lisp/` and project root to `load-path`, requires all
   `ejn-*.el` modules, defines `ejn-test--fixture-path` and `ejn-test--with-temp-notebook`,
   requires buttercup and el-mock
8. Create 3 notebook fixtures (`simple.ipynb`, `mixed-lang.ipynb`, `with-outputs.ipynb`) →
   each is valid nbformat 4.5 JSON; `simple.ipynb` has 2 Python code cells with explicit
   UUID `id` fields and no outputs; `mixed-lang.ipynb` has 1 Markdown + 2 Python cells;
   `with-outputs.ipynb` has 1 cell with `text/plain` output and 1 cell with `image/png`
   output (1×1 pixel base64-encoded)
9. Write 6 skeleton test files (`ejn-data-test.el` through `ejn-lsp-test.el`) → each file
   requires `test-helper` then its corresponding `ejn-*.el` module; each contains a single
   placeholder test `(expect t :to-be t)` so `make test` outputs `1 passing`
10. Write `.dir-locals.el` → sets `indent-tabs-mode: nil`, `fill-column: 80` for all
    files, and `checkdoc-minor-mode: t` for `emacs-lisp-mode`
11. Write `.github/workflows/ci.yml` → triggers on `push` to `main` and on PRs; matrix of
    Emacs versions `29.1`, `29.4`, `30.1`; steps: checkout → install Emacs → install Cask
    → `make install` → `make compile` → `make test`; uploads artifacts on failure
12. Write `README.md` skeleton → contains package name, one-paragraph description, status
    badge wired to CI workflow, stub sections (Installation, Quick Start, Architecture,
    Contributing, License), and a note that Emacs 29.1+, `jupyter.el`, and `lsp-mode` are
    required
13. Phase 1 validation: `make all` succeeds → `make install`, `make compile` (zero warnings,
    zero errors), `make test` (all placeholder tests passing), `make lint` (no errors),
    `(require 'ejn)` loads cleanly in Emacs 29.1, CI workflow passes on GitHub

---

## Out of scope

- Any functional code beyond the stubs and utilities in Phase 1 (no cell model, no I/O,
  no kernel communication, no LSP, no buffer management, no display layer)
- Real kernel or LSP integration in CI (mocks only, from later phases)
- MELPA recipe, user manual, or release artifacts (Phase 10)
- Test coverage targets (Phase 10)
- Documentation files beyond the README skeleton (`docs/ARCHITECTURE.md` and
  `docs/CONTRIBUTING.md` are created as empty stubs only)

---

## Architecture

### Directory layout

```
ejn.el/                        # project root
├── ejn.el                     # package entry point
├── lisp/
│   ├── ejn-data.el            # data model (stub)
│   ├── ejn-io.el              # .ipynb I/O (stub)
│   ├── ejn-kernel.el          # kernel adapter (stub)
│   ├── ejn-buffer.el          # buffer management (stub)
│   ├── ejn-shadow.el          # shadow document (stub)
│   ├── ejn-lsp.el             # LSP adapter (stub)
│   ├── ejn-display.el         # ewoc display (stub)
│   ├── ejn-output.el          # output rendering (stub)
│   ├── ejn-treesit.el         # tree-sitter helpers (stub)
│   └── ejn-util.el            # shared utilities (functional)
├── test/
│   ├── test-helper.el         # test bootstrap
│   ├── ejn-data-test.el       # placeholder test
│   ├── ejn-io-test.el         # placeholder test
│   ├── ejn-kernel-test.el     # placeholder test
│   ├── ejn-buffer-test.el     # placeholder test
│   ├── ejn-shadow-test.el     # placeholder test
│   └── ejn-lsp-test.el        # placeholder test
├── fixtures/
│   ├── simple.ipynb           # 2 Python code cells, no outputs
│   ├── mixed-lang.ipynb       # 1 Markdown + 2 Python
│   └── with-outputs.ipynb     # text output + 1×1 PNG output
├── docs/
│   ├── ARCHITECTURE.md        # empty stub
│   └── CONTRIBUTING.md        # empty stub
├── .github/
│   └── workflows/
│       └── ci.yml             # GitHub Actions CI
├── Makefile
├── Cask
├── .dir-locals.el
├── .elpaignore
├── README.md
├── LICENSE
├── .gitignore
└── plan/
    └── roadmap.md
```

### File formats

- **`.el` files**: `-*- lexical-binding: t; -*-`, `SPDX-License-Identifier: GPL-3.0-or-later`,
  commentary block (3–5 sentences), `(provide 'ejn-<module>)` footer, `;;; ejn-<module>.el ends here`
- **`.ipynb` files**: nbformat 4.5 JSON, `json-parse-string :object-type 'hash-table`
  compatible, cells have explicit `id` string fields (UUID format)
- **`Cask`**: Cask DSL format as specified in section 1.5 of roadmap
- **`Makefile`**: POSIX make, tab-indented recipe lines, `.PHONY` declaration

### `ejn-util.el` API

| Symbol | Signature | Description |
|--------|-----------|-------------|
| `ejn--debug-p` | `defvar` | Boolean; nil by default |
| `ejn--log` | `(fmt &rest args)` | Writes to `*ejn-log*` buffer if `ejn--debug-p` is non-nil |
| `ejn--uuid` | `()` | Returns a 36-character hyphenated UUID-like string |
| `ejn--assert` | `(condition message)` | Signals `(error message)` if condition is nil |

### `test/test-helper.el` API

| Symbol | Signature | Description |
|--------|-----------|-------------|
| `ejn-test--fixture-path` | `(name)` | Returns absolute path to `fixtures/<name>` |
| `ejn-test--with-temp-notebook` | `(body-fn)` | Macro: copies `fixtures/simple.ipynb` to a temp dir, runs `body-fn` with the temp path, cleans up |

### Tech stack

| Tool | Rationale |
|------|-----------|
| Emacs 29.1+ | Baseline requirement; treesit and json features used |
| Cask | Build and test harness (dependency resolution, batch execution) |
| Buttercup | Emacs testing framework for all test files |
| el-mock | Function mocking for kernel and LSP tests |
| Undercover | Test coverage measurement (Phase 10) |
| GitHub Actions (purcell/setup-emacs) | CI across Emacs 29.1, 29.4, 30.1 |
| package-lint | ELPA package linting |
| checkdoc | Emacs Lisp documentation checking |

---

## Task list

### Phase 1 — Project Scaffolding

- [x] P1-T1 Create directory tree (`lisp/`, `test/`, `fixtures/`, `docs/`, `.github/workflows/`) [scaffold] (no importable code, no observable behavior)
- [x] P1-T2 Write `ejn-util.el` with `ejn--debug-p`, `ejn--log`, `ejn--uuid`, `ejn--assert` [tdd] (functional code with conditional branches, I/O, and state mutation)
- [x] P1-T3 Write 10 stub module files (`ejn-data.el` through `ejn-treesit.el`, excluding `ejn-util.el`) [smoke] (importable code with structural requirements — wrong requires or missing provides would be a runtime failure)
- [x] P1-T4 Write `ejn.el` package entry point with ELPA header, guarded requires, provide, footer [smoke] (importable code — structural wiring, wrong header or missing provide is a runtime failure)
- [x] P1-T5 Write `Cask` dependency manifest [scaffold] (static config file with no computed values)
- [x] P1-T6 Write `Makefile` with 6 documented targets and `.PHONY` declaration [scaffold] (static config file; `make` is an external tool, not importable code)
- [x] P1-T7 Create 3 notebook fixture files (`simple.ipynb`, `mixed-lang.ipynb`, `with-outputs.ipynb`) as valid nbformat 4.5 JSON [scaffold] (data files with no executable code)
- [x] P1-T8 Write `test/test-helper.el` (load-path setup, requires, `ejn-test--fixture-path`, `ejn-test--with-temp-notebook` macro, buttercup/el-mock requires) [scaffold] (test infrastructure — structural glue, no real test assertions)
- [x] P1-T9 Write 6 skeleton test files with placeholder buttercup tests [scaffold] (placeholder tests only, no real assertions, no logic)
- [x] P1-T10 Write `.dir-locals.el` [scaffold] (static project-local settings, no code)
- [x] P1-T11 Write `.elpaignore` listing files to exclude from ELPA packaging [scaffold] (static config file)
- [x] P1-T12 Write `.github/workflows/ci.yml` with Emacs version matrix, Cask install, compile, test steps [scaffold] (static CI config file; no importable code)
- [x] P1-T13 Write `README.md` skeleton with package name, description, CI badge, stub sections, dependency notes [scaffold] (static documentation file)
- [x] P1-T14 Create empty stubs for `docs/ARCHITECTURE.md` and `docs/CONTRIBUTING.md` [scaffold] (empty files, no content)

### Phase 1 Validation Checklist

Before proceeding to Phase 2, confirm all of the following:

- [ ] `make install` completes without error
- [ ] `make compile` produces zero warnings and zero errors
- [ ] `make test` outputs `X passing` with no failures (where X equals the number of skeleton test files)
- [ ] `make lint` reports no `package-lint` or `checkdoc` errors
- [ ] `(require 'ejn)` loads cleanly in a bare Emacs 29.1
- [ ] GitHub Actions CI workflow runs and passes for all Emacs versions in the matrix

---

## Open questions

- [x] Author name for copyright headers → **Answer:** `Kyohei-Prj` (confirmed by user)
