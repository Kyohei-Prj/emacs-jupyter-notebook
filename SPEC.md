# SPEC.md — EJN Bug Fix Pass

## Goal

Repair 44 bugs across 7 files in the Emacs Jupyter Notebook (EJN) package so that a user can open a `.ipynb` file, see the master view, edit cells, execute them against a Jupyter kernel, see output rendered inline, undo changes, and save back to a valid `.ipynb` — all without crashes, silent failures, or data corruption.

## Features

1. **Open notebook → master view appears** — `M-x ejn-open-file` on any `.ipynb` switches to `*ejn-master:FILE.ipynb*` displaying polymode-rendered cell chunks. (B01)
2. **Buffer-local variables scoped correctly** — `ejn--notebook` and `ejn--cell` are `defvar-local`; `buffer-local-value` in a fresh buffer returns `nil` without global leakage. (B02, B03)
3. **Structural cell commands crash-proof** — `insert-above`, `insert-below`, `move-up`, `move-down`, `split`, `merge`, `yank`, `copy` signal `user-error` (not `wrong-type-argument`) when called from master view; new cell buffers switch to the user's window; copy/merge sync dirty buffers before reading `:source`. (B04–B13)
4. **Master view stays polymode after structural ops** — After any cell insert/move/kill/merge, the master view buffer contains only polymode chunk delimiters (`# %%<ejn-cell:N:code>`), never button text. Dead button-renderer functions removed. (B16–B20)
5. **Navigation works from master view** — `C-c C-n` / `C-c C-p` from master view search for polymode chunk headers (regex `^# %%<ejn-cell:[0-9]+:`); from cell buffers they switch to adjacent cell buffers. (B14, B15)
6. **Shadow files survive crash and cleanup** — `ejn-shadow-write-cell` uses `.tmp` + `rename-file` (atomic). `ejn--reindex-shadow-files` globs the cache directory and deletes orphaned `cell_NNN.{py,md,raw}` files. `ejn--cell-kill-buffer-hook` flushes dirty content before unregistering LSP. (B21–B23)
7. **Save produces valid nbformat 4.5 JSON** — Parser handles vector `source` (not just list). `ejn--cell-to-json` always emits `"id"`, `"metadata"` (empty `{}` if unset), `"outputs"` (empty `[]` if nil). `ejn--notebook-to-json` emits `"metadata"` as `{}` not `null`. `jupyter nbconvert --to script` on the saved file does not error. (B24–B28)
8. **Kernel start command available** — `C-c C-S-k` prompts for kernelspec via `completing-read`, starts kernel, stores client in `notebook.kernel-id`, activates `ejn-kernel-manager-mode`. Signals `user-error` if kernel already running or no kernelspecs found. (B38)
9. **Execute sends current buffer content** — `ejn--execute-cell` calls `ejn-shadow-sync-cell` before sending; retrieves client from `notebook.kernel-id`; uses `jupyter-execute-request` within the correct client context. (B36, B37)
10. **iopub messages dispatched correctly** — `jupyter-iopub-message-hook` callback uses `jupyter-message-type` and `jupyter-message-get` accessors (not raw `plist-get` on wrong key format). `ejn--render-output` handles `stream`, `execute_result`, `display_data`, `error`, and `execute_reply` message structures. Cell `exec-count` updates on `execute_reply`. (B34, B35, B39)
11. **LSP virtual buffer registered correctly** — `lsp-virtual-buffer-register` called with integer `offset-line` (extracted from `(LINE . COL)` cons). Scroll hook added to buffer-local `window-scroll-functions` (not global). Chunk head prefix extracted to `defconst ejn--cell-chunk-head-prefix`. (B30–B33)
12. **Undo restores deleted text** — `ejn--undo-before-change` captures full buffer snapshot in `before-change-functions`. `ejn--undo-after-change` uses snapshot for `before-text`. `ejn-global-undo` removes `erase-buffer` before `replace-buffer-contents`. Structural undo dispatched via `ejn--undo-structural-change`. Cell-type-toggle `with-current-buffer` nesting fixed. (B40–B44)
13. **Close prompts on save failure** — `ejn:notebook-close` calls `ejn-notebook-save` directly; on `nil` return, prompts "Save failed. Close anyway and lose changes?"; aborts on `n`. Kernel NOT killed (existing behavior). (B29)

## Out of scope

- Kernel-based completion (`ejn-kernel-complete`) — reserved for Phase 4 of the original roadmap.
- `ejn:notebook-open` (attach to running Jupyter server kernel) — existing stub, not fixed here.
- Widget support, HTML/JS display, LaTeX rendering beyond text/plain.
- Multi-notebook session management.
- LSP fallback path (composite file mode) — only the `lsp-virtual-buffer-register` path is fixed.

