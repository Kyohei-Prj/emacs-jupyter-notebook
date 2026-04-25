# EJN Development Roadmap

This roadmap is designed to move from a structural skeleton to a fully integrated IDE experience. By the end of each phase, you will have a "runnable" artifact that validates the core assumptions of your architecture. Each phase builds directly on the previous one — no phase assumes work that hasn't been completed.

---

## Phase 1: Scaffolding & Environment (The Skeleton)

**Goal:** Establish the project's physical presence and automated workflow. No logic is implemented here — only the "containers" that will hold it. A developer checking out this repo at the end of Phase 1 should be able to run `make install` and `make test` and get a passing (empty) test suite.

### 1.1 Directory Structure

Create the canonical directory layout for an Eask-based Emacs package:

```
ejn/
├── lisp/
│   ├── ejn.el
│   ├── ejn-core.el
│   ├── ejn-network.el
│   └── ejn-lsp.el
├── test/
│   └── ejn-test.el
├── .ejn-cache/          ← gitignored; holds shadow files at runtime
├── Eask
├── Makefile
└── README.md
```

The `.ejn-cache/` directory must be added to `.gitignore` immediately. It is a runtime artifact and must never be committed.

### 1.2 Eask File & Dependency Declaration

The `Eask` file is the single source of truth for all runtime and development dependencies. Pin each package to a minimum version to prevent silent breakage from upstream changes.

```elisp
(package "ejn" "0.1.0" "Emacs Jupyter Notebook")

(depends-on "dash"     "2.19.0")
(depends-on "s"        "1.13.0")
(depends-on "f"        "0.20.0")
(depends-on "jupyter"  "0.8.0")
(depends-on "polymode" "0.2.2")

(development
 (depends-on "buttercup")
 (depends-on "undercover"))
```

### 1.3 Template Source Files

Each file is created with only its package header, `require` statements, and a `provide` form at the bottom. No logic yet — the goal is to confirm the load path is correct and all `require` chains resolve cleanly.

- **`ejn.el`** — Top-level entry point. `require`s all sub-modules and exposes the public-facing autoloads.
- **`ejn-core.el`** — Will hold EIEIO class definitions. For now, just the file skeleton.
- **`ejn-network.el`** — Will wrap `jupyter.el` kernel connections. For now, just the file skeleton.
- **`ejn-lsp.el`** — Will manage shadow file generation and `lsp-mode` integration. For now, just the file skeleton.

### 1.4 CI/CD & Makefile

The `Makefile` provides three targets that cover the full local development loop:

```makefile
install:
	eask install-deps

test:
	eask test buttercup

lint:
	eask lint package
```


### Phase 1 Deliverable

A repository that loads without errors (`M-x load-file ejn.el` produces no warnings), passes an empty test suite, and has CI running green on GitHub.

---

## Phase 2: Buffer-Cell Mapping & Virtual File System

**Goal:** Create a working prototype that can open a `.ipynb` file, parse it into structured EIEIO objects, and split it into individual, independently editable buffers — all kept in sync with a central data model.

### 2.1 EIEIO Data Model (`ejn-core.el`)

Define two classes that model the complete notebook state in memory.

**`ejn-notebook`** holds notebook-level metadata and owns all cells:

```elisp
(defclass ejn-notebook ()
  ((path       :initarg :path       :type string)
   (metadata   :initarg :metadata   :type list)
   (cells      :initarg :cells      :initform nil :type list)
   (kernel-id  :initarg :kernel-id  :initform nil)))
```

**`ejn-cell`** represents a single cell and owns its buffer association:

```elisp
(defclass ejn-cell ()
  ((id          :initarg :id          :type string)
   (type        :initarg :type        :type symbol)   ; 'code or 'markdown
   (source      :initarg :source      :type string)
   (outputs     :initarg :outputs     :initform nil)
   (buffer      :initarg :buffer      :initform nil)
   (shadow-file :initarg :shadow-file :initform nil)
   (exec-count  :initarg :exec-count  :initform nil)))
```

