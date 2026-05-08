# EJN Phased Roadmap

Version: 0.1  

---

# 1. Project Goals

EJN aims to provide a maintainable, extensible, Emacs-native notebook environment for Jupyter kernels.

Primary goals:

- structured notebook editing,
- asynchronous execution,
- notebook persistence,
- LSP integration,
- high responsiveness,
- keyboard-centric workflows,
- modular architecture.

---

# 2. Development Strategy

The project should be developed incrementally.

Each phase must:
- produce usable artifacts,
- stabilize APIs before expansion,
- minimize architectural coupling,
- preserve testability.

The roadmap intentionally separates:
- MVP functionality,
- production hardening,
- advanced future capabilities.

---

# Phase 0 — Architecture and Technical Design

# Goals

Define core architecture before implementation begins.

Prevent:
- UI/model coupling,
- synchronization dead ends,
- async execution bugs,
- LSP integration rewrites.

---

# Tasks

## Define notebook data model

Design:
- notebook structure,
- cell structure,
- outputs,
- metadata,
- execution state.

---

## Define rendering model

Decide:
- overlay usage,
- text property usage,
- incremental rendering strategy,
- output region handling.

---

## Define synchronization strategy

Specify:
- model ↔ buffer ownership,
- dirty tracking,
- transactional updates,
- undo semantics.

---

## Define async execution lifecycle

Design:
- request queueing,
- output routing,
- execution cancellation,
- kernel state transitions.

---

## Define extension interfaces

Specify APIs for:
- kernels,
- MIME renderers,
- LSP integrations,
- persistence backends.

---

# Deliverables

- architecture design document,
- subsystem diagrams,
- notebook state diagrams,
- synchronization strategy,
- extension API specifications.

---

# Finish Conditions

Architecture questions can be answered clearly for:
- state ownership,
- synchronization,
- rendering,
- async execution,
- LSP integration.

---

# Phase 1 — Foundation and Infrastructure

# Goals

Create a production-grade development environment.

---

# Tasks

## Repository setup

Configure:
- lexical binding,
- package metadata,
- autoload generation,
- package-lint compliance.

---

## Tooling

Setup:
- Eask,
- Makefile,
- lint pipeline.

---

## Testing infrastructure

Setup:
- ERT,
- integration test framework,
- fixture loading utilities.

---

## Logging and diagnostics

Implement:
- structured debug logging,
- execution tracing,
- profiling hooks.

---

## Compatibility policy

Define:
- supported Emacs versions,
- supported operating systems,
- treesit requirements.

Recommendation:
- Emacs 29+ only.

---

# Deliverables

- reproducible development environment,
- CI pipeline,
- linting pipeline,
- test harness,
- debug infrastructure.

---

# Finish Conditions

Project is:
- CI green,
- byte-compile clean,
- package-lint clean,
- reproducibly testable.

---

# Phase 2 — Notebook Model and Persistence

# Goals

Implement notebook engine independent of UI.

---

# Tasks

## Notebook object model

Implement:
- notebook structs,
- cell structs,
- metadata APIs,
- execution state tracking.

---

## `.ipynb` parsing

Support:
- nbformat v4,
- metadata preservation,
- unknown field round-tripping.

---

## Serialization

Implement:
- stable save/load,
- notebook normalization,
- schema validation.

---

## Dirty tracking

Implement:
- notebook dirty state,
- transactional updates,
- change tracking.

---

## Persistence abstraction

Design for future:
- autosave,
- remote notebooks,
- alternate backends.

---

# Deliverables

- notebook model APIs,
- serializer/deserializer,
- notebook fixtures,
- persistence layer.

---

# Finish Conditions

Notebook state can be:
- loaded,
- modified,
- serialized,
- diffed,

without UI involvement.

---

# Phase 3 — Buffer Projection and Cell Engine

# Goals

Render notebook models into editable Emacs buffers.

---

# Tasks

## Major mode

