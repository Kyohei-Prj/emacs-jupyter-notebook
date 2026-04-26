# SPEC.md — Emacs Jupyter Notebook (EJN) Phase 2

## Goal

Create a working prototype that opens a `.ipynb` file, parses it into structured EIEIO objects, and splits it into individual, independently editable buffers kept in sync with a central data model. The full set of structural commands — insert, kill, move, split, merge, copy, yank, and navigate — all work correctly and round-trip through save: a notebook edited structurally and saved produces a valid `.ipynb` that re-opens identically.

## Features

1. EIEIO data model — `ejn-notebook` and `ejn-cell` classes defined in `lisp/ejn-core.el` with all slots from the roadmap (path, metadata, cells, kernel-id / id, type, source, outputs, buffer, shadow-file, exec-count), accessible via standard EIEIO accessor functions.

2. JSON parser & `.ipynb` loader — `ejn-notebook-load` reads a `.ipynb` file, handles nbformat 4.x (`notebook["cells"]`) and nbformat 3.x (`notebook["worksheets"][0]["cells"]`), instantiates each cell as an `ejn-cell` object, appends it to the notebook's `:cells` list, and returns the `ejn-notebook` object.

3. Shadow file write — `ejn-shadow-write-cell` writes a cell's `:source` to `.ejn-cache/<notebook-stem>/cell_XXX.<ext>` where `XXX` is zero-padded to match list order and `<ext>` is `.py` for code cells, `.md` for markdown cells, `.raw` for raw cells. Returns the shadow file path.

4. Shadow file sync & dirty tracking — `ejn-cell-dirty-p` flag set by `after-change-functions` hook in cell buffers. `ejn-shadow-sync-cell` diffs buffer content against `:source` slot, updates both, writes to disk atomically (`.tmp` → `rename-file`), and clears the dirty flag. Dirty flag is accessible from any cell buffer.

5. Master view buffer — `ejn-open-file` opens a `.ipynb` file, creates a `special-mode` master view buffer listing all cells as `insert-text-button` entries. Each button displays cell type, execution count, and source preview. Clicking a button opens/switches to that cell's dedicated buffer.

6. Cell insertion — `ejn:worksheet-insert-cell-above` and `ejn:worksheet-insert-cell-below` create a new `ejn-cell` with a `cl-gensym` ID, insert it at the correct index in `:cells`, write an empty shadow file, and refresh the master view.

7. Cell movement — `ejn:worksheet-move-cell-down` and `ejn:worksheet-move-cell-up` swap the cell at point with its neighbor in `:cells`, rename shadow files to preserve lexicographic order, and refresh the master view.

8. Cell deletion — `ejn:worksheet-kill-cell` removes the cell at point from `:cells`, kills its buffer if live, removes its shadow file from `.ejn-cache/`, and refreshes the master view. Prompts for confirmation if the cell is dirty.

9. Cell split & merge — `ejn:worksheet-split-cell-at-point` divides the current cell at point's line into two cells (above stays, below becomes new cell), both inheriting the original type. `ejn:worksheet-merge-cell` concatenates the current cell with the one below (blank line separator) and removes the lower cell.

10. Cell copy & yank — `C-c C-w` / `C-c M-w` (`ejn:worksheet-copy-cell`) deep-copies the cell's source and type onto `ejn-notebook`'s `ejn-cell-kill-ring` slot. `C-c C-w` additionally kills the cell (cut). `C-c C-y` (`ejn:worksheet-yank-cell`) inserts a new cell below point from the top of the kill ring.

11. Cell navigation — `ejn:worksheet-goto-next-input` and `ejn:worksheet-goto-prev-input` move point between cells in the master view or switch focus between cell buffers.

12. Notebook save — `ejn:notebook-save-notebook-command` flushes all dirty cell buffers to the EIEIO model, serializes the notebook back to a valid `.ipynb` JSON file at `:path`, clears all dirty flags, and returns t on success.

13. Notebook rename — `ejn:notebook-rename-command` prompts for a new filename, renames the `.ipynb` file on disk, updates the `:path` slot, renames `.ejn-cache/<notebook-stem>/` to match, and returns t.

