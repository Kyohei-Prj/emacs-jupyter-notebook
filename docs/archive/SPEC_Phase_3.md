# SPEC.md — Phase 3: LSP Integration (The Intelligence Layer)

## Goal

Every code cell buffer provides cross-cell code intelligence: LSP-aware completions, diagnostics, and jump-to-definition that see symbols defined in other cells of the same notebook. The user edits a cell and gets completion for variables defined two cells up. `M-.` on a function name defined in Cell 1 jumps to the Cell 1 buffer at the correct line.

## Features

1. Composite shadow file generation → `composite.py` in `.ejn-cache/<stem>/` contains all code cell sources concatenated with `# ejn:cell:N` sentinel comments, regenerated within 0.3s of any cell edit.
2. Bidirectional position translation → `ejn-lsp-pos-to-composite` converts `(buffer . 0 . 5)` to `(composite . 7 . 5)` and `ejn-lsp-pos-from-composite` reverses the mapping.
3. LSP virtual buffer registration → each cell buffer is registered with `lsp-mode` via `lsp-virtual-buffer-register` so the language server sees the composite file with correct line offsets.
4. LSP lifecycle on cell open → opening a cell buffer sets `default-directory` to the notebook directory, ensures `composite.py` exists, and attaches the language server exactly once per buffer.
5. LSP completion in cell buffers → `completion-at-point-functions` includes the LSP completion source, providing cross-cell completions from the language server.
6. Jump-to-definition across cells → `M-.` on a symbol defined in another cell opens that cell's buffer at the correct source line; `M-,` returns to the originating cell buffer.
7. Fallback for older lsp-mode → if `lsp-virtual-buffer-register` is unavailable, a fallback attaches LSP to the composite shadow file directly with a warning message.

## Out of scope

- Kernel-based dynamic completion (`ejn-kernel-complete`) — deferred to Phase 4 (requires live kernel).
- `cape` package integration for merging LSP + kernel results — deferred to Phase 4.
- Full `eglot` support — stub with message only; `lsp-mode` is the supported backend.
- eglot position translation shim — deferred indefinitely.
- Flymake/flycheck configuration — LSP diagnostics work automatically once the server is attached; explicit configuration deferred.

## Architecture

### Data model

No new EIEIO classes. The existing `ejn-notebook` and `ejn-cell` classes are sufficient. No new slots are required — the composite file is a derived artifact regenerated on demand.

The sentinel comment format in `composite.py`:

```
# ejn:cell:0
<cell 0 source>

# ejn:cell:1
<cell 1 source>
```

Only cells of type `code` are included in the composite. Markdown and raw cells are skipped. Each cell block is followed by a trailing newline, and the sentinel comment occupies exactly one line.

### Interface contracts

**File: `lisp/ejn-lsp.el`** — all Phase 3 functions defined here.

| Function | Signature | Purpose |
|----------|-----------|---------|
| `ejn-lsp-sentinel-line` | `(cell-index) → string` | Returns `"# ejn:cell:N\n"` for given 0-based code cell index. Pure function. |
| `ejn-lsp-cell-line-count` | `(source) → integer` | Returns the number of lines in a source string, counting the final line even if it has no trailing newline. Pure function. |
| `ejn-lsp-composite-path` | `(notebook) → string` | Returns the absolute path to `composite.py` in the notebook's cache directory. Pure function. |
| `ejn-lsp-generate-composite` | `(notebook) → string` | Iterates notebook code cells, concatenates sources with sentinel lines, writes atomically via `.tmp` + `rename-file`. Returns the absolute path to `composite.py`. |
| `ejn-lsp--debounced-composite-regen` | `(start end pre-change-length) → nil` | After-change callback: cancels any pending composite regen timer, schedules `ejn-lsp-generate-composite` on a 0.3s idle timer. Stores timer ID in a notebook-local variable. |
| `ejn-lsp-pos-to-composite` | `(cell notebook buffer-line buffer-col) → (composite-line . composite-col)` | Translates a `(buffer-line, buffer-col)` in CELL's buffer to the equivalent position in `composite.py`. Line numbers are 0-based. |
| `ejn-lsp-pos-from-composite` | `(notebook composite-line) → (cell . cell-line)` | Given a 0-based line in `composite.py`, returns the `(cell . cell-line)` pair. Returns `nil` for sentinel/separator lines. |
| `ejn-lsp-cell-code-index` | `(cell notebook) → integer` | Returns the 0-based index of CELL among code-only cells. Returns `-1` for non-code cells. |
| `ejn-lsp--register-virtual-buffer` | `(cell notebook) → nil` | Calls `lsp-virtual-buffer-register` with `:real-buffer`, `:virtual-file` (composite path), `:offset-line` (from pos-to-composite). Sets `ejn--cell-lsp-attached-p` to `t`. |
| `ejn-lsp--register-fallback` | `(cell notebook) → nil` | For older lsp-mode: generates composite, calls `lsp` on the composite path, displays warning about limited position translation. |
| `ejn-lsp-register-cell` | `(cell notebook) → nil` | Idempotent orchestrator: checks `ejn--cell-lsp-attached-p`, dispatches to `--register-virtual-buffer` (preferred) or `--register-fallback`. |
| `ejn-lsp-unregister-cell` | `(cell) → nil` | Calls `lsp-virtual-buffer-unregister` (or `lsp-kill-workspace` for fallback). Clears `ejn--cell-lsp-attached-p`. |
| `ejn-lsp-setup-cell-buffer` | `(cell notebook) → nil` | In the cell's buffer: sets `default-directory` to notebook dir, ensures composite exists, calls `ejn-lsp-register-cell`, pushes `lsp-completion-at-point` onto `completion-at-point-functions`. Guarded by `ejn--cell-lsp-attached-p`. |
| `ejn:pytools-jump-to-source` | `() → nil` | Interactive command. Translates point to composite, calls `lsp-find-definition`, uses `ejn-lsp--translate-xref-to-cell` to map result back, switches to target cell buffer. |
| `ejn-lsp--translate-xref-to-cell` | `(xref notebook) → (buffer . position)` | Extracts target file and line from XREF, maps composite line to cell via `ejn-lsp-pos-from-composite`. Returns target cell buffer and line, or `nil` if not mappable. |
| `ejn:pytools-jump-back` | `() → nil` | Interactive command. Delegates to `xref-pop-marker-stack`. |
| `ejn-kernel-complete` | `(callback) → nil` | Stub. Signals `user-error "Kernel completion requires Phase 4"`. Reserved for Phase 4. |

