# EJN Code Inspection Fix Plan

**Date:** 2026-05-03
**Source:** Self-inspection + senior engineer review
**Scope:** All identified bugs, architectural gaps, and quality issues

---

## Priority 1: Critical Bugs (Must Fix)

These cause runtime corruption, broken functionality, or data loss.

### P1-1: `ejn--output-overlay` always creates new overlay

**File:** `lisp/ejn-network.el:241-257`
**Problem:** The `when` branch at line 250-251 evaluates to `overlay` but doesn't exit the function. Execution falls through and always creates a new overlay, leaking overlays and ignoring the cached one.
**Impact:** Every call creates a new overlay. Old overlays are never deleted, accumulating in the buffer. The `:output-overlay` slot is overwritten each time, losing references to old overlays.
**Fix:** Change `when` to `if` with the creation block as the `else` branch:

```elisp
(defun ejn--output-overlay (cell)
  (let* ((buf (slot-value cell 'buffer))
         (overlay (slot-value cell 'output-overlay)))
    (if (and overlay (overlayp overlay))
        overlay
      (with-current-buffer buf
        (goto-char (point-max))
        (let ((new-overlay (make-overlay (point) (point))))
          (overlay-put new-overlay 'after-string "")
          (oset cell output-overlay new-overlay)
          new-overlay))))))
```

### P1-2: `jupyter-insert` writes to buffer, not overlay

**File:** `lisp/ejn-network.el:259-277`
**Problem:** `jupyter-insert` inserts text at point in the buffer. Output content is inserted directly into the cell buffer, polluting the source code. The architecture specifies output should appear in the overlay's `after-string`.
**Impact:** Cell source code is corrupted by output text. Subsequent edits mix with output content. Save will serialize output as part of source.
**Fix:** Replace `jupyter-insert` with manual `after-string` construction. Parse the MIME data, convert to a styled string, and set it on the overlay's `after-string`. Rough sketch:

```elisp
(defun ejn--render-output (cell msg)
  (let* ((content (plist-get msg 'content))
         (data (plist-get content 'data))
         (metadata (plist-get content 'metadata)))
    (when (and data (slot-value cell 'buffer)
               (buffer-live-p (slot-value cell 'buffer)))
      (let ((overlay (ejn--output-overlay cell))
            (rendered (ejn--render-mime-data data metadata)))
        (overlay-put overlay 'after-string rendered))))
    nil))

(defun ejn--render-mime-data (data metadata)
  "Render MIME DATA into a styled string for overlay after-string."
  ;; Priority: text/html > image/png > image/svg+xml > text/plain
  ...)
```

### P1-3: `ejn-markdown-render-cell` runs for non-markdown cells

**File:** `lisp/ejn-ui.el:370-396`
**Problem:** The `unless` at line 383-384 returns nil for non-markdown cells but doesn't exit. The `let*` body at line 385 runs for all cell types.
**Impact:** Code cells get markdown text properties applied (bold/italic/link regex matching). `font-lock-fontify-buffer` runs on code buffers unnecessarily.
**Fix:** Change `unless` + fallthrough to `when` + guarded body:

```elisp
(defun ejn-markdown-render-cell (cell)
  (when (eq (slot-value cell 'type) 'markdown)
    (let* ((source (slot-value cell 'source))
           (buf (and source (slot-value cell 'buffer))))
      (if (not (and source (> (length source) 0) buf (buffer-live-p buf)))
          nil
        (when (fboundp 'markdown-mode)
          (with-current-buffer buf
            (font-lock-fontify-buffer)))
        (ejn--markdown-apply-text-properties buf)
        nil))))
```

### P1-4: Yank consumes kill-ring entry

**File:** `lisp/ejn-cell.el:411-433`
**Problem:** Line 431: `(oset notebook ejn-cell-kill-ring (cdr kill-ring))` pops the entry from the kill-ring on yank. Emacs convention is that yank does NOT consume.
**Impact:** User can only yank once per copy. Second yank fails with "Kill ring is empty".
**Fix:** Remove the `oset` line. Keep the kill-ring intact:

```elisp
(defun ejn:worksheet-yank-cell ()
  ...
  (let* ((entry (car kill-ring))   ; read, don't pop
         ...)
    ;; Remove this line:
    ;; (oset notebook ejn-cell-kill-ring (cdr kill-ring))
    ...))
```

---

## Priority 2: Architectural Gaps (Should Fix)

These affect core features and user experience.

### P2-1: `window-scroll-functions` hook registered globally

**File:** `lisp/ejn-master.el:158-159`
**Problem:** `add-hook` without `'local` flag makes the hook global. Every window scroll in Emacs (any buffer) triggers `ejn--master-scroll-hook`, which then checks `ejn--notebook` in the scrolled buffer.
**Impact:** Performance cost on every scroll in non-EJN buffers. Minor but unnecessary.
**Fix:** Add `'local` flag:

```elisp
(add-hook 'window-scroll-functions #'ejn--master-scroll-hook 'append 'local)
```

### P2-2: Cell move functions don't explicitly update slot

**File:** `lisp/ejn-cell.el:230-261, 263-295`
**Problem:** Both `move-cell-up` and `move-cell-down` use `setf (nth ...)` to mutate the shared list cons cells, but never call `(oset notebook cells cells)`. Works by side effect on shared structure, but is fragile.
**Impact:** Currently functional, but would silently break if the list were ever copied/reconsed. Defensive coding issue.
**Fix:** Add explicit `(oset notebook cells cells)` after the `setf` in both functions.

