# EJN Phase 0 — Design Specifications

Version: 0.1  

---

## 1. State Ownership

### Principle

The notebook model is the single authoritative source of truth for all notebook state. The Emacs buffer is a _projection_ — a rendered view — of that model. Model mutations are restricted to three authorized paths:

1. **Sync layer** (`ejn-sync.el`): buffer edits → model updates (debounced, via `ejn--perform-sync`)
2. **Cell engine** (`ejn-cell-engine.el`): user commands → `ejn-with-undo-group` → model mutations + re-render
3. **Execution callbacks** (`ejn-execute.el`): kernel messages → model updates (outputs, state)

### Ownership Table

| State | Owner | Access Pattern |
|---|---|---|
| Cell source text | `ejn-notebook` model | Read by renderer; written only via sync layer |
| Cell outputs | `ejn-notebook` model | Written by output router; read by renderer |
| Execution count | `ejn-cell` struct | Written by kernel callback; never by UI |
| Buffer text | Emacs buffer | Managed by renderer; read by sync layer for change detection |
| Dirty cell set | `ejn-dirty-tracker` | Set by sync layer; consumed by renderer |
| Kernel state | `ejn-kernel` | Owned by kernel layer; exposed via callbacks |
| Execution queue | `ejn-executor` | Owned by executor; never shared with UI |
| LSP virtual doc | `ejn-virtual-document` | Generated from model; never written back to model |

### Forbidden Patterns

- Buffer text must never be treated as the notebook source — it is a rendering artifact.
- Subsystems outside the three authorized paths (sync layer, cell engine, execution callbacks) must never mutate the model directly.
- Kernel callbacks must never modify buffer text directly; they deliver results to the output router, which updates the model, which triggers re-rendering.

### Authorized Mutation Paths

| Path | Module | Mechanism | Undo-safe |
|---|---|---|---|
| Sync layer | `ejn-sync.el` | `ejn--perform-sync` (debounced) | Yes (transactional) |
| Cell engine | `ejn-cell-engine.el` | `ejn-with-undo-group` (wraps `ejn-with-transaction`) | Yes |
| Execution callbacks | `ejn-execute.el` | Direct model-level API calls | No (streaming) |

Execution callbacks bypass the transaction layer for performance reasons — streaming outputs arrive at high frequency and each would be expensive to snapshot. They use model-level setter APIs directly. Because these mutations are append-only (adding outputs, advancing state), undo is not supported for partial execution output.

---

## 2. Synchronization Strategy

### Change Detection

The sync layer uses `after-change-functions` to detect edits in the notebook buffer. On each change:

1. Identify the affected cell by position using the cell region index.
2. Extract the new source text from the buffer region.
3. Mark the cell dirty in `ejn-dirty-tracker`.
4. Schedule a debounced model update (default: 200ms idle).

### Transactional Updates

The sync layer groups model mutations into transactions:

```elisp
(ejn-with-transaction notebook
  (ejn-cell-set-source cell new-source)
  (ejn-notebook-mark-dirty notebook cell))
```

UI commands use `ejn-with-undo-group`, which wraps `ejn-with-transaction` and establishes an undo boundary:

```elisp
(ejn-with-undo-group "Insert cell"
  (ejn-cell-engine-insert notebook :after current-cell))
```

A transaction records a before/after snapshot for undo purposes. Transactions must be atomic — partial updates are never committed. Execution callbacks bypass transactions for performance, mutating the model directly via model-level setter APIs.

### Undo Semantics

Each user-visible operation (insert cell, delete cell, type in cell, execute) corresponds to one undo group. The undo group boundary is set before the operation begins and closed after the model update is committed.

```elisp
(ejn-with-undo-group "Insert cell"
  (ejn-cell-engine-insert notebook :after current-cell))
```

Buffer undo entries that fall within a managed transaction are suppressed; the model transaction is the canonical undo record.

### Re-rendering

After a model update, the renderer is notified of the dirty cell set. It performs an incremental update — only the affected cell regions are redrawn. Full-buffer redraws are prohibited except on initial notebook load.

```
model update
  → dirty-tracker marks cell
    → renderer reads dirty set
      → incremental redraw of affected region
        → dirty set cleared
```

---

## 3. Notebook Data Model

### Core Structs