**Keymap changes in `ejn-mode-map` (`ejn.el`):**

| Key | Function |
|-----|----------|
| `M-.` | `ejn:pytools-jump-to-source` |
| `M-,` | `ejn:pytools-jump-back` |

### Tech stack

- `lsp-mode` → primary LSP client; provides `lsp-virtual-buffer` API for position translation.
- `python-mode` → major mode for code cell buffers; LSP server (e.g., `pyright`, `ruff`) attaches to this mode.
- No new Emacs packages beyond `lsp-mode`.

### Non-goals

- No `eglot` implementation — stub with message only.
- No kernel completion — `ejn-kernel-complete` is a stub; Phase 4 fills it in.
- No `cape` merge layer — single LSP source only; Phase 4 adds multi-source merging.
- No explicit Flymake/Flymake configuration — LSP server provides diagnostics automatically.

### Task dependency graph

```
T01 → T02
      T03
      T04
T02, T03, T04 → T05 → T06
T02, T03, T04, T05 → T07
T02, T03, T04, T05 → T08
T07, T08 → T09
T04, T05 → T10
T02, T03, T04 → T11 → T12 → T13 → T15
                                  → T17 → T19
T09 → T20 → T19
T19 → T22
T21 → T23
```

Legend: T = P3-T. Tasks T14, T16, T24 have no ordering constraints beyond loading after their dependencies.

## Task list

### Phase 3 — LSP Integration

#### 3.1 Composite Shadow File — helpers and generation

- [x] P3-T01 Add `lsp-mode` dependency to Eask [scaffold] (static dependency declaration — no code behaviour)
- [x] P3-T02 Implement `ejn-lsp-sentinel-line` — returns `"# ejn:cell:N\n"` for a given 0-based code cell index [tdd] (pure function — string formatting)
- [x] P3-T03 Implement `ejn-lsp-cell-line-count` — returns the number of lines in a source string, counting the final line even without trailing newline [tdd] (pure function — string parsing with edge case for empty/non-terminated strings)
- [x] P3-T04 Implement `ejn-lsp-composite-path` — returns the absolute path to `composite.py` in the notebook's cache directory [tdd] (pure function — path construction from notebook :path)
- [x] P3-T05 Implement `ejn-lsp-generate-composite` — iterates notebook code cells, concatenates sources with sentinel lines into `composite.py`, writes atomically via `.tmp` + `rename-file` [tdd] (I/O — filesystem write; conditional — skip non-code cells; data transformation — concatenation)
- [x] P3-T06 Implement `ejn-lsp--debounced-composite-regen` — callback that cancels any pending timer, then schedules `ejn-lsp-generate-composite` on a 0.3s idle timer; stores timer ID in a notebook-local variable [tdd] (state mutation — timer ID storage; conditional — pending timer cancellation)
- [x] P3-T07 Add `ejn-lsp--debounced-composite-regen` call to `ejn--cell-after-change-hook` in `ejn-cell.el` [smoke] (structural wiring — appends call to existing hook; uses `declare-function` for forward reference to `ejn-lsp.el`)

#### 3.2 Cursor Position Translation

- [x] P3-T08 Implement `ejn-lsp-pos-to-composite` — given a cell, notebook, 0-based buffer line and column, returns `(composite-line . composite-col)` by summing preceding code cell line counts plus sentinel lines [tdd] (algorithm — offset accumulation; input validation — boundary checks for line/column bounds)
- [x] P3-T09 Implement `ejn-lsp-pos-from-composite` — given a notebook and a 0-based composite line, returns `(cell . cell-line)` by scanning the code cell offset table; returns `nil` for sentinel/separator lines [tdd] (algorithm — linear scan with boundary detection; conditional — sentinel vs content line)
- [x] P3-T10 Implement `ejn-lsp-cell-code-index` — returns the 0-based index of a cell among code-only cells in the notebook; returns `-1` for non-code cells [tdd] (data transformation — filtered list position; conditional — type guard on cell type)