## Architecture

### Data model

No changes to the EIEIO classes (`ejn-notebook`, `ejn-cell`) or the `ejn-undo-record` struct. All fixes operate on existing slots and fields.

### Interface contracts

| Function | Change | New signature / behavior |
|----------|--------|--------------------------|
| `ejn--notebook` (var) | `defvar` → `defvar-local` | Buffer-local, default `nil` |
| `ejn--cell` (var) | `defvar` → `defvar-local` | Buffer-local, default `nil` |
| `ejn-open-file` | Return value captured | `switch-to-buffer` on master view; returns `nil` |
| `ejn:worksheet-insert-cell-above` | Guards + switch | Signals `user-error` if no cell/notebook; `switch-to-buffer` on new cell |
| `ejn:worksheet-insert-cell-below` | Guards + switch | Same as above |
| `ejn:worksheet-move-cell-up` | Guards + polymode refresh | Signals `user-error`; calls `ejn--poly-refresh-cells` |
| `ejn:worksheet-move-cell-down` | Guards + polymode refresh | Signals `user-error`; calls `ejn--poly-refresh-cells` |
| `ejn:worksheet-kill-cell` | Polymode refresh | Calls `ejn--poly-refresh-cells` |
| `ejn:worksheet-split-cell-at-point` | Guards + switch | Signals `user-error`; `switch-to-buffer` on new cell |
| `ejn:worksheet-merge-cell` | Guards + sync + polymode | Syncs both cells; signals `user-error`; calls `ejn--poly-refresh-cells` |
| `ejn:worksheet-yank-cell` | Guards + switch | Signals `user-error`; `switch-to-buffer` on yanked cell |
| `ejn:worksheet-copy-cell` | Guards + sync | Signals `user-error`; syncs buffer before reading `:source` |
| `ejn--make-cell` | Polymode refresh | Calls `ejn--poly-refresh-cells` instead of `ejn--refresh-master-cells` |
| `ejn:worksheet-goto-next-input` | Polymode nav | Master view: `re-search-forward` for chunk header; cell buffer: unchanged |
| `ejn:worksheet-goto-prev-input` | Polymode nav | Master view: `re-search-backward` for chunk header; cell buffer: unchanged |
| `ejn-shadow-write-cell` | Atomic write | `.tmp` + `rename-file`; `(or source "")` for nil safety |
| `ejn--reindex-shadow-files` | Glob-based cleanup | `directory-files` + regex; deletes orphans |
| `ejn--cell-kill-buffer-hook` | Flush dirty | Calls `ejn-shadow-sync-cell` when `:dirty` is set |
| `ejn--parse-cell-data` | Vector source | `(vectorp source)` → `mapconcat`; `(listp source)` → `string-join` |
| `ejn--cell-to-json` | nbformat 4.5 | Always emits `"id"`, `"metadata"` (`{}`), `"outputs"` (`[]`) |
| `ejn--notebook-to-json` | Metadata nil guard | `(or metadata (make-hash-table :test 'equal))` |
| `ejn:notebook-start-kernel` | NEW command | `(defun ejn:notebook-start-kernel (&optional kernel-name))` → prompts, starts kernel |
| `ejn--execute-cell` | Correct API | `ejn-shadow-sync-cell` → `jupyter-execute-request`; stores `request-id` on cell |
| `ejn--iopub-handler` | Correct API | `(client msg)` signature; `jupyter-message-type`/`jupyter-message-get`; parent-ID correlation |
| `ejn--render-output` | All msg types | `pcase` on `jupyter-message-type`; stream/execute_result/display_data/error/execute_reply |
| `ejn-lsp--register-virtual-buffer` | Integer offset-line | Extract `car` from `(LINE . COL)` cons |
| `ejn--create-master-view` | Buffer-local hook check | `buffer-local-value` for `window-scroll-functions` |
| `ejn--cell-chunk-head-prefix` | NEW defconst | `"# %%<ejn-cell:"` — used by render + scroll hook + navigation |
| `ejn--undo-before-change` | NEW function | `before-change-functions` hook; captures `ejn--pre-change-snapshot` |
| `ejn--undo-after-change` | Snapshot-based | Uses `ejn--pre-change-snapshot` for `before-text`; clears snapshot |
| `ejn-global-undo` | No erase-buffer | `replace-buffer-contents` without `erase-buffer`; structural undo dispatch |
| `ejn:worksheet-toggle-cell-type` | Buffer nesting | `with-current-buffer` closed before markdown render |
| `ejn:worksheet-change-cell-type` | Buffer nesting | Same fix |
| `ejn:notebook-close` | Save failure guard | Calls `ejn-notebook-save`; prompts on failure; aborts on decline |
| `ejn-master.el` dead code | DELETED | `ejn--truncate-source`, `ejn--make-cell-button`, `ejn--render-master-cells`, `ejn--refresh-master-cells` |

