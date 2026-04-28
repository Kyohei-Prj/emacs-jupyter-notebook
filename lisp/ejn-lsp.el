;;; ejn-lsp.el --- LSP integration for EJN  -*- lexical-binding: t -*-

;; Copyright (C) 2025  EJN Contributors

;; Author: EJN Contributors
;; Version: 0.1.0
;; Keywords: jupyter, notebook, tools, convenience

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; LSP integration for Emacs Jupyter Notebook - scaffolding only.

;; URL: https://github.com/emacs-jupyter-notebook/emacs-jupyter-notebook
;; Package-Requires: ((emacs "24.1"))

;;; Code:

(require 'polymode)
(require 'xref)

;;;###autoload
(defun ejn-lsp-sentinel-line (cell-index)
  "Return a sentinel line string for CODE CELL at CELL-INDEX.

CELL-INDEX is a 0-based integer identifying the code cell.
Returns a string of the form \"# ejn:cell:N\\n\" where N is CELL-INDEX."
  (format "# ejn:cell:%d\n" cell-index))

(defun ejn-lsp-cell-line-count (source)
  "Return the number of lines in SOURCE string.

Counts the final line even if it has no trailing newline.
Returns 0 for an empty string."
  (if (string-empty-p source)
      0
    (let* ((nl-count (cl-loop for i from 0 below (length source)
                              count (eq (aref source i) ?\n)))
           (trailing-newline (string-suffix-p "\n" source)))
      (if trailing-newline
          nl-count
        (1+ nl-count)))))

(defun ejn-lsp-composite-path (notebook)
  "Return the absolute path to `composite.py' in NOTEBOOK's cache directory.

NOTEBOOK is an `ejn-notebook' instance with a `:path' slot.
The cache directory is `.ejn-cache/<stem>/' where stem is the notebook
filename without its extension.
Pure function — no side effects."
  (let* ((nb-path (slot-value notebook 'path))
         (nb-stem (file-name-sans-extension
                   (file-name-nondirectory nb-path)))
         (cache-dir (expand-file-name
                     (concat ".ejn-cache/" nb-stem)
                     (file-name-directory nb-path))))
    (expand-file-name "composite.py" cache-dir)))

(defun ejn-lsp-generate-composite (notebook)
  "Generate composite.py for NOTEBOOK and return its absolute path.

Iterates NOTEBOOK's `:cells`, selecting only cells of type `code`.
Concatenates each code cell's `:source` with a sentinel line
(`# ejn:cell:N` where N is the 0-based index among code cells).
Writes atomically via a `.tmp` file and `rename-file`.
Returns the absolute path to `composite.py`."
  (let* ((cells (slot-value notebook 'cells))
         (code-cells (cl-loop for cell in cells
                              when (eq (slot-value cell 'type) 'code)
                                collect cell))
         (composite-path (ejn-lsp-composite-path notebook))
         (cache-dir (file-name-directory composite-path))
         (tmp-path (concat composite-path ".tmp"))
         (content (with-output-to-string
                    (cl-loop for idx from 0
                             for cell in code-cells
                             do (princ (ejn-lsp-sentinel-line idx))
                             do (princ (slot-value cell 'source))
                             do (princ "\n")))))
    (make-directory cache-dir t)
    (with-temp-file tmp-path
      (insert content))
    (rename-file tmp-path composite-path 'replace)
    composite-path))

(defun ejn-lsp-pos-to-composite (cell notebook buffer-line buffer-col)
  "Translate a position in CELL's buffer to the composite file position.

CELL is an `ejn-cell' instance. NOTEBOOK is an `ejn-notebook' instance.
BUFFER-LINE and BUFFER-COL are 0-based line and column within CELL's buffer.
Returns `(COMPOSITE-LINE . COMPOSITE-COL)' for code cells, or `nil' for
non-code cells (markdown, raw)."
  (if (eq (slot-value cell 'type) 'code)
      (let* ((cells (slot-value notebook 'cells))
         (code-cells (cl-loop for c in cells
                              when (eq (slot-value c 'type) 'code)
                                collect c))
         (code-idx (cl-position cell code-cells))
         (preceding-cells (cl-subseq code-cells 0 code-idx))
         (offset 0))
    ;; Sum line contributions of all preceding code cells
    (dolist (preceding preceding-cells)
      (let* ((source (slot-value preceding 'source))
             (source-lines (ejn-lsp-cell-line-count source))
             (has-trailing-newline (string-suffix-p "\n" source)))
        ;; Each preceding cell contributes: sentinel (1) + source lines
        ;; + separator (1) if source ends with a trailing newline
        (cl-incf offset (1+ source-lines))
        (when has-trailing-newline
          (cl-incf offset 1))))
    ;; Add current cell's sentinel (1 line) + buffer-line offset
    (cl-incf offset (1+ buffer-line))
    (cons offset buffer-col))
    nil))

(defvar ejn-lsp--composite-regen-timer nil
  "Buffer-local timer for debounced composite regeneration.")

(defun ejn-lsp--debounced-composite-regen (start end pre-change-length)
  "After-change callback to debounce composite regeneration.

Cancels any pending composite regen timer, then schedules
`ejn-lsp-generate-composite' on a 0.3s idle timer.
START, END, and PRE-CHANGE-LENGTH are the standard
`after-change-functions' callback arguments (unused).
Stores the timer ID in the buffer-local variable
`ejn-lsp--composite-regen-timer'."
  (let ((notebook ejn--notebook))
    (when notebook
      (when (and (boundp 'ejn-lsp--composite-regen-timer)
                 (timerp ejn-lsp--composite-regen-timer))
        (cancel-timer ejn-lsp--composite-regen-timer))
      (set (make-local-variable 'ejn-lsp--composite-regen-timer)
           (run-with-timer
            0.3 nil
            #'ejn-lsp-generate-composite notebook)))))

(defun ejn-lsp-cell-code-index (cell notebook)
  "Return the 0-based index of CELL among code-only cells in NOTEBOOK.

Returns -1 if CELL is not a code cell (markdown, raw, etc.).
CELL is an `ejn-cell' instance. NOTEBOOK is an `ejn-notebook' instance.
Pure function — no side effects."
  (if (eq (slot-value cell 'type) 'code)
      (let* ((cells (slot-value notebook 'cells))
             (code-cells (cl-loop for c in cells
                                  when (eq (slot-value c 'type) 'code)
                                    collect c)))
        (cl-position cell code-cells))
    -1))

(defun ejn-lsp-pos-from-composite (notebook composite-line)
  "Given a 0-based COMPOSITE-LINE in composite.py, return (CELL . CELL-LINE) or nil.

NOTEBOOK is an ejn-notebook instance. COMPOSITE-LINE is a 0-based line number
in the composite file. Returns a cons of the ejn-cell instance and the
0-based line within that cell's source. Returns nil for sentinel lines
(lines with `# ejn:cell:N`), separator lines (empty lines between cells
caused by trailing newlines in source), and lines beyond the last cell."
  (let* ((cells (slot-value notebook 'cells))
         (code-cells (cl-loop for c in cells
                              when (eq (slot-value c 'type) 'code)
                                collect c))
         (offset 0))
    (catch 'ejn-lsp-pos-from-composite
      (dolist (cell code-cells)
        (let* ((source (slot-value cell 'source))
               (source-lines (ejn-lsp-cell-line-count source))
               (has-trailing-newline (string-suffix-p "\n" source)))
          ;; Sentinel line → nil
          (when (eq composite-line offset)
            (throw 'ejn-lsp-pos-from-composite nil))

          ;; Content lines → (cell . cell-line)
          (let ((content-start (1+ offset)))
            (when (and (>= composite-line content-start)
                       (< composite-line (+ content-start source-lines)))
              (throw 'ejn-lsp-pos-from-composite
                     (cons cell (- composite-line content-start)))))

          ;; Separator line (if source has trailing newline) → nil
          (when (and has-trailing-newline
                     (eq composite-line (+ offset source-lines 1)))
            (throw 'ejn-lsp-pos-from-composite nil))

          ;; Advance offset
          (cl-incf offset (1+ source-lines))
          (when has-trailing-newline
            (cl-incf offset 1))))
      ;; Beyond last cell → nil
      nil)))

(defvar ejn--cell-lsp-attached-p nil
  "Buffer-local flag indicating whether LSP has been attached to this cell buffer.")

(declare-function lsp-completion-at-point (&rest args) "lsp-mode")
(declare-function lsp-find-definition (&rest args) "lsp-mode")
(declare-function lsp-virtual-buffer-register (&rest args) "lsp-virtual-buffer")
(declare-function lsp-virtual-buffer-unregister (&rest args) "lsp-virtual-buffer")

(defun ejn-lsp--register-virtual-buffer (cell notebook)
  "Register CELL's buffer as an LSP virtual buffer for the composite file.

Calls `lsp-virtual-buffer-register' with :real-buffer (CELL's buffer),
:virtual-file (composite path via `ejn-lsp-composite-path'), and
:offset-line (from `ejn-lsp-pos-to-composite' at buffer position 0,0).
Sets buffer-local `ejn--cell-lsp-attached-p' to t.
Returns nil."
  (let* ((real-buffer (slot-value cell 'buffer))
         (virtual-file (ejn-lsp-composite-path notebook))
         (offset-line (ejn-lsp-pos-to-composite cell notebook 0 0)))
    (lsp-virtual-buffer-register :real-buffer real-buffer
                                 :virtual-file virtual-file
                                 :offset-line offset-line)
    (with-current-buffer real-buffer
      (set (make-local-variable 'ejn--cell-lsp-attached-p) t))))

(defun ejn-lsp--register-fallback (cell notebook)
  "Fallback LSP registration for older lsp-mode without `lsp-virtual-buffer-register'.

Generate composite file, call `lsp' on the composite path, display a
warning message about limited position translation, and set
`ejn--cell-lsp-attached-p' to `t'.

CELL is an `ejn-cell' instance. NOTEBOOK is an `ejn-notebook' instance.
Returns nil."
  (let ((composite-path (ejn-lsp-generate-composite notebook)))
    (lsp composite-path)
    (message "Warning: LSP attached via composite file (limited position translation)"))
  (when (slot-value cell 'buffer)
    (with-current-buffer (slot-value cell 'buffer)
      (set (make-local-variable 'ejn--cell-lsp-attached-p) t))))

(defun ejn-lsp-register-cell (cell notebook)
  "Idempotently register CELL for LSP support within NOTEBOOK.

Checks `ejn--cell-lsp-attached-p' in the cell's buffer; if not set,
dispatches to `ejn-lsp--register-virtual-buffer' (preferred when
`lsp-virtual-buffer-register' is available) or
`ejn-lsp--register-fallback' otherwise.
Returns nil."
  (when (slot-value cell 'buffer)
    (unless (with-current-buffer (slot-value cell 'buffer)
              ejn--cell-lsp-attached-p)
      (condition-case-unless-debug err
          (ejn-lsp--register-virtual-buffer cell notebook)
        (error
         (ejn-lsp--register-fallback cell notebook))))))

(defun ejn-lsp-unregister-cell (cell)
  "Unregister CELL from LSP support.

Calls `lsp-virtual-buffer-unregister' if available and the cell was
registered via virtual buffer. Otherwise calls `lsp-kill-workspace'
for fallback cleanup. Clears `ejn--cell-lsp-attached-p' in the
cell's buffer. Returns nil."
  (when (slot-value cell 'buffer)
    (when (with-current-buffer (slot-value cell 'buffer)
            ejn--cell-lsp-attached-p)
      (condition-case-unless-debug err
          (when (fboundp 'lsp-virtual-buffer-unregister)
            (lsp-virtual-buffer-unregister))
        (error
         (condition-case-unless-debug _err2
             (lsp-kill-workspace)
           (error nil))))
      (with-current-buffer (slot-value cell 'buffer)
        (set (make-local-variable 'ejn--cell-lsp-attached-p) nil)))))

(defun ejn-lsp-setup-cell-buffer (cell notebook)
  "Set up LSP for CELL's buffer within NOTEBOOK.

In the cell's buffer context:
1. Sets `default-directory' to the notebook's parent directory.
2. Adds `lsp-completion-at-point' to `completion-at-point-functions'.
3. Calls `ejn-lsp-generate-composite' if the composite file doesn't exist yet.
4. Calls `ejn-lsp-register-cell' to register the cell with LSP.
Guarded by `ejn--cell-lsp-attached-p' — does nothing if already set.
Returns nil."
  (let ((buf (slot-value cell 'buffer)))
    (when (buffer-live-p buf)
      (unless (with-current-buffer buf
                ejn--cell-lsp-attached-p)
        (with-current-buffer buf
          (setq default-directory (file-name-directory
                                    (slot-value notebook 'path)))
          (add-hook 'completion-at-point-functions
                    #'lsp-completion-at-point 'append 'local))
        (unless (file-exists-p (ejn-lsp-composite-path notebook))
          (ejn-lsp-generate-composite notebook))
        (ejn-lsp-register-cell cell notebook)))))

(defun ejn-lsp--translate-xref-to-cell (xref notebook)
  "Translate an XREF pointing to composite file to a cell buffer position.

XREF is an xref object (typically from lsp-find-definition).
NOTEBOOK is the current ejn-notebook.
Returns (BUFFER . LINE) where BUFFER is the target cell's buffer and
LINE is the 0-based line within that cell. Returns nil if XREF does
not point to the composite file or cannot be mapped."
  (let* ((location (xref-item-location xref))
         (composite-path (ejn-lsp-composite-path notebook)))
    (when (and (xref-file-location-p location)
               (string= (xref-file-location-file location)
                        composite-path))
      (let* ((composite-line (1- (xref-file-location-line location)))
             (mapped (ejn-lsp-pos-from-composite notebook composite-line)))
        (when mapped
          (let* ((cell (car mapped))
                 (cell-line (cdr mapped))
                 (cell-buf (ejn-cell-open-buffer cell notebook)))
            (cons cell-buf cell-line)))))))

(defun ejn:pytools-jump-to-source ()
  "Jump to the source definition of the symbol at point via LSP.

Translates the current buffer position to a composite file position,
calls `lsp-find-definition', translates the xref result back to a
cell buffer via `ejn-lsp--translate-xref-to-cell', and switches to
the target cell buffer at the resolved line.
Signals `user-error' if no definition is found."
  (interactive)
  (let* ((cell ejn--cell)
         (notebook ejn--notebook)
         (buffer-line (1- (line-number-at-pos)))
         (buffer-col (- (point) (line-beginning-position)))
         (composite-pos (ejn-lsp-pos-to-composite
                         cell notebook buffer-line buffer-col))
         (xrefs (lsp-find-definition composite-pos))
         (xref (car xrefs)))
    (unless xref
      (user-error "No definition found"))
    (let ((result (ejn-lsp--translate-xref-to-cell xref notebook)))
      (let ((target-buf (car result))
            (target-line (cdr result)))
        (switch-to-buffer target-buf)
        (goto-char (point-min))
        (forward-line target-line)))))

(defun ejn:pytools-jump-back ()
  "Jump back to the previous location in the xref navigation stack.
Delegates to `xref-pop-marker-stack'."
  (interactive)
  (xref-pop-marker-stack))

(defun ejn-kernel-complete (callback)
  "Stub for kernel-based completion. Reserved for Phase 4.
CALLBACK is unused. Signals `user-error'."
  (signal 'user-error '("Kernel completion requires Phase 4")))

(provide 'ejn-lsp)

;;; ejn-lsp.el ends here