```elisp
(cl-defstruct ejn-notebook
  id           ; stable UUID string
  path         ; file path or nil
  metadata     ; alist of notebook-level metadata
  cells        ; vector of ejn-cell structs
  dirty        ; boolean
  nbformat     ; integer, e.g. 4
  nbformat-minor)

(cl-defstruct ejn-cell
  id             ; stable UUID string (from .ipynb or generated)
  type           ; 'code | 'markdown | 'raw
  source         ; string — the editable content
  outputs        ; list of ejn-output structs
  metadata       ; alist
  execution-count ; integer or nil
  execution-state ; 'idle | 'queued | 'executing | 'streaming
                  ; | 'completed | 'error | 'interrupted
  execution-version) ; monotonically increasing integer, for stale output detection

(cl-defstruct ejn-output
  type       ; 'stream | 'display-data | 'execute-result | 'error
  mime-data  ; alist of mime-type → content
  metadata   ; alist
  request-id) ; execution request ID this output belongs to
```

### Stable Cell IDs

Cell IDs are never recomputed. On load, existing `.ipynb` cell IDs are preserved. New cells get a UUID generated at insertion time. IDs survive:

- cell reordering,
- source edits,
- re-renders,
- undo/redo cycles.

### Execution Versioning

Each time a cell is submitted for execution, its `execution-version` is incremented. Output routing checks that the arriving output's request maps to the current `execution-version`. Stale outputs (from a superseded execution) are silently discarded.

---

## 4. Async Execution Lifecycle

### Sequence

```
1. User invokes ejn-execute-cell
2. ejn-executor increments execution-version on cell
3. ejn-executor enqueues (cell-id, execution-version, source) request
4. ejn-kernel-execute called with callbacks:
     :on-output  → ejn-output-router
     :on-complete → ejn-execution-complete
     :on-error    → ejn-execution-error
5. Cell state transitions: idle → queued → executing
6. Kernel sends output messages → ejn-output-router
     - validates cell-id and execution-version
     - appends ejn-output to cell
     - triggers incremental renderer update
     - cell state: executing → streaming
7. Kernel sends execute_reply → ejn-execution-complete
     - sets execution-count
     - cell state: streaming → completed (or → error)
8. Renderer redraws cell region with final outputs
```

### Cancellation

On interrupt:

1. `ejn-kernel-interrupt` is called immediately.
2. Cell state transitions to `'interrupted`.
3. Any queued requests behind this cell remain queued (they will execute after the kernel acknowledges the interrupt and becomes idle again).
4. Partial outputs already stored in the cell are preserved.

### Queue Policy

- The queue is per-kernel.
- Queue order matches user submission order.
- Cells from different notebooks sharing a kernel are interleaved in submission order.
- The queue is drained after each `execute_reply`.

---

## 5. Extension API Specifications

### 5.1 Kernel API

All kernels implement these generic functions. The default implementation delegates to `ejn-jupyter-kernel`.

```elisp
;; Async code execution.
;; callbacks is a plist:
;;   :on-output   (lambda (output))        — called for each output message
;;   :on-complete (lambda (execution-count)) — called on execute_reply ok
;;   :on-error    (lambda (ename evalue traceback)) — called on execute_reply error
;; Returns a request-id string.
(cl-defgeneric ejn-kernel-execute (kernel code callbacks))

;; Async completion at position.
;; Returns a promise resolving to (list matches cursor-start cursor-end).
(cl-defgeneric ejn-kernel-complete (kernel code position))

;; Async introspection at position.
;; Returns a promise resolving to a plist :status :data :metadata.
(cl-defgeneric ejn-kernel-inspect (kernel code position detail-level))

;; Send interrupt signal. Fire-and-forget.
(cl-defgeneric ejn-kernel-interrupt (kernel))

;; Restart the kernel. Returns a promise resolving when the kernel is idle.
(cl-defgeneric ejn-kernel-restart (kernel))

;; Return kernel status: 'idle | 'busy | 'starting | 'dead.
(cl-defgeneric ejn-kernel-status (kernel))
```

Implementations register themselves:

```elisp
(ejn-register-kernel-backend 'jupyter #'ejn-jupyter-kernel-create)
```

### 5.2 MIME Renderer API

MIME handlers are registered globally and resolve by priority order.

```elisp
;; Register a handler for a MIME type.
;; priority: integer, higher wins (default 50).
;; handler: (lambda (content metadata cell-id)) → renders into current buffer at point.
(ejn-register-mime-handler "image/png" #'ejn-render-png :priority 100)
(ejn-register-mime-handler "text/markdown" #'ejn-render-markdown :priority 80)
(ejn-register-mime-handler "text/plain" #'ejn-render-plain :priority 10)

;; Look up the best available handler for a MIME type.
(ejn-mime-handler-for "image/svg+xml")
;; => #'ejn-render-svg
```