### Tech stack

- Emacs 30.1+ with `lexical-binding` — baseline
- EIEIO — data model (`ejn-notebook`, `ejn-cell`)
- `jupyter.el` (MELPA) — kernel communication; hook-based iopub via `jupyter-add-hook`
- `polymode` — master view syntax highlighting
- `lsp-mode` + `lsp-virtual-buffer` — LSP integration for cell buffers
- ERT (built-in) — test framework (replaces empty buttercup setup)
- Eask — build/test/lint orchestration

### Non-goals

- No changes to EIEIO class definitions (no new slots, no inheritance changes).
- No changes to the polymode mode definitions (`poly-ejn-mode` et al.).
- No changes to the markdown rendering pipeline (`ejn-markdown-render-cell`).
- No changes to the LSP composite file generation (`ejn-lsp-generate-composite`).
- No changes to `ejn:notebook-open` or `ejn-kernel-complete`.

## Task list

### Phase 1 — Foundation (variables + open)

Tasks that must load correctly before any other fix is testable.

- [x] P1-T1 Convert `ejn--notebook` and `ejn--cell` to `defvar-local`; remove redundant `make-variable-buffer-local` in `ejn-master.el` (B02, B03) [smoke] (no logic — declaration-only change)
- [x] P1-T2 Fix `ejn-open-file`: capture `ejn--create-master-view` return, call `switch-to-buffer` (B01) [smoke] (structural — adds one buffer switch)

### Phase 2 — Structural cell commands + polymode unification

Merges plan Tasks 3 and 4: all structural commands get guards, `switch-to-buffer`, and polymode refresh in a single pass over `ejn-cell.el`. Dead button renderer removed from `ejn-master.el`.

- [x] P2-T1 Add nil guards + `switch-to-buffer` + polymode refresh to all 8 structural commands in `ejn-cell.el` (`insert-above`, `insert-below`, `move-up`, `move-down`, `kill`, `split`, `merge`, `yank`, `copy`); sync dirty buffers in `copy` and `merge` before reading `:source`; replace all `ejn--refresh-master-cells` calls with `ejn--poly-refresh-cells` (B04–B20) [tdd] (conditional guards, data sync, state mutation)
- [x] P2-T2 Delete dead button-renderer functions from `ejn-master.el`: `ejn--truncate-source`, `ejn--make-cell-button`, `ejn--render-master-cells`, `ejn--refresh-master-cells`; remove `(require 'button)` (B16–B20 cleanup) [scaffold] (dead code removal only)

### Phase 3 — Navigation from master view

- [x] P3-T1 Rewrite `ejn:worksheet-goto-next-input` and `ejn:worksheet-goto-prev-input` master-view branches: `re-search-forward/backward` for `^# %%<ejn-cell:[0-9]+:` instead of `next-button/previous-button` (B14, B15) [tdd] (conditional dispatch: cell buffer vs master view path)

### Phase 4 — Shadow file integrity

- [ ] P4-T1 Make `ejn-shadow-write-cell` atomic (`.tmp` + `rename-file`); fix `ejn--reindex-shadow-files` to glob cache directory and delete orphans; flush dirty content in `ejn--cell-kill-buffer-hook` (B21–B23) [tdd] (I/O, error handling, state mutation)

### Phase 5 — JSON serialization (save/load)

- [ ] P5-T1 Handle vector `source` in `ejn--parse-cell-data`: `(vectorp source)` → `mapconcat` (B24) [tdd] (data transformation, type check)
- [ ] P5-T2 Fix `ejn--cell-to-json`: always emit `"id"`, `"metadata"` (`{}`), `"outputs"` (`[]`); fix `ejn--notebook-to-json`: nil-guard `metadata` (B25–B28) [tdd] (data transformation, validation against nbformat spec)

### Phase 6 — Kernel execution + iopub messaging

Uses correct `jupyter.el` API: `jupyter-add-hook` for iopub subscription (not `jupyter-message-subscribed` or `jupyter-add-receive-callback`); `jupyter-message-type`/`jupyter-message-get` accessors (not raw `plist-get`).

