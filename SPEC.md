# SPEC — EJN Code Inspection Fixes

**Date:** 2026-05-03
**Source:** `plan/fixes.md`

---

## Goal

Eliminate all runtime bugs that corrupt cell buffers, leak overlays, or violate Emacs conventions, close architectural gaps that cause unnecessary work or dead code, verify LSP integration correctness against live dependencies, and apply targeted UX polish — producing a stable, maintainable codebase with full regression coverage for every fix.

---

## Features

1. Overlay cache (P1-1) → Calling `ejn--output-overlay` twice on the same cell returns the identical overlay object; no orphan overlays accumulate in the buffer.
2. MIME output rendering (P1-2) → Kernel output appears in the overlay's `after-string` property, never inserted into the cell buffer's text. `text/plain` renders as ansi-colored text. `text/html` renders via `shr` in graphical Emacs or shows a `"[HTML output]"` placeholder in terminal. `image/png`, `image/jpeg`, `image/svg+xml` render as `create-image` objects in graphical Emacs or `"[image/png]"`-style placeholders in terminal. `text/latex` renders as plain text. Error messages (`ename`/`evalue`/`traceback`) render as red-propertized text.
3. Markdown guard (P1-3) → Calling `ejn-markdown-render-cell` on a code cell returns `nil` without applying text properties or calling `font-lock-fontify-buffer`.
4. Yank non-consuming (P1-4) → `ejn:worksheet-yank-cell` can be invoked twice in succession; both yanks produce cells with identical source and type.
5. Local scroll hook (P2-1) → `ejn--master-scroll-hook` appears only in the master buffer's local `window-scroll-functions`, not in the global value.
6. Defensive slot write (P2-2) → Both `ejn:worksheet-move-cell-up` and `ejn:worksheet-move-cell-down` call `(oset notebook cells cells)` after mutating the shared list.
7. Dead code removal (P2-3) → `ejn--cell-after-change-hook` function definition and its `remove-hook` call in `ejn--cell-kill-buffer-hook` are both removed.
8. Undercover dep removal (P2-4) → `(depends-on "undercover")` line is removed from `Eask`; `(development "undercover")` remains.
9. Docstring placement (P2-6) → In `ejn-kernel-stop`, `ejn--cell-notebook`, `ejn--iopub-handler`, the `(let` or `(when-let*` form opens on the line after the closing docstring `"`.
10. lsp-virtual-buffer-register API (P3-1) → `ejn-lsp--register-virtual-buffer` calls `lsp-virtual-buffer-register` with the correct argument form; a `condition-case` guards against API mismatch errors.
11. lsp-find-definition API (P3-2) → `ejn:pytools-jump-to-source` calls `lsp-find-definition` with the correct argument form; a `condition-case` guards against API mismatch errors.
12. Position translation tests (P3-3) → ERT tests verify `ejn-lsp-pos-to-composite` and `ejn-lsp-pos-from-composite` are exact inverses for sources with and without trailing newlines.
13. JSON outputs round-trip test (P3-4) → ERT test saves a notebook with non-nil `outputs` to a temp `.ipynb`, reloads it, and asserts outputs survive serialization unchanged.
14. Cache preservation (P4-1) → `ejn:notebook-kill-kernel-then-close` and `ejn:notebook-close` no longer delete `.ejn-cache/<stem>/`. Cache directory persists across sessions.
15. Cell type prompt (P4-2) → `completing-read` in `ejn:worksheet-change-cell-type` prompts `"Cell type: "` (no leading `'(`).
16. Kernel completion stub (P4-3) → `ejn-kernel-complete` calls `(message "Kernel completion not yet available")` and returns `nil` instead of signaling `user-error`.

---

## Out of scope

- P2-5 (structural undo for `:move`, `:split`, `:merge`) — excluded by request; current stub behavior is acceptable.
- Cache staleness detection — cache is preserved as-is; no age-based or content-based invalidation.
- Full `jupyter-insert` MIME parity — only common MIME types (text/plain, text/html, image/png/jpeg/svg+xml, text/latex, error) are handled.
- Polymode chunk editing — P5 polymode integration is a separate effort.

---

## Architecture

### Data model

No data model changes. All EIEIO classes (`ejn-notebook`, `ejn-cell`) remain unchanged.

