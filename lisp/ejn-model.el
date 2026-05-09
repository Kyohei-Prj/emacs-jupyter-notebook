;;; ejn-model.el --- Notebook model and transaction system  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Kyohei

;; This file is part of emacs-jupyter-notebook.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'cl-lib)
(require 'ejn-cell)

(cl-defstruct ejn-notebook
  id
  path
  metadata
  cells
  dirty
  nbformat
  nbformat-minor
  dirty-set
  undo-history)

(defun ejn-make-notebook (&optional metadata)
  "Create a new notebook with optional METADATA alist.
Returns an `ejn-notebook' struct initialized with defaults."
  (make-ejn-notebook
   :id (ejn-generate-uuid)
   :path nil
   :metadata (or metadata nil)
   :cells (vconcat)
   :dirty nil
   :nbformat 4
   :nbformat-minor 5
   :dirty-set (make-hash-table :test 'equal)
   :undo-history nil))

(defun ejn-notebook-mark-dirty (notebook cell-id)
  "Mark CELL-ID as dirty in NOTEBOOK.
Sets the overall dirty flag on NOTEBOOK."
  (puthash cell-id t (ejn-notebook-dirty-set notebook))
  (setf (ejn-notebook-dirty notebook) t))

(defun ejn-notebook-clean-cell (notebook cell-id)
  "Remove CELL-ID from the dirty set in NOTEBOOK."
  (remhash cell-id (ejn-notebook-dirty-set notebook))
  (when (zerop (hash-table-count (ejn-notebook-dirty-set notebook)))
    (setf (ejn-notebook-dirty notebook) nil)))

(defun ejn-notebook-dirty-cells (notebook)
  "Return a list of dirty cell IDs in NOTEBOOK."
  (let ((result))
    (maphash (lambda (key _value)
               (push key result))
             (ejn-notebook-dirty-set notebook))
    result))

(defun ejn-notebook-clean-all (notebook)
  "Clear all dirty cells and reset the dirty flag in NOTEBOOK."
  (clrhash (ejn-notebook-dirty-set notebook))
  (setf (ejn-notebook-dirty notebook) nil))

(cl-defun ejn-notebook-insert-cell (notebook type &key at after)
  "Insert a new cell of TYPE into NOTEBOOK.
Position is determined by AT (integer index) or AFTER (cell ID)."
  (let ((new-cell (ejn-make-cell type))
        (cells (ejn-notebook-cells notebook)))
    (let ((insert-index
           (cond
            (at at)
            (after
             (let ((idx (ejn-notebook-cell-index notebook after)))
               (if idx (1+ idx) 0)))
            (t (length cells)))))
      (setf (ejn-notebook-cells notebook)
            (vconcat (seq-take cells insert-index)
                     (vector new-cell)
                     (seq-drop cells insert-index))))
    (ejn-notebook-mark-dirty notebook (ejn-cell-id new-cell))
    new-cell))

(defun ejn-notebook-delete-cell (notebook cell-id)
  "Delete the cell with CELL-ID from NOTEBOOK."
  (let ((idx (ejn-notebook-cell-index notebook cell-id)))
    (unless idx
      (error "Cell not found: %s" cell-id))
    (let ((cells (ejn-notebook-cells notebook)))
      (setf (ejn-notebook-cells notebook)
            (vconcat (seq-take cells idx)
                     (seq-drop cells (1+ idx)))))
    (ejn-notebook-mark-dirty notebook cell-id)))

(defun ejn-notebook-set-cell-source (notebook cell-id source)
  "Set the source text of cell CELL-ID in NOTEBOOK to SOURCE."
  (let ((cell (ejn-notebook-cell-by-id notebook cell-id)))
    (setf (ejn-cell-source cell) source)
    (ejn-notebook-mark-dirty notebook cell-id)))

(defun ejn-notebook-cell-by-id (notebook cell-id)
  "Return the cell with CELL-ID from NOTEBOOK, or signal an error."
  (let ((cell nil))
    (cl-loop for c across (ejn-notebook-cells notebook)
             when (string= (ejn-cell-id c) cell-id)
             do (setq cell c))
    (unless cell
      (error "Cell not found: %s" cell-id))
    cell))

(defun ejn-notebook-cell-at-index (notebook index)
  "Return the cell at INDEX in NOTEBOOK, or nil."
  (let ((cells (ejn-notebook-cells notebook)))
    (when (< index (length cells))
      (aref cells index))))

(defun ejn-notebook-cell-index (notebook cell-id)
  "Return the index of cell CELL-ID in NOTEBOOK, or nil."
  (cl-loop for i from 0
           for c across (ejn-notebook-cells notebook)
           when (string= (ejn-cell-id c) cell-id)
           return i))

(provide 'ejn-model)
;;; ejn-model.el ends here
