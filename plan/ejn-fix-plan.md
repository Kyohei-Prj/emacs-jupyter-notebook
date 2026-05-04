# EJN — Complete Bug Fix Plan

**44 bugs across 7 files.** This plan groups them into 10 fix tasks, ordered so each task can be applied, loaded, and tested independently before the next begins. Every fix includes the exact location, the root cause, the complete replacement code, and the test to confirm it works.

---

## How to Read This Plan

Each task lists:
- **Bugs fixed** — the bug IDs from the inventory table at the end
- **File / function / line** — where to make the change
- **Root cause** — why it is broken
- **Fix** — the complete replacement code (not a diff, but the full corrected form)
- **Test** — the minimal interactive test to confirm the fix

---

## Task 1 — Fix Buffer-Local Variable Declarations

**Bugs fixed:** B02, B03  
**Files:** `ejn-core.el` line 356, `ejn-cell.el` line 45  
**Severity:** Low (silent failure; masks missing notebook associations)

### Root cause

`ejn--notebook` and `ejn--cell` are declared with plain `defvar`, which makes them global by default. They rely on `(set (make-local-variable ...) ...)` at buffer creation time to work per-buffer. This is fragile: `buffer-local-value` on a buffer where `make-local-variable` was never called returns the global `nil` silently rather than signaling an error. Additionally, having the master view and each cell share a global default is a latent data-corruption risk.

### Fix — `ejn-core.el`

```elisp
;; BEFORE (line 356):
(defvar ejn--notebook nil
  "Buffer-local variable storing the ejn-notebook for the current view.")

;; AFTER:
(defvar-local ejn--notebook nil
  "Buffer-local variable storing the ejn-notebook for the current view.")
```

### Fix — `ejn-cell.el`

```elisp
;; BEFORE (line 45):
(defvar ejn--cell nil
  "Buffer-local variable storing the `ejn-cell' object for this cell buffer.")

;; AFTER:
(defvar-local ejn--cell nil
  "Buffer-local variable storing the `ejn-cell' object for this cell buffer.")
