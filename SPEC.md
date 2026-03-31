# Emacs-Jupyter-Notebook (EJN) — Specification

## Goal

Create an Emacs package that replicates Jupyter Notebook functionality with full LSP-based code intelligence. Users can open/edit/save `.ipynb` files, execute code cells against a Jupyter kernel, and receive real-time completions, diagnostics, and jump-to-definition across cell boundaries — all within Emacs.

## Features

1. **Notebook buffer creation** → `M-x ejn:notebook-open-scratch` creates a buffer with one code cell and activates `ejn-mode`
2. **Cell navigation** → `C-c C-n` / `C-c C-p` moves point to next/previous cell; `C-<down>` / `C-<up>` as aliases
3. **Cell insertion** → `C-c C-a` / `C-c C-b` inserts code or markdown cell above/below current cell
4. **Cell deletion** → `C-c C-k` removes current cell and cleans up overlays/registry
5. **Cell splitting** → `C-c C-s` splits current cell at point into two cells
6. **Cell merging** → `C-c RET` merges current cell with the cell below
7. **Cell reordering** → `C-c <up>` / `C-c <down>` moves current cell up/down in notebook
8. **Cell type toggle** → `C-c C-t` toggles current cell between code/markdown; `C-c C-u` changes to specific type
9. **Cell copy/paste** → `C-c C-w` / `C-c M-w` copies cell; `C-c C-y` yanks copied cell
10. **Open .ipynb file** → `C-c C-o` loads existing notebook from JSON file into buffer
11. **Save notebook** → `C-x C-s` serializes buffer to `.ipynb` JSON format with no data loss
12. **Rename notebook** → `C-x C-w` saves notebook to new filename
13. **Execute single cell** → `C-c C-c` sends cell code to kernel, displays plain-text output inline
14. **Execute + next** → `M-RET` executes current cell and moves point to next cell
15. **Execute all cells** → `C-u C-c C-c` executes all cells in order, queuing requests
16. **Execute + insert below** → `M-S-RET` executes cell and inserts new cell below
17. **Toggle output visibility** → `C-c C-e` hides/shows output region of current cell
18. **Clear output** → `C-c C-l` clears current cell output; `C-c C-S-l` clears all outputs
19. **Set output visibility** → `C-c C-v` sets visibility mode (all/hide/show) for all cells
20. **Interrupt kernel** → `C-c C-z` sends interrupt signal to kernel process
21. **Restart kernel** → `C-c C-x C-r` kills and restarts kernel, reinitializes session
22. **Reconnect session** → `C-c C-r` reestablishes connection to existing kernel session
23. **Kill kernel + close** → `C-c C-q` terminates kernel and closes notebook buffer
24. **Jump to definition** → `M-.` jumps to definition of symbol at point, works across cell boundaries
25. **Jump back** → `M-,` returns to previous location before jump
26. **LSP completion** → `M-TAB` or `C-TAB` triggers LSP-based completion in code cells only
27. **LSP diagnostics** → Errors/warnings from LSP server display as underlines in correct cell regions
28. **Render images** → Base64-encoded image outputs display inline in output region
29. **Render HTML** → HTML output renders using `shr` with sandboxed CSS
30. **Show code from output** → `C-c C-;` navigates from output region to source code cell
31. **Toolbar** → `C-c C-$` toggles minimal toolbar showing kernel status and quick actions
32. **Scratch notebook** → `C-c C-/` opens disposable notebook buffer without file association
33. **Close notebook** → `C-c C-#` closes notebook buffer and optionally kills kernel
34. **Multi-notebook support** → Multiple notebooks can be open with isolated kernels and state
35. **Cell border appearance** → Cells display colored borders: blue for command mode, green for edit mode, matching Jupyter's visual language
36. **Cell background styling** → Code cells have light gray background (#f5f5f5), markdown cells have white background
37. **Execution count display** → Code cells show `In [n]:` prefix with monospace styling; nil count shows `In [ ]:`
38. **Output styling** → Output regions display `Out[n]:` prefix for executable outputs; plain text output uses monospace font
39. **Cell hover effect** → Hovering over a cell highlights its border slightly for visual feedback
40. **Cell selection indicator** → Selected cell in command mode shows subtle background tint
41. **Markdown preview toggle** → Markdown cells can be rendered as HTML preview or shown as source

## Out of scope

- Cell execution history beyond current session (no persistent execution counts)
- Interactive widget support (e.g., ipywidgets)
- Notebook cell tags or custom metadata
- Export to PDF/HTML/other formats
- Version control integration
- Collaborative editing (multi-user sessions)
- Custom kernel spec management (relies on user's existing Jupyter installation)

## Architecture

### Data model

| Entity | Field | Type | Constraints | Default |
|---|---|---|---|---|
| **Cell** | `id` | string | unique, immutable | UUID |
| | `type` | symbol | `code` or `markdown` | `code` |
| | `input-start` | integer | buffer position, ≥ 0 | 0 |
| | `input-end` | integer | buffer position, > start | start + 1 |
| | `output-start` | integer | buffer position or nil | nil |
| | `output-end` | integer | buffer position or nil | nil |
| | `overlay` | overlay | non-nil when cell active | nil |
| | `execution-count` | integer | ≥ 0 or nil | nil |
| | `output-visibility` | symbol | `show`, `hide`, `all` | `show` |
| | `mode` | symbol | `command` or `edit` | `edit` |
| **Notebook** | `cells` | list | ordered list of Cell objects | `()` |
| | `metadata` | alist | key-value pairs from ipynb | `()` |
| | `kernel-id` | string or nil | Jupyter kernel ID | nil |
| | `kernel-process` | process or nil | Emacs process object | nil |
| | `virtual-buffer` | buffer or nil | LSP virtual buffer | nil |

### Interface contracts

#### Core API (`ejn-core.el`)

```elisp
;; Cell management
(ejn--create-cell TYPE) → ejn-cell            ; TYPE is 'code or 'markdown
(ejn--register-cell CELL) → nil               ; adds to buffer-local registry
(ejn--remove-cell CELL) → nil                 ; removes from registry, deletes overlay
(ejn--cell-at-point) → ejn-cell or nil        ; finds cell containing point
(ejn--cells-list) → (list of ejn-cell)        ; returns all cells in buffer order

;; Buffer operations
(ejn--insert-cell-at-point TYPE) → ejn-cell   ; inserts cell at current point
(ejn--build-virtual-document) → string        ; concatenates code cells for LSP
(ejn--cell-offset-map) → (alist cell-id → (start . end))
(ejn--offset->cell-position OFFSET) → (cell-id . buffer-pos)

;; Visual appearance
(ejn--apply-cell-border CELL) → nil           ; applies colored border overlay
(ejn--apply-cell-background CELL) → nil       ; applies background face
(ejn--render-execution-count CELL) → nil      ; renders In [n]: prefix
(ejn--render-output-prefix CELL) → nil        ; renders Out[n]: prefix
(ejn--set-cell-mode CELL MODE) → nil          ; sets command/edit mode visually
```

#### Kernel API (`ejn-kernel.el`)

```elisp
;; Kernel lifecycle
(ejn:notebook-start-kernel-command-km) → nil  ; starts kernel process
(ejn:notebook-kernel-interrupt-command-km) → nil
(ejn:notebook-restart-session-command-km) → nil
(ejn:notebook-kill-kernel-then-close-command-km) → nil

;; Execution
(ejn--execute-cell CELL) → nil                ; sends cell to kernel async
(ejn--execute-all-cells) → nil                ; queues all cells in order
```

#### LSP API (`ejn-lsp.el`)

```elisp
;; Virtual document sync
(ejn--sync-to-lsp) → nil                       ; updates virtual buffer
(ejn--debounce-sync) → nil                     ; debounced version (300ms)

;; Navigation
(ejn:pytools-jump-to-source-command) → nil    ; M-.
(ejn:pytools-jump-back-command) → nil         ; M-,

;; Diagnostics
(ejn--apply-diagnostics DIAGNOSTICS) → nil    ; applies LSP diagnostics to buffer
```

### Tech stack

- Emacs 28.1+ → native overlay API, async process support
- `lsp-mode` → LSP client for completion, diagnostics, jump-to-definition
- Jupyter kernel → code execution via ZeroMQ messaging protocol (native implementation)
- `json-parse-buffer` / `json-encode` → ipynb file I/O
- `shr` → HTML rendering for rich outputs
- `ert` → unit and integration testing framework with mocks for external dependencies

### Non-goals

- No incremental LSP sync (full document sync only; performance trade-off accepted)
- No multi-language LSP support in initial release (Python-only virtual buffer)
- No kernel process pooling (one kernel per notebook)
- No output caching beyond current session
- No real kernel/LSP integration in CI (mocks used for all tests)

## Task list

### Phase 1 — Core Buffer Model & Cell Navigation

- [ ] P1-T1 Create package skeleton (ejn.el, ejn-core.el, ejn-mode.el) with headers and provide [scaffold] (no code logic)
- [ ] P1-T2 Define `ejn-cell` struct with id, type, input-start, input-end, overlay fields [scaffold] (data structure only)
- [ ] P1-T3 Implement `ejn--generate-cell-id` using UUID or counter [tdd] (generates unique strings)
- [ ] P1-T4 Implement `ejn--cells` buffer-local variable with `ejn--register-cell` / `ejn--remove-cell` [tdd] (state mutation)
- [ ] P1-T5 Define `ejn-mode` major mode derived from `fundamental-mode` with `ejn-mode-map` [smoke] (mode registration, no logic)
- [ ] P1-T6 Implement `ejn:notebook-open-scratch` creating buffer and inserting initial cell [tdd] (buffer creation + cell insertion)
- [ ] P1-T7 Implement `ejn--create-cell-overlay` with face and cell property [tdd] (overlay creation with properties)
- [ ] P1-T8 Implement `ejn--insert-cell-at-point` inserting region and creating overlay [tdd] (buffer modification + state)
- [ ] P1-T9 Implement `ejn--cell-at-point` using `overlays-at` lookup [tdd] (search logic)
- [ ] P1-T10 Implement `ejn:worksheet-goto-next-input-km` and `ejn:worksheet-goto-prev-input-km` [tdd] (navigation logic)
- [ ] P1-T11 Implement `ejn:worksheet-insert-cell-below-km` [tdd] (cell insertion at computed position)
- [ ] P1-T12 Implement `ejn:worksheet-insert-cell-above-km` [tdd] (cell insertion at computed position)
- [ ] P1-T13 Implement `ejn:worksheet-kill-cell-km` with overlay cleanup [tdd] (deletion + state cleanup)
- [ ] P1-T14 Implement `ejn--validate-state` checking overlay consistency [tdd] (validation logic)
- [ ] P1-T15 Wire all Phase 1 keybindings in `ejn-mode-map` [smoke] (keymap registration only)

### Phase 2 — Cell Editing & Structural Transformations

- [ ] P2-T1 Implement `ejn:worksheet-split-cell-at-point-km` splitting cell at point [tdd] (buffer manipulation + cell creation)
- [ ] P2-T2 Implement `ejn:worksheet-merge-cell-km` merging current cell with below [tdd] (buffer manipulation + cell deletion)
- [ ] P2-T3 Implement `ejn:worksheet-move-cell-down-km` and `ejn:worksheet-move-cell-up-km` [tdd] (cell reordering logic)
- [ ] P2-T4 Implement `ejn:worksheet-copy-cell-km` with cell clipboard storage [tdd] (state mutation)
- [ ] P2-T5 Implement `ejn:worksheet-yank-cell-km` pasting from clipboard [tdd] (cell creation from stored state)
- [ ] P2-T6 Implement `ejn:worksheet-toggle-cell-type-km` toggling code↔markdown [tdd] (type change + overlay update)
- [ ] P2-T7 Implement `ejn:worksheet-change-cell-type-km` with prefix arg selection [tdd] (conditional type assignment)
- [ ] P2-T8 Implement `ejn--with-cell-update` macro wrapping mutations with validation [smoke] (macro definition, no logic)
- [ ] P2-T9 Wire all Phase 2 keybindings [smoke] (keymap registration only)

### Phase 3 — Notebook Persistence (File I/O)

- [ ] P3-T1 Implement `ejn--parse-ipynb-json` converting ipynb structure to cell list [tdd] (JSON parsing + transformation)
- [ ] P3-T2 Implement `ejn--serialize-to-ipynb` converting cell list to JSON structure [tdd] (serialization + data transformation)
- [ ] P3-T3 Implement `ejn:notebook-open-km` loading file into buffer [tdd] (file I/O + buffer initialization)
- [ ] P3-T4 Implement `ejn:file-open-km` with file dialog [smoke] (uses Emacs file-utils, minimal logic)
- [ ] P3-T5 Implement `ejn:notebook-save-notebook-command-km` saving to current file [tdd] (file I/O + serialization)
- [ ] P3-T6 Implement `ejn:notebook-rename-command-km` saving to new filename [tdd] (file I/O + rename logic)
- [ ] P3-T7 Implement round-trip test ensuring no metadata loss [tdd] (validation test)
- [ ] P3-T8 Wire all Phase 3 keybindings [smoke] (keymap registration only)

### Phase 4 — Kernel Integration (Execution MVP)

- [ ] P4-T0 Create mock kernel server for testing (simulates Jupyter messaging) [tdd] (test infrastructure)
- [ ] P4-T1 Implement Jupyter messaging protocol: `ejn--kernel-send-message MSG` [tdd] (ZeroMQ/socket communication)
- [ ] P4-T2 Implement `ejn:notebook-start-kernel-command-km` spawning kernel process [tdd] (process creation)
- [ ] P4-T3 Implement `ejn--execute-cell` sending execute_request to kernel [tdd] (message construction + async send)
- [ ] P4-T4 Implement `ejn--handle-execution-result` parsing execute_response [tdd] (JSON parsing + state update)
- [ ] P4-T5 Implement `ejn--display-plain-text-output` rendering stdout in output region [tdd] (buffer insertion)
- [ ] P4-T6 Implement `ejn--increment-execution-count` and store in cell [tdd] (counter logic)
- [ ] P4-T7 Implement `ejn:worksheet-execute-cell-km` command [smoke] (calls ejn--execute-cell)
- [ ] P4-T8 Implement `ejn:worksheet-execute-cell-and-goto-next-km` [smoke] (execute + navigation)
- [ ] P4-T9 Wire all Phase 4 keybindings [smoke] (keymap registration only)

### Phase 5 — Execution Workflow Enhancements

- [ ] P5-T1 Implement `ejn:worksheet-execute-all-cells` queuing sequential execution [tdd] (iteration + async queue)
- [ ] P5-T2 Implement `ejn:worksheet-execute-cell-and-insert-below-km` [tdd] (execute + insert + navigate)
- [ ] P5-T3 Implement `ejn:worksheet-toggle-output-km` hiding/showing output region [tdd] (overlay visibility toggle)
- [ ] P5-T4 Implement `ejn:worksheet-clear-output-km` for current cell [tdd] (buffer deletion)
- [ ] P5-T5 Implement `ejn:worksheet-clear-all-output-km` for all cells [tdd] (iteration + deletion)
- [ ] P5-T6 Implement `ejn:worksheet-set-output-visibility-all-km` with prefix arg modes [tdd] (conditional visibility setting)
- [ ] P5-T7 Implement output overlay separation from input overlay [tdd] (overlay management)
- [ ] P5-T8 Wire all Phase 5 keybindings [smoke] (keymap registration only)

### Phase 6 — Kernel Lifecycle Management

- [ ] P6-T1 Implement `ejn:notebook-kernel-interrupt-command-km` sending SIGINT [tdd] (process signal)
- [ ] P6-T2 Implement `ejn:notebook-restart-session-command-km` killing and respawning kernel [tdd] (process lifecycle)
- [ ] P6-T3 Implement `ejn:notebook-reconnect-session-command-km` reestablishing socket [tdd] (connection logic)
- [ ] P6-T4 Implement `ejn:notebook-kill-kernel-then-close-command-km` [tdd] (cleanup + buffer kill)
- [ ] P6-T5 Implement kernel state machine: `starting` → `idle` → `busy` → `dead` [tdd] (state transitions)
- [ ] P6-T6 Implement zombie process detection and cleanup [tdd] (process state checking)
- [ ] P6-T7 Implement broken socket recovery [tdd] (error handling + reconnection)
- [ ] P6-T8 Wire all Phase 6 keybindings [smoke] (keymap registration only)

### Phase 7 — LSP Integration (Code Intelligence)

- [ ] P7-T0 Create mock LSP server for testing (simulates lsp-mode responses) [tdd] (test infrastructure)
- [ ] P7-T1 Implement `ejn--build-virtual-document` concatenating code cells with separators [tdd] (string construction)
- [ ] P7-T2 Implement `ejn--cell-offset-map` building cell-to-offset mapping [tdd] (mapping construction)
- [ ] P7-T3 Implement `ejn--offset->cell-position` reverse lookup [tdd] (search logic)
- [ ] P7-T4 Implement `ejn--create-virtual-buffer` hidden buffer for LSP [smoke] (buffer creation)
- [ ] P7-T5 Implement `ejn--set-virtual-buffer-mode` setting language mode (python-mode) [smoke] (mode setting)
- [ ] P7-T6 Implement `ejn--start-lsp-on-virtual-buffer` calling `lsp-start` [smoke] (LSP initialization)
- [ ] P7-T7 Implement `ejn--sync-to-lsp` full document sync [tdd] (buffer update + LSP notification)
- [ ] P7-T8 Implement `ejn--debounce-sync` with 300ms idle timer [tdd] (timer logic)
- [ ] P7-T9 Implement `ejn--hook-into-after-change` registering change function [smoke] (hook registration)
- [ ] P7-T10 Implement `ejn:pytools-jump-to-source-command` with position mapping [tdd] (LSP call + position translation)
- [ ] P7-T11 Implement `ejn:pytools-jump-back-command` with position stack [tdd] (stack management)
- [ ] P7-T12 Implement `ejn--receive-diagnostics` from LSP [tdd] (LSP message handling)
- [ ] P7-T13 Implement `ejn--map-diagnostics-to-cells` translating LSP ranges [tdd] (range conversion)
- [ ] P7-T14 Implement `ejn--render-diagnostics-as-underlines` with overlays [tdd] (overlay creation)
- [ ] P7-T15 Implement `ejn--completion-at-point` for LSP completion [tdd] (completion trigger)
- [ ] P7-T16 Implement `ejn--restrict-completion-to-code-cells` guard [tdd] (conditional logic)
- [ ] P7-T17 Implement virtual buffer lifecycle cleanup on notebook close [tdd] (cleanup logic)
- [ ] P7-T18 Wire all Phase 7 keybindings [smoke] (keymap registration only)

### Phase 8 — Rich Output & UI Enhancements

- [ ] P8-T1 Implement `ejn--render-base64-image` displaying image in output region [tdd] (image decoding + display)
- [ ] P8-T2 Implement `ejn--render-html-output` using `shr` with sandboxed CSS [tdd] (HTML rendering)
- [ ] P8-T3 Implement output caching to avoid re-rendering [tdd] (cache logic)
- [ ] P8-T4 Implement `ejn:shared-output-show-code-cell-at-point-km` navigation [tdd] (position lookup)
- [ ] P8-T5 Implement `ejn:tb-show-km` toggling toolbar visibility [tdd] (UI toggle)
- [ ] P8-T6 Implement toolbar widget showing kernel status [tdd] (widget creation)
- [ ] P8-T7 Wire all Phase 8 keybindings [smoke] (keymap registration only)

### Phase 9 — Notebook UX Completion & Utilities

- [ ] P9-T1 Implement `ejn:notebook-scratchsheet-open-km` opening disposable notebook [smoke] (buffer creation without file)
- [ ] P9-T2 Implement `ejn:notebook-close-km` with optional kernel kill confirmation [tdd] (cleanup with conditional)
- [ ] P9-T3 Implement multi-notebook namespace isolation [tdd] (buffer-local state management)
- [ ] P9-T4 Implement concurrent kernel support (multiple kernels running) [tdd] (process management)
- [ ] P9-T5 Implement resource cleanup on buffer kill (kernels, virtual buffers, overlays) [tdd] (cleanup hooks)
- [ ] P9-T6 Wire all Phase 9 keybindings [smoke] (keymap registration only)
- [ ] P9-T7 Final integration testing across all phases [tdd] (end-to-end validation)

### Phase 10 — Jupyter-Style Visual Appearance

- [ ] P10-T1 Define cell face set: `ejn-cell-border`, `ejn-cell-bg-code`, `ejn-cell-bg-markdown`, `ejn-execution-count`, `ejn-output-prefix`, `ejn-cell-command-mode`, `ejn-cell-edit-mode` [scaffold] (face definitions only)
- [ ] P10-T2 Implement `ejn--apply-cell-border` creating border overlay with mode-dependent color using `before-string` property [tdd] (overlay creation with left border rendering) // classification: tdd — creates visual overlay with conditional styling based on cell mode
- [ ] P10-T3 Implement `ejn--apply-cell-background` setting cell region background face via extent overlay [tdd] (overlay with extent properties) // classification: tdd — applies background face to cell region, different for code vs markdown
- [ ] P10-T4 Implement `ejn--render-execution-count` displaying `In [n]:` prefix before code cells [tdd] (string formatting + before-string overlay) // classification: tdd — renders formatted execution count prefix, shows `In [ ]:` when nil
- [ ] P10-T5 Implement `ejn--render-output-prefix` displaying `Out[n]:` prefix for executable outputs [tdd] (conditional rendering with execution count) // classification: tdd — conditionally renders output prefix based on execution count
- [ ] P10-T6 Implement `ejn--cell-hover-handler` for mouse-enter/mouse-exit events to highlight cell border [tdd] (mouse event handling with overlay modification) // classification: tdd — handles mouse events and modifies border appearance dynamically
- [ ] P10-T7 Implement `ejn--update-cell-visuals` consolidating all visual updates for a cell [tdd] (orchestrates border, background, execution count rendering) // classification: tdd — coordinates multiple visual updates atomically
- [ ] P10-T8 Implement `ejn--markdown-render-toggle` for preview/source switching in markdown cells [tdd] (markdown-to-html rendering using `shr` or `htmlize`) // classification: tdd — toggles between source and rendered markdown preview
- [ ] P10-T9 Wire mouse event handlers in `ejn-mode-map` using `local-set-key` on mouse maps [smoke] (mouse map registration only) // classification: smoke — simple keymap wiring, no logic

## Open questions

- [x] Which LSP client? → `lsp-mode` (user selected)
- [x] Should kernel integration be included? → Yes, all Phases 4-6 for complete notebook experience
- [x] What file structure? → Modular approach: `ejn.el` (entry), `ejn-core.el` (cell model), `ejn-mode.el` (mode), `ejn-kernel.el` (execution), `ejn-lsp.el` (LSP), `ejn-io.el` (file I/O)
- [x] What test strategy? → `ert` for unit/integration tests; each task classified as `tdd`/`smoke`/`scaffold` per task-classifier rules

## Human review flags

1. **Phase 4 kernel protocol**: ZeroMQ-based Jupyter messaging confirmed. ✅ Resolved
2. **LSP virtual buffer approach**: Performance trade-off accepted, no incremental sync. ✅ Resolved
3. **Test coverage for kernel/LSP**: Mocks confirmed for CI testing. ✅ Resolved
4. **Phase 10 visual appearance**: Jupyter-style cell borders, backgrounds, and execution count display. **NEW — please review face color choices and visual design decisions.**

**SPEC.md is approved and ready for the build loop.**

