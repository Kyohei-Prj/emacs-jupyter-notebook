# Emacs-Jupyter-Notebook (EJN) — Phase 1 Specification

## Goal

Enable Emacs users to create and navigate a Jupyter-like notebook buffer with code and markdown cells, using standard Emacs keybindings (`C-c C-b` to insert below, `C-<down>` to navigate). The buffer uses overlays to mark cell boundaries and maintains an internal registry for O(1) navigation. No kernel integration or file I/O yet — only the structural foundation.

## Features

1. Create notebook buffer → `M-x ejn:notebook-open-scratch` opens new buffer with one empty code cell
2. Insert cell below current → `C-c C-b` inserts new code cell below current cell, moves point to new cell
3. Insert cell above current → `C-c C-a` inserts new code cell above current cell, moves point to new cell
4. Navigate to next cell → `C-<down>` or `C-c C-n` moves point to start of next cell (stays at last if at end)
5. Navigate to previous cell → `C-<up>` or `C-c C-p` moves point to start of previous cell (stays at first if at start)
6. Kill current cell → `C-c C-k` deletes current cell; if last cell remains, creates new empty code cell

## Out of scope

- File I/O (`.ipynb` loading/saving)
- Kernel execution
- Markdown rendering
- Rich output (images, HTML)
- LSP integration
- Cell reordering (move up/down)
- Cell splitting/merging
- Output visibility toggling

## Architecture

### Data model

| Entity | Fields | Constraints |
|---|---|---|
| `ejn-cell` (struct) | `id` (string), `type` (symbol: `'code` or `'markdown`), `input-start` (integer), `input-end` (integer), `overlay` (overlay) | `input-start` < `input-end`; `overlay` must span `[input-start, input-end]` |
| Buffer-local registry | `ejn--cells` (list of `ejn-cell`, ordered by buffer position) | List order matches overlay order in buffer |

### Interface contracts

#### Mode & Keymap
- `ejn-mode`: derived from `fundamental-mode`, `line-wrap` disabled
- `ejn-mode-map`: sparse keymap with bindings defined in Features
- Buffer-local variable: `ejn--cells` (initially `nil`)

#### Core Functions (internal)
- `ejn--cell-at-point ()` → `ejn-cell` or `nil`
- `ejn--generate-cell-id ()` → string (64-bit hex)
- `ejn--register-cell (cell)` → `nil`
- `ejn--remove-cell (cell)` → `nil`
- `ejn--insert-cell-at-point (type)` → `ejn-cell`
- `ejn--validate-state ()` → signals error if invariants violated

#### Commands (interactive, public API)
- `ejn:notebook-open-scratch ()` → creates buffer, enables mode, inserts initial cell
- `ejn:worksheet-insert-cell-below-km ()` → inserts cell below, moves point
- `ejn:worksheet-insert-cell-above-km ()` → inserts cell above, moves point
- `ejn:worksheet-goto-next-input-km ()` → moves point to next cell
- `ejn:worksheet-goto-prev-input-km ()` → moves point to prev cell
- `ejn:worksheet-kill-cell-km ()` → kills cell, handles edge case

#### Faces
- `ejn-code-cell`: `:box` (thin line), `:background` (subtle gray, e.g., `#f0f0f0`)
- `ejn-markdown-cell`: `:box` (thin line), `:background` (subtle yellow, e.g., `#fffef0`)

### Tech stack

- Emacs 28+ (for `cl-defstruct`, overlays, lexical binding)
- ERT (Emacs Lisp Regression Testing)
- Always use`elisp-dev` MCP to facilitate Emacs Lisp (elisp) development
- `make-string-random` or `(format "%x" (random (expt 2 64)))` for cell IDs

### Non-goals

- No cell validation (cells can be empty)
- No cell metadata storage (execution count, timestamps deferred to Phase 2+)
- No hook system (cell-insert hooks added later)
- No undo/redo tracking beyond Emacs standard undo

## Task list

### Phase 1 — Core Buffer Model & Cell Navigation

