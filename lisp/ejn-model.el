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

(defun ejn--notebook-snapshot (notebook)
  "Create a snapshot of the mutable state of NOTEBOOK.
Returns a list of plists, one per cell, capturing mutable fields."
  (cl-loop for cell across (ejn-notebook-cells notebook)
           collect (list :id (ejn-cell-id cell)
                         :source (ejn-cell-source cell)
                         :outputs (ejn-cell-outputs cell)
                         :execution-count (ejn-cell-execution-count cell)
                         :execution-state (ejn-cell-execution-state cell)
                         :execution-version (ejn-cell-execution-version cell))))

(defun ejn--notebook-apply-snapshot (notebook snapshot)
  "Apply SNAPSHOT to NOTEBOOK, restoring cell mutable state.
SNAPSHOT is a list of plists as produced by `ejn--notebook-snapshot'."
  (cl-loop for cell-plist in snapshot
           do (let ((cell (ejn-notebook-cell-by-id notebook
                                                   (plist-get cell-plist :id))))
                (setf (ejn-cell-source cell) (plist-get cell-plist :source)
                      (ejn-cell-outputs cell) (plist-get cell-plist :outputs)
                      (ejn-cell-execution-count cell) (plist-get cell-plist :execution-count)
                      (ejn-cell-execution-state cell) (plist-get cell-plist :execution-state)
                      (ejn-cell-execution-version cell) (plist-get cell-plist :execution-version)))))

(defmacro ejn-with-transaction (notebook &rest body)
  "Execute BODY as a transaction on NOTEBOOK.
If BODY errors, cell state is restored to its pre-transaction values.
Marks the notebook dirty on success."
  (declare (indent 1))
  `(let ((ejn--txn-notebook ,notebook)
         (ejn--txn-snapshot (ejn--notebook-snapshot ,notebook)))
     (condition-case err
         (progn ,@body)
       (error
        (ejn--notebook-apply-snapshot ejn--txn-notebook ejn--txn-snapshot)
        (signal (car err) (cdr err))))))

(defmacro ejn-with-undo-group (label notebook &rest body)
  "Execute BODY within an undoable transaction on NOTEBOOK.
LABEL is a human-readable description stored with the undo entry.
Records before/after snapshots for undo and redo."
  (declare (indent 2))
  `(let ((ejn--undo-notebook ,notebook)
         (ejn--undo-before (ejn--notebook-snapshot ,notebook)))
     (ejn-with-transaction ejn--undo-notebook
			   ,@body)
     (let ((ejn--undo-after (ejn--notebook-snapshot ejn--undo-notebook)))
       (push (list :label ,label
                   :before ejn--undo-before
                   :after ejn--undo-after)
             (ejn-notebook-undo-history ejn--undo-notebook)))))

(defun ejn--undo-entry-p (entry)
  "Return non-nil if ENTRY is a regular undo entry (not a redo marker)."
  (and (consp entry)
       (eq (car entry) :label)))

(defun ejn--redo-entry-p (entry)
  "Return non-nil if ENTRY is a redo marker."
  (and (consp entry)
       (eq (car entry) 'redo)))

(defun ejn-undo (notebook)
  "Undo the last undoable operation on NOTEBOOK.
Restores cell state to the pre-operation snapshot."
  (let ((history (ejn-notebook-undo-history notebook))
        entry)
    (unless (cl-find-if #'ejn--undo-entry-p history)
      (user-error "Nothing to undo"))
    (setq entry (cl-find-if #'ejn--undo-entry-p history))
    (setf (ejn-notebook-undo-history notebook)
          (cl-remove entry history :count 1))
    (ejn--notebook-apply-snapshot notebook (plist-get entry :before))
    (push (cons 'redo entry)
          (ejn-notebook-undo-history notebook))
    (setf (ejn-notebook-dirty notebook) t)
    entry))

(defun ejn-redo (notebook)
  "Redo the last undone operation on NOTEBOOK.
Reapplies the post-operation snapshot from the undone entry."
  (let ((history (ejn-notebook-undo-history notebook))
        redo-entry)
    (setq redo-entry (cl-find-if #'ejn--redo-entry-p history))
    (unless redo-entry
      (user-error "Nothing to redo"))
    (setf (ejn-notebook-undo-history notebook)
          (cl-remove-if #'ejn--redo-entry-p history))
    (let ((entry (cdr redo-entry)))
      (ejn--notebook-apply-snapshot notebook (plist-get entry :after))
      (push entry (ejn-notebook-undo-history notebook))
      (setf (ejn-notebook-dirty notebook) t))
    redo-entry))

(provide 'ejn-model)
;;; ejn-model.el ends here
