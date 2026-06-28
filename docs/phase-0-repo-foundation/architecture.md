# Architecture — phase-0-repo-foundation

## Overview
Phase 0 establishes the complete repository foundation for EJN (Emacs Jupyter Notebook). It creates the full directory skeleton for all planned modules, the build system, CI pipeline, package metadata, and developer onboarding infrastructure. No production Elisp logic is implemented — only scaffolding that enables Phase 1+ to proceed.

## Components
| Component | Responsibility | Tech |
|---|---|---|
| `eln/` | Source root for all Elisp modules | Emacs Lisp |
| `eln/core/` | Core utilities, error hierarchy, config groups | Elisp |
| `eln/model/` | Notebook, cell, output domain model | Elisp |
| `eln/transactions/` | Transaction engine, commit pipeline | Elisp |
| `eln/events/` | Event bus, subscriptions, change tracking | Elisp |
| `eln/sync/` | Incremental buffer-to-model synchronization | Elisp |
| `eln/backend/` | Backend abstraction, Jupyter implementation | Elisp |
| `eln/scheduler/` | Execution queue, async scheduling | Elisp |
| `eln/render/` | Render planner, overlay management | Elisp |
| `eln/lang/` | Language intelligence, LSP integration | Elisp |
| `eln/serializer/` | .ipynb and .ejn serializers | Elisp |
| `eln/ui/` | Transient menus, mode, commands | Elisp |
| `eln/plugin/` | Plugin framework, service registry | Elisp |
| `test/` | Test suites (unit, contract, integration, perf) | ERT |
| `test/helpers/` | Test builders, fixtures, mocks | ERT |
| `scripts/` | Developer scripts (benchmarks, validation) | Shell/Elisp |
| `docs/` | Product docs (PRS, roadmap, test strategy) | Markdown |
| `.github/workflows/` | CI pipelines | GitHub Actions |
| `Makefile` | Build orchestration | Make |

## Data flow
Phase 0 has no runtime data flow. The architecture establishes the static directory layout and build pipeline:

```
Source (eln/)  →  Make (compile/lint/test)  →  GitHub Actions (CI)
Test (test/)   →  Make (test)               →  GitHub Actions (CI)
```

## Data model
N/A — Phase 0 creates no domain types. Module directories are pre-created per the roadmap's dependency graph.

## External dependencies
- `emacs-jupyter` — Jupyter messaging protocol (referenced from `/home/kyohei/Projects/jupyter/`)
- `use-package` — Dependency management for development
- `elint` — Built-in Elisp linter
- `ert` — Emacs regression testing framework (built-in)
- `transient` — Command menus (runtime dep, declared but not used in Phase 0)
- `lsp-mode` — LSP client (runtime dep, declared but not used in Phase 0)

## Key decisions & trade-offs
- **Decision:** Full skeleton in Phase 0 — Why: Enables parallel Phase 3+ development immediately — Alternatives: incremental per-phase (slower parallel work)
- **Decision:** Make + use-package — Why: Simple, well-known, no extra tooling to learn — Alternatives: a.el (more modern but less established)
- **Decision:** Emacs 30+ only — Why: Modern Elisp features, smaller compatibility surface — Alternatives: support Emacs 28 (broader compat, more boilerplate)
- **Decision:** elint only (no package-lint) — Why: Minimal linting, elint is built-in — Alternatives: add package-lint (more thorough but external dep)
- **Decision:** Skip GitHub issue/PR templates — Why: Not critical for development infrastructure — Alternatives: include templates (better for open source later)

## Open questions
- Should `.ejn` serializer format be defined before Phase 10?
- Should the `eln/` root file (`ejn.el`) contain the package header, or each module file?