#### 1. Project Skeleton & Mode Initialization

- [ ] P1-T1 Create package files (`ejn.el`, `ejn-core.el`, `ejn-mode.el`) with headers and `provide` [scaffold] (file creation only)
- [ ] P1-T2 Define `ejn-mode` (fundamental-mode derived), `ejn-mode-map`, and `ejn--cells` buffer-local variable [smoke] (structural mode definition)
- [ ] P1-T3 Implement `ejn:notebook-open-scratch` command (create buffer, enable mode, insert initial empty code cell) [smoke] (structural wiring, no logic)

#### 2. Cell Data Model

- [ ] P1-T4 Define `ejn-cell` struct with fields: id, type, input-start, input-end, overlay [scaffold] (data structure definition only)
- [ ] P1-T5 Implement `ejn--generate-cell-id` using 64-bit hex random string [tdd] (algorithm: ID generation)
- [ ] P1-T6 Implement `ejn--register-cell` and `ejn--remove-cell` for buffer-local `ejn--cells` list [tdd] (state mutation: list operations)

#### 3. Cell Rendering (Overlays)

- [ ] P1-T7 Define faces `ejn-code-cell` and `ejn-markdown-cell` with `:box` and `:background` properties [scaffold] (face definition only)
- [ ] P1-T8 Implement `ejn--insert-cell-at-point` (insert text, create overlay with face, link to struct) [tdd] (I/O: buffer modification + overlay creation)
- [ ] P1-T9 Ensure cells are contiguous (no blank line separator), overlays non-overlapping [smoke] (layout constraint, no logic)

#### 4. Cell Insertion Commands

- [ ] P1-T10 Implement `ejn:worksheet-insert-cell-below-km` (find current cell, move to end, insert new code cell) [tdd] (command logic: find + insert + navigation)
- [ ] P1-T11 Implement `ejn:worksheet-insert-cell-above-km` (find current cell, move to start, insert new code cell) [tdd] (command logic: find + insert + navigation)

#### 5. Cell Navigation

- [ ] P1-T12 Implement `ejn--cell-at-point` using `overlays-at` and `overlay-get` for `ejn-cell` property [tdd] (lookup: overlay search)
- [ ] P1-T13 Implement `ejn:worksheet-goto-next-input-km` (get index, move to next if exists, else stay) [tdd] (navigation logic with boundary check)
- [ ] P1-T14 Implement `ejn:worksheet-goto-prev-input-km` (get index, move to prev if exists, else stay) [tdd] (navigation logic with boundary check)

#### 6. Cell Deletion

- [ ] P1-T15 Implement `ejn:worksheet-kill-cell-km` (delete region, remove overlay, unregister, create new cell if last) [tdd] (deletion with edge case handling)

#### 7. Consistency & Safety Layer

- [ ] P1-T16 Implement `ejn--validate-state` (check: no overlapping overlays, list matches buffer order, all overlays map to valid cells) [tdd] (validation logic)
- [ ] P1-T17 Define macro `ejn--with-cell-update` wrapping body with `(ejn--validate-state)` call at end [smoke] (macro definition, structural)

#### 8. Keymap Wiring

- [ ] P1-T18 Bind all Phase 1 keys in `ejn-mode-map` (`C-<down>`, `C-<up>`, `C-c C-n`, `C-c C-p`, `C-c C-a`, `C-c C-b`, `C-c C-k`) [smoke] (structural wiring)

## Human Review Flags

1. **Cell ID strategy**: UUID via `(format "%x" (random (expt 2 64)))` chosen for stability across future reordering (Phase 2). Confirm acceptable.
2. **Edge case**: Deleting last cell creates new empty code cell. Confirm this behavior is desired.
3. **Face colors**: `ejn-code-cell` uses `#f0f0f0` (gray), `ejn-markdown-cell` uses `#fffef0` (yellow). Adjust if brand colors differ.

---

**Next step**: Approve this SPEC.md or request amendments. Upon approval, the build loop begins with Phase 1 tasks in order.
