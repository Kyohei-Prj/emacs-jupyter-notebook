## Goal

Replace the raw buffer scaffolding with a polished, cohesive notebook UI and solve the distributed undo problem introduced by multi-buffer editing. A production-quality notebook experience: a unified `poly-ejn-mode` view with rendered Markdown, styled code cells with margin indicators, and a global undo system that traverses changes chronologically across all cells — including structural operations like cell insertion and deletion. All keybindings from `keymap.md` are wired and functional. Large notebooks open instantly. The package is ready for an initial public release on MELPA.

## Features

1. **Visual cell headers** — `before-string` text property on the first line of each cell buffer displays a styled cell header (`╔══ In [3]: ═══════╗`) with cell type badge and execution count. Left margin shows `In [N]:` indicator via `display-margin` text property. `ejn-cell-refresh-header` updates both after each execution.

2. **Global undo** — `C-u` in any cell buffer calls `ejn-global-undo`, which pops the top record from the notebook's undo stack, restores the named cell's buffer to its `before` state, and moves point to that buffer — regardless of which cell is currently active. Rapid typing is coalesced into single records using a 1-second debounce window. Structural operations (insert, delete, move, split, merge) are also undoable.

3. **Polymode master view** — The master view buffer uses `poly-ejn-mode` with `special-mode` as host, `python-mode` for code cell chunks, and `markdown-mode` for Markdown cell chunks. Replaces the button-based master view entirely. The master view serves as both navigation hub and readable, rendered notebook surface.

4. **Markdown cell rendering** — Markdown cells are rendered in place using `markdown-mode`'s inline rendering capabilities (bold, italics, links, code spans) using text properties, without spawning an external process.

5. **Cell type toggle** — `C-c C-t` cycles the current cell's type between `code` and `markdown`. Updates the cell buffer's major mode and re-renders the master view.

6. **Cell type change** — `C-c C-u` presents a `completing-read` of all available cell types (`code`, `markdown`, `raw`) and applies the selection.

7. **Notebook close** — `C-c C-#` kills all cell buffers, kills the master view buffer, and cleans up the `.ejn-cache/<stem>/` directory. Prompts to save if any cells are dirty. Does not kill the kernel.

8. **Scratchsheet** — `C-c C-/` opens a transient cell buffer attached to the current notebook's kernel but not saved to the `.ipynb` file. Lives in `.ejn-cache/<stem>/scratch.py`.

9. **Traceback viewer** — `C-c C-$` opens a dedicated buffer showing the full, syntax-highlighted traceback from the most recent kernel error, using `python-mode`.

10. **Shared output buffer** — `C-c C-;` opens a persistent output buffer that appends output from the current cell each time it is executed, without overwriting in place.

11. **Lazy buffer initialization** — On `ejn-open-file`, all cells are parsed into EIEIO objects but no buffers, shadow files, or LSP connections are created. A `window-scroll-functions` hook on the master view triggers `ejn-cell-initialize` for cells that scroll into view. A 1000-cell notebook opens in under 500ms.

## Out of scope

- Widget rendering (`application/vnd.jupyter.widget-view+json`) — delegated to jupyter.el's external browser handling
- Hybrid completion (kernel + LSP) — reserved for future phase
- Multiple kernel support — reserved for future phase
- Cell metadata editing (custom tags, etc.) — reserved for future phase
- Undo grouping/boundary management (e.g., "undo entire cell edit") — reserved for future phase
- Keyboard shortcut for polymode view switching — reserved for future phase

## Architecture

### Data model

**`ejn-undo-record` struct (new, in `ejn-ui.el`):**

```elisp
(cl-defstruct ejn-undo-record
  cell-id    ; which cell was affected (string)
  before     ; cell source before the change (string)
  after      ; cell source after the change (string)
  timestamp  ; (float-time) for debounce window
  operation  ; :content for typing, :insert/:delete/:move/:split/:merge for structural ops)
```

**`ejn-notebook` amendments:**
- New `:undo-stack` slot: `:initform nil`, `:type list` — list of `ejn-undo-record` structs

**`ejn-cell` amendments:**
- New `:initialized-p` slot: `:initform nil`, `:type boolean` — flag for lazy initialization
- New `:scratch-p` slot: `:initform nil`, `:type boolean` — flag for scratch cells (not persisted)

### Interface contracts

**Visual styling (ejn-ui.el):**