14. Two-way buffer sync — `ejn-cell-refresh-buffer` updates a cell buffer from its EIEIO object using `replace-buffer-contents`, preserving point position. `ejn-notebook-of-buffer` returns the notebook object from a cell buffer's back-pointer.

15. Keymap & stub commands — `ejn-mode` minor mode registers all keybindings from `keymap.md`. Unimplemented Phase 4 commands are registered as stubs that display a "not yet implemented" message. `M-<down>` / `M-<up>` are `ignore` stubs.

## Out of scope

- LSP integration (composite file, cursor translation, lsp-virtual-buffer) — Phase 3.
- Kernel communication & execution (ZMQ, iopub handlers, output rendering) — Phase 4.
- Output rendering for any MIME type — Phase 4.
- Global undo manager (notebook-wide undo stack) — Phase 5.
- Polymode master view composition — Phase 5.
- Markdown cell rendering (formatted display) — Phase 5.
- Cell type toggling between code and markdown — Phase 5.
- Lazy buffer initialization for large notebooks — Phase 5.
- Scratchsheet buffer — Phase 5.
- Traceback viewer — Phase 5.
- `ejn:notebook-open` (Jupyter server sessions) — Phase 4 (stub only in Phase 2).
- `ejn:worksheet-execute-cell-and-insert-below` (`M-S-<return>`) — Phase 4 (stub only in Phase 2).
- `ejn:worksheet-execute-cell-and-goto-next` (`M-RET`) — Phase 4 (stub only in Phase 2).
- `ejn:notebook-reconnect-session` — Phase 4 (stub only in Phase 2).
- `ejn:notebook-kill-kernel-then-close` — Phase 4 (stub only in Phase 2).
- `ejn:worksheet-clear-output`, `ejn:worksheet-clear-all-output` — Phase 4 (stub only in Phase 2).
- `ejn:worksheet-toggle-output`, `ejn:worksheet-set-output-visibility-all` — Phase 4 (stub only in Phase 2).
- `ejn:tb-show`, `ejn:shared-output-show-code-cell-at-point` — Phase 5 (stub only in Phase 2).
- `eglot` equivalent for LSP (Phase 3 concern, deferred).
- Hybrid completion (Phase 3 concern, deferred).

## Architecture

### Data model

| Entity | Field | Type | Default | Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `ejn-notebook` | `path` | string | required | Absolute path to `.ipynb` file on disk. Read after initialization. |
| `ejn-notebook` | `metadata` | list | `nil` | Parsed from `.ipynb` top-level metadata object. |
| `ejn-notebook` | `cells` | list | `nil` | Ordered list of `ejn-cell` objects. Index determines display order. |
| `ejn-notebook` | `kernel-id` | string or `nil` | `nil` | Reserved for Phase 4. Not set in Phase 2. |
| `ejn-notebook` | `ejn-cell-kill-ring` | list | `nil` | Internal kill ring for cell copy/yank. Top entry is most recent copy. Separate from Emacs's `kill-ring`. |
| `ejn-notebook` | `master-buffer` | buffer or `nil` | `nil` | Buffer-local back-pointer: the master view buffer. Used to retrieve notebook from any cell buffer. |
| `ejn-cell` | `id` | string | generated | Unique cell identifier. Generated via `cl-gensym` at creation time. |
| `ejn-cell` | `type` | symbol | required | One of: `'code`, `'markdown`, `'raw`. |
| `ejn-cell` | `source` | string | required | Cell source code or markdown text. Source of truth for EIEIO model. |
| `ejn-cell` | `outputs` | list | `nil` | Parsed from `.ipynb` outputs array. Populated in Phase 4. |
| `ejn-cell` | `buffer` | buffer or `nil` | `nil` | The dedicated cell editing buffer. Set when `ejn-cell-open-buffer` is called. |
| `ejn-cell` | `shadow-file` | string or `nil` | `nil` | Path to the shadow file on disk. Set when `ejn-shadow-write-cell` is called. |
| `ejn-cell` | `exec-count` | integer or `nil` | `nil` | Execution count from `.ipynb`. Populated in Phase 4. |
| `ejn-cell` | `dirty` | boolean | `nil` | Set by `after-change-functions` when buffer content diverges from `:source`. Cleared by `ejn-shadow-sync-cell`. |

