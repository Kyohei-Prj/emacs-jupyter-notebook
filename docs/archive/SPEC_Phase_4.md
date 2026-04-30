## Goal

Connect a live Jupyter kernel to an EJN notebook, execute cell code, and render all output types — including rich media like images and HTML — directly within Emacs. The mode-line accurately reflects kernel state. Kernel interrupt, restart, and reconnect work reliably. Execute-and-navigate commands mirror the Jupyter Notebook workflow.

## Features

1. **Kernel start** — `ejn-kernel-start` creates a `jupyter-kernel-client`, stores it in the notebook's `:kernel-id` slot, activates the kernel manager minor mode in the master view buffer, and displays kernel status in the mode-line.

2. **Kernel manager minor mode** — `ejn-kernel-manager-mode` is a buffer-local minor mode active in the master view buffer. Displays `EJN [LANG | ●State]` in the mode-line. Handles states: `starting`, `idle`, `busy`, `dead`. On `dead`, prompts to restart.

3. **Execute cell** — `ejn:worksheet-execute-cell` (C-c C-c) sends the cell's source to the kernel via `jupyter-execute-request`, registers an iopub callback to dispatch messages by type, marks the cell busy, and updates mode-line on status changes.

4. **Execute and goto next** — `ejn:worksheet-execute-cell-and-goto-next` (M-RET) executes the current cell and moves point to the next cell buffer. Signals `user-error` if no next cell.

5. **Execute and insert below** — `ejn:worksheet-execute-cell-and-insert-below` (M-S-<return>) executes the current cell, inserts a new empty code cell below, and moves point to the new cell.

6. **Execute all cells** — `ejn:worksheet-execute-all-cells` (C-u C-c C-c) executes all code cells sequentially, waiting for `idle` status between each. Skips cells without live buffers.

7. **Output rendering** — Kernel output (stream, execute_result, display_data, error) is rendered below the cell's code in a dedicated overlay region using `jupyter-insert` for MIME dispatch. Output is cleared before each new execution.

8. **Clear output** — `ejn:worksheet-clear-output` (C-c C-l) clears the output overlay for the current cell. `ejn:worksheet-clear-all-output` (C-c C-S-l) clears all cells' output overlays.

9. **Toggle output visibility** — `ejn:worksheet-toggle-output` (C-c C-e) toggles the visibility of the current cell's output overlay using the `invisible` text property. Output data is preserved when hidden.

10. **Set output visibility all** — `ejn:worksheet-set-output-visibility-all` (C-c C-v) applies the current cell's output visibility state to all cells.

11. **Kernel interrupt** — `ejn:notebook-kernel-interrupt` (C-c C-z) sends an interrupt signal via `jupyter-interrupt-kernel`. Handles both message-mode and signal-mode kernels.

12. **Kernel restart** — `ejn:notebook-restart-session` (C-c C-x C-r) restarts the kernel via `jupyter-restart-kernel`, then prompts to re-execute all cells.

13. **Kill kernel and close** — `ejn:notebook-kill-kernel-then-close` (C-c C-q) interrupts the kernel, shuts it down, closes the notebook, kills all cell buffers, and cleans up the cache directory.

14. **Reconnect session** — `ejn:notebook-reconnect-session` (C-c C-r) drops the current client connection and re-establishes it without restarting the kernel process.

15. **Notebook open** — `ejn:notebook-open` (C-c C-o) queries the Jupyter server's kernel list via `jupyter-api-get-kernel` and presents a completing-read of running kernels to attach to.

## Out of scope

- Kernel completion (hybrid LSP + kernel completions) — reserved for future phase
- Widget rendering (`application/vnd.jupyter.widget-view+json`) — delegated to jupyter.el's external browser handling
- Traceback viewer (`ejn:tb-show`) — reserved for Phase 5
- Scratchsheet — reserved for Phase 5
- Shared output buffer — reserved for Phase 5
- Notebook close (without killing kernel) — reserved for Phase 5
- Cell type toggle/change — reserved for Phase 5

## Architecture

### Data model