| Function | Signature | Behavior |
|---|---|---|
| `ejn--cell-header-string` | `(cell)` | Returns styled header string with cell type badge and execution count. |
| `ejn--setup-cell-visuals` | `(cell)` | Applies `before-string` on first line, sets up margin decorations. Idempotent. |
| `ejn-cell-refresh-header` | `(cell)` | Updates header string and margin indicator for CELL after execution. |
| `ejn--setup-cell-margin` | `(cell)` | Sets `display-margin` text property on first line for `In [N]:` indicator. |

**Global undo (ejn-ui.el):**

| Function | Signature | Behavior |
|---|---|---|
| `ejn--undo-after-change` | `(start end pre-change-length)` | After-change wrapper that coalesces rapid typing and pushes `ejn-undo-record` to notebook's undo stack. |
| `ejn-global-undo` | `()` | Pops top record from notebook's undo stack, restores cell buffer to `before` state, moves point. |
| `ejn--record-structural-change` | `(notebook operation data)` | Replaces no-op stub. Records structural operation (insert/delete/move/split/merge) on undo stack. |
| `ejn--undo-structural-change` | `(record)` | Reverses a structural undo record (re-inserts deleted cell, restores moved position, etc.). |

**Polymode master view (ejn-master.el):**

| Function | Signature | Behavior |
|---|---|---|
| `poly-ejn-mode` | `()` | Polymode with `special-mode` host, `python-mode` inner for code cells, `markdown-mode` inner for Markdown cells. |
| `ejn--poly-chunk-start` | `(cell-index)` | Returns chunk start delimiter for cell at CELL-INDEX. |
| `ejn--poly-chunk-end` | `(cell-index)` | Returns chunk end delimiter for cell at CELL-INDEX. |
| `ejn--poly-render-cells` | `(notebook)` | Replaces `ejn--render-master-cells`. Renders cells using polymode chunk delimiters. |
| `ejn--poly-refresh-cells` | `()` | Replaces `ejn--refresh-master-cells`. Re-renders master view with polymode. |

**Markdown rendering (ejn-ui.el):**

| Function | Signature | Behavior |
|---|---|---|
| `ejn-markdown-render-cell` | `(cell)` | Renders Markdown cell content in place using text properties. Uses `markdown-mode` if available, falls back to `shr-render-region`. |

**Cell type commands (ejn-cell.el):**

| Function | Signature | Behavior |
|---|---|---|
| `ejn:worksheet-toggle-cell-type` | `()` | Cycles cell type between `code` and `markdown`. Updates major mode and master view. |
| `ejn:worksheet-change-cell-type` | `()` | Presents `completing-read` of cell types (`code`, `markdown`, `raw`). Applies selection. |

**Notebook utilities (ejn.el):**

| Function | Signature | Behavior |
|---|---|---|
| `ejn:notebook-close` | `()` | Kills all cell buffers, kills master view, cleans up cache directory. Prompts to save if dirty. |
| `ejn:notebook-scratchsheet-open` | `()` | Opens transient scratch cell attached to notebook's kernel. Not persisted. |
| `ejn:tb-show` | `()` | Opens traceback buffer with syntax-highlighted traceback from most recent kernel error. |
| `ejn:shared-output-show-code-cell-at-point` | `()` | Opens shared output buffer appending from current cell. |

**Lazy initialization (ejn-cell.el):**

| Function | Signature | Behavior |
|---|---|---|
| `ejn-cell-initialize` | `(cell notebook)` | Creates buffer, writes shadow file, attaches LSP (with idle delay). Idempotent — guarded by `:initialized-p`. |
| `ejn--master-scroll-hook` | `(window)` | `window-scroll-functions` hook. Calls `ejn-cell-initialize` for cells that scroll into view. |

### Tech stack

- `polymode` → Multi-mode master view (already declared in Eask)
- `markdown-mode` → Markdown cell rendering (optional dependency, fallback to `shr-render-region`)
- `shr-render-region` → Built-in HTML rendering for Markdown fallback (Emacs 24+)
- `cl-defstruct` → Undo record structures (lighter than EIEIO for simple records)
- `before-string` + `display-margin` text properties → Cell headers and margin indicators (no overlays)
- `window-scroll-functions` → Lazy initialization trigger
- `buttercup` → Test framework (consistent with Phases 2-4)

### Non-goals