#### 3.3 LSP Virtual Buffer Registration

- [x] P3-T11 Implement `ejn-lsp--register-virtual-buffer` — calls `lsp-virtual-buffer-register` with `:real-buffer`, `:virtual-file` (composite path), and `:offset-line` (from `ejn-lsp-pos-to-composite`); sets `ejn--cell-lsp-attached-p` to `t` [tdd] (I/O — calls external API; state mutation — buffer-local flag)
- [x] P3-T12 Implement `ejn-lsp--register-fallback` — for older lsp-mode without `lsp-virtual-buffer-register`: generates composite, calls `lsp` on the composite path, displays a warning message about limited position translation [tdd] (conditional — checks `(fboundp 'lsp-virtual-buffer-register)`; I/O — file generation + LSP invocation; error handling — message on failure)
- [x] P3-T13 Implement `ejn-lsp-register-cell` — checks `ejn--cell-lsp-attached-p`; if not set, dispatches to `ejn-lsp--register-virtual-buffer` (preferred) or `ejn-lsp--register-fallback` [tdd] (conditional — idempotency guard + API availability check; state mutation — flag setting)
- [x] P3-T14 Implement `ejn-lsp-unregister-cell` — calls `lsp-virtual-buffer-unregister` if available and the cell was registered, or `lsp-kill-workspace` for fallback; clears `ejn--cell-lsp-attached-p` [smoke] (structural — calls external cleanup API; no conditional logic beyond API availability)

#### 3.4 LSP Lifecycle Management

- [x] P3-T15 Implement `ejn-lsp-setup-cell-buffer` — in the cell's buffer: sets `default-directory` to notebook directory, calls `ejn-lsp-generate-composite` if composite doesn't exist, calls `ejn-lsp-register-cell`; guarded by `ejn--cell-lsp-attached-p` [tdd] (conditional — idempotency check + file existence; I/O — composite generation; state mutation — buffer-local directory and flag)
- [x] P3-T16 Stub `ejn-kernel-complete` — signals `user-error` with message `"Kernel completion requires Phase 4"` [smoke] (stub function — no logic, signals immediately)
- [x] P3-T17 Add `ejn-lsp-setup-cell-buffer` call to `ejn-cell-open-buffer` in `ejn-cell.el` [smoke] (structural wiring — inserts call after shadow file write; uses `declare-function` for forward reference to `ejn-lsp.el`)

#### 3.5 Completion Wiring

- [x] P3-T18 Add LSP completion to `completion-at-point-functions` in cell buffers via `ejn-lsp-setup-cell-buffer` [smoke] (structural wiring — pushes `lsp-completion-at-point` onto buffer-local list)

#### 3.6 Source Navigation Keybindings

- [x] P3-T19 Implement `ejn:pytools-jump-to-source` — translates current point to composite position, calls `lsp-find-definition`, translates the target position back via `ejn-lsp-pos-from-composite`, and switches to the target cell's buffer at the resolved line [tdd] (position transformation — buffer→composite→buffer; error handling — nil xref result; conditional — target cell buffer detection)
- [x] P3-T20 Implement `ejn-lsp--translate-xref-to-cell` — given an xref object and notebook, extracts the target buffer/file and line, maps composite line to cell buffer via `ejn-lsp-pos-from-composite`, returns the target cell buffer and position [tdd] (data transformation — xref parsing; conditional — composite vs other file detection)
- [x] P3-T21 Implement `ejn:pytools-jump-back` — delegates to `xref-pop-marker-stack` [smoke] (structural delegation — single function call, no logic)
- [x] P3-T22 Wire `M-.` → `ejn:pytools-jump-to-source` into `ejn-mode-map` in `ejn.el` [smoke] (structural wiring — single `define-key` call)
- [x] P3-T23 Wire `M-,` → `ejn:pytools-jump-back` into `ejn-mode-map` in `ejn.el` [smoke] (structural wiring — single `define-key` call)
- [x] P3-T24 Update `ejn--cell-kill-buffer-hook` in `ejn-cell.el` to call `ejn-lsp-unregister-cell` [smoke] (structural wiring — adds cleanup call to existing hook; uses `declare-function` for forward reference)

## Deliverable

Opening any cell buffer provides LSP completions that include symbols defined in other cells. `M-.` (jump-to-definition) routed through `composite.py` lands in the target cell's buffer at the correct line. `M-,` (jump back) returns to the originating cell buffer. Diagnostics from the language server (via Flymake or the LSP server's built-in diagnostics) highlight real errors without false positives from missing cross-cell context. The composite file is regenerated within 0.3s of any keystroke, and the LSP server stays attached across buffer revisits.