**`ejn-notebook` amendments:**
- `kernel-id` slot type changed from `(or string null)` to `(or object null)` to accept `jupyter-kernel-client` instances.
- New `output-visible-p` slot added to `ejn-cell` class: `:initform t`, `:type boolean` — tracks per-cell output visibility state.

**`ejn-cell` amendments:**
- New `output-overlay` slot: `:initform nil`, `:type (or overlay null)` — stores the output overlay for each cell.
- New `output-visible-p` slot: `:initform t`, `:type boolean` — tracks whether output is currently visible for this cell.

### Interface contracts

**Kernel lifecycle (ejn-network.el):**

| Function | Signature | Behavior |
|---|---|---|
| `ejn-kernel-start` | `(notebook &optional kernel-name)` | Returns `jupyter-kernel-client`. Stores in notebook `:kernel-id`. Activates `ejn-kernel-manager-mode`. |
| `ejn-kernel-stop` | `(notebook)` | Calls `jupyter-shutdown-kernel` on client. Clears `:kernel-id`. Returns nil. |
| `ejn-kernel-reconnect` | `(notebook)` | Disconnects client, re-creates client for same kernel, stores in `:kernel-id`. Returns new client. |
| `ejn-kernel-interrupt` | `(notebook)` | Calls `jupyter-interrupt-kernel` on client. Returns nil. |
| `ejn-kernel-restart` | `(notebook)` | Calls `jupyter-restart-kernel` on client. Returns nil. |
| `ejn-kernel-client` | `(notebook)` | Returns `jupyter-kernel-client` from notebook `:kernel-id` slot. Signals `user-error` if nil. |
| `ejn-kernel-alive-p` | `(notebook)` | Returns non-nil if kernel client exists and kernel is alive. |
| `ejn-kernel-execution-state` | `(notebook)` | Returns string: `"idle"`, `"busy"`, `"starting"`, or `"dead"`. |

**Execution pipeline (ejn-network.el):**

| Function | Signature | Behavior |
|---|---|---|
| `ejn--execute-cell` | `(cell)` | Sends cell source to kernel. Registers iopub callback. Returns `jupyter-request`. |
| `ejn--iopub-handler` | `(cell msg)` | Dispatches iopub message by type. Updates mode-line on status messages. |
| `ejn--wait-idle` | `(req &optional timeout)` | Waits for `idle` status on REQ. Returns message or nil on timeout. |
| `ejn--execute-all-cells` | `(notebook)` | Executes all code cells sequentially. Returns nil. |

**Output rendering (ejn-network.el):**

| Function | Signature | Behavior |
|---|---|---|
| `ejn--render-output` | `(cell msg)` | Renders output from MSG into cell's output overlay. Uses `jupyter-insert` for MIME dispatch. |
| `ejn--clear-output` | `(cell)` | Deletes the output overlay for CELL. Returns nil. |
| `ejn--toggle-output-visibility` | `(cell)` | Toggles `invisible` text property on output overlay. Updates `output-visible-p` slot. |
| `ejn--set-output-visibility-all` | `(notebook visible-p)` | Sets output visibility to VISIBLE-P for all cells in NOTEBOOK. |
| `ejn--output-overlay` | `(cell)` | Returns (or creates) the output overlay for CELL. |

**Kernel manager minor mode (ejn-network.el):**

| Function | Signature | Behavior |
|---|---|---|
| `ejn-kernel-manager-mode` | `(&optional arg)` | Minor mode for master view buffer. Manages mode-line kernel status. |
| `ejn--kernel-status-lighter` | `(notebook)` | Returns mode-line string: `" EJN [LANG \\| ●State]"`. |
| `ejn--update-mode-line` | `(notebook)` | Updates mode-line with current kernel state. Called by iopub handler. |

### Tech stack

- `jupyter.el` → ZMQ/REST kernel communication, MIME output rendering, client lifecycle
- `jupyter-insert` → Rich output MIME type dispatch (HTML, PNG, SVG, text/plain, LaTeX)
- `jupyter-kernel-client` → EIEIO client object with execution-state tracking
- Overlay-based output regions → Non-destructive output rendering in cell buffers
- Minor mode (`ejn-kernel-manager-mode`) → Mode-line kernel status display