- No external process spawning for Markdown rendering
- No undo grouping/boundary management in this phase
- No multiple kernel support
- No cell metadata editing
- Scratchsheet cells are transient — never written to `.ipynb` on save
- Polymode master view replaces button view entirely — no view-switching command

## Task list

### Phase 5 — UI Refinement & Global UX

<!--
Classification reasoning per task:
- P5-T01 through P5-T05: tdd — data transformation (header string construction), text property manipulation, conditional logic (execution count presence)
- P5-T06 through P5-T11: tdd — state mutation (undo stack), conditional logic (debounce, structural vs content ops), data transformation (buffer restoration)
- P5-T12 through P5-T16: tdd — polymode configuration involves conditional chunk detection, data transformation (cell rendering), and structural wiring
- P5-T17 through P5-T20: tdd — conditional logic (markdown mode availability), data transformation (markdown rendering), state mutation (cell type changes)
- P5-T21 through P5-T25: tdd — I/O (buffer creation, file operations), conditional logic (dirty check, kernel state), state mutation
- P5-T26 through P5-T30: tdd — I/O (buffer/shadow file creation), conditional logic (initialized-p flag), structural wiring (scroll hooks)
-->

#### Phase A — Visual Cell Styling (ejn-ui.el)

- [x] P5-T01 Create `ejn-ui.el` module with package header and requires [scaffold] (new file, no runtime behavior)
- [x] P5-T02 Implement `ejn--cell-header-string` in `ejn-ui.el` [tdd] (returns styled header string with cell type badge and execution count, e.g., `"╔══ In [3]: ════════════════════════════╗"` for code cell with exec-count 3, `"╔══ Markdown ═══════════════════════╗"` for markdown cell)
- [x] P5-T03 Implement `ejn--setup-cell-visuals` in `ejn-ui.el` [tdd] (applies `before-string` text property on first line of cell buffer with header string, sets up margin decorations; idempotent)
- [x] P5-T04 Implement `ejn-cell-refresh-header` in `ejn-ui.el` [tdd] (updates the `before-string` on first line of cell buffer with new header string reflecting current execution count; called after each execution)
- [x] P5-T05 Implement `ejn--setup-cell-margin` in `ejn-ui.el` [tdd] (sets `display-margin` text property on first line for left margin `In [N]:` indicator; uses `set-window-margins` to ensure margin width is sufficient)

#### Phase B — Integrate Visuals into Cell Buffer Lifecycle (ejn-cell.el)

- [x] P5-T06 Call `ejn--setup-cell-visuals` from `ejn-cell-open-buffer` after buffer creation [smoke] (structural wiring — adds call to existing function)
- [x] P5-T07 Call `ejn-cell-refresh-header` from `ejn--iopub-handler` on status:idle message [smoke] (structural wiring — adds call in existing iopub dispatch)

#### Phase C — Global Undo Manager (ejn-ui.el)

