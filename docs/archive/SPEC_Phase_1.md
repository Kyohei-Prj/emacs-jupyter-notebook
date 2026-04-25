# SPEC.md — Emacs Jupyter Notebook (EJN)

## Goal

Establish the EJN project's physical scaffolding and automated workflow so that a developer checking out the repository can run `make install` and `make test` and get a passing (empty) test suite — the "containers" that will hold future logic.

## Features

1. Directory structure — `lisp/` and `test/` directories exist at the repo root with the canonical layout specified in the roadmap.
2. `.ejn-cache/` gitignored — the runtime cache directory is excluded from version control via `.gitignore`.
3. Eask file with pinned dependencies — `Eask` declares the package at version 0.1.0 and pins all runtime dependencies (`dash` ≥ 2.19.0, `s` ≥ 1.13.0, `f` ≥ 0.20.0, `jupyter` ≥ 0.8.0, `polymode` ≥ 0.2.2) and development dependencies (`buttercup`, `undercover`) to exact minimum versions.
4. Makefile with three targets — `make install` runs `eask install-deps`, `make test` runs `eask test buttercup`, `make lint` runs `eask lint package`.
5. Template source files — `ejn.el` (repo root), `lisp/ejn-core.el`, `lisp/ejn-network.el`, `lisp/ejn-lsp.el` each contain a package header, `require` statements, and a `provide` form; no logic.
6. Empty test suite — `test/ejn-test.el` loads without error and `make test` returns exit code 0.
7. README placeholder — `README.md` exists with project name and status.

## Out of scope

- Any runtime logic (cell parsing, LSP integration, kernel communication, output rendering, global undo).
- CI pipeline configuration (GitHub Actions or other). The Makefile targets exist but CI integration is deferred.
- `README.md` content beyond a one-line placeholder.
- Generated autoloads or compiled `.elc` files.
- Emacs version compatibility below 30.1.

## Architecture

### Data model

Not applicable in Phase 1. No data structures are defined.

### Interface contracts

Not applicable in Phase 1. No functions are exported.

### Tech stack

| Tool | Rationale |
| :--- | :--- |
| Eask | Standard build tool for Emacs packages; provides dependency management and test orchestration. |
| buttercup | BDD-style test framework for Emacs Lisp; the canonical choice for Eask projects. |
| undercover | Coverage measurement for Emacs Lisp test suites; included as a dev dependency for future use. |
| jupyter.el ≥ 0.8.0 | ZeroMQ-based kernel communication library; EJN's networking foundation. |
| dash ≥ 2.19.0 | Functional programming library for Emacs Lisp; provides lists, maps, and sequences. |
| s ≥ 1.13.0 | String manipulation library for Emacs Lisp. |
| f ≥ 0.20.0 | Filesystem utility library for Emacs Lisp. |
| polymode ≥ 0.2.2 | Multi-mode composition library for Emacs; required by later phases. |
| Emacs ≥ 30.1 | Minimum supported Emacs version. |

### Non-goals

- Phase 1 delivers scaffolding only. No functions, no data model, no I/O, no external communication.
- CI configuration is deferred; the Makefile targets are the only automation artifact.
- Generated autoloads (`-*-autogen.el`) are produced by later tooling, not created in this phase.

## Task list

### Phase 1 — Scaffolding & Environment

- [x] P1-T1 Create `lisp/` and `test/` directories [scaffold] (no code, directory setup)
- [x] P1-T2 Add `.ejn-cache/` to `.gitignore` [scaffold] (static config change)
- [x] P1-T3 Create `Eask` file with pinned dependencies [scaffold] (static config file)
- [x] P1-T4 Create `Makefile` with install, test, and lint targets [scaffold] (static config file)
- [x] P1-T5 Create `README.md` placeholder [scaffold] (no code, static content)
- [x] P1-T6 Create `ejn.el` skeleton at repo root (package header, requires, provide) [smoke] (structural — import path resolution; file will be loaded at runtime)
- [x] P1-T7 Create `lisp/ejn-core.el` skeleton (package header, provide) [smoke] (structural — import path resolution; file will be loaded at runtime)
- [x] P1-T8 Create `lisp/ejn-network.el` skeleton (package header, require, provide) [smoke] (structural — import path resolution; file will be loaded at runtime)
- [x] P1-T9 Create `lisp/ejn-lsp.el` skeleton (package header, require, provide) [smoke] (structural — import path resolution; file will be loaded at runtime)
- [x] P1-T10 Create `test/ejn-test.el` with empty buttercup test suite [smoke] (structural — test file must load and produce exit code 0)

## Open questions

- [x] Package root structure → repo root is the package root. `ejn.el` at repo root; supporting modules in `lisp/`.
- [x] Emacs minimum version → 30.1+.
- [x] Eask/Makefile placement → at repo root.
- [x] README.md content → minimal placeholder created in Phase 1.
- [x] `.ejn-cache/` in `.gitignore` → added.
- [x] Copyright / author info → leave GPL template as-is.
