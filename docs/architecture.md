# Product Requirements Specification (PRS)

## Emacs Jupyter Notebook (EJN)

### Version 1.0 (Draft)

---

# 1. Executive Summary

## Product Name

**Emacs Jupyter Notebook (EJN)**

## Product Vision

EJN is a next-generation notebook environment for Emacs that combines the reproducibility and interoperability of the Jupyter ecosystem with the efficiency, extensibility, and editing experience of Emacs.

EJN is designed for developers, researchers, data scientists, educators, and technical writers who prefer keyboard-driven workflows and expect IDE-quality language features without sacrificing the flexibility of plain text editing.

Unlike browser-based notebook interfaces, EJN treats notebooks as structured documents within the Emacs environment, enabling seamless integration with existing Emacs packages and workflows while remaining fully functional in both graphical and terminal environments.

---

# 2. Product Goals

## Primary Goals

* Deliver a first-class notebook experience entirely within Emacs.
* Preserve native Emacs editing behavior.
* Provide responsive execution of Jupyter kernels.
* Offer IDE-quality language intelligence through pluggable providers.
* Maintain full usability in both GUI and terminal modes.
* Scale efficiently to large notebooks.
* Enable a rich extension ecosystem.

## Secondary Goals

* Provide a version-control-friendly notebook format.
* Support multiple programming languages.
* Integrate naturally with the broader Emacs ecosystem.
* Minimize external dependencies.

## Non-Goals (Initial Release)

* Browser-based collaboration.
* Real-time multi-user editing.
* Notebook server management.
* Visual drag-and-drop editing.
* Widget authoring.
* Cloud-hosted notebook synchronization.

---

# 3. Target Users

## Primary Personas

### Software Engineers

Requirements:

* Fast editing.
* Language Server Protocol integration.
* Version control.
* Multi-language support.
* Keyboard-only workflows.

---

### Data Scientists

Requirements:

* Interactive execution.
* Rich output.
* Plot visualization.
* Notebook interoperability.
* Efficient navigation.

---

### Researchers

Requirements:

* Reproducibility.
* Literate programming.
* Long-form notebook editing.
* Export capabilities.

---

### Emacs Power Users

Requirements:

* Native keybindings.
* Compatibility with existing packages.
* Full customization.
* Terminal support.
* Scriptability.

---

# 4. User Experience Principles

## P1. Emacs First

Users should never feel they are operating a web application embedded inside Emacs.

---

## P2. Keyboard First

Every feature must be accessible without a mouse.

Mouse interaction is optional.

---

## P3. Plain Text Editing

Notebook editing should feel indistinguishable from editing any other structured text buffer.

---

## P4. Progressive Enhancement

GUI-only features must have meaningful terminal alternatives.

---

## P5. Minimal Visual Noise

Visual elements should communicate notebook structure without overwhelming the editing experience.

---

## P6. Predictable Behavior

Commands should behave consistently across notebooks, kernels, and programming languages.

---

# 5. Core User Stories

## Notebook Lifecycle

As a user I want to:

* Create notebooks.
* Open existing notebooks.
* Save notebooks.
* Save As.
* Export notebooks.
* Import notebooks.
* Rename notebooks.
* Close notebooks safely.

---

## Cell Management

As a user I want to:

* Insert cells.
* Delete cells.
* Split cells.
* Merge cells.
* Duplicate cells.
* Move cells.
* Convert between code and markdown.
* Collapse and expand cells.
* Select cells efficiently.

---

## Editing

As a user I want to:

* Edit normally using standard Emacs commands.
* Use keyboard macros.
* Perform query-replace.
* Use multiple cursors.
* Use rectangle editing.
* Use incremental search.
* Edit without artificial notebook restrictions.

---

## Execution

As a user I want to:

* Execute current cell.
* Execute and advance.
* Execute selected cells.
* Execute all cells.
* Interrupt execution.
* Restart kernel.
* Restart and execute all.
* Monitor execution progress.

---

## Output

As a user I want to:

* View textual output.
* View images.
* View formatted tables.
* View HTML output.
* Fold large outputs.
* Clear outputs.
* Clear selected outputs.
* Export outputs.

---

## Navigation

As a user I want to:

* Jump between cells.
* Jump between markdown sections.
* Jump between errors.
* Jump between outputs.
* Navigate execution history.
* Navigate edit history.
* Navigate notebook outline.

---

## Language Intelligence

As a user I want to:

* Completion.
* Hover documentation.
* Diagnostics.
* Signature help.
* Rename symbols.
* Find references.
* Semantic highlighting (when available).