A handler receives the raw MIME content string and must insert rendered output at point. It must not move point outside the designated output region.

MVP handlers (required before Phase 7):
- `text/plain` — insert as-is, read-only
- `text/markdown` — render via `markdown-mode` font-lock if available, else plain
- `image/png` — decode base64, insert via `create-image`
- `image/svg+xml` — decode, insert via `create-image` with SVG support

### 5.3 Persistence Backend API

```elisp
;; Read a notebook from path. Returns ejn-notebook or signals error.
(cl-defgeneric ejn-persistence-read (backend path))

;; Write a notebook to path. Returns t on success or signals error.
(cl-defgeneric ejn-persistence-write (backend notebook path))

;; Return t if backend can handle this path.
(cl-defgeneric ejn-persistence-can-handle-p (backend path))
```

Backends register themselves:

```elisp
(ejn-register-persistence-backend 'ipynb #'ejn-ipynb-backend-create
                                   :predicate (lambda (path) (string-suffix-p ".ipynb" path)))
```

The `.ipynb` backend must:
- preserve all unknown top-level metadata keys,
- preserve all cell metadata keys,
- preserve cell IDs exactly,
- preserve all MIME bundle keys in outputs, including unrecognized ones.

### 5.4 LSP Integration API

LSP backends are registered independently, allowing both `lsp-mode` and `eglot` to coexist.

```elisp
;; Register an LSP integration.
;; sync-fn: (lambda (virtual-doc)) → sends textDocument/didChange to the LSP server.
;; diag-fn: (lambda (diagnostics virtual-doc)) → receives diagnostics, maps to cells.
(ejn-register-lsp-backend 'lsp-mode
                           :sync #'ejn-lsp-mode-sync
                           :diagnostics #'ejn-lsp-mode-diagnostics)
```

Virtual document structure:

```elisp
(cl-defstruct ejn-virtual-document
  uri          ; string — synthetic file URI
  language-id  ; string — e.g. "python"
  content      ; string — concatenated cell sources with separators
  cell-map)    ; alist mapping (line-start . line-end) → cell-id
```

Position translation:

```elisp
;; Convert a (line col) in the virtual document to (cell-id line col) in notebook space.
(ejn-vdoc-position-to-cell vdoc line col)
;; => (cell-id . (line . col))

;; Convert a (cell-id line col) to a (line col) in the virtual document.
(ejn-cell-position-to-vdoc vdoc cell-id line col)
;; => (line . col)
```

---

## 6. Phase 0 Finish Conditions

These questions must be answerable without ambiguity before Phase 1 begins:

| Question | Answer |
|---|---|
| Who owns cell source text? | `ejn-notebook` model; buffer is a read projection |
| Who may mutate the model? | Sync layer (`ejn--perform-sync`), cell engine (`ejn-with-undo-group`), execution callbacks (direct model APIs) |
| How are stale outputs prevented? | Execution versioning on each cell; outputs validated by version before insertion |
| How does undo work? | `ejn-with-undo-group` wraps model transactions; buffer undo suppressed inside transactions |
| How do renderers know what to redraw? | `ejn-dirty-tracker` accumulates changed cell IDs; renderer consumes and clears the set |
| How does the kernel layer stay kernel-agnostic? | `cl-defgeneric` dispatch; UI only calls generic functions, never transport-specific APIs |
| How does LSP avoid running on notebook buffers directly? | Virtual document abstraction; `ejn-virtual-document` is the LSP target, not the notebook buffer |
| How do MIME handlers integrate? | Registration via `ejn-register-mime-handler`; dispatch by MIME type at render time |

---

## 7. Open Questions (Requiring Resolution Before Phase 3)

1. **Overlay budget per cell** — what is the maximum overlay count acceptable for a 1000-cell notebook without redisplay slowdown? Needs a benchmark.
2. **Debounce interval** — 200ms buffer-to-model sync delay is a guess. Needs UX validation against fast typists.
3. **Cell separator representation** — text properties vs. dedicated overlay for cell boundaries. Decision affects navigation and sync complexity.
4. **LSP virtual document separator strategy** — how to inject cell boundaries into the virtual document without confusing the language server. Current candidates: blank lines, `# %%` comments, or a configurable separator string.
5. **Multi-kernel routing** — when multiple kernels are active (e.g. a Python kernel and an R kernel in the same notebook), how does the executor route cells to the correct kernel? Needs a kernel-per-cell metadata convention.