### P2-3: `ejn--cell-after-change-hook` is dead code

**File:** `lisp/ejn-cell.el:49-54`
**Problem:** `ejn--cell-after-change-hook` is defined but never added as a hook. The `remove-hook` call in `ejn-cell-open-buffer` at line 126 is a no-op (removing something that was never added).
**Impact:** Dead code, harmless but confusing.
**Fix:** Remove `ejn--cell-after-change-hook` and the corresponding `remove-hook` call.

### P2-4: `undercover` listed as runtime dependency

**File:** `Eask:17-19`
**Problem:** Line 17: `(development "undercover")` and line 19: `(depends-on "undercover")`. Undercover is a coverage tool, should only be a development dependency.
**Impact:** Installs an unnecessary runtime dependency.
**Fix:** Remove line 19: `(depends-on "undercover")`.

### P2-5: Structural undo stubs for `:move`, `:split`, `:merge`

**File:** `lisp/ejn-ui.el:319-324`
**Problem:** `ejn--undo-structural-change` prints "not yet implemented" for `:move`, `:split`, `:merge` operations.
**Impact:** User who performs these operations and tries global undo gets a message, changes are lost.
**Fix:** Implement reversal logic:
- `:move` — reverse the swap (swap cells back to original positions)
- `:split` — merge the two cells back with `\n\n` separator
- `:merge` — split at the known separator point

### P2-6: Misplaced docstrings

**Files:** `lisp/ejn-network.el:100, 186, 200`
**Problem:** `(let` opens on the same line as the closing `"` of the docstring. Emacs accepts this but causes indentation issues and poor readability.
**Impact:** Cosmetic only, but affects code quality.
**Fix:** Move `(let` to the next line after the closing `"`.

---

## Priority 3: Verification Needed (Investigate)

These require checking against actual dependencies or runtime behavior.

### P3-1: `lsp-virtual-buffer-register` API signature

**File:** `lisp/ejn-lsp.el:224-226`
**Problem:** The call uses keyword arguments `:real-buffer`, `:virtual-file`, `:offset-line`. Need to verify if `lsp-virtual-buffer-register` accepts these as keyword args or requires a single plist argument.
**Action:** Check `lsp-mode` source or M-x `describe-function` on a live Emacs. If API is wrong, fix the call. Verify the fallback path works correctly as well.

### P3-2: `lsp-find-definition` usage

**File:** `lisp/ejn-lsp.el:341`
**Problem:** `lsp-find-definition` is called with `composite-pos` as argument, but it may not accept position arguments — it typically operates on `(point)`.
**Action:** Verify `lsp-find-definition` signature. If it doesn't accept args, may need to use `lsp-request :textDocument/definition` with a position parameter instead.

### P3-3: Composite position translation consistency

**Files:** `lisp/ejn-lsp.el:71-126`
**Problem:** The composite generator adds `(princ "\n")` after each source, while the position translator adds `+1` only for trailing-newline sources. The interaction may have off-by-one errors.
**Action:** Write targeted unit tests with specific source strings (with/without trailing newlines) to verify pos-to-composite and pos-from-composite are exact inverses.

### P3-4: JSON round-trip for `outputs`

**File:** `lisp/ejn-notebook.el:33-42`
**Problem:** `ejn--cell-to-json` passes `outputs` directly to `json-encode`. Outputs may contain nested hash-tables/lists parsed from JSON. Round-trip validity is untested.
**Action:** Add a save → load round-trip test in `test/ejn-notebook-tests.el` that verifies outputs survive serialization.

---

## Priority 4: UX Improvements

Nice-to-have changes that improve user experience.

### P4-1: Cache deletion on close

**Files:** `ejn.el:154-180, ejn.el:381-415`
**Problem:** Both `ejn:notebook-kill-kernel-then-close` and `ejn:notebook-close` delete `.ejn-cache/<stem>/` recursively. Reopening the notebook regenerates everything from scratch.
**Suggestion:** Preserve cache across sessions. Only delete on explicit user request or when cache is stale (e.g., notebook moved). Consider deleting only `composite.py` and output files, not shadow files.

### P4-2: `completing-read` prompt polish

**File:** `ejn.el:322`
**Problem:** Prompt is `"Cell type: '("` — the leading quote and paren are cosmetic noise.
**Fix:** Change to `"Cell type: "`.

### P4-3: Kernel completion stub

**File:** `lisp/ejn-lsp.el:358-362`
**Problem:** `ejn-kernel-complete` signals `user-error`. If accidentally triggered, produces an error.
**Suggestion:** Change to `(message "Kernel completion not yet available")` or return `nil` gracefully.

---

## Execution Order

1. P1-1, P1-2, P1-3, P1-4 (critical bugs, small fixes)
2. P2-1, P2-2, P2-3, P2-4, P2-6 (architectural, small fixes)
3. P3-1, P3-2, P3-3, P3-4 (investigation, may require lsp-mode/jupyter.el inspection)
4. P2-5 (structural undo, proper implementation task)
5. P4-1, P4-2, P4-3 (UX polish)

---

## Testing Strategy

After each fix batch:
- Run `make test` to verify no regressions
- For P1 fixes, add targeted ERT tests:
  - P1-1: Test that calling `ejn--output-overlay` twice returns the same overlay
  - P1-2: Test that output appears in overlay `after-string`, not in buffer source
  - P1-3: Test that calling on code cell returns nil without side effects
  - P1-4: Test that yanking twice works
- For P3 fixes, add position translation round-trip tests