### Non-goals

- No support for kernel widgets (delegated to jupyter.el's external browser)
- No support for kernel-based tab completion (reserved for future phase)
- No support for cell type changes (reserved for Phase 5)
- No support for scratchsheet (reserved for Phase 5)
- Kernel connection uses local kernel process by default; server kernel support via `jupyter-server-kernel` is optional

## Task list

### Phase 4 — Communication & Execution

<!-- 
Classification reasoning per task:
- P4-T1 through P4-T3: tdd — conditional logic (kernel state machine, EIEIO type constraint change, slot management)
- P4-T4 through P4-T8: tdd — I/O (jupyter.el calls), state mutation (mode-line, cell slots), error handling
- P4-T9 through P4-T15: tdd — I/O (jupyter.el calls), data transformation (message dispatch), conditional logic
- P4-T16 through P4-T20: tdd — I/O, state mutation, conditional branching
- P4-T21 through P4-T25: tdd — I/O (jupyter.el), state mutation (cell slots), conditional logic
- P4-T26 through P4-T29: tdd — I/O, conditional logic, error handling
- P4-T30: smoke — stub replacement, no new logic
- P4-T31: scaffold — EIEIO slot type change only
-->

- [x] P4-T31 Change `ejn-notebook` `:kernel-id` slot type from `(or string null)` to `(or object null)` [tdd] (EIEIO type constraint — must instantiate with valid `jupyter-kernel-client` or nil)
- [x] P4-T32 Add `output-overlay` and `output-visible-p` slots to `ejn-cell` class [tdd] (EIEIO slot definitions with type constraints)
- [x] P4-T01 Implement `ejn-kernel-start` in `ejn-network.el` [tdd] (creates `jupyter-kernel-client` from kernelspec, stores in notebook `:kernel-id`, activates minor mode, returns client)
- [x] P4-T02 Implement `ejn-kernel-stop` in `ejn-network.el` [tdd] (calls `jupyter-shutdown-kernel`, clears `:kernel-id`, returns nil)
- [x] P4-T03 Implement `ejn-kernel-client` accessor in `ejn-network.el` [tdd] (returns client from `:kernel-id`, signals `user-error` if nil)
- [x] P4-T04 Implement `ejn-kernel-alive-p` in `ejn-network.el` [tdd] (checks client exists and kernel is alive via `jupyter-kernel-alive-p` or process check)
- [x] P4-T05 Implement `ejn-kernel-execution-state` in `ejn-network.el` [tdd] (returns `"idle"`/`"busy"`/`"starting"`/`"dead"` string from client `execution-state` slot or process status)
- [x] P4-T06 Implement `ejn-kernel-manager-mode` minor mode in `ejn-network.el` [tdd] (buffer-local minor mode for master view, manages mode-line kernel status, `:lighter " EJN"`)
- [x] P4-T07 Implement `ejn--kernel-status-lighter` in `ejn-network.el` [tdd] (returns mode-line string with language name and state indicator)
- [x] P4-T08 Implement `ejn--update-mode-line` in `ejn-network.el` [tdd] (updates master view mode-line with current kernel state, called by iopub handler)
- [x] P4-T09 Implement `ejn--execute-cell` in `ejn-network.el` [tdd] (sends cell source via `jupyter-sent` + `jupyter-execute-request`, registers iopub callback via `jupyter-message-subscribed`, returns request)
- [x] P4-T10 Implement `ejn--iopub-handler` in `ejn-network.el` [tdd] (dispatches iopub message by msg_type: stream/execute_result/display_data/error/status → render or update state)
- [x] P4-T11 Implement `ejn--wait-idle` in `ejn-network.el` [tdd] (waits for status:idle on request, returns message or nil on timeout)
- [x] P4-T12 Replace `ejn:worksheet-execute-cell` stub with real implementation [tdd] (calls `ejn--execute-cell`, updates mode-line to busy, registers callback)
- [x] P4-T13 Implement `ejn--render-output` in `ejn-network.el` [tdd] (renders MIME output using `jupyter-insert` in cell's output overlay, handles HTML/PNG/SVG/text/plain/LaTeX)
- [x] P4-T14 Implement `ejn--output-overlay` getter/creator in `ejn-network.el` [tdd] (returns existing output overlay or creates new one at point-max with after-string)
- [x] P4-T15 Implement `ejn--clear-output` in `ejn-network.el` [tdd] (deletes output overlay for a cell, handles nil overlay gracefully)
- [x] P4-T16 Replace `ejn:worksheet-clear-output` stub with real implementation [tdd] (calls `ejn--clear-output` for cell at point)
- [x] P4-T17 Replace `ejn:worksheet-clear-all-output` stub with real implementation [tdd] (iterates notebook cells, calls `ejn--clear-output` for each)
- [x] P4-T18 Implement `ejn--toggle-output-visibility` in `ejn-network.el` [tdd] (toggles `invisible` text property on overlay's after-string, updates `output-visible-p` slot)
- [x] P4-T19 Replace `ejn:worksheet-toggle-output` stub with real implementation [tdd] (calls `ejn--toggle-output-visibility` for cell at point)
- [x] P4-T20 Implement `ejn--set-output-visibility-all` in `ejn-network.el` [tdd] (applies current cell's visibility to all cells)
- [x] P4-T21 Replace `ejn:worksheet-set-output-visibility-all` stub with real implementation [tdd] (calls `ejn--set-output-visibility-all` for all cells)
- [x] P4-T22 Replace `ejn:worksheet-execute-cell-and-goto-next` stub with real implementation [tdd] (execute cell, then navigate to next cell buffer, signals error if last cell)
- [x] P4-T23 Replace `ejn:worksheet-execute-cell-and-insert-below` stub with real implementation [tdd] (execute cell, insert new code cell below, switch to new cell)
- [x] P4-T24 Implement `ejn--execute-all-cells` in `ejn-network.el` [tdd] (iterates code cells, executes sequentially, waits for idle between each)
- [x] P4-T25 Implement `ejn:worksheet-execute-all-cells` command in `ejn.el` [tdd] (interactive wrapper for `ejn--execute-all-cells`, bound to C-u C-c C-c)
- [x] P4-T26 Implement `ejn-kernel-interrupt` in `ejn-network.el` [tdd] (calls `jupyter-interrupt-kernel` on client, handles message-mode vs signal-mode)
- [x] P4-T27 Replace `ejn:notebook-kernel-interrupt` stub with real implementation [tdd] (calls `ejn-kernel-interrupt`, updates mode-line)
- [x] P4-T28 Implement `ejn-kernel-restart` in `ejn-network.el` [tdd] (calls `jupyter-restart-kernel` on client)
- [x] P4-T29 Replace `ejn:notebook-restart-session` stub with real implementation [tdd] (restarts kernel, prompts to re-execute all cells)
- [x] P4-T30 Replace `ejn:notebook-kill-kernel-then-close` stub with real implementation [tdd] (interrupt, shutdown kernel, save dirty cells, kill buffers, clean cache)
- [x] P4-T33 Implement `ejn-kernel-reconnect` in `ejn-network.el` [tdd] (drops client connection, re-creates for same kernel, stores in `:kernel-id`)
- [x] P4-T34 Replace `ejn:notebook-reconnect-session` stub with real implementation [tdd] (calls `ejn-kernel-reconnect`, re-activates minor mode)
- [x] P4-T35 Replace `ejn:notebook-open` stub with real implementation [tdd] (queries server kernels via `jupyter-current-server` + `jupyter-api-get-kernel`, presenting completing-read of running kernels)

## Open questions

(All resolved during clarification loop.)

---

## Amendment log

<!-- This section records changes made after initial spec approval. -->

- 2026-04-28: Initial spec written based on roadmap Phase 4 and current codebase analysis.