- [ ] P6-T1 Add `ejn:notebook-start-kernel` interactive command to `ejn.el` with `C-c C-S-k` keybinding; prompts for kernelspec; stores client in `notebook.kernel-id`; activates `ejn-kernel-manager-mode` (B38) [smoke] (structural wiring — wrapper + keybinding, no logic)
- [ ] P6-T2 Rewrite `ejn--execute-cell` in `ejn-network.el`: call `ejn-shadow-sync-cell` before send; use `jupyter-execute-request` within kernel client context; store `(jupyter-request-id req)` in cell slot for parent-ID correlation (B36, B37) [tdd] (I/O, state mutation, client context management)
- [ ] P6-T3 Rewrite iopub pipeline: register `jupyter-iopub-message-hook` in `ejn-kernel-start` (called with `(client msg)`); rewrite `ejn--iopub-handler` to accept `(client msg)`, use `jupyter-message-type`/`jupyter-message-get` accessors, correlate messages to cells via parent-ID matching against stored request-ids; rewrite `ejn--render-output` for `stream`/`execute_result`/`display_data`/`error`/`execute_reply`; update `exec-count` on `execute_reply` (B34, B35, B39) [tdd] (message dispatch, MIME rendering, conditional branches, parent-ID correlation)

### Phase 7 — LSP registration + master view scroll

- [ ] P7-T1 Fix `ejn-lsp--register-virtual-buffer`: extract integer `offset-line` from `(LINE . COL)` cons via `car`; wrap args in `(list ...)`. Fix `ejn--create-master-view` scroll hook: use `buffer-local-value` for `window-scroll-functions` check. Add `defconst ejn--cell-chunk-head-prefix`; replace all `format "# %%%%<ejn-cell:…"` call sites with the constant (B30–B33) [smoke] (structural API call fix, no new logic)

### Phase 8 — Undo system

- [ ] P8-T1 Add `ejn--undo-before-change` (`before-change-functions` hook capturing full buffer to `ejn--pre-change-snapshot`); rewrite `ejn--undo-after-change` to use snapshot for `before-text`; register hook in `ejn-cell-open-buffer` (B40) [tdd] (data capture, state mutation, conditional debounce logic)
- [ ] P8-T2 Fix `ejn-global-undo`: remove `erase-buffer` before `replace-buffer-contents`; dispatch structural undo via `ejn--undo-structural-change` when `operation` is not `:content` (B41, B42) [tdd] (state mutation, conditional dispatch)
- [ ] P8-T3 Fix `with-current-buffer` nesting in `ejn:worksheet-toggle-cell-type` and `ejn:worksheet-change-cell-type`: close form before markdown render / header refresh / master re-render (B43, B44) [smoke] (structural — parenthesis fix only)

### Phase 9 — Save failure handling on close

- [ ] P9-T1 Fix `ejn:notebook-close`: call `ejn-notebook-save` directly (not command wrapper); on `nil` return, prompt "Save failed. Close anyway and lose changes?"; `user-error` on decline; proceed with buffer kills on confirmation or success (B29) [smoke] (adds one conditional prompt — structural guard)

## Bug → Task mapping

| Bug | Task | Status |
|-----|------|--------|
| B01 | P1-T2 | done |
| B02 | P1-T1 | done |
| B03 | P1-T1 | done |
| B04 | P2-T1 | done |
| B05 | P2-T1 | done |
| B06 | P2-T1 | done |
| B07 | P2-T1 | done |
| B08 | P2-T1 | done |
| B09 | P2-T1 | done |
| B10 | P2-T1 | done |
| B11 | P2-T1 | done |
| B12 | P2-T1 | done |
| B13 | P2-T1 | done |
| B14 | P3-T1 | done |
| B15 | P3-T1 | done |
| B16 | P2-T1 | done |
| B17 | P2-T1 | done |
| B18 | P2-T1 | done |
| B19 | P2-T1 | done |
| B20 | P2-T1 | done |
| B21 | P4-T1 | pending |
| B22 | P4-T1 | pending |
| B23 | P4-T1 | pending |
| B24 | P5-T1 | pending |
| B25 | P5-T2 | pending |
| B26 | P5-T2 | pending |
| B27 | P5-T2 | pending |
| B28 | P5-T2 | pending |
| B29 | P9-T1 | pending |
| B30 | P7-T1 | pending |
| B31 | P7-T1 | pending |
| B32 | P7-T1 | pending |
| B33 | P7-T1 | pending |
| B34 | P6-T3 | pending |
| B35 | P6-T3 | pending |
| B36 | P6-T2 | pending |
| B37 | P6-T2 | pending |
| B38 | P6-T1 | pending |
| B39 | P6-T3 | pending |
| B40 | P8-T1 | pending |
| B41 | P8-T2 | pending |
| B42 | P8-T2 | pending |
| B43 | P8-T3 | pending |
| B44 | P8-T3 | pending |
