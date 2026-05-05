;;; ejn-cell.el --- Cell buffer management for EJN  -*- lexical-binding: t -*-

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

;; Cell buffer management for Emacs Jupyter Notebook.
;;
;; This file provides:
;;   - ejn-cell-open-buffer   : Create/return a cell editing buffer
;;   - ejn--cell-after-change-hook : after-change-functions hook for dirty tracking
;;   - ejn--cell-kill-buffer-hook  : kill-buffer-hook for cleanup

;;; Code:

(require 'cl-lib)
(require 'ejn-core)
(declare-function markdown-mode 'markdown-mode ())
(declare-function ejn-mode 'ejn (arg))
(declare-function ejn--reindex-shadow-files 'ejn-core (notebook))
(declare-function ejn-lsp--debounced-composite-regen 'ejn-lsp (start end pre-change-length))
(declare-function ejn-lsp-setup-cell-buffer 'ejn-lsp (cell notebook))
(declare-function ejn-lsp-unregister-cell 'ejn-lsp (cell))
(declare-function ejn--setup-cell-visuals 'ejn-ui (cell))
(declare-function ejn--undo-after-change 'ejn-ui (start end pre-change-length))
(declare-function make-ejn-undo-record 'ejn-ui (&rest args))

;; Buffer-local variable holding the ejn-cell for the current cell buffer
(defvar-local ejn--cell nil
  "Buffer-local variable storing the `ejn-cell' object for this cell buffer.")

(defun ejn--cell-after-change-hook (_start _end _pre-change-length)
  "Mark the cell buffer's `ejn-cell' as dirty.
Called by `after-change-functions' with arguments START, END,
PRE-CHANGE-LENGTH (all unused here)."
  (when (and (boundp 'ejn--cell) ejn--cell)
    (oset ejn--cell dirty t)))

(defun ejn--cell-kill-buffer-hook ()
  "Clean up when the cell buffer is killed.
Remove `ejn--cell-after-change-hook' from `after-change-functions',
and unregister the cell from LSP via `ejn-lsp-unregister-cell'."
  (when (and (boundp 'ejn--cell) ejn--cell)
    (when (fboundp 'ejn-lsp-unregister-cell)
      (ejn-lsp-unregister-cell ejn--cell)))
  (remove-hook 'after-change-functions #'ejn--undo-after-change 'local))

(defun ejn-cell-refresh-buffer (cell)
  "Replace the cell buffer's contents with CELL's `:source'.

Uses `replace-buffer-contents' which is non-destructive,
preserving markers, properties, overlays, point position and
undo history as much as possible.
Returns nil."
  (let ((buf (slot-value cell 'buffer)))
    (when (buffer-live-p buf)
      (let ((temp-buf (generate-new-buffer " *ejn-refresh-temp*")))
        (unwind-protect
            (progn
              (with-current-buffer temp-buf
                (insert (slot-value cell 'source)))
              (with-current-buffer buf
                (undo-boundary)
                (save-excursion
                  (replace-buffer-contents temp-buf))
                (undo-boundary)))
          (kill-buffer temp-buf))))))

(defun ejn-cell-open-buffer (cell &optional notebook)
  "Open or switch to the editing buffer for CELL.

If CELL's `:buffer' slot is live, return it.
Otherwise create a new buffer with `:source' content, set major-mode,
attach `after-change-functions' hook for dirty tracking, set buffer-local
`ejn--cell' and (when NOTEBOOK is given) `ejn--notebook', write shadow
file via `ejn-shadow-write-cell' (when NOTEBOOK is given), update
`:buffer' slot, and return the buffer."
  (let ((buf (slot-value cell 'buffer)))
    (if (buffer-live-p buf)
        (get-buffer buf)
      (let ((new-buf (generate-new-buffer
                       (format "*ejn-cell:%s*" (slot-value cell 'id)))))
        (with-current-buffer new-buf
           (insert (slot-value cell 'source))
           (cl-case (slot-value cell 'type)
             (code (python-mode))
             (markdown
              (condition-case nil
                  (markdown-mode)
                ((command-error void-function)
                 (fundamental-mode))))
             (raw (fundamental-mode)))
           (ejn-mode 1)
           (set (make-local-variable 'ejn--cell) cell)
           (when notebook
             (set (make-local-variable 'ejn--notebook) notebook))
           (add-hook 'kill-buffer-hook
                     #'ejn--cell-kill-buffer-hook 'append 'local))
         (oset cell buffer new-buf)
         (when (fboundp 'ejn--setup-cell-visuals)
           (ejn--setup-cell-visuals cell))
         (when notebook
           (ejn-shadow-write-cell cell notebook))
         (when (and notebook (fboundp 'ejn-lsp-setup-cell-buffer))
           (ejn-lsp-setup-cell-buffer cell notebook))
         ;; Register after-change hooks AFTER all setup functions
         ;; to avoid triggering them during initial buffer population.
         (with-current-buffer new-buf
           (remove-hook 'after-change-functions #'ejn--cell-after-change-hook 'local)
           (when (fboundp 'ejn--undo-after-change)
             (add-hook 'after-change-functions
                       #'ejn--undo-after-change 'append 'local))
           (when (fboundp 'ejn-lsp--debounced-composite-regen)
             (add-hook 'after-change-functions
                       #'ejn-lsp--debounced-composite-regen 'append 'local)))
         new-buf))))

(defun ejn-cell-initialize (cell notebook)
  "Initialize CELL for lazy loading within NOTEBOOK.

Creates buffer, writes shadow file, and attaches LSP.
Idempotent — guarded by :initialized-p flag."
  (unless (slot-value cell 'initialized-p)
    (ejn-cell-open-buffer cell notebook)
    (oset cell initialized-p t)))

(defun ejn--record-structural-change (notebook operation data)
  "Record a structural change on NOTEBOOK's undo stack.

NOTEBOOK is an `ejn-notebook' instance.
OPERATION is a symbol naming the structural operation
(`:insert', `:delete', `:move', `:split', `:merge').
DATA is a list containing the affected cell object(s) and any
additional information needed for undo (e.g., cell index).

This function captures the current cell list state as a snapshot
of cell IDs, creates an `ejn-undo-record', and pushes it onto
the notebook's undo stack.
Returns nil."
  (when notebook
    (let* ((cells (slot-value notebook 'cells))
           (cell-ids (mapcar (lambda (c) (slot-value c 'id)) cells))
           (affected-cell (car data))
           (cell-id (and affected-cell (slot-value affected-cell 'id)))
           (record (make-ejn-undo-record
                    :cell-id (or cell-id "structural")
                    :before cell-ids
                    :after cell-ids
                    :timestamp (float-time)
                    :operation operation
                    :notebook notebook
                    :data data))
           (undo-stack (slot-value notebook 'undo-stack)))
      (push record undo-stack)
      (oset notebook undo-stack undo-stack))))

(defun ejn--make-cell (notebook index type &optional source)
  "Create a new ejn-cell and insert it into NOTEBOOK at INDEX.

TYPE is the cell type symbol (code, markdown, or raw).
SOURCE is optional and defaults to an empty string.
The new cell is inserted at INDEX in the notebook's :cells list.
A shadow file is written via `ejn-shadow-write-cell'.
The master view is refreshed via `ejn--poly-refresh-cells'.
`ejn--record-structural-change' is called as a hook for future undo.
Returns the new cell."
  (let* ((new-cell (make-instance 'ejn-cell
                                    :type type
                                    :source (or source "")))
         (cells (slot-value notebook 'cells))
         (before (cl-subseq cells 0 index))
         (after (cl-subseq cells index)))
    (oset notebook cells (append before (list new-cell) after))
    (ejn-shadow-write-cell new-cell notebook)
    (ejn--reindex-shadow-files notebook)
    (when (and (fboundp 'ejn--poly-refresh-cells)
               (buffer-live-p (slot-value notebook 'master-buffer)))
      (with-current-buffer (slot-value notebook 'master-buffer)
        (ejn--poly-refresh-cells)))
    (ejn--record-structural-change notebook 'insert (list new-cell index))
    new-cell))

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

(defun ejn:worksheet-move-cell-down ()
  "Move the current cell down by one position in the notebook."
  (interactive)
  (let* ((notebook     (ejn-notebook-of-buffer))
         (current-cell ejn--cell))
    (unless notebook     (user-error "No notebook associated with this buffer"))
    (unless current-cell (user-error "No cell at point"))
    (let* ((cells         (slot-value notebook 'cells))
           (num-cells     (length cells))
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

(defun ejn:worksheet-kill-cell ()
  "Kill the current cell.

Removes the cell at point from the notebook's `:cells' list.
If the cell is `:dirty', prompts for confirmation via `y-or-n-p'.
Kills the cell's buffer if live, removes its shadow file from disk,
reindexes shadow files for remaining cells via `ejn--reindex-shadow-files',
and refreshes the master view."
  (interactive)
  (cl-block nil
    (let* ((notebook (ejn-notebook-of-buffer))
           (current-cell ejn--cell))
      (unless notebook     (user-error "No notebook associated with this buffer"))
      (unless current-cell (user-error "No cell at point"))
      ;; If dirty, prompt for confirmation; abort silently on decline
      (when (ejn-cell-dirty-p current-cell)
        (unless (y-or-n-p "Cell has unsaved changes. Kill anyway? ")
          (cl-return)))
      ;; Get shadow file path before killing buffer
      (let ((shadow-path (slot-value current-cell 'shadow-file)))
        ;; Remove shadow file from disk
        (when (and shadow-path (file-exists-p shadow-path))
          (delete-file shadow-path)))
      ;; Kill buffer if live
      (let ((buf (slot-value current-cell 'buffer)))
        (when (buffer-live-p buf)
          (kill-buffer buf)))
      ;; Remove from :cells list
      (let ((cells (slot-value notebook 'cells)))
        (oset notebook cells (delq current-cell cells)))
      ;; Reindex shadow files so remaining cells get correct paths
      (ejn--reindex-shadow-files notebook)
      ;; Refresh master view
      (when (fboundp 'ejn--poly-refresh-cells)
        (with-current-buffer (slot-value notebook 'master-buffer)
          (ejn--poly-refresh-cells)))
      (ejn--record-structural-change notebook 'kill (list current-cell)))))

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

(defun ejn:worksheet-merge-cell ()
  "Merge the current cell with the cell below it."
  (interactive)
  (let* ((notebook     (ejn-notebook-of-buffer))
         (current-cell ejn--cell))
    (unless notebook     (user-error "No notebook associated with this buffer"))
    (unless current-cell (user-error "No cell at point"))
    ;; Sync current cell's buffer to :source before merging
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
        ;; Do NOT pop the kill ring — Emacs convention: yank does not consume
        (switch-to-buffer
         (ejn-cell-open-buffer
          (ejn--make-cell notebook (1+ current-index) type source)
          notebook))))))

(defun ejn:worksheet-copy-cell (&optional kill)
  "Copy the current cell's source and type to the notebook's kill ring.
With KILL non-nil, also remove the cell."
  (interactive "P")
  (let* ((notebook (ejn-notebook-of-buffer))
         (cell     ejn--cell))
    (unless notebook (user-error "No notebook associated with this buffer"))
    (unless cell     (user-error "No cell at point"))
    ;; Sync buffer -> :source before copying, so copy reflects current edits
    (ejn-shadow-sync-cell cell)
    (let ((entry `((source . ,(slot-value cell 'source))
                   (type   . ,(slot-value cell 'type)))))
      (oset notebook ejn-cell-kill-ring
            (cons entry (slot-value notebook 'ejn-cell-kill-ring)))
      (when kill
        (ejn:worksheet-kill-cell)))))

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
          (forward-char 1)
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

(provide 'ejn-cell)

;;; ejn-cell.el ends here
