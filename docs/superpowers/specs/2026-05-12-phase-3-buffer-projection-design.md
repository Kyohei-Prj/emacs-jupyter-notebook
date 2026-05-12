# Phase 3 — Buffer Projection and Cell Engine Design

Date: 2026-05-12
Phase: 3
Status: Draft

---

## Goal

Render notebook models into editable Emacs buffers. Provide a complete notebook editing experience with cell navigation, cell operations (insert, delete, split, merge, move), debounced buffer-to-model synchronization, and output rendering — all following the model-first architecture established in Phase 0.

---

## Architectural Decisions

### Cell Separator: Text Properties Only (No Overlays)

Cell boundaries are rendered using text properties only. Each cell's source region carries `ejn-cell-id` and `ejn-cell-type` text properties on every character. Execution state is displayed via a colored left margin on the first character of each cell using `face` and `display` text properties. No overlays are used for cell boundaries.

This minimizes the overlay budget (critical for 1000+ cell notebooks), keeps the rendering architecture simple, and aligns with Phase 0's principle: "prefer text properties, minimize overlays."

Trade-off: execution state display is limited to color coding (gray=idle, yellow=executing, green=completed, red=error). No inline text indicators like `[In: 3]` or `● executing`. The buffer's header line can supplement this with current cell information.

### Sync Strategy: Debounced Updates (200ms Default)

User edits are synced to the model after 200ms of idle typing via `after-change-functions`. This keeps the model nearly current while batching rapid keystrokes into single updates. The debounce interval is configurable via `ejn-sync-debounce-seconds`.

This choice supports future LSP integration (Phase 6): the LSP layer watches the model's dirty set through `ejn-after-sync-hook`, so one sync path serves both rendering and language intelligence.

### Output Regions: Dedicated Read-Only Zones

Each cell's output appears in a distinct read-only region below the cell's source text. Output zones carry `ejn-output-zone` text properties and `read-only` properties. The sync layer ignores changes in output zones. Output can be folded/unfolded using `invisible` text properties.

### Module Structure: Modular by Concern

Six focused files, each with one responsibility:

```
lisp/
├── ejn-mode.el          ; Major mode, keymap, buffer-local state
├── ejn-render.el        ; Projection renderer, text properties, output zones
├── ejn-cell-engine.el   ; Cell insert/delete/split/merge/move operations
├── ejn-navigation.el    ; Structural motion (next/prev cell)
├── ejn-sync.el          ; Buffer-to-model sync, debounced updates
├── ejn-undo.el          ; Emacs undo integration
└── ejn-mime.el          ; MIME handler registry and MVP handlers
```

---

## File Structure

```
lisp/
├── ejn-mode.el
├── ejn-render.el
├── ejn-cell-engine.el
├── ejn-navigation.el
├── ejn-sync.el
├── ejn-undo.el
└── ejn-mime.el

test/
├── ejn-mode-test.el
├── ejn-render-test.el
├── ejn-cell-engine-test.el
├── ejn-navigation-test.el
└── ejn-sync-test.el
```

`ejn-core.el` will `(require)` all Phase 3 modules to expose them at package load.

---

## Major Mode (`ejn-mode.el`)

### Responsibilities

- Define `ejn-mode` major mode
- Set up buffer-local state
- Install keymap
- Provide `ejn-open` command

### Mode Definition

`ejn-mode` derives from `text-mode` via `define-derived-mode`. Deriving from `text-mode` provides sensible defaults for indentation, electric characters, and filling behavior that users expect in a text editing environment.

### Buffer-Local State

| Variable | Type | Description |
|---|---|---|
| `ejn--notebook` | `ejn-notebook` | Model instance for this buffer |
| `ejn--sync-timer` | timer \| nil | Debounced sync timer |
| `ejn--rendering-p` | boolean | Guard flag to prevent reentrant renders |

All variables are buffer-local and private (double-dash prefix).

### Keymap

Derived from `docs/keymap.md` (EIN worksheet keymap). All cell operations use `C-c` prefix:

