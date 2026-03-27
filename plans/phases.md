Below is a dependency-ordered, multi-phase development plan for **Emacs-Jupyter-Notebook (EJN)**. Each phase produces a usable system, progressively converging toward a full notebook + LSP experience.

---

# Phase 1 — Core Buffer Model & Cell Navigation

## Goal

Establish the **minimal notebook abstraction inside Emacs**: a buffer with structured cells and navigation.

## Features / Functions

* Define core data model:

  * Cell types: `code`, `markdown`
  * Cell structure:

    * unique ID
    * type
    * content region
    * output region (initially empty placeholder)
* Buffer representation:

  * Use text properties or overlays to mark cell boundaries
  * Delimit cells with invisible markers or structured separators
* Basic navigation:

  * Move between cells
* Cell insertion:

  * Insert above/below
* Basic cell deletion

## Keybindings Activated

**Navigation**

* `C-<down>` → `ejn:worksheet-goto-next-input-km`
* `C-<up>` → `ejn:worksheet-goto-prev-input-km`
* `C-c C-n` → `ejn:worksheet-goto-next-input-km`
* `C-c C-p` → `ejn:worksheet-goto-prev-input-km`

**Cell creation / deletion**

* `C-c C-a` → `ejn:worksheet-insert-cell-above-km`
* `C-c C-b` → `ejn:worksheet-insert-cell-below-km`
* `C-c C-k` → `ejn:worksheet-kill-cell-km`

## Technical Considerations

* Prefer **overlays** over text properties for:

  * dynamic resizing
  * easier region management
* Maintain a **cell index cache** for O(1) navigation
* Define a major mode: `ejn-mode`
* Use a **gap-buffer friendly design** (avoid frequent full-buffer scans)

## Definition of Done

* User can:

  * Create a notebook buffer
  * Insert/delete cells
  * Navigate between cells reliably
* No kernel, no execution yet — but structurally stable

---

# Phase 2 — Cell Editing & Structural Transformations

## Goal

Enable **editing workflows similar to Jupyter**: splitting, merging, reordering, and typing cells.

## Features / Functions

* Cell splitting at point
* Cell merging
* Move cells up/down
* Copy/yank cells (internal clipboard)
* Change/toggle cell type (code ↔ markdown)

## Keybindings Activated

**Cell structure**

* `C-c C-s` → `ejn:worksheet-split-cell-at-point-km`
* `C-c RET` → `ejn:worksheet-merge-cell-km`

**Cell movement**

* `C-c <down>` → `ejn:worksheet-move-cell-down-km`
* `C-c <up>` → `ejn:worksheet-move-cell-up-km`
* `M-<down>` → `ejn:worksheet-not-move-cell-down-km`
* `M-<up>` → `ejn:worksheet-not-move-cell-up-km`

**Copy/paste**

* `C-c C-w`, `C-c M-w` → `ejn:worksheet-copy-cell-km`
* `C-c C-y` → `ejn:worksheet-yank-cell-km`

**Cell typing**

* `C-c C-t` → `ejn:worksheet-toggle-cell-type-km`
* `C-c C-u` → `ejn:worksheet-change-cell-type-km`

## Technical Considerations

* Cell operations must:

  * preserve overlays correctly
  * maintain stable IDs
* Introduce **transaction-like updates** to avoid corruption
* Abstract operations into:

  * `ejn-cell-*` API layer

## Definition of Done

* All structural edits work without breaking buffer integrity
* Copy/paste preserves full cell state
* Markdown/code toggling works correctly

---

# Phase 3 — Notebook Persistence (File I/O)

## Goal

Enable **loading and saving `.ipynb` files**, making EJN practically usable.

## Features / Functions

* Open notebook file
* Save notebook
* Rename notebook
* JSON parsing/serialization (`nbformat`)
* Map between:

  * JSON cells ↔ internal cell model

## Keybindings Activated

**File operations**

* `C-c C-o` → `ejn:notebook-open-km`
* `C-c C-f` → `ejn:file-open-km`
* `C-x C-s` → `ejn:notebook-save-notebook-command-km`
* `C-x C-w` → `ejn:notebook-rename-command-km`

## Technical Considerations

* Use Emacs JSON library (`json-parse-buffer`)
* Preserve:

  * metadata
  * execution counts (even if unused yet)
* Normalize line endings and encoding (UTF-8)

## Definition of Done

* Can open/save real `.ipynb` files
* Round-trip integrity: no data loss
* Notebook usable across sessions

---

# Phase 4 — Kernel Integration (Execution MVP)

## Goal

Introduce **basic Jupyter kernel communication** for executing code cells.

## Features / Functions

* Start kernel process
* Execute single cell
* Display plain-text output
* Maintain execution order counter

## Keybindings Activated

**Execution**