- [x] P5-T08 Add `:undo-stack` slot to `ejn-notebook` class [tdd] (EIEIO slot definition with type constraint)
- [x] P5-T09 Define `ejn-undo-record` struct in `ejn-ui.el` [scaffold] (cl-defstruct with cell-id, before, after, timestamp, operation fields)
- [x] P5-T10 Implement `ejn--undo-after-change` in `ejn-ui.el` [tdd] (after-change wrapper: coalesces rapid typing into single records using 1-second debounce window, pushes ejn-undo-record to notebook's undo stack; replaces direct dirty flag on after-change)
- [x] P5-T11 Implement `ejn-global-undo` command in `ejn-ui.el` [tdd] (interactive command: pops top record from notebook's undo stack, restores named cell's buffer to `before` state via `replace-buffer-contents`, moves point to that buffer; signals `user-error` if undo stack empty)

#### Phase D — Structural Undo Integration (ejn-cell.el)

- [x] P5-T12 Replace `ejn--record-structural-change` no-op stub with real implementation in `ejn-cell.el` [tdd] (records structural operation on notebook's undo stack: captures cell list state before and after, stores as ejn-undo-record with operation type)
- [x] P5-T13 Implement `ejn--undo-structural-change` in `ejn-ui.el` [tdd] (reverses a structural undo record: for :insert — removes inserted cell; for :delete — re-inserts deleted cell at original index; for :move — restores original position; for :split — merges cells back; for :merge — splits cells back)
- [x] P5-T14 Integrate `ejn--undo-after-change` into cell buffer setup in `ejn-cell-open-buffer` [smoke] (structural wiring — replaces direct dirty flag with undo-after-change wrapper)

#### Phase E — Polymode Master View (ejn-master.el)

- [x] P5-T15 Define `poly-ejn-mode` with chunk delimiters in `ejn-master.el` [tdd] (polymode definition: special-mode host, python-mode inner for code chunks, markdown-mode inner for markdown chunks; chunk delimiters keyed on sentinel comment format)
- [x] P5-T16 Implement `ejn--poly-render-cells` in `ejn-master.el` [tdd] (replaces `ejn--render-master-cells`: renders cells using polymode chunk delimiters with cell content between delimiters)
- [x] P5-T17 Implement `ejn--poly-refresh-cells` in `ejn-master.el` [tdd] (replaces `ejn--refresh-master-cells`: clears buffer and re-renders with polymode chunk delimiters)
- [x] P5-T18 Wire `ejn--poly-render-cells` into `ejn--create-master-view` [smoke] (structural wiring — replaces call to `ejn--render-master-cells`)

#### Phase F — Markdown Cell Rendering & Cell Type Commands (ejn-ui.el + ejn-cell.el)

- [x] P5-T19 Implement `ejn-markdown-render-cell` in `ejn-ui.el` [tdd] (renders Markdown cell content in place using text properties; uses `markdown-mode` if available, falls back to `shr-render-region`)
- [x] P5-T20 Replace `ejn:worksheet-toggle-cell-type` stub with real implementation in `ejn.el` [tdd] (cycles cell type between `code` and `markdown`; updates cell buffer's major mode; calls `ejn-markdown-render-cell` for markdown cells; re-renders master view)
- [x] P5-T21 Replace `ejn:worksheet-change-cell-type` stub with real implementation in `ejn.el` [tdd] (presents completing-read of cell types: `code`, `markdown`, `raw`; applies selection; updates cell buffer major mode; re-renders master view)

#### Phase G — Notebook Utilities (ejn.el)

- [x] P5-T22 Replace `ejn:notebook-close` stub with real implementation in `ejn.el` [tdd] (kills all cell buffers, kills master view buffer, cleans up `.ejn-cache/<stem>/` directory; prompts to save if any cells dirty; does NOT kill the kernel)
- [x] P5-T23 Replace `ejn:notebook-scratchsheet-open` stub with real implementation in `ejn.el` [tdd] (creates transient cell buffer attached to notebook's kernel; writes to `.ejn-cache/<stem>/scratch.py`; cell has `:scratch-p` flag; not persisted on save)
- [x] P5-T24 Replace `ejn:tb-show` stub with real implementation in `ejn.el` [tdd] (opens dedicated buffer with python-mode showing syntax-highlighted traceback from most recent kernel error; uses `ansi-color-apply` for ANSI-stripped traceback text)
- [x] P5-T25 Replace `ejn:shared-output-show-code-cell-at-point` stub with real implementation in `ejn.el` [tdd] (opens persistent shared output buffer; appends output from current cell each time it is executed; buffer name includes notebook stem)

#### Phase H — Lazy Buffer Initialization (ejn-cell.el + ejn-master.el)

- [x] P5-T26 Add `:initialized-p` and `:scratch-p` slots to `ejn-cell` class [tdd] (EIEIO slot definitions with type constraints)
- [x] P5-T27 Implement `ejn-cell-initialize` in `ejn-cell.el` [tdd] (creates buffer, writes shadow file, attaches LSP after idle delay; idempotent — guarded by `:initialized-p` flag)
- [x] P5-T28 Refactor `ejn-open-file` to use lazy initialization in `ejn.el` [tdd] (parses all cells into EIEIO objects but does NOT create buffers/shadow files/LSP; creates master view with polymode; first cell buffer still opened immediately for usability)
- [x] P5-T29 Implement `ejn--master-scroll-hook` in `ejn-master.el` [tdd] (`window-scroll-functions` hook: calls `ejn-cell-initialize` for cells that scroll into visible window area; marks cells as initialized)
- [x] P5-T30 Wire `ejn--master-scroll-hook` into `ejn--create-master-view` [smoke] (structural wiring — adds hook registration)

## Open questions

(All resolved during clarification loop.)

---

## Amendment log

<!-- This section records changes made after initial spec approval. -->

- 2026-04-30: Initial spec written based on roadmap Phase 5 and current codebase analysis.