Note: `ejn-notebook` instances are stored as a buffer-local variable in the master view buffer. Cell buffers access the notebook via `ejn-notebook-of-buffer` which reads the master view's buffer-local variable.

### Interface contracts

#### `ejn-notebook-load` — `lisp/ejn-core.el`
```
Argument: file-path (string) — absolute path to `.ipynb` file
Returns: ejn-notebook object
Behavior: Reads JSON from file, determines nbformat version, parses cells
  into ejn-cell objects, appends to :cells list, returns the notebook.
Error: Signal file-error if file does not exist. Signal json-error if
  file is not valid JSON or not a recognized nbformat.
```

#### `ejn-notebook-save` — `lisp/ejn-core.el`
```
Argument: notebook (ejn-notebook)
Returns: t on success, nil on failure
Behavior: Flushes all dirty cell buffers to EIEIO model via
  after-change-functions. Serializes notebook to valid .ipynb JSON at
  :path slot. Clears all :dirty flags after successful write.
```

#### `ejn-shadow-write-cell` — `lisp/ejn-core.el`
```
Argument: cell (ejn-cell), notebook (ejn-notebook)
Returns: string (absolute path to shadow file)
Behavior: Creates .ejn-cache/<notebook-stem>/ directory if needed.
  Generates zero-padded filename based on cell index in :cells list.
  Extension determined by cell type: code→.py, markdown→.md, raw→.raw.
  Writes :source to file. Updates cell's :shadow-file slot.
```

#### `ejn-shadow-sync-cell` — `lisp/ejn-core.el`
```
Argument: cell (ejn-cell)
Returns: t if file was written, nil if no changes
Behavior: Reads current buffer content (from cell's :buffer).
  Compares against cell's :source slot. If different, updates :source,
  writes to shadow file atomically (.tmp → rename-file), clears :dirty
  flag, returns t. If identical, returns nil.
```

#### `ejn-cell-dirty-p` — `lisp/ejn-core.el`
```
Argument: cell (ejn-cell)
Returns: boolean
Behavior: Returns cell's :dirty slot value.
```

#### `ejn-cell-open-buffer` — `lisp/ejn-cell.el`
```
Argument: cell (ejn-cell)
Returns: buffer (the cell's editing buffer)
Behavior: If cell's :buffer slot is live, switch to it. Otherwise
  create a new buffer with :source content, set major-mode to
  python-mode for code cells / markdown-mode for markdown cells,
  attach after-change-functions hook for dirty tracking, update
  :buffer and :shadow-file slots, return the buffer.
```

#### `ejn-cell-refresh-buffer` — `lisp/ejn-cell.el`
```
Argument: cell (ejn-cell)
Returns: nil
Behavior: Calls replace-buffer-contents with cell's :source content.
  Preserves point position and undo history.
```

#### `ejn-notebook-of-buffer` — `lisp/ejn-core.el`
```
Argument: buffer (buffer, optional — defaults to current buffer)
Returns: ejn-notebook object
Behavior: Reads the buffer-local ejn-notebook variable from the
  master view buffer. Returns nil if no notebook is associated.
```

#### `ejn-open-file` — `ejn.el`
```
Argument: none (interactive, prompts for .ipynb file path)
Returns: nil
Behavior: Prompts for file path. Calls ejn-notebook-load. Creates
  master view buffer. Opens first cell buffer. Returns nil.
```

#### Structural commands — `lisp/ejn-cell.el`
```
ejn:worksheet-insert-cell-above — inserts new ejn-cell before cell at point
ejn:worksheet-insert-cell-below — inserts new ejn-cell after cell at point
ejn:worksheet-move-cell-up      — swaps cell at point with predecessor
ejn:worksheet-move-cell-down    — swaps cell at point with successor
ejn:worksheet-kill-cell         — removes cell at point (prompts if dirty)
ejn:worksheet-split-cell-at-point — splits current cell at line of point
ejn:worksheet-merge-cell        — merges current cell with cell below
ejn:worksheet-copy-cell         — copies current cell to kill ring (C-w cuts, M-w copies)
ejn:worksheet-yank-cell         — inserts new cell below from kill ring
ejn:worksheet-goto-next-input   — navigates to next cell
ejn:worksheet-goto-prev-input   — navigates to previous cell
```

