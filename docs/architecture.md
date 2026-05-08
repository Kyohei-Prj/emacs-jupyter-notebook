# EJN Architecture Design Document

Version: 0.1  
Target Emacs Version: 29+  
Primary Language: Emacs Lisp (lexical-binding enabled)

---

# 1. Overview

EJN (Emacs Jupyter Notebook) is an Emacs-native notebook environment for Jupyter kernels.

The project aims to provide:

- notebook-style editing,
- asynchronous code execution,
- notebook persistence,
- LSP integration,
- rich outputs,
- keyboard-centric workflows,
- and extensible multi-language architecture,

while remaining idiomatic to Emacs.

EJN is not intended to replicate JupyterLab fully.

The primary design goal is:

> Structured notebook editing optimized for Emacs workflows.

---

# 2. Architectural Principles

## 2.1 Emacs-First Design

EJN should behave like a native Emacs editing environment.

Avoid:
- browser-like UI paradigms,
- mouse-centric interaction,
- excessive widget usage,
- heavyweight embedded HTML rendering.

Prefer:
- standard buffer editing,
- composable commands,
- xref integration,
- CAPF completion,
- repeat-mode compatibility,
- project.el integration.

---

## 2.2 Model-First Architecture

The notebook model is the authoritative source of truth.

Buffers are projections of notebook state.

```text
Notebook Model
    ↓
Projection Renderer
    ↓
Editable Notebook Buffer
```

The UI must never own notebook state directly.

This separation prevents:
- rendering synchronization bugs,
- state corruption,
- execution mismatches,
- persistence inconsistencies.

---

## 2.3 Async-by-Default

Kernel communication must never block Emacs.

All kernel interactions should be asynchronous:
- execution,
- completion,
- inspection,
- interrupts,
- diagnostics.

---

## 2.4 Extensibility

EJN should support:
- multiple kernels,
- future language integrations,
- alternate renderers,
- output plugins,
- notebook backends,
- alternate synchronization strategies.

Core abstractions must remain kernel-agnostic.

---

## 2.5 Stable Cell Identity

Each cell must have a stable internal ID independent of:
- position,
- rendering,
- buffer markers,
- overlays.

Stable IDs are required for:
- diagnostics,
- async execution mapping,
- output synchronization,
- LSP integration,
- undo consistency.

---

# 3. High-Level Architecture

```text
+------------------------------------------------------+
|                    UI Layer                          |
|------------------------------------------------------|
| Notebook Buffer | Output Views | Header Line         |
+------------------------------------------------------+
|               Interaction Layer                      |
|------------------------------------------------------|
| Commands | Navigation | Editing | Execution          |
+------------------------------------------------------+
|                Projection Layer                      |
|------------------------------------------------------|
| Incremental Rendering | Dirty Regions | Folding      |
+------------------------------------------------------+
|                 Notebook Model                       |
|------------------------------------------------------|
| Notebook | Cells | Outputs | Metadata | State        |
+------------------------------------------------------+
|             Synchronization Layer                    |
|------------------------------------------------------|
| Buffer ↔ Model Sync | Change Tracking                |
+------------------------------------------------------+
|                 LSP Layer                            |
|------------------------------------------------------|
| Virtual Docs | Position Mapping | Diagnostics        |
+------------------------------------------------------+
|               Kernel Abstraction                     |
|------------------------------------------------------|
| Execute | Complete | Inspect | Interrupt             |
+------------------------------------------------------+
|               Transport Layer                        |
|------------------------------------------------------|
| Jupyter Protocol | Async Messaging | Sessions        |
+------------------------------------------------------+
|               Persistence Layer                      |
|------------------------------------------------------|
| .ipynb Reader/Writer | Serialization                 |
+------------------------------------------------------+
```

---

# 4. Core Subsystems

# 4.1 Notebook Model

## Responsibilities

- notebook state management,
- cell storage,
- metadata storage,
- execution state tracking,
- output storage,
- dirty tracking.

## Requirements

- independent of UI,
- independent of kernel implementation,
- serializable,
- testable without buffers.