| Key | Command |
|---|---|
| `C-c C-a` | `ejn-insert-cell-above` |
| `C-c C-b` | `ejn-insert-cell-below` |
| `C-c C-c` | `ejn-execute-cell` |
| `C-u C-c C-c` | `ejn-execute-all-cells` |
| `C-c RET` | `ejn-merge-cell` |
| `C-c C-k` | `ejn-delete-cell` |
| `C-c C-l` | `ejn-clear-output` |
| `C-c C-n` | `ejn-goto-next-cell` |
| `C-c C-p` | `ejn-goto-prev-cell` |
| `C-c C-r` | `ejn-split-cell` |
| `C-c C-t` | `ejn-toggle-cell-type` |
| `C-c C-u` | `ejn-change-cell-type` |
| `C-c C-e` | `ejn-toggle-output` |
| `C-c C-w` | `ejn-copy-cell` |
| `C-c C-y` | `ejn-yank-cell` |
| `C-c <down>` | `ejn-move-cell-down` |
| `C-c <up>` | `ejn-move-cell-up` |
| `C-<down>` | `ejn-goto-next-cell` |
| `C-<up>` | `ejn-goto-prev-cell` |
| `M-<down>` | `ejn-move-cell-down` |
| `M-<up>` | `ejn-move-cell-up` |
| `M-RET` | `ejn-execute-cell-and-goto-next` |
| `M-S-<return>` | `ejn-execute-cell-and-insert-below` |
| `C-x C-s` | `ejn-save-notebook` |
| `C-c C-S-l` | `ejn-clear-all-outputs` |

Kernel lifecycle commands (`C-c C-q`, `C-c C-z`, `C-c C-x C-r`) are defined as stubs in Phase 3 that signal "kernel not connected" — they will be implemented in Phase 4.

### `ejn-open` Command

Prompts for a `.ipynb` file path, loads the model via `ejn-model-from-file`, creates a new buffer in `ejn-mode`, and performs a full render. Sets `buffer-file-name` for standard Emacs save/kill behavior.

---

## Projection Renderer (`ejn-render.el`)

### Responsibilities

- Project notebook model into buffer text
- Manage text properties for cell structure
- Render output zones
- Support incremental updates
- Handle output folding

### Buffer Layout

Each cell renders as:

```
[execution state margin] source line 1
[continuation margin]     source line 2
...
                          (blank line if cell has outputs)
                          output zone (read-only, may be folded)
\n                         (cell separator)
```

### Text Properties

| Property | Value | Region | Purpose |
|---|---|---|---|
| `ejn-cell-id` | string (UUID) | Cell source region | Cell identification |
| `ejn-cell-type` | keyword | Cell source region | Cell type for font-lock |
| `ejn-output-zone` | t | Output region | Sync layer exclusion |
| `read-only` | t | Output region | Prevent accidental edits |
| `face` | face name | First char of cell | Execution state color |
| `display` | `(space ...)` | First char of cell | Left margin indicator |
| `invisible` | `ejn-folded-output` | Folded output zone | Output folding |

### Execution State Faces

| State | Face | Description |
|---|---|---|
| `idle` | `ejn-cell-idle` (gray) | Default state |
| `queued` | `ejn-cell-queued` (blue) | Waiting for kernel |
| `executing` | `ejn-cell-executing` (yellow) | Kernel running code |
| `streaming` | `ejn-cell-streaming` (yellow) | Output arriving |
| `completed` | `ejn-cell-completed` (green) | Success |
| `error` | `ejn-cell-error` (red) | Execution error |
| `interrupted` | `ejn-cell-interrupted` (orange) | User interrupt |

Faces are defined with `defface` and inherit from `font-lock` faces for theme compatibility.

### Full Render

`ejn-render-notebook` NOTEBOOK &optional BUFFER

Clears the buffer and renders all cells. Used for initial load and operations that change cell count/order.

### Incremental Render

`ejn-render-dirty-cells` NOTEBOOK &optional BUFFER

Reads the notebook's dirty set, re-renders only affected cell regions, and clears the dirty set. Finds cell regions by searching for `ejn-cell-id` text properties.

### Output Rendering

`ejn-render-outputs` CELL BUFFER

Renders a cell's outputs into the output zone. Dispatches to MIME handlers registered via `ejn-register-mime-handler`. MVP handlers:

| MIME Type | Handler |
|---|---|
| `text/plain` | Insert as-is with fixed-pitch face |
| `text/markdown` | Render via `markdown-mode` font-lock if available |
| `image/png` | Decode base64, insert via `create-image` |
| `image/svg+xml` | Decode, insert via `create-image` with SVG |

Output rendering is part of the renderer module but uses the MIME registry API defined in Phase 0 spec section 5.2. The MIME registry itself is a small module (`ejn-mime.el`) that will be created in Phase 3 as a foundation for Phase 7.

### Output Folding

`ejn-toggle-output` sets `invisible` property on the current cell's output zone. Uses a custom invisibility spec `ejn-folded-output` added to `buffer-invisibility-spec`. Folded output is replaced with a placeholder line `... [output folded]` rendered via the `display` property on the first character of the output zone.

---

## Cell Engine (`ejn-cell-engine.el`)

### Responsibilities

All cell structural operations. Model-first: mutate the model, then render.

### Operations