#### Notebook file commands — `lisp/ejn-notebook.el`
```
ejn:notebook-save-notebook-command — flushes dirty buffers, serializes to .ipynb
ejn:notebook-rename-command        — prompts for new name, renames file + cache dir
ejn:file-open                      — alias for ejn-open-file
ejn:notebook-open                  — stub (not yet implemented)
```

#### Keymap — `lisp/ejn.el`
```
ejn:pytools-not-move-cell-down-km  → ignore (M-<down> stub)
ejn:pytools-not-move-cell-up-km    → ignore (M-<up> stub)
```

All structural commands reserve a hook point for Phase 5 global undo via
`ejn--record-structural-change` (no-op in Phase 2).

### Tech stack

| Tool | Rationale |
| :--- | :--- |
| EIEIO `defclass` | Built into Emacs core. Provides slot types, initargs, and OOP hierarchy matching the roadmap's architectural pillar. |
| `json-parse-buffer` | Native JSON parser (Emacs 27+), returns hash tables, faster than `json-read`. Minimum version 30.1 satisfies this. |
| `cl-gensym` | Built-in unique symbol generator. Produces session-unique cell IDs without external dependencies. |
| `insert-text-button` | Built-in interactive button widget for master view cell entries. |
| `replace-buffer-contents` | Built-in (Emacs 27.1+), preserves point position and undo history when updating cell buffers. |
| `rename-file` | Built-in atomic file rename for shadow file sync (.tmp → real). |
| `after-change-functions` | Built-in Emacs hook for detecting buffer modifications in cell buffers. |

### Non-goals

- Kernel language detection from kernelspec — all code cells default to `python-mode` for Phase 2. Language-specific mode selection is a Phase 3 concern.
- nbformat version writing during save — save always writes nbformat 4.x. Reading nbformat 3.x is supported for loading only.
- Concurrent buffer access safety — not a concern since Emacs is single-threaded. Buffer modifications happen sequentially.
- Performance optimization for large notebooks — lazy initialization is a Phase 5 concern. All buffers are created at open time in Phase 2.
- nbconvert or export functionality — exporting to HTML/PDF is out of scope.

## Task list

### Phase 2 — Buffer-Cell Mapping & Virtual File System

#### EIEIO Data Model

- [x] P2-T1 Define `ejn-notebook` and `ejn-cell` EIEIO classes in `lisp/ejn-core.el` [tdd] (data model — EIEIO defclass with slot types, initargs, and all fields from data model table. `ejn-notebook` slot `cells` holds ordered `ejn-cell` list. `ejn-cell` slot `type` is symbol (`'code`, `'markdown`, `'raw`). `ejn-notebook` slot `ejn-cell-kill-ring` is list.)

#### JSON Parser & `.ipynb` Loader

- [x] P2-T2 Implement `ejn-notebook-load` in `lisp/ejn-core.el` [tdd] (parsing logic + I/O — reads file with `json-parse-buffer`, detects nbformat version, dispatches to nbformat 4.x or 3.x parser, returns `ejn-notebook` object)
- [x] P2-T3 Implement nbformat 4.x cell parser in `lisp/ejn-core.el` [tdd] (conditional data transformation — reads `notebook["cells"]` array, maps each JSON cell to `ejn-cell` via `ejn--parse-cell-data` helper, returns list of `ejn-cell` objects)
- [x] P2-T4 Implement nbformat 3.x cell parser in `lisp/ejn-core.el` [tdd] (conditional data transformation — reads `notebook["worksheets"][0]["cells"]` array, same mapping as nbformat 4.x but with different source path)
- [x] P2-T5 Implement `ejn--parse-cell-data` helper in `lisp/ejn-core.el` [tdd] (data transformation + error handling — takes a single cell JSON object, extracts `cell_type`, `source`, `outputs`, `execution_count`, creates `ejn-cell` instance, returns object)