Create:
- `ejn-mode`,
- notebook-local state,
- command dispatch system.

---

## Projection renderer

Implement:
- notebook rendering,
- incremental updates,
- dirty-region rendering,
- output folding.

---

## Cell engine

Implement:
- insertion,
- deletion,
- split,
- merge,
- move,
- reorder.

---

## Navigation system

Implement:
- structural motion,
- cell indexing,
- stable region mapping.

---

## Undo integration

Ensure:
- coherent undo groups,
- transactional edits.

---

# Deliverables

- notebook editor UI,
- cell operations,
- navigation system,
- rendering engine.

---

# Finish Conditions

Notebook editing is:
- stable,
- predictable,
- performant on moderate notebook sizes.

---

# Phase 4 — Kernel Runtime Integration

# Goals

Implement asynchronous kernel execution.

---

# Tasks

## Kernel abstraction layer

Create:
- generic kernel interfaces,
- request lifecycle APIs,
- execution callbacks.

---

## Transport integration

Integrate with:
- `emacs-jupyter`.

Avoid implementing Jupyter transport directly.

---

## Async execution

Implement:
- request queueing,
- execution tracking,
- output streaming,
- cancellation.

---

## Output handling

Support:
- stdout,
- stderr,
- execute_result,
- display_data.

---

## Kernel lifecycle management

Implement:
- restart,
- reconnect,
- interrupt,
- dead kernel recovery.

---

# Deliverables

- async execution pipeline,
- kernel management,
- output routing system.

---

# Finish Conditions

Notebook execution:
- does not block Emacs,
- handles streaming outputs,
- survives kernel interruptions.

---

# Phase 5 — UX and Editing Ergonomics

# Goals

Refine notebook editing experience.

---

# Tasks

## Keybinding system

Implement:
- notebook command map,
- repeat-mode integration,
- discoverability improvements.

---

## Visual indicators

Add:
- execution indicators,
- cell headers,
- folding markers,
- kernel state display.

---

## Editing polish

Improve:
- motion consistency,
- command composability,
- minibuffer integration.

---

## Performance optimization

Profile:
- overlays,
- redisplay,
- scrolling,
- large outputs.

---

# Deliverables

- polished editing workflow,
- responsive rendering behavior,
- stable notebook interaction model.

---

# Finish Conditions

Large notebooks remain responsive during:
- editing,
- scrolling,
- execution.

---

# Phase 6 — LSP and Semantic Features

# Goals

Implement notebook-aware language intelligence.

---

# Tasks

## Virtual document system

Implement:
- notebook → virtual document mapping,
- incremental synchronization,
- position translation.

---

## LSP synchronization

Support:
- incremental updates,
- debounced sync,
- semantic region mapping.

---

## Diagnostics projection

Map:
- diagnostics,
- references,
- symbol locations,
- code actions,

back into notebook cells.

---

## Treesitter integration

Integrate:
- `python-ts-mode`,
- syntax-aware region handling.

---

## LSP backend integration

Support:
- `lsp-mode`,
- future `eglot` support.

Avoid hard dependency on a single LSP backend.

---

# Deliverables

- notebook-aware diagnostics,
- completion,
- hover,
- goto-definition,
- rename support.

---

# Finish Conditions

LSP features work reliably across multiple notebook cells.

---

# Phase 7 — Rich Output and MIME System

# Goals

Support extensible notebook output rendering.

---

# Tasks

## MIME registry

Implement pluggable handlers for:
- text,
- markdown,
- images,
- LaTeX.

---

## Output virtualization

Implement:
- truncation,
- lazy rendering,
- deferred expansion.

---

## Image handling

Support:
- PNG,
- SVG,
- caching,
- scaling.

---

## Markdown rendering

Integrate:
- markdown-mode,
- syntax highlighting.

---

# Deliverables

- extensible MIME rendering system,
- performant output rendering.

---

# Finish Conditions