| Command | Model Action | Render Type |
|---|---|---|
| `ejn-insert-cell-above` | Insert cell before current | Full |
| `ejn-insert-cell-below` | Insert cell after current | Full |
| `ejn-delete-cell` | Delete current cell | Full |
| `ejn-split-cell` | Split at point into two cells | Full |
| `ejn-merge-cell` | Merge current + next cell | Full |
| `ejn-move-cell-up` | Swap with previous cell | Full |
| `ejn-move-cell-down` | Swap with next cell | Full |
| `ejn-toggle-cell-type` | Cycle code→markdown→raw→code | Incremental |
| `ejn-change-cell-type` | Prompt for type, set cell type | Incremental |
| `ejn-clear-output` | Clear cell outputs | Incremental |
| `ejn-clear-all-outputs` | Clear all cells' outputs | Full |
| `ejn-copy-cell` | Push cell to kill ring | N/A |
| `ejn-yank-cell` | Insert cell from kill ring | Full |

### Structural vs Incremental Renders

Operations that change the cell count or cell order (insert, delete, split, merge, move, yank) trigger a **full render** because buffer positions shift globally. Operations that only modify a single cell's properties (toggle type, change type, clear output) trigger an **incremental render** of the affected cell.

### Undo Integration

Every operation wraps its model mutation in `ejn-with-undo-group`. Buffer modifications are grouped within a single Emacs undo boundary using `(undo-boundary)` before and after the operation.

### Copy/Yank

Cells are copied to the kill ring as serialized model data (not buffer text). `ejn-copy-cell` serializes the current cell to a plist. `ejn-yank-cell` deserializes and inserts the cell below the current cell. This ensures copied cells survive buffer re-renders.

---

## Navigation (`ejn-navigation.el`)

### Responsibilities

Structural motion commands operating on cell boundaries.

### Core Primitives

| Function | Returns |
|---|---|
| `ejn-cell-at-point` | `ejn-cell` struct at point, or signal error |
| `ejn-cell-region` | `(START . END)` of current cell's source (excludes output) |
| `ejn-cell-full-region` | `(START . END)` including output zone |

`ejn-cell-at-point` reads the `ejn-cell-id` text property at point and looks up the cell in the model. If point is in an output zone, it finds the parent cell by scanning backward for `ejn-cell-id`.

### Navigation Commands

| Command | Behavior |
|---|---|
| `ejn-goto-next-cell` | Point to start of next cell's source region |
| `ejn-goto-prev-cell` | Point to start of previous cell's source region |
| `ejn-goto-first-cell` | Point to start of first cell |
| `ejn-goto-last-cell` | Point to start of last cell |

Navigation always targets the source region, never the output zone. If the next cell is already current, behavior is a no-op.

### Standard Emacs Motion

Regular Emacs movement commands (`C-n`, `C-p`, `M-f`, `M-b`, `C-a`, `C-e`, etc.) work normally within the buffer. They move character-by-character through source and output regions. Structural commands (`C-c C-n`, `C-c C-p`, `C-<up>`, `C-<down>`) jump between cells.

---

## Synchronization (`ejn-sync.el`)

### Responsibilities

Detect user edits in the buffer and update the notebook model with debounced batching.

### Change Detection

An `after-change-functions` hook fires on each buffer modification:

1. Checks `ejn--rendering-p` guard — if rendering, skip
2. Checks for `ejn-output-zone` text property — if in output zone, skip
3. Reads `ejn-cell-id` text property at the change position
4. Adds the cell ID to `ejn--pending-sync-set` (a buffer-local hash table)
5. Schedules debounced sync if not already scheduled

### Debounced Update

After `ejn-sync-debounce-seconds` (default 0.2) of no further changes:

1. Iterates over cell IDs in `ejn--pending-sync-set`
2. For each cell, extracts current source text from the buffer's cell region
3. Compares with model's `ejn-cell-source` — skips if unchanged
4. Calls `ejn-notebook-set-cell-source` for changed cells
5. Runs `ejn-after-sync-hook` (empty by default, Phase 6 will add LSP sync)
6. Clears `ejn--pending-sync-set`

### Configurable Debounce

```elisp
(defcustom ejn-sync-debounce-seconds 0.2
  "Seconds to wait after typing before syncing buffer to model.
Set to 0 for real-time sync (every keystroke updates the model)."
  :type 'number
  :group 'ejn)
```

### Rendering Guard

When `ejn-render.el` modifies the buffer, it sets `ejn--rendering-p` to `t` before changes and restores it to `nil` afterward. This prevents the sync layer from processing renderer-induced buffer changes.

---

## Undo Integration (`ejn-undo.el`)

### Responsibilities

Bridge between Emacs' built-in buffer undo and the model's transactional undo system.

### Design

Each cell engine operation wraps buffer modifications in Emacs undo boundaries:

```elisp
(undo-boundary)
;; ... buffer modifications ...
(undo-boundary)
```

This ensures that `C-/` (undo) groups all buffer changes from a single operation into one undo step. The model's `ejn-with-undo-group` provides the canonical undo record; Emacs buffer undo is supplementary and operates on the rendered buffer state.

