;;; ejn-ui.el --- UI utilities for EJN  -*- lexical-binding: t -*-

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

;; UI utilities for Emacs Jupyter Notebook.
;;
;; This file provides:
;;   - Global undo recording and replay
;;   - Cell header rendering (text-property-based, no overlays)
;;   - Markdown preview rendering
;;   - Output visibility helpers

;;; Code:

(require 'cl-lib)
(require 'eieio)
(require 'ejn-core)

(declare-function ejn-shadow-sync-cell 'ejn-core (cell))

;; ---------------------------------------------------------------------------
;; Global undo
;; ---------------------------------------------------------------------------

(cl-defstruct (ejn-undo-record
               (:constructor make-ejn-undo-record)
               (:copier nil))
  "An entry on the notebook-wide undo stack.

Slots:
  cell-id   — ID of the cell that changed (or \"structural\" for structural ops).
  before    — Buffer string (or cell-id list for structural) before the change.
  after     — Buffer string (or cell-id list) after the change.
  timestamp — `float-time' at which the record was created.
  operation — Symbol: `:text', `:insert', `:delete', `:move-up', `:move-down',
               `:split', `:merge', `:kill'.
  notebook  — Back-pointer to the `ejn-notebook' (weak reference).
  data      — Additional data specific to the operation."
  cell-id
  before
  after
  timestamp
  operation
  notebook
  data)

(defvar ejn--undo-debounce-timer nil
  "Buffer-local timer for debouncing undo record creation.")

(defvar ejn--undo-pending-before nil
  "Buffer-local snapshot of text before a pending undo record.")

(defun ejn--undo-after-change (start end pre-change-length)
  "After-change hook for global undo recording.

START, END, and PRE-CHANGE-LENGTH are the standard `after-change-functions'
callback arguments.  Sets `:dirty' on the cell and debounces undo record
creation: captures the before-text on the first change within a 1-second
window, then schedules a timer to finalise the record after 1 second of
inactivity.

This function is added buffer-locally to `after-change-functions' in each
cell buffer via `ejn-cell-open-buffer'.  It replaces the defunct
`ejn--cell-after-change-hook' (FIX #4 — that hook was dead code and has
been removed)."
  (ignore start end pre-change-length)
  (let ((cell (bound-and-true-p ejn--cell))
        (notebook (bound-and-true-p ejn--notebook)))
    ;; Mark cell dirty whenever text changes
    (when cell
      (oset cell dirty t))
    ;; Debounce: capture before-text only on first change in window
    (when (and cell notebook)
      (unless (bound-and-true-p ejn--undo-pending-before)
        (set (make-local-variable 'ejn--undo-pending-before)
             (buffer-substring-no-properties (point-min) (point-max))))
      ;; Cancel any existing timer and reschedule
      (when (and (bound-and-true-p ejn--undo-debounce-timer)
                 (timerp ejn--undo-debounce-timer))
        (cancel-timer ejn--undo-debounce-timer))
      (set (make-local-variable 'ejn--undo-debounce-timer)
           (run-with-idle-timer
            1.0 nil
            #'ejn--undo-commit-record
            cell notebook (current-buffer))))))

(defun ejn--undo-commit-record (cell notebook buf)
  "Finalise a pending undo record for CELL in NOTEBOOK from BUF.

Called by the 1-second idle timer set by `ejn--undo-after-change'.
Reads the current buffer text as the \"after\" snapshot, creates an
`ejn-undo-record', and pushes it onto the notebook's `:undo-stack'.
Clears `ejn--undo-pending-before' and `ejn--undo-debounce-timer'."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (let* ((before ejn--undo-pending-before)
             (after (buffer-substring-no-properties (point-min) (point-max)))
             (cell-id (slot-value cell 'id))
             (record (make-ejn-undo-record
                      :cell-id cell-id
                      :before before
                      :after after
                      :timestamp (float-time)
                      :operation :text
                      :notebook notebook
                      :data nil))
             (undo-stack (slot-value notebook 'undo-stack)))
        (push record undo-stack)
        (oset notebook undo-stack undo-stack)
        (set (make-local-variable 'ejn--undo-pending-before) nil)
        (set (make-local-variable 'ejn--undo-debounce-timer) nil)))))

(defun ejn-global-undo ()
  "Undo the most recent change recorded on the notebook's undo stack.

Pops the topmost `ejn-undo-record' from the notebook's `:undo-stack'.
For `:text' operations, restores the \"before\" text in the affected cell
buffer.  For structural operations (`:insert', `:delete', `:move-up',
`:move-down', `:split', `:merge', `:kill'), signals a `user-error' noting
that structural undo is reserved for a future phase.

Returns nil."
  (interactive)
  (let* ((notebook ejn--notebook)
         (undo-stack (slot-value notebook 'undo-stack))
         (record (car undo-stack)))
    (unless record
      (user-error "Nothing to undo"))
    ;; Pop the record
    (oset notebook undo-stack (cdr undo-stack))
    (pcase (ejn-undo-record-operation record)
      (:text
       ;; Restore the before-text in the cell buffer
       (let* ((cell-id (ejn-undo-record-cell-id record))
              (before (ejn-undo-record-before record))
              (cells (slot-value notebook 'cells))
              (cell (cl-find-if (lambda (c)
                                  (string= (slot-value c 'id) cell-id))
                                cells))
              (buf (and cell (slot-value cell 'buffer))))
         (when (buffer-live-p buf)
           (with-current-buffer buf
             (let ((inhibit-read-only t))
               (erase-buffer)
               (insert (or before "")))
             (oset cell source (or before ""))
             (oset cell dirty t)
             (ejn-shadow-sync-cell cell)))))
      (_
       ;; Structural undo operations are reserved for Phase 4
       (user-error
        "Structural undo (operation: %s) is not yet implemented"
        (ejn-undo-record-operation record))))))

;; ---------------------------------------------------------------------------
;; Cell header rendering (text-property based, no overlays)
;; ---------------------------------------------------------------------------

(defface ejn-cell-header-face
  '((t :inherit header-line :weight bold))
  "Face for the cell header line in EJN cell buffers.")

(defface ejn-cell-header-type-code
  '((t :foreground "DodgerBlue" :weight bold))
  "Face for code cell type indicator in EJN cell header.")

(defface ejn-cell-header-type-markdown
  '((t :foreground "DarkOrange" :weight bold))
  "Face for markdown cell type indicator in EJN cell header.")

(defface ejn-cell-header-type-raw
  '((t :foreground "dim gray" :weight bold))
  "Face for raw cell type indicator in EJN cell header.")

(defun ejn--cell-type-face (cell)
  "Return the face symbol for CELL's type indicator in the cell header.

Returns `ejn-cell-header-type-code' for code cells,
`ejn-cell-header-type-markdown' for markdown cells, and
`ejn-cell-header-type-raw' for all other types."
  (cl-case (slot-value cell 'type)
    (code     'ejn-cell-header-type-code)
    (markdown 'ejn-cell-header-type-markdown)
    (raw      'ejn-cell-header-type-raw)
    (t        'ejn-cell-header-type-raw)))

(defun ejn-cell-refresh-header (cell)
  "Refresh the header-line in CELL's buffer to show current execution count.

Sets `header-line-format' buffer-locally to a propertized string of the
form:
  [TYPE] In [N]:
where TYPE is the cell's `:type', and N is the cell's `:exec-count' (or
`?' if nil).  Uses `ejn-cell-header-face' and `ejn--cell-type-face'.

FIX #16: Docstring is on a separate line from the function body.
Does nothing if CELL has no live buffer."
  (let ((buf (slot-value cell 'buffer)))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (let* ((cell-type (slot-value cell 'type))
               (exec-count (slot-value cell 'exec-count))
               (count-str (if exec-count
                              (number-to-string exec-count)
                            "?"))
               (type-str (symbol-name cell-type))
               (header
                (concat
                 (propertize (format "[%s]" type-str)
                             'face (ejn--cell-type-face cell))
                 (propertize (format " In [%s]:" count-str)
                             'face 'ejn-cell-header-face))))
          (setq-local header-line-format header))))))

(defun ejn--setup-cell-visuals (cell)
  "Set up visual properties for CELL's buffer on first open.

Calls `ejn-cell-refresh-header' to render the initial cell header.
Enables `display-line-numbers-mode' for code cells.

Called from `ejn-cell-open-buffer' after the buffer is created."
  (let ((buf (slot-value cell 'buffer)))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (ejn-cell-refresh-header cell)
        (when (eq (slot-value cell 'type) 'code)
          (when (fboundp 'display-line-numbers-mode)
            (display-line-numbers-mode 1)))))))

;; ---------------------------------------------------------------------------
;; Markdown rendering
;;
;; FIX #14: The original ejn-markdown-render-cell used `unless' for the
;; type guard followed unconditionally by the `let*' body, meaning the
;; rendering logic ran for every cell type regardless of the guard.  `unless'
;; evaluates its body and returns nil, but does NOT provide an early exit from
;; the enclosing `defun'.  Fixed by wrapping the entire function body in
;; `when' so it only runs for markdown cells.
;; ---------------------------------------------------------------------------

(defun ejn-markdown-render-cell (cell)
  "Render CELL's source as Markdown if it is a markdown cell.

FIX #14: Uses `when' to wrap the entire body so the function returns nil
immediately for non-markdown cells instead of executing the rendering
logic unconditionally.

For markdown cells, reads the cell's `:source', renders it to HTML via
`markdown-render-region', and inserts the result into a dedicated preview
buffer named `*ejn-markdown-preview:<cell-id>*'.  If `markdown-render-region'
is not available (markdown-mode not loaded), falls back to displaying the
raw source in a help buffer.

Does nothing and returns nil for code and raw cells."
  (when (eq (slot-value cell 'type) 'markdown)
    (let* ((source (or (slot-value cell 'source) ""))
           (cell-id (slot-value cell 'id))
           (preview-buf-name (format "*ejn-markdown-preview:%s*" cell-id)))
      (with-current-buffer (get-buffer-create preview-buf-name)
        (let ((inhibit-read-only t))
          (erase-buffer)
          (if (fboundp 'markdown-render-region)
              ;; markdown-mode available: render HTML preview
              (progn
                (insert source)
                (markdown-render-region (point-min) (point-max)))
            ;; Fallback: display raw source
            (insert source)))
        (read-only-mode 1)
        (display-buffer (current-buffer)
                        '((display-buffer-below-selected)
                          (window-height . 0.3)))))))

;; ---------------------------------------------------------------------------
;; Traceback display
;; ---------------------------------------------------------------------------

(defun ejn--show-traceback (notebook)
  "Display the last kernel error traceback for NOTEBOOK.

Reads the notebook's `:last-traceback' slot.  If non-nil, pops up
a dedicated `*ejn-traceback*' buffer displaying the traceback text
in `compilation-mode' for navigation.  If no traceback is available,
displays a message.

FIX #16: Docstring on a separate line from the function body."
  (let ((tb (slot-value notebook 'last-traceback)))
    (if (not tb)
        (message "No traceback available")
      (with-current-buffer (get-buffer-create "*ejn-traceback*")
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert tb))
        (compilation-mode)
        (display-buffer (current-buffer))))))

;; ---------------------------------------------------------------------------
;; Output section management
;; ---------------------------------------------------------------------------

(defun ejn--clear-output-section (cell)
  "Clear the rendered output for CELL.

Removes the `:after-string' from CELL's output overlay and resets the
overlay position to point-max of the cell buffer.  Sets `:output-visible-p'
to t (so the next output appears visible).  Does nothing if CELL has no
live buffer or no overlay."
  (let ((buf (slot-value cell 'buffer)))
    (when (buffer-live-p buf)
      (let ((overlay (slot-value cell 'output-overlay)))
        (when (and overlay (overlayp overlay))
          (overlay-put overlay 'after-string "")
          (oset cell output-visible-p t))))))

;; ---------------------------------------------------------------------------
;; Scratch sheet
;; ---------------------------------------------------------------------------

(defun ejn-scratchsheet-open (notebook)
  "Open a transient scratch cell buffer for NOTEBOOK.

Creates a new `ejn-cell' with `:scratch-p' set and `:type' `code'.
Opens its buffer in the other window.  The cell is NOT added to
the notebook's `:cells' list, so it will never be saved.

Returns the scratch cell's buffer."
  (let* ((scratch-cell (make-instance 'ejn-cell
                                      :type 'code
                                      :source ""
                                      :scratch-p t))
         (scratch-buf (ejn-cell-open-buffer scratch-cell notebook)))
    (with-current-buffer scratch-buf
      (rename-buffer (format "*ejn-scratch:%s*"
                             (file-name-sans-extension
                              (file-name-nondirectory
                               (slot-value notebook 'path))))
                     'unique))
    (switch-to-buffer-other-window scratch-buf)
    scratch-buf))

(provide 'ejn-ui)

;;; ejn-ui.el ends here