### Interface contracts

| Function | File | Change |
|---|---|---|
| `ejn--output-overlay` | `lisp/ejn-network.el` | Return cached overlay; no fallthrough creation |
| `ejn--render-output` | `lisp/ejn-network.el` | Set `after-string` on overlay; do not call `jupyter-insert` |
| `ejn--render-mime-data` | `lisp/ejn-network.el` | NEW — returns styled string from MIME data plist |
| `ejn-markdown-render-cell` | `lisp/ejn-ui.el` | Guard body with `when` on cell type |
| `ejn:worksheet-yank-cell` | `lisp/ejn-cell.el` | Remove kill-ring pop |
| `ejn--create-master-view` | `lisp/ejn-master.el` | Add `'local` to scroll hook |
| `ejn:worksheet-move-cell-up` | `lisp/ejn-cell.el` | Add `(oset notebook cells cells)` |
| `ejn:worksheet-move-cell-down` | `lisp/ejn-cell.el` | Add `(oset notebook cells cells)` |
| `ejn--cell-after-change-hook` | `lisp/ejn-cell.el` | Removed entirely |
| `ejn--cell-kill-buffer-hook` | `lisp/ejn-cell.el` | Remove `remove-hook` for dead function |
| `ejn-lsp--register-virtual-buffer` | `lisp/ejn-lsp.el` | Add `condition-case` around `lsp-virtual-buffer-register` |
| `ejn:pytools-jump-to-source` | `lisp/ejn-lsp.el` | Add `condition-case` around `lsp-find-definition` |
| `ejn-kernel-complete` | `lisp/ejn-lsp.el` | Return nil + message instead of signal |
| `ejn:worksheet-change-cell-type` | `ejn.el` | Prompt string changed |
| `ejn:notebook-kill-kernel-then-close` | `ejn.el` | Remove `delete-directory` call |
| `ejn:notebook-close` | `ejn.el` | Remove `delete-directory` call |

### Tech stack

- Emacs 30.1+ lexical-binding elisp — target platform
- EIEIO — data model
- ERT — test framework
- `jupyter` elpa package — kernel communication
- `lsp-mode` — LSP integration (verified against live installation)
- `json` — notebook serialization

### Non-goals

- No new public API surface; all new functions are internal (`ejn--` prefix).
- No cache versioning or migration logic.
- No image display in terminal Emacs (placeholder strings only).

---

## Current phase

Phase 3 — Verification

## Task list

### Phase 1 — Critical Bugs

Fix four runtime bugs that corrupt cell buffers, leak overlays, or violate Emacs conventions.

- [x] P1-T1 Fix `ejn--output-overlay` to return cached overlay via `if` instead of `when` fallthrough [tdd] (conditional branch + overlay cache; acceptance: two calls return identical overlay)
- [x] P1-T2 Replace `jupyter-insert` in `ejn--render-output` with `ejn--render-mime-data` → overlay `after-string`; handle `text/plain`, `text/html`, `image/png`, `image/jpeg`, `image/svg+xml`, `text/latex`, and `error` msg_type [tdd] (data transformation + MIME dispatch + string propertization; acceptance: output in overlay, not buffer text)
- [x] P1-T3 Guard `ejn-markdown-render-cell` body with `when (eq type 'markdown)` so non-markdown cells skip rendering [tdd] (conditional guard; acceptance: code cell returns nil with no side effects)
- [x] P1-T4 Remove kill-ring pop from `ejn:worksheet-yank-cell`; read `(car kill-ring)` without mutating the slot [tdd] (state mutation fix; acceptance: two successive yanks produce identical cells)

### Phase 2 — Architectural Gaps

Close five architectural gaps: global hook, fragile mutation, dead code, wrong dependency, cosmetic formatting.

- [x] P2-T1 Add `'local` flag to `add-hook` for `window-scroll-functions` in `ejn--create-master-view` [smoke] (structural fix — hook registration scope)
- [x] P2-T2 Add `(oset notebook cells cells)` after `setf` in both `move-cell-up` and `move-cell-down` [smoke] (defensive coding — no behavioral change, verifies list identity)
- [x] P2-T3 Remove `ejn--cell-after-change-hook` function and its `remove-hook` call in `ejn--cell-kill-buffer-hook` [smoke] (dead code removal — verify no other callers via grep)
- [x] P2-T4 Remove `(depends-on "undercover")` from `Eask`; keep `(development "undercover")` [scaffold] (config change only — no code)
- [x] P2-T5 Move `(let` / `(when-let*` to next line after closing docstring `"` in `ejn-kernel-stop`, `ejn--cell-notebook`, `ejn--iopub-handler` [smoke] (cosmetic formatting — no behavioral change)