* `C-c C-c` → `ejn:worksheet-execute-cell-km`
* `M-RET` → `ejn:worksheet-execute-cell-and-goto-next-km`

## Technical Considerations

* Implement **Jupyter messaging protocol**:

  * ZeroMQ or reuse existing Emacs Jupyter libraries if possible
* Async handling:

  * execution must not block Emacs
* Output handling:

  * initially support `stdout` only

## Definition of Done

* User can:

  * run a Python cell
  * see output inline
* Kernel lifecycle minimal but functional

---

# Phase 5 — Execution Workflow Enhancements

## Goal

Match **core notebook ergonomics** (multi-cell execution, insertion, output control).

## Features / Functions

* Execute all cells
* Execute + insert below
* Output visibility toggle
* Clear output (cell/all)

## Keybindings Activated

**Execution workflows**

* `M-S-<return>` → `ejn:worksheet-execute-cell-and-insert-below-km`
* `C-u C-c C-c` → `ejn:worksheet-execute-all-cells`

**Output control**

* `C-c C-e` → `ejn:worksheet-toggle-output-km`
* `C-c C-l` → `ejn:worksheet-clear-output-km`
* `C-c C-S-l` → `ejn:worksheet-clear-all-output-km`
* `C-c C-v` → `ejn:worksheet-set-output-visibility-all-km`

## Technical Considerations

* Maintain **output overlays separate from input overlays**
* Ensure idempotent execution (clear + re-render)
* Batch execution must queue requests properly

## Definition of Done

* Notebook behaves like Jupyter for execution flow
* Output management is stable and predictable

---

# Phase 6 — Kernel Lifecycle Management

## Goal

Provide **robust kernel control**, essential for real-world usage.

## Features / Functions

* Interrupt kernel
* Restart kernel
* Reconnect session
* Kill kernel and close notebook

## Keybindings Activated

**Kernel control**

* `C-c C-z` → `ejn:notebook-kernel-interrupt-command-km`
* `C-c C-x C-r` → `ejn:notebook-restart-session-command-km`
* `C-c C-r` → `ejn:notebook-reconnect-session-command-km`
* `C-c C-q` → `ejn:notebook-kill-kernel-then-close-command-km`

## Technical Considerations

* Handle:

  * zombie processes
  * broken sockets
* Maintain kernel state machine:

  * `starting → idle → busy → dead`
* Reconnect must rebind buffers safely

## Definition of Done

* Kernel failures are recoverable
* No orphaned processes
* Session lifecycle is predictable

---

# Phase 7 — LSP Integration (Code Intelligence)

## Goal

Enable **language intelligence across cells** via LSP.

## Features / Functions

* Integrate with `lsp-mode` or `eglot`
* Treat notebook as a **virtual concatenated document**
* Support:

  * completion
  * diagnostics
  * jump-to-definition
  * jump-back

## Keybindings Activated

**LSP navigation**

* `M-.` → `ejn:pytools-jump-to-source-command`
* `M-,` → `ejn:pytools-jump-back-command`

## Technical Considerations

* Core challenge: **multi-cell document mapping**

  * Map cell regions → virtual file offsets
* Maintain sync on:

  * edits
  * cell reorder
* Use incremental sync where possible

## Definition of Done

* LSP features work across cells seamlessly
* Jump-to-definition works even across cell boundaries

---

# Phase 8 — Rich Output & UI Enhancements

## Goal

Improve **visual fidelity and usability**, approaching Jupyter UX.

## Features / Functions

* Render:

  * images (base64)
  * HTML outputs
* Toggle code visibility from output
* Shared output navigation
* Basic toolbar

## Keybindings Activated

**UI / output inspection**

* `C-c C-;` → `ejn:shared-output-show-code-cell-at-point-km`
* `C-c C-$` → `ejn:tb-show-km`

## Technical Considerations

* Use:

  * `shr` for HTML rendering
  * image display APIs
* Sandbox HTML rendering (security)
* Cache rendered outputs

## Definition of Done

* Rich outputs display correctly
* User can navigate between output and source

---

# Phase 9 — Notebook UX Completion & Utilities

## Goal

Finalize **usability features and polish**.

## Features / Functions

* Scratch notebook
* Close notebook buffer
* Multi-notebook support
* Session isolation

## Keybindings Activated

**Notebook management**

* `C-c C-/` → `ejn:notebook-scratchsheet-open-km`
* `C-c C-#` → `ejn:notebook-close-km`

## Technical Considerations

* Namespace isolation per notebook
* Resource cleanup on close
* Support multiple kernels simultaneously

## Definition of Done

* Multiple notebooks can run concurrently
* Scratch workflow works
* Clean shutdown without leaks

---

# Final Remarks

This plan enforces:

* **Progressive usability** (each phase is shippable)
* **Strict dependency ordering** (data model → execution → intelligence)
* **Separation of concerns**:

  * buffer model
  * execution engine
  * LSP layer