---

## Search

As a user I want to search:

* Notebook text.
* Code only.
* Markdown only.
* Outputs.
* Symbols.
* Diagnostics.

---

## Notebook Organization

As a user I want to:

* Fold sections.
* Fold outputs.
* Collapse markdown.
* View notebook outline.
* Bookmark cells.
* Reorder sections.

---

# 6. Functional Requirements

## Notebook Management

The system shall:

* Open multiple notebooks simultaneously.
* Support independent kernel sessions.
* Recover from kernel restarts.
* Detect unsaved modifications.
* Preserve notebook metadata.

---

## Editing

The system shall:

* Preserve ordinary Emacs editing behavior.
* Synchronize edits incrementally.
* Maintain stable cell identities.
* Support unlimited notebook size subject to system resources.

---

## Execution

The system shall:

* Execute asynchronously.
* Queue execution requests.
* Stream outputs.
* Associate outputs with the originating cell.
* Report execution status.

---

## Rendering

The system shall:

* Display notebook cells clearly.
* Render outputs incrementally.
* Render markdown.
* Support rich MIME outputs.
* Virtualize off-screen outputs.

---

## Language Services

The system shall:

* Provide completion.
* Display diagnostics.
* Display hover information.
* Synchronize virtual documents.
* Support pluggable language providers.

---

## Persistence

The system shall:

* Read and write `.ipynb`.
* Read and write `.ejn`.
* Preserve notebook metadata.
* Preserve execution outputs when requested.

---

## Terminal Compatibility

The system shall:

* Operate fully under `emacs -nw`.
* Replace graphical elements with textual equivalents where necessary.
* Avoid mandatory GUI dependencies.

---

# 7. Non-Functional Requirements

## Performance

Opening notebooks shall remain responsive.

Editing latency should remain effectively constant for localized edits.

Execution should never block the editor UI.

Scrolling should remain smooth regardless of notebook size.

---

## Reliability

Kernel failures must not corrupt notebook state.

Unexpected process termination must be recoverable.

Notebook saves should be atomic whenever practical.

---

## Extensibility

New:

* kernels
* serializers
* language providers
* MIME renderers
* commands

shall be installable without modifying the core package.

---

## Accessibility

All functionality shall be keyboard accessible.

Visual indicators shall have textual equivalents.

---

## Portability

Support:

* GNU/Linux
* macOS
* Windows

Support both graphical and terminal Emacs.

---

# 8. Command Philosophy

Every major notebook operation shall be available through:

* Interactive command.
* Keybinding.
* `transient` menu.
* Lisp API.

---

# 9. Configuration Philosophy

Reasonable defaults.

Extensive customization through standard Emacs customization facilities.

Configuration should be declarative rather than requiring advice or monkey-patching.

---

# 10. Success Metrics

## Usability

A proficient Emacs user should be able to create, edit, execute, and navigate notebooks without learning a new editing model.

---

## Performance

Localized edits should not exhibit latency proportional to notebook size.

Notebook scrolling should remain responsive even with large outputs.

---

## Compatibility

All primary workflows should function identically in GUI and terminal environments, except where graphical rendering is inherently unavailable.

---

## Extensibility

New language providers, serializers, and output renderers should integrate through documented extension points without requiring changes to the core.

---

# 11. Release Scope

## Version 1.0

Included:

* Notebook editing.
* Cell management.
* Jupyter execution.
* Asynchronous scheduler.
* Output rendering.
* Markdown cells.
* `lsp-mode` integration.
* `.ipynb` support.
* `.ejn` support.
* Terminal compatibility.
* Plugin architecture.
* Incremental synchronization.
* Viewport-aware rendering.

Deferred:

* Debug Adapter Protocol integration.
* Collaborative editing.
* Notebook widgets (Comms).
* Remote notebook browser.
* Variable explorer.
* Dataframe viewer.
* Interactive plotting panes.

---

# 12. Acceptance Criteria

The product will be considered ready for Version 1.0 when:

1. Users can edit notebooks using standard Emacs editing commands without restriction.
2. Code execution is asynchronous and non-blocking.
3. Output rendering remains responsive for large notebooks.
4. Language intelligence functions within notebook cells.
5. `.ipynb` notebooks round-trip without data loss for supported features.
6. `.ejn` notebooks provide a human-readable, version-control-friendly representation.
7. All core workflows operate in both GUI and terminal Emacs.
8. Public extension points are documented and stable.
9. Core architectural invariants defined in the Architecture Specification are preserved.
10. Performance and correctness tests meet the project's quality thresholds.