### Phase 3 — Verification

Verify LSP API correctness and add round-trip tests for position translation and JSON serialization.

- [x] P3-T1 Verify `lsp-virtual-buffer-register` API signature; wrap call in `condition-case` with fallback if signature mismatches [tdd] (error handling + conditional dispatch; acceptance: no void-function error)
- [x] P3-T2 Verify `lsp-find-definition` API signature; wrap call in `condition-case` with `(save-excursion (goto-char pos))` fallback if it rejects position arg [tdd] (error handling + conditional dispatch; acceptance: no void-function or wrong-number-of-args error)
- [x] P3-T3 Write ERT tests for `ejn-lsp-pos-to-composite` / `ejn-lsp-pos-from-composite` round-trip with sources having trailing newlines, no trailing newlines, empty sources, and multi-line sources [tdd] (test writing; acceptance: pos→composite→pos returns original coords)
- [x] P3-T4 Write ERT test that saves a notebook with non-empty `outputs` to temp `.ipynb`, reloads via `ejn-notebook-load`, and asserts outputs match [tdd] (test writing; acceptance: outputs survive json-encode/json-parse round-trip)

### Phase 4 — UX Polish

Three targeted UX improvements.

- [ ] P4-T1 Remove `delete-directory` calls from `ejn:notebook-kill-kernel-then-close` and `ejn:notebook-close` [smoke] (code removal — verify cache persists after close)
- [ ] P4-T2 Change `completing-read` prompt in `ejn:worksheet-change-cell-type` from `"Cell type: '("` to `"Cell type: "` [smoke] (string literal change)
- [ ] P4-T3 Replace `(signal 'user-error ...)` in `ejn-kernel-complete` with `(message "Kernel completion not yet available")` returning `nil` [smoke] (error → graceful no-op)

---

## Testing Strategy

### Phase 1 (Critical Bugs)
Each fix gets targeted ERT tests in the corresponding test file:
- P1-T1 → `test/ejn-network-tests.el`: verify same overlay returned on repeated calls; verify no overlay accumulation.
- P1-T2 → `test/ejn-network-tests.el`: verify output appears in `after-string` property; verify buffer text is unchanged; verify error messages render.
- P1-T3 → `test/ejn-ui-tests.el`: call on code cell → return nil, no text properties applied.
- P1-T4 → `test/ejn-cell-tests.el`: yank twice → both cells have same source/type.

### Phase 2 (Architectural)
- P2-T1 → `test/ejn-master-tests.el`: assert hook is buffer-local.
- P2-T2 → `test/ejn-cell-tests.el`: assert `(slot-value notebook 'cells)` identity after move (smoke-level check).
- P2-T3 → `grep` for zero remaining references to `ejn--cell-after-change-hook`.
- P2-T4 → `make test` passes; no undercover import at runtime.
- P2-T5 → `make lint` (checkdoc) passes with no warnings on the three functions.

### Phase 3 (Verification)
- P3-T1 → `test/ejn-lsp-tests.el`: stub test that `ejn-lsp--register-virtual-buffer` does not signal when `lsp-virtual-buffer-register` is void.
- P3-T2 → `test/ejn-lsp-tests.el`: stub test that `ejn:pytools-jump-to-source` does not signal on API mismatch.
- P3-T3 → `test/ejn-lsp-tests.el`: new round-trip tests.
- P3-T4 → `test/ejn-notebook-tests.el`: new round-trip test.

### Phase 4 (UX)
- P4-T1 → `test/ejn-core-tests.el` or `test/ejn-notebook-tests.el`: verify cache dir still exists after close.
- P4-T2 → Smoke: inspect source string.
- P4-T3 → `test/ejn-lsp-tests.el`: call returns nil, no signal.

### Regression gate
After each phase merge, run `make test` on the full suite to confirm no regressions.