The module provides:

| Function | Description |
|---|---|
| `ejn-with-undo-boundary` LABEL &rest body | Wraps BODY in Emacs undo boundaries |
| `ejn-undo` | Undo last operation (delegates to model, then re-renders) |
| `ejn-redo` | Redo last undone operation (delegates to model, then re-renders) |

`ejn-undo` and `ejn-redo` call the model's `ejn-undo`/`ejn-redo`, then trigger a full render to reflect the restored state in the buffer.

---

## MIME Registry (`ejn-mime.el`)

A small foundation module for the MIME handler system. Implements the registration API from Phase 0 spec section 5.2 with MVP handlers.

### API

| Function | Description |
|---|---|
| `ejn-register-mime-handler` MIME-TYPE HANDLER &key priority | Register a renderer for a MIME type |
| `ejn-mime-handler-for` MIME-TYPE | Return best handler for MIME type |

### MVP Handlers

| MIME Type | Handler | Priority |
|---|---|---|
| `text/plain` | `ejn-render-plain` | 10 |
| `text/markdown` | `ejn-render-markdown` | 80 |
| `image/png` | `ejn-render-png` | 100 |
| `image/svg+xml` | `ejn-render-svg` | 100 |

Handlers are auto-registered at module load.

---

## Testing Strategy

### `ejn-mode-test.el`

- `ejn-open` creates buffer with `ejn-mode`
- Buffer-local `ejn--notebook` is set correctly after open
- Keymap is installed (spot-check `C-c C-c` binding)
- Mode exit cleanup releases sync timer

### `ejn-render-test.el`

- Full render produces correct buffer content for known notebook model
- `ejn-cell-id` text properties are set on source regions
- `ejn-cell-type` text properties match cell type
- Output zones have `ejn-output-zone` and `read-only` properties
- Execution state faces are applied based on cell `execution-state`
- Incremental render updates only dirty cell regions
- Output folding toggles `invisible` property correctly
- Render guard (`ejn--rendering-p`) prevents reentrant renders

### `ejn-cell-engine-test.el`

- Insert above/below produces correct cell order in model
- Delete removes correct cell from model
- Split divides source at point into two cells
- Merge concatenates current and next cell source
- Move up/down swaps cell positions
- Toggle type cycles code→markdown→raw→code
- Clear output removes outputs from cell
- Copy/yank round-trips cell content correctly
- All operations are undoable

### `ejn-navigation-test.el`

- `ejn-cell-at-point` returns correct cell for source region positions
- `ejn-cell-at-point` returns correct cell for output zone positions
- `ejn-goto-next-cell` moves to next cell's source
- `ejn-goto-prev-cell` moves to previous cell's source
- Navigation skips output zones
- First/last cell commands work at boundaries
- No-op when already at target cell

### `ejn-sync-test.el`

- Typing in a cell updates the model after debounce interval
- Multiple keystrokes are batched into one sync
- Changes in output zones are ignored by sync
- Unchanged cells are not re-synced
- Sync guard prevents updates during render
- `ejn-after-sync-hook` runs after sync completes
- Debounce timer is cleaned up on buffer kill

### Test Helpers

`ejn-test-util.el` gains:

- `ejn-test-with-notebook-buffer` NOTEBOOK — creates a temporary buffer with the rendered notebook, runs body, and kills the buffer
- `ejn-test-wait-for-sync` — waits for the debounce timer to fire

---

## Dependencies

No new external dependencies. Uses only:
- `cl-lib` — struct access, control flow
- `ejn-cell` — cell/output structs
- `ejn-model` — notebook model, transactions, dirty tracking
- `ejn-persistence` — notebook loading
- `text-mode` — parent mode for `ejn-mode`
- Built-in Emacs: `timer`, `subr-x`, `faces`

---

## Out of Scope

- Kernel execution (Phase 4) — execute commands are stubs
- LSP integration (Phase 6) — hook point exists but is empty
- Rich MIME extensions (Phase 7) — MVP handlers only (plain, markdown, PNG, SVG)
- Ecosystem integration (Phase 8) — no consult/embark/transient integration
- Performance optimization (Phase 5) — basic rendering, no profiling yet
- Virtual document generation (Phase 6)
- Autosave (Phase 9)

---

## Finish Conditions

Notebook editing is:
- A major mode (`ejn-mode`) provides a complete editing environment
- Notebook files can be opened, edited, and saved
- Cells can be inserted, deleted, split, merged, and moved
- Navigation jumps between cells structurally
- User edits sync to the model with configurable debounce
- Outputs render in dedicated read-only zones with fold/unfold
- Text properties (not overlays) define cell structure
- All operations are undoable
- All modules pass byte-compilation, lint, and ERT tests