Rich outputs remain usable and performant.

---

# Phase 8 — Ecosystem Integration

# Goals

Integrate EJN into standard Emacs workflows.

---

# Tasks

## Project integration

Support:
- project.el,
- dir-locals,
- virtual environments.

---

## Completion ecosystem

Integrate:
- CAPF,
- Corfu,
- Consult,
- Embark.

---

## Xref integration

Support:
- symbol navigation,
- references,
- jump stack integration.

---

## Command discoverability

Integrate:
- which-key,
- transient menus.

---

# Deliverables

- ecosystem-native integration layer,
- project-aware notebook behavior.

---

# Finish Conditions

EJN behaves like a first-class Emacs package.

---

# Phase 9 — Stability and Release Engineering

# Goals

Prepare for public release.

---

# Tasks

## Stress testing

Test:
- large notebooks,
- large outputs,
- kernel crashes,
- malformed notebooks.

---

## Memory profiling

Profile:
- overlays,
- markers,
- output retention.

---

## Cross-platform validation

Test:
- Linux,
- macOS,
- terminal Emacs,
- GUI Emacs.

---

## Packaging

Prepare:
- MELPA packaging,
- autoloads,
- user documentation,
- migration guides.

---

# Deliverables

- stable beta release,
- release process,
- benchmark results,
- installation documentation.

---

# Finish Conditions

Package is:
- maintainable,
- benchmarked,
- distributable.

---

# 3. MVP Definition

The MVP includes:

- notebook open/save,
- notebook editing,
- async Python execution,
- basic output rendering,
- notebook navigation,
- kernel lifecycle management,
- minimal LSP support.

The MVP excludes:

- collaborative editing,
- advanced HTML widgets,
- multi-user synchronization,
- notebook server management UI,
- full JupyterLab parity,
- advanced multi-language semantics.

---

# 4. Recommended Package Structure

```text
lisp/
├── ejn-core.el
├── ejn-model.el
├── ejn-cell.el
├── ejn-buffer.el
├── ejn-render.el
├── ejn-overlay.el
├── ejn-navigation.el
├── ejn-edit.el
├── ejn-execute.el
├── ejn-kernel.el
├── ejn-kernel-jupyter.el
├── ejn-transport.el
├── ejn-output.el
├── ejn-mime.el
├── ejn-lsp.el
├── ejn-virtual-document.el
├── ejn-sync.el
├── ejn-persistence.el
├── ejn-ipynb.el
├── ejn-session.el
├── ejn-project.el
├── ejn-debug.el
├── ejn-custom.el


---

# 5. Recommended Dependencies

# Required

- emacs-jupyter
- compat
- dash
- s
- f

---

# Optional

- lsp-mode
- eglot
- corfu
- consult
- embark
- transient
- markdown-mode

---

# 6. Technical Risks

# Overlay Explosion

Risk:
- redisplay slowdown.

Mitigation:
- minimize overlays,
- prefer text properties,
- reuse overlay objects.

---

# Async State Corruption

Risk:
- outputs routed to incorrect cells.

Mitigation:
- stable cell IDs,
- execution request IDs,
- execution version tracking.

---

# LSP Synchronization Complexity

Risk:
- unreliable diagnostics mapping.

Mitigation:
- virtual document abstraction,
- centralized position translation layer.

---

# UI/Model Coupling

Risk:
- difficult maintenance,
- rendering bugs.

Mitigation:
- model-first architecture,
- strict subsystem boundaries.

---

# MIME Rendering Complexity

Risk:
- HTML rendering instability.

Mitigation:
- narrow MVP MIME support,
- plugin renderer architecture.

---

# 7. Long-Term Future Directions

Potential future work:

- multi-language notebooks,
- collaborative editing,
- notebook diffing,
- Org interoperability,
- remote execution backends,
- notebook version history,
- advanced semantic notebooks,
- HTML widget support.

These are intentionally deferred until the core architecture stabilizes.