Each `ejn-notebook` instance is stored in a buffer-local variable in the master view buffer so it can be retrieved from any child cell buffer via a back-pointer.

### 2.2 JSON Parser & `.ipynb` Loader

Implement `ejn-notebook-load` using Emacs's native `json-parse-buffer` (available since Emacs 27) rather than `json-read`, which is slower and produces alists rather than hash tables.

The parser must handle the two current `.ipynb` format versions:
- **nbformat 4.x** (the current standard): cells are at `notebook["cells"]`.
- **nbformat 3.x** (legacy, but common in old repos): cells are nested under `notebook["worksheets"][0]["cells"]`.

Each parsed cell is immediately instantiated as an `ejn-cell` object and appended to the parent notebook's `:cells` slot.

### 2.3 The Shadow File Layer

The shadow file system is the foundation of EJN's LSP compatibility. It lives entirely in `.ejn-cache/` and is structured as follows:

```
.ejn-cache/
├── <notebook-stem>/
│   ├── cell_001.py
│   ├── cell_002.py
│   └── composite.py     ← generated in Phase 3
```

**Writing shadow files:** `ejn-shadow-write-cell` serializes a cell's `:source` to disk. The filename is zero-padded to allow lexicographic sorting to match notebook order.

**Syncing changes back:** Hook into `after-change-functions` in each cell buffer. The hook calls `ejn-shadow-sync-cell`, which diffs the buffer content against the EIEIO object's `:source` slot and updates both the in-memory object and the shadow file atomically (write to a `.tmp` file, then `rename-file`).

**Dirty tracking:** Add an `ejn-cell-dirty-p` flag that is set by `after-change-functions` and cleared after a successful sync. This feeds the save prompt in `ejn-notebook-save`.

### 2.4 Master View Buffer

The master view is a read-only buffer (using `special-mode` as its base) that lists all cells as interactive buttons. It is not the editing surface — it is the navigation hub.

Each cell is rendered as a button using `insert-text-button`:

```
[Code  | In [1]] ──────────────────────────────────────
import pandas as pd
df = pd.read_csv("data.csv")

[Markdown] ─────────────────────────────────────────────
## Data Overview
```

Clicking a cell button calls `ejn-cell-open-buffer`, which creates (or switches to) that cell's dedicated editing buffer.

### 2.5 Cell Structural Operations

With the EIEIO model and master view in place, implement the full set of cell manipulation commands. These are pure data model operations — they mutate the notebook's `:cells` list, rename shadow files on disk, and refresh the master view. No kernel or LSP is required.

**Insertion commands** create a new `ejn-cell` object with a generated UUID, insert it at the correct index in the `:cells` list, write its (empty) shadow file, and re-render the master view:

- **`C-c C-a` (`ejn:worksheet-insert-cell-above`)** — inserts a new code cell before the cell at point.
- **`C-c C-b` (`ejn:worksheet-insert-cell-below`)** — inserts a new code cell after the cell at point.
- **`M-S-<return>` (`ejn:worksheet-execute-cell-and-insert-below`)** — reserved for Phase 4; register the keybinding now but leave it unimplemented with a message.

**Movement commands** swap the cell at point with its neighbour in the `:cells` list, then rename shadow files to keep filenames in sync with list order (e.g. `cell_002.py` ↔ `cell_003.py`), and refresh the master view:

- **`C-c <down>` / `M-<down>` (`ejn:worksheet-move-cell-down`)** — moves the current cell one position down.
- **`C-c <up>` / `M-<up>` (`ejn:worksheet-move-cell-up`)** — moves the current cell one position up.

Note: `M-<down>` and `M-<up>` map to `ejn:worksheet-not-move-cell-down-km` / `ejn:worksheet-not-move-cell-up-km` in the keymap — these are intentional no-ops that shadow conflicting global bindings. Implement them as `ignore` stubs to prevent accidental window/paragraph movement inside a cell buffer.

**Destructive commands** operate on the `:cells` list and clean up the corresponding shadow files from `.ejn-cache/`:

- **`C-c C-k` (`ejn:worksheet-kill-cell`)** — removes the cell at point from the notebook. Kills its buffer if live. Prompts for confirmation if the cell has unsaved content (dirty flag set).

**Split & merge commands** divide or combine cell source content:

- **`C-c C-s` (`ejn:worksheet-split-cell-at-point`)** — splits the current cell at point's line into two cells. The content above point stays in the original cell; content from point downward becomes a new cell inserted immediately below. Both cells share the original cell's type.
- **`C-c RET` (`ejn:worksheet-merge-cell`)** — merges the current cell with the cell directly below it, concatenating their source with a blank line separator. The lower cell is then removed.

**Copy & yank commands** use an internal `ejn-cell-kill-ring` (a simple list on the notebook object, separate from Emacs's main kill ring) to allow copying and pasting entire cells:

- **`C-c C-w` / `C-c M-w` (`ejn:worksheet-copy-cell`)** — deep-copies the current cell's source and type onto `ejn-cell-kill-ring`. `C-c C-w` additionally kills the cell (cut); `C-c M-w` only copies (copy without delete).
- **`C-c C-y` (`ejn:worksheet-yank-cell`)** — inserts a new cell below point, initialized from the top of `ejn-cell-kill-ring`.

**Navigation commands** move point between cells in the master view or switch focus between cell buffers:

- **`C-<down>` / `C-c C-n` (`ejn:worksheet-goto-next-input`)** — moves point to the next cell in the master view, or switches to the next cell buffer if called from within a cell buffer.
- **`C-<up>` / `C-c C-p` (`ejn:worksheet-goto-prev-input`)** — moves point to the previous cell.

All structural operations must record an entry on the global undo stack (introduced formally in Phase 5, but reserve the hook point now as a no-op `ejn--record-structural-change`). This ensures Phase 5 can retrofit undo support for structural edits without touching Phase 2 code.

### 2.6 Notebook File Commands

Implement the notebook-level file operations that do not depend on a live kernel:

- **`C-x C-s` (`ejn:notebook-save-notebook-command`)** — serializes the EIEIO model back to a valid `.ipynb` JSON file at the notebook's `:path`. Clears all dirty flags after a successful write.
- **`C-x C-w` (`ejn:notebook-rename-command`)** — prompts for a new filename, renames the file on disk, updates the `:path` slot, and renames the `.ejn-cache/<notebook-stem>/` directory to match.
- **`C-c C-f` (`ejn:file-open`)** — alias for `ejn-open-file`; opens a new notebook from a file path prompt.
- **`C-c C-o` (`ejn:notebook-open`)** — opens a notebook from the Jupyter server's list of running sessions (stub for now; requires kernel connection in Phase 4).

### 2.7 Two-Way Buffer Sync

Cell buffers must never drift from the EIEIO model. Implement two directions of sync:

- **Buffer → Model:** `after-change-functions` hook (described above).
- **Model → Buffer:** `ejn-cell-refresh-buffer`, called when an external event (e.g., kernel execution) modifies a cell's outputs. It uses `replace-buffer-contents` rather than `erase-buffer` + `insert` to preserve point position and undo history.

### Phase 2 Deliverable

An `ejn-open-file` command (`M-x ejn-open-file`) that prompts for a `.ipynb` file, opens the master view, and allows editing any cell in its own buffer. Changes made in a cell buffer are reflected in the EIEIO model and on disk in `.ejn-cache/`. The full set of structural commands — insert, kill, move, split, merge, copy, yank, and navigate — all work correctly and round-trip through save: a notebook edited structurally and saved produces a valid `.ipynb` that re-opens identically.

---

## Phase 3: LSP Integration (The Intelligence Layer)

**Goal:** Enable full code intelligence — completion, diagnostics, jump-to-definition, find-references — within cell buffers, with the LSP server aware of symbols defined in *other* cells of the same notebook.

### 3.1 The Composite Shadow File

The composite file solves the cross-cell awareness problem. It is a single Python file (`composite.py`) that concatenates the source of all code cells in order, separated by a sentinel comment that encodes the original cell index:

```python
# ejn:cell:0
import pandas as pd
df = pd.read_csv("data.csv")

# ejn:cell:1
print(df.head())
```

The composite file is regenerated any time a cell's source changes. Use a debounced idle timer (`run-with-idle-timer`) with a 0.3-second delay to avoid thrashing disk on every keystroke.

### 3.2 Cursor Position Translation

The LSP server sees the composite file. EJN must translate positions in both directions:

**Cell buffer → Composite file:** Given a `(line, col)` in `cell_002.py`, compute the equivalent line in `composite.py` by summing the line counts of all preceding cells plus their sentinel lines. Store this offset per cell in a slot added to `ejn-cell`.

**Composite file → Cell buffer:** Given an LSP response referencing a position in `composite.py`, reverse the mapping by scanning the cell offset table.

Implement `ejn-lsp-pos-to-composite` and `ejn-lsp-pos-from-composite` as pure functions with unit tests in Phase 1's test skeleton.

### 3.3 `lsp-virtual-buffer` Integration

Use `lsp-mode`'s `lsp-virtual-buffer` API to present each cell buffer to the LSP server as if it were the composite file, with position translation applied transparently:

```elisp
(lsp-virtual-buffer-register
  :real-buffer  (ejn-cell-buffer cell)
  :virtual-file (ejn-composite-path notebook)
  :offset-line  (ejn-cell-line-offset cell notebook))
```

This allows `lsp-mode` to route all language server requests through the composite mapping without any changes to `lsp-mode` itself.

For `eglot` users, implement an equivalent shim using `eglot`'s `eglot-managed-p` and `:textDocument/didChange` interception.

### 3.4 LSP Lifecycle Management

When `ejn-cell-open-buffer` creates a new cell buffer, it must:

1. Set `major-mode` to `python-mode` (or the kernel language's mode).
2. Set `default-directory` to the notebook's directory so `project.el` resolves the workspace root correctly.
3. Ensure the composite file exists on disk before calling `lsp` or `eglot`, since the LSP server may index it immediately on attach.
4. Call `lsp` (or `eglot`) to attach the server.

Add a buffer-local variable `ejn-cell-lsp-attached-p` to avoid double-attaching when a cell buffer is revisited.

### 3.5 Hybrid Completion

Layer two completion sources in `completion-at-point-functions`:

- **Static (LSP):** Types, imports, and names from the composite file, resolved by the language server.
- **Dynamic (Kernel):** Runtime values such as Pandas DataFrame column names, object attributes only knowable after execution. Implement `ejn-kernel-complete` which sends a `complete_request` to the Jupyter kernel and returns results asynchronously via a callback.

Use `cape-merge` (from the `cape` package) or a manual `:company-kind` discriminator to deduplicate results and rank kernel completions above LSP completions when inside a known runtime context (e.g., after a `df.` prefix).

### 3.6 Source Navigation Keybindings

With LSP fully live, wire the two navigation commands from the keymap that depend on an active language server:

- **`M-.` (`ejn:pytools-jump-to-source`)** — delegates to `lsp-find-definition` (or `eglot-find-definition`), routing the request through the composite file mapping so that jumping to a symbol defined in another cell lands in that cell's buffer at the correct line.
- **`M-,` (`ejn:pytools-jump-back`)** — delegates to `xref-pop-marker-stack` to return from a jump. No special EJN logic is needed here beyond ensuring the xref marker pushed by `M-.` references the originating cell buffer, not the composite file.

### Phase 3 Deliverable

Opening any cell buffer provides working `company-mode` or `corfu` completions that include symbols defined in other cells. `M-.` (jump-to-definition) and `M-,` (jump back) work across cell boundaries by routing through the composite file. Flycheck or Flymake diagnostics highlight real errors without false positives caused by missing cross-cell context.

---

## Phase 4: Communication & Execution

**Goal:** Connect to a live Jupyter kernel, execute cell code, and render all output types — including rich media like images and DataFrames — directly within Emacs.

### 4.1 Kernel Lifecycle Management (`ejn-network.el`)

Wrap `jupyter.el`'s connection primitives in a higher-level manager:

**`ejn-kernel-start`** launches or connects to a kernel:

```elisp
(defun ejn-kernel-start (notebook &optional kernel-name)
  "Start a kernel for NOTEBOOK, using KERNEL-NAME (default: notebook's kernelspec)."
  ...)
```

It stores the resulting `jupyter-kernel-client` in the notebook's `:kernel-id` slot.

**`ejn-kernel-manager`** is a buffer-local minor mode activated in the master view buffer. It displays kernel status in the mode-line using a sentinel that polls the kernel's heartbeat channel:

```
EJN [Python 3.11 | ●Idle]
```

States to handle: `starting`, `idle`, `busy`, `dead`. On `dead`, prompt the user to restart automatically.

### 4.2 Execution Pipeline

Implement `ejn-worksheet-execute-cell` (bound to `C-c C-c`) as the primary execution command:

1. Retrieve the cell object from the current buffer's back-pointer.
2. Send `(jupyter-execute-request client :code (buffer-string))`.
3. Mark the cell as busy (update mode-line indicator).
4. Register an `iopub` handler via `jupyter-add-receive-callback` to receive output messages asynchronously.

The `iopub` handler dispatches on `msg_type`:
- `stream` → append text to the output area.
- `execute_result` → render the `data` dict (see §4.3).
- `display_data` → same as `execute_result`.
- `error` → render traceback with ANSI color conversion.
- `status` with `execution_state: idle` → mark cell as idle, update execution count.

### 4.3 Output Rendering

Outputs are rendered below the cell's code content in a dedicated, read-only overlay region. Clear the region before each new execution.

Render each output type in priority order (richest first):

| MIME type | Rendering method |
| :--- | :--- |
| `text/html` | Convert to plain text via `shr-render-region` (built-in) |
| `image/png` | Decode base64, write to `.ejn-cache/output_N.png`, insert via `create-image` |
| `image/svg+xml` | Write SVG to disk, render with `create-image` using the `svg` type |
| `text/plain` | Insert directly with `ansi-color-apply` for ANSI escape codes |

Implement `ejn-output-clear` (bound to `C-c C-l`) and `ejn-worksheet-clear-all-output` (bound to `C-c C-S-l`) to wipe output areas.

### 4.4 Kernel Interrupt & Restart

- **`C-c C-z` (`ejn-notebook-kernel-interrupt`):** Sends a kernel interrupt signal via `jupyter-interrupt-kernel`. Use this when a cell is running too long.
- **`C-c C-x C-r` (`ejn-notebook-restart-session`):** Sends a restart request. After restart, prompt whether to re-execute all cells from the top (a full "Run All" pass).
- **`C-u C-c C-c` (`ejn-worksheet-execute-all-cells`):** Executes all cells sequentially, waiting for `idle` status between each before sending the next request. Implements a simple async queue using `cl-loop` and `accept-process-output`.

### 4.5 Output Visibility & Execute-Navigate Commands

With the output pipeline in place, implement the remaining keybindings that depend on output areas existing:

- **`C-c C-e` (`ejn:worksheet-toggle-output`)** — toggles the visibility of the output area for the cell at point. Uses the `invisible` text property on the output region rather than deleting it, so toggling back is instant and the output data is not lost.
- **`C-c C-v` (`ejn:worksheet-set-output-visibility-all`)** — applies the current cell's output visibility state to all cells in the notebook. Useful for quickly collapsing all outputs before presenting a notebook.
- **`M-RET` (`ejn:worksheet-execute-cell-and-goto-next`)** — executes the current cell (same pipeline as `C-c C-c`) and then moves point to the next cell. This mirrors the default Jupyter Notebook `Shift-Enter` workflow.
- **`M-S-<return>` (`ejn:worksheet-execute-cell-and-insert-below`)** — executes the current cell and inserts a new empty code cell immediately below, then moves point to it. Mirrors Jupyter's `Alt-Enter`. This activates the stub registered in Phase 2.
- **`C-c C-q` (`ejn:notebook-kill-kernel-then-close`)** — interrupts the kernel, waits for it to die, then closes the notebook and all associated cell buffers. Prompts to save if any cells are dirty.
- **`C-c C-r` (`ejn:notebook-reconnect-session`)** — drops the current ZMQ connection and re-establishes it without restarting the kernel process. Useful when the connection drops but the kernel is still alive.
- **`C-c C-o` (`ejn:notebook-open`)** — now fully implemented: queries the Jupyter server's `/api/sessions` endpoint via `ejn-network.el` and presents a completing-read of running sessions to attach to.

### Phase 4 Deliverable

`C-c C-c` in a cell buffer sends the code to a live Python kernel and renders text output and PNG plots directly below the code in the same buffer. The mode-line accurately reflects kernel state. `C-c C-z` reliably interrupts a hung cell.

---

## Phase 5: UI Refinement & Global UX

**Goal:** Replace the raw buffer scaffolding with a polished, cohesive notebook UI, and solve the distributed undo problem introduced by multi-buffer editing.

### 5.1 Visual Cell Styling

Replace plain buffer separators with styled text properties. Use `before-string` overlays on the first line of each cell buffer to display a "cell header" that includes the cell type and execution count without consuming actual buffer positions:

```
╔══ In [3]: ══════════════════════════════════════════╗
```

Implement using `put-text-property` with `display` and `before-string` rather than with overlays, to avoid the interaction bugs that plagued EIN. The cell type badge (`Code` / `Markdown`) and execution count are updated by `ejn-cell-refresh-header`, called after each execution.

Add margin decorations using `set-window-margins` and `display-margin` text properties to render the `In [N]:` indicator in the left margin, matching the visual convention of classic Jupyter Notebook.

### 5.2 Global Undo Manager

The standard Emacs undo system is per-buffer, which means undoing a change in Cell B cannot undo a preceding change in Cell A, even if the user made them sequentially. EJN's global undo manager solves this.

**Design:** Maintain a notebook-wide undo stack in the `ejn-notebook` object as a list of `ejn-undo-record` structures:

```elisp
(cl-defstruct ejn-undo-record
  cell-id    ; which cell was affected
  before     ; cell source before the change
  after      ; cell source after the change
  timestamp)
```

**Integration:** Override `undo` in all cell buffers with `ejn-global-undo`, which pops the top record from the notebook's stack, restores the named cell's buffer to `:before`, and moves point to that buffer — regardless of which cell is currently active.

Records are appended to the stack by a wrapper around `after-change-functions` that coalesces rapid typing into single records using a debounce window of 1 second (similar to how `undo-amalgamate-change-group` works).

### 5.3 Polymode Integration for the Master View

Replace the button-based master view with a true `polymode` composition that renders Markdown and Code cells in a single unified buffer, each with its own major mode applied to the appropriate region.

Define a `poly-ejn-mode` with:
- A **host mode** of `special-mode` for the inter-cell scaffold.
- An **inner mode** of `python-mode` for code cells, with chunk delimiters keyed on the sentinel comments written into the composite file format.
- An **inner mode** of `gfm-mode` (GitHub Flavored Markdown) or `markdown-mode` for Markdown cells.

This allows the master view to serve double duty: both navigation hub and a readable, rendered notebook surface. The individual cell buffers remain available for focused editing via `ejn-cell-open-buffer`.

### 5.4 Markdown Cell Rendering

Implement `ejn-markdown-render-cell` using `markdown-mode`'s `markdown-display-inline-images` or `shr-render-region` to render formatted Markdown in place (bold, italics, links, code spans) using text properties, without spawning an external process.

Add a toggle `ejn-worksheet-toggle-cell-type` (bound to `C-c C-t`) that switches a cell between `code` and `markdown` and immediately re-renders the master view.

### 5.5 Cell Type Commands

Finalize the two cell-type mutation commands, which require Polymode to be in place for proper re-rendering:

- **`C-c C-t` (`ejn:worksheet-toggle-cell-type`)** — cycles the current cell's type between `code` and `markdown`. After toggling, the cell's buffer major mode is updated (`python-mode` ↔ `markdown-mode`) and the master view re-renders the cell with the correct Polymode inner mode.
- **`C-c C-u` (`ejn:worksheet-change-cell-type`)** — presents a `completing-read` of all available cell types (including `raw` for nbformat raw cells) and applies the selection. More explicit than the toggle, useful when working with raw cells.

### 5.6 Notebook Utility & Scratchsheet Commands

Implement the remaining notebook-level commands that require the full UI to be in place:

- **`C-c C-#` (`ejn:notebook-close`)** — closes the notebook: kills all cell buffers, kills the master view buffer, and cleans up the `.ejn-cache/<notebook-stem>/` directory. Prompts to save if any cells are dirty. Does **not** kill the kernel (use `C-c C-q` for that).
- **`C-c C-/` (`ejn:notebook-scratchsheet-open`)** — opens a transient "scratch" cell buffer attached to the current notebook's kernel but not saved to the `.ipynb` file. Useful for quick experiments without polluting the notebook. The scratch buffer lives in `.ejn-cache/<stem>/scratch.py` and is gitignored by default.
- **`C-c C-$` (`ejn:tb-show`)** — opens a dedicated traceback buffer showing the full, syntax-highlighted traceback from the most recent kernel error. The buffer uses `python-mode` for ANSI-stripped traceback text and `compilation-mode`-style file links where the traceback references a source file.
- **`C-c C-;` (`ejn:shared-output-show-code-cell-at-point`)** — opens a shared output buffer that persists across cell executions, appending output from the current cell each time it is executed. Useful for monitoring long-running cells without the output being overwritten in place.

### 5.7 Lazy Buffer Initialization

Large notebooks (500+ cells) must not block Emacs at open time. Implement lazy initialization using a `window-scroll-functions` hook on the master view:

1. On `ejn-open-file`, parse all cells into EIEIO objects but do **not** create buffers, write shadow files, or attach LSP.
2. Hook `window-scroll-functions` on the master view buffer.
3. When a cell scrolls into the visible window area, call `ejn-cell-initialize` for that cell (create buffer, write shadow file, attach LSP after a short idle delay).
4. Mark initialized cells with a flag to avoid re-initialization on subsequent scrolls.

This ensures a 1000-cell notebook opens in under 500ms regardless of cell content.

### Phase 5 Deliverable

A production-quality notebook experience: a unified `poly-ejn-mode` view with rendered Markdown, styled code cells with margin indicators, and a global undo system that traverses changes chronologically across all cells — including structural operations like cell insertion and deletion. All keybindings from `keymap.md` are wired and functional. Large notebooks open instantly. The package is ready for an initial public release on MELPA.

---

## Summary of Milestones

| Phase | Working Prototype Capability | Key Technical Achievement |
| :--- | :--- | :--- |
| **Phase 1** | Repo loads, CI is green, `make test` passes. | Project scaffolding and toolchain. |
| **Phase 2** | Open/edit/save `.ipynb`; insert, kill, move, split, merge, copy, and navigate cells. | EIEIO data model + shadow file layer + full structural editing. |
| **Phase 3** | Cross-cell LSP completion, jump-to-definition (`M-.`), and jump-back (`M-,`). | Composite file + position translation + LSP lifecycle. |
| **Phase 4** | Execute cells, render images/plots; output toggle, execute-and-navigate, kernel reconnect. | ZMQ kernel communication + output rendering + execute-flow commands. |
| **Phase 5** | Polished UI, global undo (including structural ops), cell type toggling, scratchsheet, traceback viewer. | Production-ready UX — all keymap bindings wired and functional. |