```

Also remove the redundant `(make-variable-buffer-local 'ejn--notebook)` call in `ejn-master.el` line 43, since `defvar-local` in `ejn-core.el` now handles it globally.

### Test

Load a notebook with `M-x ejn-open-file`. In the master view buffer, evaluate `(describe-variable 'ejn--notebook)`. It should show a buffer-local value (the notebook object), not `nil`.

---

## Task 2 — Fix `ejn-open-file`: Display the Master View

**Bugs fixed:** B01  
**File:** `ejn.el` — `ejn-open-file`  
**Severity:** Blocking (nothing appears on screen after open)

### Root cause

`ejn--create-master-view` creates the master view buffer and returns it, but `ejn-open-file` discards the return value. No `switch-to-buffer` or `display-buffer` is ever called. The master view exists in memory but is invisible.

### Fix — `ejn.el`

```elisp
;; BEFORE:
(defun ejn-open-file ()
  (interactive)
  (let* ((file-path (read-file-name "Open notebook: " nil nil t))
         (notebook (ejn-notebook-load file-path))
         (cells (slot-value notebook 'cells)))
    (ejn--create-master-view notebook)
    (when cells
      (ejn-cell-initialize (car cells) notebook))))

;; AFTER:
(defun ejn-open-file ()
  "Open a Jupyter Notebook .ipynb file.

Prompts for a file path, loads the notebook via `ejn-notebook-load',
creates and displays a master view buffer via `ejn--create-master-view'.
Cells are parsed into EIEIO objects but buffers, shadow files, and
LSP connections are created lazily. The first cell is initialized
immediately for usability via `ejn-cell-initialize'.
Returns nil."
  (interactive)
  (let* ((file-path   (read-file-name "Open notebook: " nil nil t))
         (notebook    (ejn-notebook-load file-path))
         (cells       (slot-value notebook 'cells))
         (master-buf  (ejn--create-master-view notebook)))
    (switch-to-buffer master-buf)
    (when cells
      (ejn-cell-initialize (car cells) notebook))
    nil))
```

### Test

`M-x ejn-open-file` on any `.ipynb` file. The master view buffer `*ejn-master:FILE.ipynb*` should appear in the current window, displaying the notebook's cells as polymode-rendered chunks.

---

## Task 3 — Add Guards and `switch-to-buffer` to All Structural Cell Commands

**Bugs fixed:** B04, B05, B06, B07, B08, B09, B10, B11, B12, B13  
**File:** `ejn-cell.el`  
**Severity:** Blocking (crashes from master view; new buffers not shown)

### Root cause

Eight commands in `ejn-cell.el` read `ejn--cell` and `ejn-notebook-of-buffer` without nil-checking either. `ejn--cell` is only set in cell buffers, not the master view. Calling `(slot-value nil 'type)` crashes with `wrong-type-argument: eieio-object, nil`. Additionally, `insert-above` and `insert-below` call `ejn-cell-open-buffer` but ignore the return value, so the user's view never moves to the new cell.

`copy-cell` and `merge-cell` read `:source` from the EIEIO slot rather than the live buffer, producing stale data. `ejn-shadow-sync-cell` already exists to resolve this.

### Fix — complete rewrite of eight functions in `ejn-cell.el`

**`ejn:worksheet-insert-cell-above`** (replaces lines 190–202):
```elisp
(defun ejn:worksheet-insert-cell-above ()
  "Insert a new code cell above the current cell and switch to it."
  (interactive)
  (let* ((notebook     (ejn-notebook-of-buffer))
         (current-cell ejn--cell))
    (unless notebook     (user-error "No notebook associated with this buffer"))
    (unless current-cell (user-error "No cell at point"))
    (let* ((cells         (slot-value notebook 'cells))
           (current-index (cl-position current-cell cells))
           (cell-type     (slot-value current-cell 'type))
           (new-cell      (ejn--make-cell notebook current-index cell-type)))
      (switch-to-buffer (ejn-cell-open-buffer new-cell notebook)))))
```

**`ejn:worksheet-insert-cell-below`** (replaces lines 205–218):
```elisp
(defun ejn:worksheet-insert-cell-below ()
  "Insert a new code cell below the current cell and switch to it."
  (interactive)
  (let* ((notebook     (ejn-notebook-of-buffer))
         (current-cell ejn--cell))
    (unless notebook     (user-error "No notebook associated with this buffer"))
    (unless current-cell (user-error "No cell at point"))
    (let* ((cells         (slot-value notebook 'cells))
           (current-index (cl-position current-cell cells))
           (cell-type     (slot-value current-cell 'type))
           (new-cell      (ejn--make-cell notebook (1+ current-index) cell-type)))
      (switch-to-buffer (ejn-cell-open-buffer new-cell notebook)))))
```

**`ejn:worksheet-move-cell-up`** (replaces lines 220–253): add guard after `(interactive)`:
```elisp
(defun ejn:worksheet-move-cell-up ()
  "Move the current cell up by one position in the notebook."
  (interactive)
  (let* ((notebook     (ejn-notebook-of-buffer))
         (current-cell ejn--cell))
    (unless notebook     (user-error "No notebook associated with this buffer"))
    (unless current-cell (user-error "No cell at point"))
    (let* ((cells         (slot-value notebook 'cells))
           (current-index (cl-position current-cell cells)))
      (when (= current-index 0)
        (user-error "Cannot move first cell up"))
      (let ((predecessor (nth (1- current-index) cells)))
        (setf (nth (1- current-index) cells) current-cell
              (nth current-index cells)       predecessor)
        (oset notebook cells cells)
        (dolist (cell (list current-cell predecessor))
          (let ((old-shadow (slot-value cell 'shadow-file)))
            (when (and old-shadow (file-exists-p old-shadow))
              (delete-file old-shadow))))
        (ejn-shadow-write-cell current-cell notebook)
        (ejn-shadow-write-cell predecessor notebook)
        (when (fboundp 'ejn--poly-refresh-cells)
          (with-current-buffer (slot-value notebook 'master-buffer)
            (ejn--poly-refresh-cells)))
        (ejn--record-structural-change notebook 'move-up
                                       (list current-cell current-index))))))
```

**`ejn:worksheet-move-cell-down`** (replaces lines 255–290): same pattern:
```elisp
(defun ejn:worksheet-move-cell-down ()
  "Move the current cell down by one position in the notebook."
  (interactive)
  (let* ((notebook     (ejn-notebook-of-buffer))
         (current-cell ejn--cell))
    (unless notebook     (user-error "No notebook associated with this buffer"))
    (unless current-cell (user-error "No cell at point"))
    (let* ((cells     (slot-value notebook 'cells))
           (num-cells (length cells))
           (current-index (cl-position current-cell cells)))
      (when (>= current-index (1- num-cells))
        (user-error "Cannot move last cell down"))
      (let ((successor (nth (1+ current-index) cells)))
        (setf (nth current-index cells)       successor
              (nth (1+ current-index) cells)  current-cell)
        (oset notebook cells cells)
        (dolist (cell (list current-cell successor))
          (let ((old-shadow (slot-value cell 'shadow-file)))
            (when (and old-shadow (file-exists-p old-shadow))
              (delete-file old-shadow))))
        (ejn-shadow-write-cell current-cell notebook)
        (ejn-shadow-write-cell successor notebook)
        (when (fboundp 'ejn--poly-refresh-cells)
          (with-current-buffer (slot-value notebook 'master-buffer)
            (ejn--poly-refresh-cells)))
        (ejn--record-structural-change notebook 'move-down
                                       (list current-cell current-index))))))
```

**`ejn:worksheet-split-cell-at-point`** (replaces lines 330–360): add guard:
```elisp
(defun ejn:worksheet-split-cell-at-point ()
  "Split the current cell at point into two cells."
  (interactive)
  (let* ((notebook     (ejn-notebook-of-buffer))
         (current-cell ejn--cell))
    (unless notebook     (user-error "No notebook associated with this buffer"))
    (unless current-cell (user-error "No cell at point"))
    (let* ((cell-type    (slot-value current-cell 'type))
           (split-point  (line-beginning-position))
           (before       (buffer-substring-no-properties (point-min) split-point))
           (after        (buffer-substring-no-properties split-point (point-max)))
           (current-index (cl-position current-cell (slot-value notebook 'cells))))
      (oset current-cell source before)
      (ejn-shadow-write-cell current-cell notebook)
      (let ((new-cell (ejn--make-cell notebook (1+ current-index) cell-type after)))
        (ejn--reindex-shadow-files notebook)
        (ejn-cell-refresh-buffer current-cell)
        (switch-to-buffer (ejn-cell-open-buffer new-cell notebook))))))
```

**`ejn:worksheet-merge-cell`** (replaces lines 362–403): add guard and sync before reading source:
```elisp
(defun ejn:worksheet-merge-cell ()
  "Merge the current cell with the cell below it."
  (interactive)
  (let* ((notebook     (ejn-notebook-of-buffer))
         (current-cell ejn--cell))
    (unless notebook     (user-error "No notebook associated with this buffer"))
    (unless current-cell (user-error "No cell at point"))
    ;; Sync both cells' buffers to their :source slots before merging
    (ejn-shadow-sync-cell current-cell)
    (let* ((cells         (slot-value notebook 'cells))
           (current-index (cl-position current-cell cells))
           (num-cells     (length cells)))
      (when (>= current-index (1- num-cells))
        (user-error "Cannot merge: current cell is the last cell"))
      (let* ((lower-cell   (nth (1+ current-index) cells))
             (lower-shadow (slot-value lower-cell 'shadow-file))
             (lower-buf    (slot-value lower-cell 'buffer)))
        (when (buffer-live-p lower-buf)
          (ejn-shadow-sync-cell lower-cell))
        (oset current-cell source
              (concat (slot-value current-cell 'source)
                      "\n\n"
                      (slot-value lower-cell 'source)))
        (when (buffer-live-p lower-buf)
          (kill-buffer lower-buf))
        (when (and lower-shadow (file-exists-p lower-shadow))
          (delete-file lower-shadow))
        (oset notebook cells (delq lower-cell cells))
        (ejn--reindex-shadow-files notebook)
        (when (fboundp 'ejn--poly-refresh-cells)
          (with-current-buffer (slot-value notebook 'master-buffer)
            (ejn--poly-refresh-cells)))
        (ejn--record-structural-change notebook 'merge
                                       (list current-cell lower-cell))))))
```

**`ejn:worksheet-yank-cell`** (replaces lines 405–426): add guard on `ejn--cell`:
```elisp
(defun ejn:worksheet-yank-cell ()
  "Yank a cell from the notebook's kill ring below the current cell."
  (interactive)
  (let* ((notebook     (ejn-notebook-of-buffer))
         (current-cell ejn--cell))
    (unless notebook     (user-error "No notebook associated with this buffer"))
    (unless current-cell (user-error "No cell at point"))
    (let ((kill-ring (slot-value notebook 'ejn-cell-kill-ring)))
      (unless kill-ring (user-error "Kill ring is empty"))
      (let* ((entry         (car kill-ring))
             (source        (cdr (assq 'source entry)))
             (type          (cdr (assq 'type entry)))
             (cells         (slot-value notebook 'cells))
             (current-index (cl-position current-cell cells)))
        (switch-to-buffer
         (ejn-cell-open-buffer
          (ejn--make-cell notebook (1+ current-index) type source)
          notebook))))))
```

**`ejn:worksheet-copy-cell`** (replaces lines 428–443): add guard and sync before reading source:
```elisp
(defun ejn:worksheet-copy-cell (&optional kill)
  "Copy the current cell's source and type to the notebook's kill ring.
With KILL non-nil, also remove the cell."
  (interactive "P")
  (let* ((notebook (ejn-notebook-of-buffer))
         (cell     ejn--cell))
    (unless notebook (user-error "No notebook associated with this buffer"))
    (unless cell     (user-error "No cell at point"))
    ;; Sync buffer → :source before copying, so copy reflects current edits
    (ejn-shadow-sync-cell cell)
    (let ((entry `((source . ,(slot-value cell 'source))
                   (type   . ,(slot-value cell 'type)))))
      (oset notebook ejn-cell-kill-ring
            (cons entry (slot-value notebook 'ejn-cell-kill-ring)))
      (when kill
        (ejn:worksheet-kill-cell)))))
```

### Test

Open a notebook. Navigate to a cell buffer (`C-c C-n`). Press `C-c C-b` — a new empty cell buffer should open immediately. Press `C-c C-w` — cell is copied. Press `C-c C-y` — pasted cell buffer opens. Try `C-c <up>` and `C-c <down>` — cell position changes and master view updates consistently (see Task 4 for the renderer fix that makes this visible).

---

## Task 4 — Unify Master View Rendering to Polymode

**Bugs fixed:** B16, B17, B18, B19, B20  
**Files:** `ejn-cell.el` (5 call sites), `ejn-master.el` (dead code removal)  
**Severity:** Blocking (master view corrupts after any structural operation)

### Root cause

`ejn--create-master-view` populates the buffer with `ejn--poly-render-cells` (polymode chunk format: `# %%<ejn-cell:N:code>`). But `ejn--make-cell`, `move-cell-up`, `move-cell-down`, `kill-cell`, and `merge-cell` all call `ejn--refresh-master-cells` (the button renderer: `[code | In [1]] preview...`). After the first structural operation, the two formats are mixed in the same buffer. Polymode's chunk detection finds no valid delimiters and breaks syntax highlighting.

The button renderer (`ejn--render-master-cells`, `ejn--make-cell-button`) is dead code — it was the Phase 2 approach and has been superseded by polymode in Phase 5.

### Fix — `ejn-cell.el`: replace all five refresh calls

In `ejn--make-cell` (line 183–186):
```elisp
;; BEFORE:
(when (and (fboundp 'ejn--refresh-master-cells)
           (buffer-live-p (slot-value notebook 'master-buffer)))
  (with-current-buffer (slot-value notebook 'master-buffer)
    (ejn--refresh-master-cells)))

;; AFTER:
(when (and (fboundp 'ejn--poly-refresh-cells)
           (buffer-live-p (slot-value notebook 'master-buffer)))
  (with-current-buffer (slot-value notebook 'master-buffer)
    (ejn--poly-refresh-cells)))
```

Apply the identical substitution in:
- `ejn:worksheet-kill-cell` (line 325)
- `ejn:worksheet-move-cell-up` (line 249) — already replaced in Task 3's rewrite
- `ejn:worksheet-move-cell-down` (line 285) — already replaced in Task 3's rewrite
- `ejn:worksheet-merge-cell` (line 399) — already replaced in Task 3's rewrite

### Fix — `ejn-master.el`: delete dead button renderer

Delete the following three functions entirely from `ejn-master.el`:
- `ejn--truncate-source` (lines ~46–51)
- `ejn--make-cell-button` (lines ~53–72)
- `ejn--render-master-cells` (lines ~74–90)
- `ejn--refresh-master-cells` (lines ~129–135)

These are no longer called anywhere after the substitutions above.

### Test

Open a notebook. Navigate to a cell (`C-c C-n`). Insert a new cell (`C-c C-b`). Switch back to the master view buffer. It should still display polymode-formatted chunks (`# %%<ejn-cell:N:code>`), not button text.

---

## Task 5 — Fix Navigation in Master View

**Bugs fixed:** B14, B15  
**File:** `ejn-cell.el` — `ejn:worksheet-goto-next-input`, `ejn:worksheet-goto-prev-input`  
**Severity:** Moderate (navigation from master view passes wrong argument)

### Root cause

In the master view branch of `goto-next` and `goto-prev`:
```elisp
(next-button (current-buffer))     ; passes buffer as 'wrap' argument
(previous-button (current-buffer)) ; same error
```

`next-button`'s signature is `(next-button &optional wrap display-message)`. Passing `(current-buffer)` as `wrap` is treated as a truthy wrap flag, making the search wrap around at buffer boundaries — an unintended side effect. The correct call is `(next-button)` with no arguments (or `(forward-button 1)`).

However, there is a more fundamental issue: after Task 4, the master view uses polymode chunk delimiters, not buttons. `next-button` will find no buttons and signal an error immediately. Navigation from the master view should instead move point to the next chunk header.

### Fix — `ejn-cell.el`

```elisp
(defun ejn:worksheet-goto-next-input ()
  "Navigate to the next cell.

If in a cell buffer, switch to the next cell's buffer.
If in the master view buffer, search forward for the next cell
chunk header and move point there."
  (interactive)
  (if (bound-and-true-p ejn--cell)
      ;; Cell buffer path (unchanged)
      (let* ((notebook      (ejn-notebook-of-buffer))
             (cells         (slot-value notebook 'cells))
             (current-cell  ejn--cell)
             (current-index (cl-position current-cell cells))
             (next-index    (1+ current-index)))
        (if (< next-index (length cells))
            (let ((next-cell (nth next-index cells)))
              (switch-to-buffer (ejn-cell-open-buffer next-cell notebook)))
          (user-error "No more cells below")))
    ;; Master view path: search for next chunk header
    (condition-case nil
        (progn
          (forward-char 1)  ; move off current header if at one
          (if (re-search-forward "^# %%<ejn-cell:[0-9]+:" nil t)
              (beginning-of-line)
            (user-error "No more cells below")))
      (error (user-error "No more cells below")))))

(defun ejn:worksheet-goto-prev-input ()
  "Navigate to the previous cell.

If in a cell buffer, switch to the previous cell's buffer.
If in the master view buffer, search backward for the previous cell
chunk header and move point there."
  (interactive)
  (if (bound-and-true-p ejn--cell)
      ;; Cell buffer path (unchanged)
      (let* ((notebook      (ejn-notebook-of-buffer))
             (cells         (slot-value notebook 'cells))
             (current-cell  ejn--cell)
             (current-index (cl-position current-cell cells)))
        (if (> current-index 0)
            (let ((prev-cell (nth (1- current-index) cells)))
              (switch-to-buffer (ejn-cell-open-buffer prev-cell notebook)))
          (user-error "No more cells above")))
    ;; Master view path: search for previous chunk header
    (condition-case nil
        (progn
          (if (re-search-backward "^# %%<ejn-cell:[0-9]+:" nil t)
              (beginning-of-line)
            (user-error "No more cells above")))
      (error (user-error "No more cells above")))))
```

### Test

Open a notebook with multiple cells. From the master view, press `C-c C-n` — point should move to the next `# %%<ejn-cell:` line. Press `C-c C-p` — point should move back.

---

## Task 6 — Fix Shadow File Integrity

**Bugs fixed:** B21, B22, B23  
**File:** `ejn-core.el` — `ejn-shadow-write-cell`, `ejn--reindex-shadow-files`; `ejn-cell.el` — `ejn--cell-kill-buffer-hook`  
**Severity:** Moderate (data loss on crash; orphaned files accumulate)

### B22 — Make `ejn-shadow-write-cell` atomic

`ejn-shadow-write-cell` writes directly to the target path via `with-temp-file`. A crash mid-write leaves a truncated shadow file. `ejn-shadow-sync-cell` already uses `.tmp` + `rename-file` correctly; apply the same pattern here.

```elisp
;; BEFORE (ejn-core.el, ejn-shadow-write-cell body):
(make-directory cache-dir t)
(with-temp-file shadow-path
  (insert (slot-value cell 'source)))
(oset cell shadow-file shadow-path)
shadow-path

;; AFTER:
(make-directory cache-dir t)
(let ((tmp-path (concat shadow-path ".tmp")))
  (with-temp-file tmp-path
    (insert (or (slot-value cell 'source) "")))
  (rename-file tmp-path shadow-path 'replace))
(oset cell shadow-file shadow-path)
shadow-path
```

### B23 — Fix orphan deletion in `ejn--reindex-shadow-files`

The second pass only looks at paths held by current cell objects. Files left behind by killed cells are missed. Replace the second pass with a directory glob:

```elisp
;; BEFORE (second pass in ejn--reindex-shadow-files):
(cl-loop for cell in cells
         do (let ((old-shadow (slot-value cell 'shadow-file)))
              (when (and old-shadow
                         (not (member old-shadow expected-paths))
                         (file-exists-p old-shadow))
                (delete-file old-shadow))))

;; AFTER:
;; Delete every cell_NNN.{py,md,raw} file not in expected-paths
(when (file-directory-p cache-dir)
  (dolist (existing-file
           (directory-files cache-dir t "\\`cell_[0-9]\\{3\\}\\."))
    (unless (member existing-file expected-paths)
      (delete-file existing-file))))
```

### B21 — Flush dirty content in `ejn--cell-kill-buffer-hook`

When a cell buffer is killed, its unsaved content is discarded because the hook does not call `ejn-shadow-sync-cell`. This matters for cases outside of notebook close (e.g., the user kills a cell buffer with `C-x k` mid-edit).

```elisp
;; BEFORE (ejn-cell.el, ejn--cell-kill-buffer-hook):
(defun ejn--cell-kill-buffer-hook ()
  "Clean up when the cell buffer is killed."
  (when (and (boundp 'ejn--cell) ejn--cell)
    (when (fboundp 'ejn-lsp-unregister-cell)
      (ejn-lsp-unregister-cell ejn--cell)))
  (remove-hook 'after-change-functions #'ejn--undo-after-change 'local))

;; AFTER:
(defun ejn--cell-kill-buffer-hook ()
  "Clean up when the cell buffer is killed.
Flushes any dirty content to the shadow file before unregistering LSP."
  (when (and (boundp 'ejn--cell) ejn--cell)
    ;; Flush dirty buffer content to :source slot and shadow file
    (when (slot-value ejn--cell 'dirty)
      (ejn-shadow-sync-cell ejn--cell))
    (when (fboundp 'ejn-lsp-unregister-cell)
      (ejn-lsp-unregister-cell ejn--cell)))
  (remove-hook 'after-change-functions #'ejn--undo-after-change 'local))
```

### Test

Create a cell, write content, then kill the buffer with `C-x k`. Open the shadow file in `.ejn-cache/` — it should contain the content that was in the buffer. Check that the cache directory contains no orphaned `cell_NNN.py` files after killing cells.

---

## Task 7 — Fix JSON Serialization (Save)

**Bugs fixed:** B24, B25, B26, B27, B28  
**Files:** `ejn-core.el` — `ejn--parse-cell-data`; `ejn-notebook.el` — `ejn--cell-to-json`, `ejn--notebook-to-json`  
**Severity:** High (corrupts `.ipynb` on save; fails to load files with array source)

### B24 — Handle vector `source` in parser

`json-parse-buffer` with `:object-type 'hash-table` returns JSON arrays as vectors. An `.ipynb` cell where `source` is an array of strings (common in many editors) produces a vector, not a list. The existing `(when (listp source) ...)` check is false for vectors.

```elisp
;; BEFORE (ejn--parse-cell-data):
(when (listp source)
  (setq source (string-join source "")))

;; AFTER:
(cond
 ((vectorp source) (setq source (mapconcat #'identity source "")))
 ((listp source)   (setq source (string-join source ""))))
```

### B25, B26, B27, B28 — Fix `ejn--cell-to-json` and `ejn--notebook-to-json`

Four issues in the serialization layer:

1. `metadata` slot is `nil` for new notebooks → `json-encode` writes `null` → invalid nbformat (must be `{}`).
2. `outputs` slot is `nil` for new cells → `json-encode` writes `null` → invalid nbformat (must be `[]`).
3. Cell `id` field is missing → required by nbformat 4.5.
4. Cell `metadata` field is missing → required by nbformat 4 (even if `{}`).

```elisp
;; BEFORE (ejn--cell-to-json):
(defun ejn--cell-to-json (cell)
  (let ((cell-json (make-hash-table :test 'equal)))
    (puthash "cell_type"       (symbol-name (slot-value cell 'type))       cell-json)
    (puthash "source"          (slot-value cell 'source)                   cell-json)
    (puthash "execution_count" (slot-value cell 'exec-count)               cell-json)
    (puthash "outputs"         (slot-value cell 'outputs)                  cell-json)
    cell-json))

;; AFTER:
(defun ejn--cell-to-json (cell)
  "Convert CELL to a valid nbformat 4.5 cell hash-table."
  (let ((cell-json (make-hash-table :test 'equal))
        (outputs   (slot-value cell 'outputs)))
    (puthash "id"              (slot-value cell 'id)                       cell-json)
    (puthash "cell_type"       (symbol-name (slot-value cell 'type))       cell-json)
    (puthash "source"          (or (slot-value cell 'source) "")           cell-json)
    (puthash "execution_count" (slot-value cell 'exec-count)               cell-json)
    ;; outputs must be a vector/list, never null
    (puthash "outputs"         (or outputs (vector))                       cell-json)
    ;; metadata is required by nbformat 4 (empty object if not set)
    (puthash "metadata"        (make-hash-table :test 'equal)              cell-json)
    cell-json))

;; BEFORE (ejn--notebook-to-json, metadata line):
(puthash "metadata" (slot-value notebook 'metadata) nb-json)

;; AFTER:
(puthash "metadata" (or (slot-value notebook 'metadata)
                        (make-hash-table :test 'equal))
         nb-json)
```

### Test

Open a notebook, make edits, save with `C-x C-s`. Open the `.ipynb` file in a text editor and verify that `metadata` is `{}`, all cells have `id`, `metadata`, and `outputs` fields, and `outputs` is `[]` for new cells. Run `jupyter nbconvert --to script FILE.ipynb` — it should not error.

---

## Task 8 — Wire Kernel Start and Fix Execution

**Bugs fixed:** B36, B37, B38  
**Files:** `ejn-network.el` — `ejn--execute-cell`; `ejn.el` — new command + keybinding  
**Severity:** Blocking (nothing executes without these fixes)

### B38 — Add interactive `ejn:notebook-start-kernel` command

`ejn-kernel-start` exists but has no caller. Add a command and keybinding.

In `ejn.el`, add before `ejn-mode-map`:
```elisp
(defun ejn:notebook-start-kernel (&optional kernel-name)
  "Start a Jupyter kernel for the current notebook.

Prompts for a kernelspec name via `completing-read' if KERNEL-NAME
is nil. Stores the client in the notebook's `:kernel-id' slot and
activates `ejn-kernel-manager-mode' in the master buffer.

Signals `user-error' if no notebook is associated with this buffer,
if no kernelspecs are available, or if a kernel is already running."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (when (ejn-kernel-alive-p notebook)
      (user-error "A kernel is already running. Use C-c C-r to reconnect"))
    (let* ((specs    (jupyter-available-kernelspecs))
           (names    (mapcar #'jupyter-kernelspec-name specs)))
      (unless names
        (user-error "No Jupyter kernelspecs found. Is Jupyter installed?"))
      (let* ((selected (or kernel-name
                           (completing-read "Start kernel: " names nil t
                                            nil nil (car names))))
             (client   (ejn-kernel-start notebook selected)))
        (message "EJN: kernel started (%s)" selected)
        client))))
```

In `ejn-mode-map`, add the keybinding (suggest `C-c C-S-k` since `C-c C-k` is kill-cell):
```elisp
(define-key map (kbd "C-c C-S-k") #'ejn:notebook-start-kernel)
```

### B36 + B37 — Fix `ejn--execute-cell`: sync source, retrieve client, fix API call

The current implementation has three problems:
1. Does not flush the live buffer to `:source` before sending.
2. Does not retrieve the kernel client from `notebook.kernel-id`.
3. Calls `jupyter-execute-request` with no client, which is not how `jupyter.el` works.

The correct `jupyter.el` API is to call `jupyter-send` on the client with an execute-request message. The exact method name and argument format must be confirmed against the installed `jupyter.el` version, but the structural fix is:

```elisp
;; AFTER (ejn--execute-cell in ejn-network.el):
(defun ejn--execute-cell (cell)
  "Send the source of CELL to the kernel for execution.

Syncs the cell buffer to the EIEIO model, retrieves the kernel
client from the notebook's `:kernel-id' slot, sends an execute
request, and registers an iopub callback to dispatch output messages.

Signals `user-error' if no kernel is started for the notebook.
Returns the request object."
  (let* ((notebook (ejn--cell-notebook cell))
         (client   (and notebook (slot-value notebook 'kernel-id))))
    (unless client
      (user-error "No kernel started. Use C-c C-S-k to start one"))
    ;; Flush buffer → :source before sending, so user's current edits are sent
    (ejn-shadow-sync-cell cell)
    (let* ((code (slot-value cell 'source))
           ;; jupyter.el API: jupyter-send takes client + message type + content
           (req  (jupyter-send client :execute-request
                               (list :code             code
                                     :silent           nil
                                     :store-history    t
                                     :user-expressions nil
                                     :allow-stdin      nil))))
      ;; Register iopub callback for output messages
      (jupyter-add-receive-callback
       client req :iopub
       (lambda (msg)
         (ejn--iopub-handler cell msg notebook)))
      req)))
```

**Note on API verification:** The function names `jupyter-send`, `jupyter-add-receive-callback`, and the keyword `:execute-request` must be verified against the actual installed `jupyter.el` package. Consult `(describe-function 'jupyter-send)` and grep `jupyter.el` for `execute-request`. If the API differs, adapt the call site accordingly — the structural pattern (retrieve client from slot, sync before send, pass client to send) remains correct.

### Test

Open a notebook with `M-x ejn-open-file`. Press `C-c C-S-k` and select a Python kernel. The mode-line should show `EJN [python3 | ●idle]`. Navigate to a cell (`C-c C-n`), type `1 + 1`, and press `C-c C-c`. The mode-line should briefly show `●busy`, then return to `●idle`.

---

## Task 9 — Fix iopub Message Handling and Output Rendering

**Bugs fixed:** B34, B35, B39  
**File:** `ejn-network.el` — `ejn--iopub-handler`, `ejn--render-output`  
**Severity:** Blocking (no output ever appears even with a working kernel)

### B34 + B35 — Fix plist key format throughout

`jupyter.el` delivers iopub messages as plists with **keyword** keys (`:msg_type`, `:content`). All `plist-get` calls in `ejn--iopub-handler` and `ejn--render-output` use plain symbols (`'msg_type`, `'content`), which never match keyword keys and always return `nil`. This means:
- `ejn--iopub-handler`: `when-let*` immediately fails; nothing ever dispatches.
- `ejn--render-output`: `content` and `data` are always `nil`; nothing ever renders.

```elisp
;; BEFORE (ejn--iopub-handler):
(when-let* ((msg-type (plist-get msg 'msg_type))
            (nb (or notebook (ejn--cell-notebook cell))))
  (pcase msg-type
    ("status"
     (ejn--update-mode-line nb)
     (when-let* ((content    (plist-get msg 'content))
                 (exec-state (plist-get content 'execution_state)))
       ...))
    ((or "stream" "execute_result" "display_data" "error")
     (ejn--render-output cell msg))))

;; AFTER (ejn--iopub-handler):
(when-let* ((msg-type (plist-get msg :msg_type))
            (nb (or notebook (ejn--cell-notebook cell))))
  (pcase msg-type
    ("status"
     (ejn--update-mode-line nb)
     (when-let* ((content    (plist-get msg :content))
                 (exec-state (plist-get content :execution_state)))
       (when (equal exec-state "idle")
         (ejn-cell-refresh-header cell))))
    ((or "stream" "execute_result" "display_data" "error" "execute_reply")
     (ejn--render-output cell msg))))
```

Note: `"execute_reply"` is added to the dispatch list to enable exec-count updates (B39, below).

### B35 — Fix `ejn--render-output` for all message types

Rewrite `ejn--render-output` to handle the three distinct message structures correctly, and add the `execute_reply` handler for exec-count:

```elisp
;; AFTER (ejn--render-output — complete replacement):
(defun ejn--render-output (cell msg)
  "Dispatch MSG and render its output into CELL's overlay.

Handles stream (stdout/stderr), execute_result, display_data,
error, and execute_reply messages. Keyword plist keys are used
throughout to match jupyter.el's message format.

Returns nil."
  (let* ((msg-type (plist-get msg :msg_type))
         (content  (plist-get msg :content))
         (buf      (slot-value cell 'buffer)))
    (unless (and buf (buffer-live-p buf))
      (cl-return-from ejn--render-output nil))
    (pcase msg-type
      ;; Stream: content has :name and :text — no :data key
      ("stream"
       (let* ((text    (or (plist-get content :text) ""))
              (overlay (ejn--output-overlay cell))
              (existing (overlay-get overlay 'after-string)))
         ;; Stream output is cumulative — append, not replace
         (overlay-put overlay 'after-string
                      (concat (or existing "") (ansi-color-apply text)))))

      ;; execute_result and display_data: content has :data plist
      ((or "execute_result" "display_data")
       (let* ((data     (plist-get content :data))
              (metadata (plist-get content :metadata))
              (overlay  (ejn--output-overlay cell))
              (rendered (ejn--render-mime-data data metadata msg-type)))
         (overlay-put overlay 'after-string rendered)))

      ;; error: content has :ename, :evalue, :traceback — no :data
      ("error"
       (let* ((overlay  (ejn--output-overlay cell))
              (rendered (ejn--render-mime-data content nil "error")))
         (overlay-put overlay 'after-string rendered)
         ;; Store traceback in notebook for ejn:tb-show
         (when-let* ((notebook  (ejn--cell-notebook cell))
                     (traceback (plist-get content :traceback)))
           (oset notebook last-traceback
                 (mapconcat #'identity traceback "\n")))))

      ;; execute_reply: update execution count on cell header
      ("execute_reply"
       (when-let* ((exec-count (plist-get content :execution_count)))
         (oset cell exec-count exec-count)
         (ejn-cell-refresh-header cell)
         (when-let* ((notebook (ejn--cell-notebook cell)))
           (ejn--update-mode-line notebook)))))
  nil))
```

Also fix the keyword keys in `ejn--render-mime-data` where it accesses MIME data:

```elisp
;; BEFORE (in ejn--render-mime-data, MIME dispatch loop):
(let ((content (plist-get data (intern (concat ":" mime-type)))))

;; The intern trick is correct — (intern ":text/plain") = :text/plain.
;; This part is fine as-is; no change needed here.
```

### B39 — exec-count update

The `execute_reply` branch in the rewritten `ejn--render-output` above handles B39. No separate change is needed.

### Test

With a running kernel, execute a cell containing `print("hello")`. The overlay below the cell should display `hello`. Execute `1 + 1`. The overlay should display `2`. Cause an error (`1/0`). The overlay should display the error in red. `C-c C-$` should open the traceback buffer. The cell header should update from `In []:` to `In [1]:` after execution.

---

## Task 10 — Fix the Undo System

**Bugs fixed:** B40, B41, B42, B43, B44  
**Files:** `ejn-ui.el` — `ejn--undo-after-change`, `ejn-global-undo`; `ejn.el` — `ejn:worksheet-toggle-cell-type`, `ejn:worksheet-change-cell-type`  
**Severity:** Moderate (undo silently broken for deletions; structural undo never fires)

### B40 — Fix before-text reconstruction for deletions

The current approach tries to reconstruct the pre-change state from the post-change buffer content using only `start` and `end`. For deletions (`end == start`, `pre-change-length > 0`), this produces the current buffer unchanged — the deleted text is unrecoverable from `after-change-functions` alone.

The correct solution is to capture the full buffer content in `before-change-functions` and carry it forward:

```elisp
;; Add this to ejn-cell.el, registered alongside ejn--undo-after-change:
(defvar-local ejn--pre-change-snapshot nil
  "Full buffer content captured by `ejn--undo-before-change'.")

(defun ejn--undo-before-change (start end)
  "Capture full buffer content before a change, for undo reconstruction.
START and END are the bounds of the region about to change (unused)."
  (setq ejn--pre-change-snapshot
        (buffer-substring-no-properties (point-min) (point-max))))

;; Register in ejn-cell-open-buffer, alongside ejn--undo-after-change:
(add-hook 'before-change-functions
          #'ejn--undo-before-change 'append 'local)
```

Then fix `ejn--undo-after-change` to use the snapshot:

```elisp
;; AFTER (ejn--undo-after-change — relevant section):
(let* ((before-text (or ejn--pre-change-snapshot ""))
       (after-text  (buffer-substring-no-properties (point-min) (point-max)))
       (top-record  (car undo-stack)))
  ;; Clear snapshot
  (setq ejn--pre-change-snapshot nil)
  ;; Rest of debounce logic unchanged...
  )
```

### B41 — Fix `ejn-global-undo`: remove `erase-buffer`

`erase-buffer` before `replace-buffer-contents` destroys all markers and text properties, defeating the purpose of using `replace-buffer-contents`:

```elisp
;; BEFORE:
(with-current-buffer target-buf
  (erase-buffer)
  (replace-buffer-contents temp-buf))

;; AFTER:
(with-current-buffer target-buf
  (replace-buffer-contents temp-buf))
```

`replace-buffer-contents` handles the full replacement without needing `erase-buffer` first.

### B42 — Wire `ejn--undo-structural-change` into `ejn-global-undo`

Add a dispatch branch to `ejn-global-undo` after popping the record:

```elisp
;; AFTER the undo-stack pop and cell lookup, in ejn-global-undo:
(let ((operation (ejn-undo-record-operation record)))
  (if (eq operation :content)
      ;; Content undo: restore cell buffer to before-text
      (let ((temp-buf (generate-new-buffer " *ejn-undo-temp*")))
        (unwind-protect
            (progn
              (with-current-buffer temp-buf
                (insert before-text))
              (with-current-buffer target-buf
                (replace-buffer-contents temp-buf)))
          (kill-buffer temp-buf))
        (oset target-cell source before-text)
        (switch-to-buffer target-buf))
    ;; Structural undo: delegate to ejn--undo-structural-change
    (ejn--undo-structural-change record)
    (when (fboundp 'ejn--poly-refresh-cells)
      (when-let* ((master-buf (slot-value (ejn-undo-record-notebook record)
                                          'master-buffer)))
        (with-current-buffer master-buf
          (ejn--poly-refresh-cells))))))
```

### B43, B44 — Fix `with-current-buffer` nesting in cell type commands

Both `ejn:worksheet-toggle-cell-type` and `ejn:worksheet-change-cell-type` have the `with-current-buffer` form that is not closed before the markdown render, header refresh, and master re-render calls. While the net runtime behavior is accidentally correct (inner functions switch buffers themselves), the structural mistake is a maintenance trap.

**`ejn:worksheet-toggle-cell-type`** — add one `)` to close `with-current-buffer` after the `cl-case` form:

```elisp
;; BEFORE:
(with-current-buffer (slot-value cell 'buffer)
  (cl-case new-type
    (code (python-mode))
    (markdown
     (condition-case nil
         (markdown-mode)
       ((command-error void-function)
        (fundamental-mode)))))
;; Render markdown ...         ← inside with-current-buffer (wrong)
(when ...)

;; AFTER:
(with-current-buffer (slot-value cell 'buffer)
  (cl-case new-type
    (code (python-mode))
    (markdown
     (condition-case nil
         (markdown-mode)
       ((command-error void-function)
        (fundamental-mode))))))   ;; ← close with-current-buffer here
;; Render markdown ...            ← now correctly in outer let* scope
(when ...)
```

Apply the identical fix to `ejn:worksheet-change-cell-type`.

### Test

Type several characters into a cell, pause, type more. Press `C-x u` (or whichever key calls `ejn-global-undo`). The characters should be removed one debounce-batch at a time. Delete some text. Undo should restore the deleted text. Insert a cell, then undo — the cell should be removed and the master view should update.

---

## Task 11 — Fix LSP Registration

**Bugs fixed:** B30, B31, B32, B33  
**File:** `ejn-lsp.el` — `ejn-lsp--register-virtual-buffer`; `ejn-master.el` — `ejn--create-master-view`  
**Severity:** High (LSP completions fall back silently; scroll hook double-added)

### B30, B31 — Fix `lsp-virtual-buffer-register` call

The function is called with keyword arguments in a form that does not match `lsp-mode`'s API. Additionally, `offset-line` is passed as a `(LINE . COL)` cons cell where an integer line number is expected.

```elisp
;; BEFORE:
(let* ((virtual-file (ejn-lsp-composite-path notebook))
       (offset-line  (ejn-lsp-pos-to-composite cell notebook 0 0)))
  (lsp-virtual-buffer-register :real-buffer real-buffer
                                :virtual-file virtual-file
                                :offset-line  offset-line))

;; AFTER:
(let* ((virtual-file  (ejn-lsp-composite-path notebook))
       (offset-cons   (ejn-lsp-pos-to-composite cell notebook 0 0))
       ;; Extract integer line from (LINE . COL) cons; default 0 if nil
       (offset-line   (if offset-cons (car offset-cons) 0)))
  ;; lsp-virtual-buffer-register takes a property list argument
  ;; Verify this against your installed lsp-mode version:
  ;;   M-x describe-function lsp-virtual-buffer-register
  (lsp-virtual-buffer-register
   (list :real-buffer  real-buffer
         :virtual-file virtual-file
         :offset-line  offset-line)))
```

**Important:** The exact calling convention for `lsp-virtual-buffer-register` varies between `lsp-mode` versions. Before applying this fix, run `(describe-function 'lsp-virtual-buffer-register)` in Emacs to see the actual signature. The structural fix (extract integer from cons, correct plist format) is correct regardless of the exact API.

### B32 — Fix scroll hook duplicate-add guard

`(memq fn window-scroll-functions)` checks the global hook list, not the buffer-local one that `add-hook 'local` creates. The guard is never true and the hook is added multiple times.

```elisp
;; BEFORE:
(unless (memq #'ejn--master-scroll-hook window-scroll-functions)
  (add-hook 'window-scroll-functions #'ejn--master-scroll-hook 'append 'local))

;; AFTER:
;; Check the buffer-local hook list, not the global one
(unless (memq #'ejn--master-scroll-hook
              (buffer-local-value 'window-scroll-functions (current-buffer)))
  (add-hook 'window-scroll-functions #'ejn--master-scroll-hook 'append 'local))
```

### B33 — Reduce fragility of scroll hook sentinel pattern

The `format "# %%%%<ejn-cell:%d:"` double-escape is correct but fragile — two different `format` call sites must stay in sync. Extract to a named constant:

```elisp
;; Add to ejn-master.el (near the top, after requires):
(defconst ejn--cell-chunk-head-prefix "# %%<ejn-cell:"
  "Prefix string for polymode chunk head delimiters in the master view.
Used by both ejn--poly-render-cells and ejn--master-scroll-hook.")

;; In ejn--poly-render-cells, replace the format calls:
;; BEFORE:
(insert (format "# %%%%<ejn-cell:%d:%s>\n" idx (symbol-name cell-type)))
...
(insert (format "\n# %%%%<ejn-cell:%d:end>\n" idx))

;; AFTER:
(insert (format "%s%d:%s>\n" ejn--cell-chunk-head-prefix idx (symbol-name cell-type)))
...
(insert (format "\n%s%d:end>\n" ejn--cell-chunk-head-prefix idx))

;; In ejn--master-scroll-hook, replace the format call:
;; BEFORE:
(let ((head-marker (format "# %%%%<ejn-cell:%d:" idx)))

;; AFTER:
(let ((head-marker (format "%s%d:" ejn--cell-chunk-head-prefix idx)))
```

Also update the polymode matchers in `ejn-master.el` to use the constant prefix string if possible, or document that they must stay in sync with `ejn--cell-chunk-head-prefix`.

### Test

Open a notebook and scroll down in the master view. Evaluate `(length (buffer-local-value 'window-scroll-functions (current-buffer)))` — it should be 1, not growing on each scroll. Open a Python cell and trigger completion — it should show LSP suggestions (assuming `lsp-mode` is installed and a Python language server is running).

---

## Task 12 — Fix `ejn:notebook-close` Save Failure Handling

**Bug fixed:** B29  
**File:** `ejn.el` — `ejn:notebook-close`  
**Severity:** Low (data loss on save failure during close)

### Root cause

If the save fails (disk full, permissions error), `ejn:notebook-save-notebook-command` returns `nil` but `ejn:notebook-close` continues killing buffers regardless.

```elisp
;; BEFORE:
(when (and any-dirty-p
           (y-or-n-p "Save dirty cells before closing? "))
  (ejn:notebook-save-notebook-command))
;; Kill all cell buffers (proceeds even if save failed)
(dolist (cell ...) ...)

;; AFTER:
(when any-dirty-p
  (when (y-or-n-p "Save dirty cells before closing? ")
    (let ((saved (ejn-notebook-save notebook)))
      (unless saved
        (unless (y-or-n-p "Save failed. Close anyway and lose changes? ")
          (user-error "Close cancelled"))))))
;; Kill all cell buffers
(dolist (cell ...) ...)
```

### Test

Fill a disk partition, open a notebook on it, edit a cell, and try to close with `C-c C-#`. The prompt should warn that the save failed and offer to cancel before killing buffers.

---

## Complete Bug Inventory

| ID | File | Location | Description | Severity | Task |
|----|------|----------|-------------|----------|------|
| B01 | `ejn.el` | `ejn-open-file` | Master view never displayed | Blocking | 2 |
| B02 | `ejn-core.el` | line 356 | `ejn--notebook` not `defvar-local` | Low | 1 |
| B03 | `ejn-cell.el` | line 45 | `ejn--cell` not `defvar-local` | Low | 1 |
| B04 | `ejn-cell.el` | `insert-above` | No nil guard on `ejn--cell` → crash | Blocking | 3 |
| B05 | `ejn-cell.el` | `insert-below` | No nil guard on `ejn--cell` → crash | Blocking | 3 |
| B06 | `ejn-cell.el` | `move-cell-up` | No nil guards → crash | Blocking | 3 |
| B07 | `ejn-cell.el` | `move-cell-down` | No nil guards → crash | Blocking | 3 |
| B08 | `ejn-cell.el` | `split-cell-at-point` | No nil guard → crash | Blocking | 3 |
| B09 | `ejn-cell.el` | `merge-cell` | No nil guard; reads stale `:source` | Blocking | 3 |
| B10 | `ejn-cell.el` | `yank-cell` | No nil guard on `ejn--cell` → crash | Blocking | 3 |
| B11 | `ejn-cell.el` | `copy-cell` | Reads stale `:source`; no nil guard | Moderate | 3 |
| B12 | `ejn-cell.el` | `insert-above` | New buffer not shown to user | Moderate | 3 |
| B13 | `ejn-cell.el` | `insert-below` | New buffer not shown to user | Moderate | 3 |
| B14 | `ejn-cell.el` | `goto-next` | `next-button(current-buffer)` wrong API | Moderate | 5 |
| B15 | `ejn-cell.el` | `goto-prev` | `previous-button(current-buffer)` wrong API | Moderate | 5 |
| B16 | `ejn-cell.el` | `ejn--make-cell` | Uses button renderer instead of polymode | Blocking | 4 |
| B17 | `ejn-cell.el` | `move-cell-up` | Uses button renderer instead of polymode | Blocking | 4 |
| B18 | `ejn-cell.el` | `move-cell-down` | Uses button renderer instead of polymode | Blocking | 4 |
| B19 | `ejn-cell.el` | `kill-cell` | Uses button renderer instead of polymode | Blocking | 4 |
| B20 | `ejn-cell.el` | `merge-cell` | Uses button renderer instead of polymode | Blocking | 4 |
| B21 | `ejn-cell.el` | `kill-buffer-hook` | Missing `ejn-shadow-sync-cell` → data loss | Moderate | 6 |
| B22 | `ejn-core.el` | `ejn-shadow-write-cell` | Non-atomic write (no `.tmp` + rename) | Low | 6 |
| B23 | `ejn-core.el` | `ejn--reindex-shadow-files` | Orphaned shadow files not deleted | Moderate | 6 |
| B24 | `ejn-core.el` | `ejn--parse-cell-data` | Vector `source` not handled | High | 7 |
| B25 | `ejn-notebook.el` | `ejn--notebook-to-json` | `nil` metadata → invalid JSON `null` | High | 7 |
| B26 | `ejn-notebook.el` | `ejn--cell-to-json` | `nil` outputs → invalid JSON `null` | High | 7 |
| B27 | `ejn-notebook.el` | `ejn--cell-to-json` | Missing `"id"` field (nbformat 4.5) | High | 7 |
| B28 | `ejn-notebook.el` | `ejn--cell-to-json` | Missing `"metadata"` field (nbformat 4) | High | 7 |
| B29 | `ejn.el` | `ejn:notebook-close` | Save failure not surfaced before kill | Low | 12 |
| B30 | `ejn-lsp.el` | `ejn-lsp--register-virtual-buffer` | Wrong calling convention for `lsp-virtual-buffer-register` | High | 11 |
| B31 | `ejn-lsp.el` | `ejn-lsp--register-virtual-buffer` | `offset-line` is `(LINE.COL)` cons, not integer | High | 11 |
| B32 | `ejn-master.el` | `ejn--create-master-view` | `memq` checks global hook list; hook added multiple times | Moderate | 11 |
| B33 | `ejn-master.el` | `ejn--master-scroll-hook` | Fragile double-`%%` escape in format string | Low | 11 |
| B34 | `ejn-network.el` | `ejn--iopub-handler` | Plain symbol keys (`'msg_type`) instead of keyword (`:msg_type`) | Blocking | 9 |
| B35 | `ejn-network.el` | `ejn--render-output` | Plain symbol keys; stream messages silently dropped | Blocking | 9 |
| B36 | `ejn-network.el` | `ejn--execute-cell` | Wrong `jupyter.el` API; no kernel client | Blocking | 8 |
| B37 | `ejn-network.el` | `ejn--execute-cell` | Reads stale `:source` slot, not live buffer | Blocking | 8 |
| B38 | `ejn-network.el` | — | No interactive command to start kernel | Blocking | 8 |
| B39 | `ejn-network.el` | — | `exec-count` never updated after execution | Moderate | 9 |
| B40 | `ejn-ui.el` | `ejn--undo-after-change` | `before-text` reconstruction wrong for deletions | Moderate | 10 |
| B41 | `ejn-ui.el` | `ejn-global-undo` | `erase-buffer` before `replace-buffer-contents` | Low | 10 |
| B42 | `ejn-ui.el` | `ejn-global-undo` | Structural undo records never dispatched | Moderate | 10 |
| B43 | `ejn.el` | `ejn:worksheet-toggle-cell-type` | Unbalanced `with-current-buffer` | Low | 10 |
| B44 | `ejn.el` | `ejn:worksheet-change-cell-type` | Unbalanced `with-current-buffer` | Low | 10 |