## Recommended Representation

Use `cl-defstruct`.

Example:

```elisp
(cl-defstruct ejn-cell
  id
  type
  source
  outputs
  metadata
  execution-count)
```

Avoid:
- deeply nested alists,
- direct JSON-shaped runtime structures.

---

# 4.2 Projection Renderer

## Responsibilities

- rendering notebook state into buffers,
- incremental updates,
- output folding,
- region updates,
- execution decorations.

## Design Requirements

Must support:
- partial re-rendering,
- stable markers,
- efficient redisplay,
- large notebooks.

## Rendering Strategy

### Recommended

Use:
- text properties for structure,
- overlays for transient UI state,
- markers for synchronization anchors.

### Avoid

- widget.el as a core dependency,
- overlay-heavy architectures,
- full-buffer redraws.

---

# 4.3 Cell Engine

## Responsibilities

- cell movement,
- split/merge,
- insertion/deletion,
- region mapping,
- structural navigation.

## Requirements

Operations must be:
- model-first,
- transactional,
- undo-safe.

---

# 4.4 Kernel Layer

## Responsibilities

- execution,
- completion,
- inspection,
- interrupts,
- kernel lifecycle management.

## Recommendation

Reuse `emacs-jupyter` transport abstractions where possible. :contentReference[oaicite:0]{index=0}

Do not implement the Jupyter protocol from scratch.

The Jupyter messaging protocol is complex and already well supported by existing packages. :contentReference[oaicite:1]{index=1}

---

## Kernel Abstraction API

Example:

```elisp
(cl-defgeneric ejn-kernel-execute (kernel code callbacks))
(cl-defgeneric ejn-kernel-complete (kernel code position))
(cl-defgeneric ejn-kernel-inspect (kernel code position))
(cl-defgeneric ejn-kernel-interrupt (kernel))
```

The notebook UI must never depend on transport details.

---

# 4.5 Synchronization Layer

## Responsibilities

- buffer ↔ model synchronization,
- dirty region tracking,
- incremental updates,
- execution mapping.

## Key Requirement

Synchronization logic must be centralized.

Avoid:
- scattered mutation logic,
- direct buffer mutations bypassing synchronization.

---

# 4.6 LSP Integration Layer

## Design Principle

Do NOT run LSP directly on notebook buffers.

Instead:
- generate virtual documents,
- synchronize notebook cells into shadow documents.

This follows the same architectural approach used by JupyterLab virtual documents. :contentReference[oaicite:2]{index=2}

---

## Responsibilities

- virtual document generation,
- position translation,
- diagnostics mapping,
- symbol navigation,
- semantic synchronization.

---

## Virtual Document Mapping

```text
Notebook Cells
    ↓
Virtual Python Document
    ↓
LSP Server
    ↓
Mapped Diagnostics
    ↓
Notebook Cell Overlays
```

---

# 4.7 Persistence Layer

## Responsibilities

- `.ipynb` parsing,
- serialization,
- metadata round-tripping,
- autosave support.

## Requirements

Must preserve:
- unknown metadata,
- cell IDs,
- MIME bundles,
- notebook structure.

Lossless round-tripping is required.

---

# 5. Buffer Architecture

# 5.1 Notebook Buffer

Major mode:
- `ejn-mode`

Responsibilities:
- notebook editing,
- navigation,
- execution interaction.

---

# 5.2 Output Rendering

Outputs should not be inserted as raw mutable text.

Recommended:
- managed output regions,
- output overlays,
- read-only properties.

---

# 5.3 Folding

Use invisible text properties rather than deleting output text.

---

# 5.4 Header Line

Recommended features:
- kernel state,
- execution status,
- notebook dirty state,
- active cell information.

---

# 6. Async Execution Model

# 6.1 Execution Lifecycle

```text
Execute Request
    ↓
Kernel Queue
    ↓
Async Message Stream
    ↓
Output Routing
    ↓
Cell Output Update
    ↓
Execution Completion
```

---

# 6.2 Output Routing

