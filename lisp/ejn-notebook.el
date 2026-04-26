;;; ejn-notebook.el --- Notebook file commands for EJN  -*- lexical-binding: t -*-

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

;; Notebook file commands: save, rename, etc.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'ejn-core)
(declare-function ejn-open-file "ejn" ())

(defun ejn--cell-to-json (cell)
  "Convert CELL (an ejn-cell) to a nbformat 4.x cell hash-table.

Returns a hash-table suitable for json-encode."
  (let ((cell-json (make-hash-table :test 'equal)))
    (puthash "cell_type" (symbol-name (slot-value cell 'type)) cell-json)
    (puthash "source" (slot-value cell 'source) cell-json)
    (puthash "execution_count" (slot-value cell 'exec-count) cell-json)
    (puthash "outputs" (slot-value cell 'outputs) cell-json)
    cell-json))

(defun ejn--notebook-to-json (notebook)
  "Build a full nbformat 4.x JSON structure from NOTEBOOK.

Returns a hash-table representing the complete notebook."
  (let ((nb-json (make-hash-table :test 'equal)))
    (puthash "nbformat" 4 nb-json)
    (puthash "nbformat_minor" 5 nb-json)
    (puthash "metadata" (slot-value notebook 'metadata) nb-json)
    (let* ((cells (slot-value notebook 'cells))
           (cells-json (make-vector (length cells) nil)))
      (cl-loop for cell in cells
               for idx from 0
               do (setf (aref cells-json idx)
                        (ejn--cell-to-json cell)))
      (puthash "cells" cells-json nb-json))
    nb-json))

(defun ejn-notebook-save (notebook)
  "Serialize NOTEBOOK to valid .ipynb JSON at its :path slot.

Flushes all dirty cell buffers to the EIEIO model first.
Clears all :dirty flags after successful write.
Returns t on success, nil on failure."
  (condition-case err
      (progn
        (ejn--flush-all-dirty-cells notebook)
        (let ((nb-json (ejn--notebook-to-json notebook)))
          (with-temp-file (slot-value notebook 'path)
            (insert (json-encode nb-json))))
        (dolist (cell (slot-value notebook 'cells))
          (oset cell dirty nil))
        t)
    (error
     (message "ejn-notebook-save: %s" (error-message-string err))
     nil)))

;;;###autoload
(defun ejn:notebook-save-notebook-command ()
  "Save the current notebook to its .ipynb file.

Retrieves the notebook associated with the current buffer via
`ejn-notebook-of-buffer', flushes all dirty cell buffers,
serializes the notebook to .ipynb JSON at the notebook's :path,
and clears all :dirty flags.
Returns t on success."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with current buffer"))
    (ejn-notebook-save notebook)))

(defun ejn-notebook-rename (notebook new-path)
  "Rename NOTEBOOK's .ipynb file to NEW-PATH on disk.

Renames the .ipynb file via `rename-file', updates the :path slot,
and renames `.ejn-cache/<old-stem>/' directory to match the new stem.
Returns t on success."
  (let* ((old-path (slot-value notebook 'path))
         (nb-dir (file-name-directory old-path))
         (old-stem (file-name-sans-extension
                    (file-name-nondirectory old-path)))
         (new-stem (file-name-sans-extension
                    (file-name-nondirectory new-path)))
         (old-cache-dir (expand-file-name
                         (concat ".ejn-cache/" old-stem)
                         nb-dir))
         (new-cache-dir (expand-file-name
                         (concat ".ejn-cache/" new-stem)
                         nb-dir)))
    (rename-file old-path new-path 'replace)
    (oset notebook path new-path)
    (when (file-directory-p old-cache-dir)
      (rename-file old-cache-dir new-cache-dir 'replace))
    t))

;;;###autoload
(defun ejn:notebook-rename-command ()
  "Rename the current notebook file and its cache directory.

Prompts for a new filename via `read-file-name', renames the
.ipynb file on disk, updates the :path slot, and renames the
.ejn-cache directory to match. Returns t on success."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with current buffer"))
    (let* ((old-path (slot-value notebook 'path))
           (dir (file-name-directory old-path))
           (default-name (file-name-nondirectory old-path))
           (new-name (read-file-name
                      "New notebook name: " dir default-name t default-name))
           (new-path (expand-file-name new-name dir)))
      (ejn-notebook-rename notebook new-path))))

(defalias 'ejn:file-open #'ejn-open-file)

(provide 'ejn-notebook)

;;; ejn-notebook.el ends here
