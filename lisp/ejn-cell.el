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

;; Buffer-local variable holding the ejn-cell for the current cell buffer
(defvar ejn--cell nil
  "Buffer-local variable storing the `ejn-cell' object for this cell buffer.")

(defun ejn--cell-after-change-hook (_start _end _pre-change-length)
  "Mark the cell buffer's `ejn-cell' as dirty.
Called by `after-change-functions' with arguments START, END,
PRE-CHANGE-LENGTH (all unused here)."
  (when (and (boundp 'ejn--cell) ejn--cell)
    (oset ejn--cell dirty t)))

(defun ejn--cell-kill-buffer-hook ()
  "Remove `ejn--cell-after-change-hook' from `after-change-functions'.
Called by `kill-buffer-hook' to clean up when the cell buffer is killed."
  (remove-hook 'after-change-functions #'ejn--cell-after-change-hook 'local))

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
          (set (make-local-variable 'ejn--cell) cell)
          (when notebook
            (set (make-local-variable 'ejn--notebook) notebook))
          (add-hook 'after-change-functions
                    #'ejn--cell-after-change-hook 'append 'local)
          (add-hook 'kill-buffer-hook
                    #'ejn--cell-kill-buffer-hook 'append 'local))
        (when notebook
          (ejn-shadow-write-cell cell notebook))
        (oset cell buffer new-buf)
        new-buf))))

(defun ejn--record-structural-change (_notebook _operation _data)
  "No-op hook for Phase 5 global undo.
NOTEBOOK, OPERATION, DATA are reserved arguments."
  nil)

(defun ejn--make-cell (notebook index type &optional source)
  "Create a new ejn-cell and insert it into NOTEBOOK at INDEX.

TYPE is the cell type symbol (code, markdown, or raw).
SOURCE is optional and defaults to an empty string.
The new cell is inserted at INDEX in the notebook's :cells list.
A shadow file is written via `ejn-shadow-write-cell'.
The master view is refreshed via `ejn--refresh-master-cells'.
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
    (when (fboundp 'ejn--refresh-master-cells)
      (with-current-buffer (slot-value notebook 'master-buffer)
        (ejn--refresh-master-cells)))
    (ejn--record-structural-change notebook 'insert (list new-cell index))
    new-cell))

(defun ejn:worksheet-insert-cell-above ()
  "Insert a new cell above the current cell.

Creates a new cell inheriting the type of the cell at point,
inserts it before the current cell in the notebook's cell list,
writes an empty shadow file, and opens the new cell's buffer."
  (interactive)
  (let* ((notebook (ejn-notebook-of-buffer))
         (current-cell ejn--cell)
         (cells (slot-value notebook 'cells))
         (current-index (cl-position current-cell cells))
         (cell-type (slot-value current-cell 'type))
         (new-cell (ejn--make-cell notebook current-index cell-type)))
    (ejn-cell-open-buffer new-cell notebook)))

(defun ejn:worksheet-insert-cell-below ()
  "Insert a new cell below the current cell.

Creates a new cell inheriting the type of the cell at point,
inserts it after the current cell in the notebook's cell list,
writes an empty shadow file, and opens the new cell's buffer."
  (interactive)
  (let* ((notebook (ejn-notebook-of-buffer))
         (current-cell ejn--cell)
         (cells (slot-value notebook 'cells))
         (current-index (cl-position current-cell cells))
         (cell-type (slot-value current-cell 'type))
         (new-cell (ejn--make-cell notebook (1+ current-index) cell-type)))
    (ejn-cell-open-buffer new-cell notebook)))

(defun ejn:worksheet-move-cell-up ()
  "Move the current cell up by one position in the notebook.

Swaps the cell at point with its predecessor in the notebook's
`:cells` list. Signals an error if the cell is already the first.
Rewrites shadow files for the two affected cells and refreshes
the master view."
  (interactive)
  (let* ((notebook (ejn-notebook-of-buffer))
         (current-cell ejn--cell)
         (cells (slot-value notebook 'cells))
         (current-index (cl-position current-cell cells)))
    (when (= current-index 0)
      (user-error "Cannot move first cell up"))
    (let ((predecessor (nth (1- current-index) cells)))
      ;; Swap in the cells list
      (setf (nth (1- current-index) cells) current-cell
            (nth current-index cells) predecessor)
      ;; Delete old shadow files before writing new ones
      (dolist (cell (list current-cell predecessor))
        (let ((old-shadow (slot-value cell 'shadow-file)))
          (when (and old-shadow (file-exists-p old-shadow))
            (delete-file old-shadow))))
      ;; Rewrite shadow files for both cells
      (ejn-shadow-write-cell current-cell notebook)
      (ejn-shadow-write-cell predecessor notebook)
      ;; Refresh master view
      (when (fboundp 'ejn--refresh-master-cells)
        (with-current-buffer (slot-value notebook 'master-buffer)
          (ejn--refresh-master-cells)))
      (ejn--record-structural-change notebook 'move-up
                                     (list current-cell current-index)))))

(defun ejn:worksheet-move-cell-down ()
  "Move the current cell down by one position in the notebook.

Swaps the cell at point with its successor in the notebook's
`:cells` list. Signals an error if the cell is already the last.
Rewrites shadow files for the two affected cells and refreshes
the master view."
  (interactive)
  (let* ((notebook (ejn-notebook-of-buffer))
         (current-cell ejn--cell)
         (cells (slot-value notebook 'cells))
         (current-index (cl-position current-cell cells))
         (num-cells (length cells)))
    (when (>= current-index (1- num-cells))
      (user-error "Cannot move last cell down"))
    (let ((successor (nth (1+ current-index) cells)))
      ;; Swap in the cells list
      (setf (nth current-index cells) successor
            (nth (1+ current-index) cells) current-cell)
      ;; Delete old shadow files before writing new ones
      (dolist (cell (list current-cell successor))
        (let ((old-shadow (slot-value cell 'shadow-file)))
          (when (and old-shadow (file-exists-p old-shadow))
            (delete-file old-shadow))))
      ;; Rewrite shadow files for both cells
      (ejn-shadow-write-cell current-cell notebook)
      (ejn-shadow-write-cell successor notebook)
      ;; Refresh master view
      (when (fboundp 'ejn--refresh-master-cells)
        (with-current-buffer (slot-value notebook 'master-buffer)
          (ejn--refresh-master-cells)))
      (ejn--record-structural-change notebook 'move-down
                                     (list current-cell current-index)))))

(defun ejn:worksheet-kill-cell ()
  "Kill the current cell.

Removes the cell at point from the notebook's `:cells' list.
If the cell is `:dirty', prompts for confirmation via `y-or-n-p'.
Kills the cell's buffer if live, removes its shadow file from disk,
and refreshes the master view.
Signals an error if there is no cell at point."
  (interactive)
  (cl-block nil
    (let* ((notebook (ejn-notebook-of-buffer))
           (current-cell ejn--cell))
      (unless current-cell
        (user-error "No cell at point"))
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
      ;; Refresh master view
      (when (fboundp 'ejn--refresh-master-cells)
        (with-current-buffer (slot-value notebook 'master-buffer)
          (ejn--refresh-master-cells)))
      (ejn--record-structural-change notebook 'kill (list current-cell)))))

(defun ejn:worksheet-split-cell-at-point ()
  "Split the current cell at point into two cells.

Splits the cell's `:source' at the line where point is located.
The part before point's line goes to the current cell; the part
from point's line onward goes to a new cell inserted below.
Both cells share the original `:type'."
  (interactive)
  (let* ((notebook (ejn-notebook-of-buffer))
         (current-cell ejn--cell)
         (cell-type (slot-value current-cell 'type))
         (split-point (line-beginning-position))
         (before (buffer-substring-no-properties (point-min) split-point))
         (after (buffer-substring-no-properties split-point (point-max)))
         (current-index (cl-position current-cell
                                     (slot-value notebook 'cells))))
    ;; Update current cell's source and shadow file
    (oset current-cell source before)
    (ejn-shadow-write-cell current-cell notebook)
    ;; Create new cell below current cell
    (let ((new-cell (ejn--make-cell notebook
                                    (1+ current-index)
                                    cell-type
                                    after)))
      ;; Refresh current cell buffer to reflect before part
      (ejn-cell-refresh-buffer current-cell)
      ;; Open new cell's buffer
      (ejn-cell-open-buffer new-cell notebook))))

(defun ejn:worksheet-merge-cell ()
  "Merge the current cell with the cell below it.

Concatenates the current cell's `:source` with the cell below's
`:source` using a blank line (\"\\n\\n\") as separator. Updates the
current cell's `:source`, kills the lower cell's buffer if live,
removes the lower cell's shadow file, removes the lower cell from
the notebook's `:cells` list, rewrites the current cell's shadow
file, and refreshes the master view.
Signals an error if the current cell is the last cell in the notebook."
  (interactive)
  (let* ((notebook (ejn-notebook-of-buffer))
         (current-cell ejn--cell)
         (cells (slot-value notebook 'cells))
         (current-index (cl-position current-cell cells))
         (num-cells (length cells)))
    (when (>= current-index (1- num-cells))
      (user-error "Cannot merge: current cell is the last cell"))
    (let* ((lower-cell (nth (1+ current-index) cells))
           (lower-shadow (slot-value lower-cell 'shadow-file))
           (lower-buf (slot-value lower-cell 'buffer)))
      ;; Concatenate sources with blank line separator
      (oset current-cell source
            (concat (slot-value current-cell 'source)
                    "\n\n"
                    (slot-value lower-cell 'source)))
      ;; Kill lower cell's buffer if live
      (when (buffer-live-p lower-buf)
        (kill-buffer lower-buf))
      ;; Remove lower cell's shadow file
      (when (and lower-shadow (file-exists-p lower-shadow))
        (delete-file lower-shadow))
      ;; Remove lower cell from :cells list
      (oset notebook cells (delq lower-cell cells))
      ;; Rewrite current cell's shadow file
      (ejn-shadow-write-cell current-cell notebook)
      ;; Refresh master view
      (when (fboundp 'ejn--refresh-master-cells)
        (with-current-buffer (slot-value notebook 'master-buffer)
          (ejn--refresh-master-cells)))
      (ejn--record-structural-change notebook 'merge
                                     (list current-cell lower-cell)))))

(defun ejn:worksheet-yank-cell ()
  "Yank a cell from the notebook's kill ring below the current cell.

Pops the top entry from `ejn-notebook`'s `ejn-cell-kill-ring`, creates
a new cell below the current cell with the copied `:source` and `:type`,
writes its shadow file via `ejn-shadow-write-cell`, and refreshes the
master view via `ejn--render-master-cells`.
Signals a `user-error` if the kill ring is empty."
  (interactive)
  (let* ((notebook (ejn-notebook-of-buffer))
         (kill-ring (slot-value notebook 'ejn-cell-kill-ring)))
    (unless kill-ring
      (user-error "Kill ring is empty"))
    (let* ((entry (car kill-ring))
           (source (cdr (assq 'source entry)))
           (type (cdr (assq 'type entry)))
           (current-cell ejn--cell)
           (cells (slot-value notebook 'cells))
           (current-index (cl-position current-cell cells)))
      ;; Pop the entry from the kill ring
      (oset notebook ejn-cell-kill-ring (cdr kill-ring))
      ;; Create new cell below current cell
      (ejn--make-cell notebook (1+ current-index) type source))))

(defun ejn:worksheet-copy-cell (&optional kill)
  "Copy the current cell's source and type to the notebook's kill ring.

Copies the cell at point's `:source' and `:type' onto
`ejn-notebook's `ejn-cell-kill-ring' slot as an association list entry.
When KILL is non-nil, also kills the cell after copying.
Interactively, KILL is the prefix argument."
  (interactive "P")
  (let* ((notebook (ejn-notebook-of-buffer))
         (cell ejn--cell)
         (entry `((source . ,(slot-value cell 'source))
                  (type . ,(slot-value cell 'type)))))
    (oset notebook ejn-cell-kill-ring
          (cons entry (slot-value notebook 'ejn-cell-kill-ring)))
    (when kill
      (ejn:worksheet-kill-cell))))

(defun ejn:worksheet-goto-next-input ()
  "Navigate to the next cell.

If in the master view buffer, move point to the next cell button
using `next-button'. If in a cell buffer, switch to the next
cell's buffer via `ejn-cell-open-buffer'."
  (interactive)
  (if (bound-and-true-p ejn--cell)
      ;; Cell buffer: switch to next cell's buffer
      (let* ((notebook (ejn-notebook-of-buffer))
             (cells (slot-value notebook 'cells))
             (current-cell ejn--cell)
             (current-index (cl-position current-cell cells))
             (next-index (1+ current-index)))
        (if (< next-index (length cells))
            (let ((next-cell (nth next-index cells)))
              (switch-to-buffer (ejn-cell-open-buffer next-cell notebook)))
          (user-error "No more cells below")))
    ;; Master view: move to next button
    (condition-case nil
        (next-button (current-buffer))
      (error (user-error "No more cells below")))))

(defun ejn:worksheet-goto-prev-input ()
  "Navigate to the previous cell.

If in the master view buffer, move point to the previous cell button
using `previous-button'. If in a cell buffer, switch to the previous
cell's buffer via `ejn-cell-open-buffer'."
  (interactive)
  (if (bound-and-true-p ejn--cell)
      ;; Cell buffer: switch to previous cell's buffer
      (let* ((notebook (ejn-notebook-of-buffer))
             (cells (slot-value notebook 'cells))
             (current-cell ejn--cell)
             (current-index (cl-position current-cell cells)))
        (if (> current-index 0)
            (let ((prev-cell (nth (1- current-index) cells)))
              (switch-to-buffer (ejn-cell-open-buffer prev-cell notebook)))
          (user-error "No more cells above")))
    ;; Master view: move to previous button
    (condition-case nil
        (previous-button (current-buffer))
      (error (user-error "No more cells above")))))

(provide 'ejn-cell)

;;; ejn-cell.el ends here