Outputs must be associated using:
- execution request IDs,
- stable cell IDs,
- execution versions.

This prevents stale outputs appearing in incorrect cells.

---

# 6.3 Streaming Outputs

Support:
- stdout,
- stderr,
- display_data,
- execute_result.

Outputs should stream incrementally.

---

# 7. Output Rendering Strategy

# Supported MVP MIME Types

- text/plain
- text/markdown
- image/png
- image/svg+xml

Delay:
- HTML widgets,
- JavaScript execution,
- rich interactive HTML.

---

# MIME Registry

Use pluggable handlers:

```elisp
(ejn-register-mime-handler
 "image/png"
 #'ejn-render-png)
```

---

# 8. Performance Strategy

# 8.1 Rendering

Avoid:
- full-buffer redraws,
- excessive overlays,
- synchronous rendering.

Prefer:
- incremental rendering,
- dirty-region updates,
- overlay reuse.

---

# 8.2 Large Outputs

Implement:
- truncation,
- lazy expansion,
- deferred rendering.

---

# 8.3 Large Notebooks

Target:
- 1000+ cell responsiveness.

---

# 9. Dependency Strategy

# Core Dependencies

## Strongly Recommended

- emacs-jupyter
- compat
- dash
- s
- f

---

## Optional Integrations

- lsp-mode
- eglot
- corfu
- consult
- embark
- markdown-mode
- transient

---

## Avoid as Core Dependencies

- polymode
- widget.el

These significantly increase complexity and maintenance burden.

---

# 10. Existing Ecosystem Analysis

# 10.1 emacs-jupyter

## Reuse

- kernel transport,
- protocol handling,
- completion patterns,
- server integration concepts.

## Avoid

- tight coupling to REPL assumptions.

---

# 10.2 code-cells.el

## Reuse

- navigation concepts,
- lightweight editing model,
- keyboard workflow philosophy.

## Avoid

- script-conversion-centered architecture.

---

# 10.3 EIN

## Learn From

- notebook UX,
- feature surface,
- execution semantics.

## Avoid

- monolithic architecture,
- tightly coupled UI/kernel logic,
- excessive mutable state.

---

# 11. Testing Architecture

# Unit Tests

Use ERT for:
- model logic,
- serialization,
- synchronization,
- diffing,
- cell operations.

---

# Integration Tests

Test:
- kernel execution,
- async messaging,
- output rendering.

Use notebook fixtures.

---

# UI Regression Tests

Add:
- rendering snapshots,
- overlay consistency tests,
- folding tests.

---

# Performance Tests

Benchmark:
- render latency,
- output insertion,
- notebook loading,
- scrolling.

---

# 12. Error Handling

# Kernel Failures

Support:
- reconnect,
- restart,
- interrupt,
- dead kernel detection.

---

# Serialization Failures

Gracefully handle:
- corrupted notebooks,
- unsupported MIME types,
- malformed metadata.

---

# 13. Security Considerations

EJN must not:
- automatically execute notebook code on open,
- evaluate arbitrary HTML/JS outputs,
- trust notebook metadata implicitly.

Notebook trust should be explicit.

---

# 14. Future Extensions

Potential future support:
- multi-language notebooks,
- collaborative editing,
- remote notebook servers,
- notebook diffing,
- notebook version history,
- Org interoperability,
- HTML widget rendering.

These are explicitly out of MVP scope.

---

# 15. MVP Scope

The MVP includes:

- open/save `.ipynb`,
- notebook editing,
- async Python execution,
- output rendering,
- basic MIME support,
- notebook navigation,
- kernel lifecycle management,
- basic completion,
- minimal LSP integration.

The MVP excludes:
- collaborative editing,
- HTML widgets,
- notebook server UI,
- advanced multi-language support,
- JupyterLab feature parity.

---

# 16. Success Criteria

EJN succeeds if it provides:

- reliable notebook editing,
- responsive async execution,
- stable notebook persistence,
- maintainable architecture,
- extensible subsystem boundaries,
- and native-feeling Emacs workflows.