#### Shadow File Layer

- [x] P2-T6 Implement `ejn-shadow-write-cell` in `lisp/ejn-core.el` [tdd] (I/O + state mutation — creates `.ejn-cache/<notebook-stem>/` directory via `make-directory`, zero-pads filename based on cell index, determines extension by cell type (`code`→`.py`, `markdown`→`.md`, `raw`→`.raw`), writes `:source` to disk, updates `:shadow-file` slot, returns file path)
- [x] P2-T7 Implement `ejn-shadow-sync-cell` in `lisp/ejn-core.el` [tdd] (state mutation + conditional + I/O — reads buffer content via `:buffer`, compares against `:source`, if different updates `:source`, writes atomically using `.tmp` + `rename-file`, clears `:dirty` flag, returns t; if identical returns nil)
- [x] P2-T8 Attach `after-change-functions` hook in cell buffers in `lisp/ejn-cell.el` [tdd] (state mutation + hook registration — in `ejn-cell-open-buffer`, registers `ejn--cell-after-change-hook` as a buffer-local hook, hook calls `ejn-shadow-sync-cell` and sets `:dirty` slot, ensures hook is removed when buffer is killed)
- [x] P2-T9 Implement `ejn--flush-all-dirty-cells` in `lisp/ejn-core.el` [tdd] (state mutation + I/O — iterates notebook's `:cells` list, for each cell with `:dirty` set and `:buffer` live, calls `ejn-shadow-sync-cell` to flush buffer content into `:source` slot)

#### Master View Buffer

- [x] P2-T10 Implement `ejn--create-master-view` in `lisp/ejn-master.el` [tdd] (interactive I/O + state mutation — creates `special-mode` buffer, stores `ejn-notebook` as buffer-local variable, sets up `kill-buffer-hook` to call `ejn--cleanup-master-view`, populates initial cell list via `ejn--render-master-cells`, returns buffer)
- [x] P2-T11 Implement `ejn--render-master-cells` in `lisp/ejn-master.el` [tdd] (data transformation + I/O — iterates notebook's `:cells` list, for each cell creates button text with format `[Type | In [N]] source_preview`, uses `insert-text-button` with `ejn-cell-open-buffer` as the action, separates cells with newline, refreshes display)
- [x] P2-T12 Implement `ejn--render-master-cells` refresh variant in `lisp/ejn-master.el` [tdd] (state mutation — same logic as P2-T11 but called after structural cell operations to re-render without recreating the buffer, handles button removal and re-insertion)

#### Cell Buffers & Two-Way Sync

- [x] P2-T13 Implement `ejn-cell-open-buffer` in `lisp/ejn-cell.el` [tdd] (state mutation + conditional I/O — if `:buffer` is live switches to it, otherwise creates new buffer with `:source` content, sets `major-mode` (`python-mode` for code, `markdown-mode` for markdown), attaches `after-change-functions` hook, sets buffer-local `ejn-notebook` back-pointer, updates `:buffer` and `:shadow-file` slots)
- [x] P2-T14 Implement `ejn-cell-refresh-buffer` in `lisp/ejn-cell.el` [tdd] (state mutation — calls `replace-buffer-contents` with `:source`, preserves point position and undo history)
- [x] P2-T15 Implement `ejn-notebook-of-buffer` in `lisp/ejn-core.el` [smoke] (simple accessor — reads buffer-local `ejn-notebook` from master view buffer, returns `ejn-notebook` object or nil)

#### Cell Structural Operations

- [x] P2-T16 Implement `ejn--make-cell` helper in `lisp/ejn-cell.el` [tdd] (state mutation — creates `ejn-cell` via `cl-gensym` for `:id`, accepts `:type` and `:source`, inserts at correct index in notebook's `:cells` list using `cl-position`, calls `ejn-shadow-write-cell`, calls `ejn--render-master-cells`, reserves `ejn--record-structural-change` hook)
- [x] P2-T17 Implement `ejn:worksheet-insert-cell-above` and `ejn:worksheet-insert-cell-below` in `lisp/ejn-cell.el` [smoke] (structural wiring — delegates to `ejn--make-cell` with correct index: `cl-position` of current cell at point minus 1 for above, plus 1 for below. Interactive commands.)
- [x] P2-T18 Implement `ejn:worksheet-move-cell-up` and `ejn:worksheet-move-cell-down` in `lisp/ejn-cell.el` [tdd] (state mutation + I/O — gets cell at point via `cl-position`, swaps with predecessor or successor in `:cells` list via `cl-substitute` or manual splice, renames shadow files for affected cells by recalculating indices, calls `ejn--render-master-cells`)
- [x] P2-T19 Implement `ejn:worksheet-kill-cell` in `lisp/ejn-cell.el` [tdd] (I/O + conditional — gets cell at point, if `:dirty` prompts for confirmation via `y-or-n-p`, removes from `:cells` list via `cl-position` + `delq`, kills buffer if live via `kill-buffer`, removes shadow file via `delete-file`, calls `ejn--render-master-cells`)
- [x] P2-T20 Implement `ejn:worksheet-split-cell-at-point` in `lisp/ejn-cell.el` [tdd] (data transformation + state mutation — gets current cell at point, splits `:source` string at the line of point into `before` and `after` parts, creates new cell with `after` part below current cell, sets current cell's `:source` to `before`, both share original `:type`, calls `ejn-shadow-write-cell` on both, calls `ejn--render-master-cells`)
- [x] P2-T21 Implement `ejn:worksheet-merge-cell` in `lisp/ejn-cell.el` [tdd] (data transformation + state mutation — gets current cell and cell below, concatenates sources with blank line separator, updates current cell's `:source`, removes lower cell from `:cells` via `cl-position` + `delq`, calls `ejn-shadow-write-cell` on current cell, calls `ejn--render-master-cells`)
- [x] P2-T22 Implement `ejn:worksheet-copy-cell` in `lisp/ejn-cell.el` [tdd] (state mutation — gets cell at point, creates shallow copy of `:source` and `:type` onto `ejn-notebook`'s `ejn-cell-kill-ring` slot (cons onto list). `C-c C-w` additionally calls `ejn:worksheet-kill-cell`. `C-c M-w` only copies.)
- [x] P2-T23 Implement `ejn:worksheet-yank-cell` in `lisp/ejn-cell.el` [tdd] (state mutation + I/O — pops top entry from `ejn-notebook`'s `ejn-cell-kill-ring`, creates new cell below point with copied `:source` and `:type`, calls `ejn-shadow-write-cell`, calls `ejn--render-master-cells`)
- [x] P2-T24 Implement `ejn:worksheet-goto-next-input` and `ejn:worksheet-goto-prev-input` in `lisp/ejn-cell.el` [smoke] (structural — if in master view, moves point to next/previous cell button via `next-button`/`previous-button` in `special-mode`. If in cell buffer, switches to the next/previous cell's buffer via `ejn-cell-open-buffer`.)

#### Notebook File Commands

- [x] P2-T25 Implement `ejn:notebook-save-notebook-command` in `lisp/ejn-notebook.el` [tdd] (I/O + conditional — retrieves notebook via `ejn-notebook-of-buffer`, calls `ejn--flush-all-dirty-cells` to sync all dirty buffers, serializes notebook to `.ipynb` JSON at `:path` using `json-encode`, clears all `:dirty` flags, returns t. Interactive command.)
- [x] P2-T26 Implement `ejn:notebook-rename-command` in `lisp/ejn-notebook.el` [tdd] (I/O + state mutation — prompts for new filename via `read-file-name`, renames `.ipynb` file via `rename-file`, updates `:path` slot, extracts new stem and renames `.ejn-cache/<old-stem>/` directory to `.ejn-cache/<new-stem>/`, returns t. Interactive command.)
- [x] P2-T27 Implement `ejn:file-open` alias in `lisp/ejn-notebook.el` [smoke] (structural — alias for `ejn-open-file`.)

#### Keymap & Stubs

- [x] P2-T28 Define `ejn-mode` minor mode in `ejn.el` [smoke] (structural wiring — `define-minor-mode` registering keymap, binds all commands from `keymap.md`. Activates in master view and cell buffers.)
- [x] P2-T29 Define stub commands in `ejn.el` [smoke] (structural — `ejn:pytools-not-move-cell-down-km` and `ejn:pytools-not-move-cell-up-km` as `ignore` functions. `ejn:notebook-open`, `ejn:worksheet-execute-cell-and-insert-below`, and other Phase 4 stubs display "not yet implemented" via `user-error`.)

#### Phase 2 Fixes — Inspection Defects

- [x] P2-T30 Enable `ejn-mode` in master view buffers in `lisp/ejn-master.el` [smoke] (structural wiring — call `(ejn-mode 1)` at the end of `ejn--create-master-view` after `special-mode` is set, so the keymap is active in the master view.)
- [x] P2-T31 Enable `ejn-mode` in cell buffers in `lisp/ejn-cell.el` [smoke] (structural wiring — call `(ejn-mode 1)` inside the `with-current-buffer` block of `ejn-cell-open-buffer`, after major-mode is set, so the keymap is active in every cell editing buffer.)
- [x] P2-T32 Bind `C-c C-w` as cut (copy + kill) in `ejn.el` [smoke] (keymap — define `ejn:worksheet-cut-cell` interactive wrapper that calls `(ejn:worksheet-copy-cell t)`, bind `C-c C-w` to it in `ejn-mode-map`. Keeps `C-c M-w` → copy-only.)
- [x] P2-T33 Implement `ejn--reindex-shadow-files` in `lisp/ejn-core.el` [tdd] (I/O + state mutation — iterates all cells in NOTEBOOK's `:cells` list, for each cell deletes its old shadow file if it exists and differs from the new path, then calls `ejn-shadow-write-cell` to write at the correct zero-padded index. Used after structural operations to prevent stale paths.)
- [x] P2-T34 Call `ejn--reindex-shadow-files` in `ejn--make-cell` in `lisp/ejn-cell.el` [tdd] (structural wiring — after inserting a new cell at an index, all cells from that index onward shift by one. Call `ejn--reindex-shadow-files` to update their shadow file paths.)
- [x] P2-T35 Call `ejn--reindex-shadow-files` in `ejn:worksheet-kill-cell` in `lisp/ejn-cell.el` [tdd] (structural wiring — after removing a cell, all cells below the removed index shift down by one. Call `ejn--reindex-shadow-files` to update their shadow file paths.)
- [x] P2-T36 Call `ejn--reindex-shadow-files` in `ejn:worksheet-split-cell-at-point` in `lisp/ejn-cell.el` [tdd] (structural wiring — after splitting a cell, the new cell is inserted and all subsequent cells shift. Call `ejn--reindex-shadow-files` to update all affected shadow file paths.)
- [x] P2-T37 Call `ejn--reindex-shadow-files` in `ejn:worksheet-merge-cell` in `lisp/ejn-cell.el` [tdd] (structural wiring — after removing the lower cell, all cells below shift down. Call `ejn--reindex-shadow-files` to update all affected shadow file paths.)
- [x] P2-T38 Implement save round-trip tests in `test/ejn-notebook-tests.el` [tdd] (I/O — test `ejn:notebook-save-notebook-command` flushes dirty buffers, serializes to valid nbformat 4.x JSON, and re-opens with identical cell count, types, and sources.)
- [x] P2-T39 Implement `ejn:file-open` alias test in `test/ejn-notebook-tests.el` [smoke] (structural — verify `ejn:file-open` is `fboundp` and is equivalent to `ejn-open-file`.)

## Open questions

- [x] Emacs minimum version → 30.1 (confirmed, matches Eask).
- [x] Data model definition style → EIEIO `defclass` (built-in, roadmap-specified, architectural pillar).
- [x] Cell ID generation → `cl-gensym` (built-in, session-unique, no extra dependency).
- [x] Cell kill ring storage → slot on `ejn-notebook` object (deterministic per-notebook scoping via back-pointer).
- [x] Shadow file extension → by cell type: code→`.py`, markdown→`.md`, raw→`.raw`.
- [x] Save behavior with open buffers → two-phase flush (force-sync all dirty cell buffers to EIEIO model before serialization).
