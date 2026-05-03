;;; ejn-notebook.el --- Notebook persistence for EJN  -*- lexical-binding: t -*-

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

;; Notebook persistence utilities for Emacs Jupyter Notebook.
;;
;; This file provides:
;;   - `ejn--cell-to-json'       : Serialize an ejn-cell to an nbformat 4 plist
;;   - `ejn-notebook-save'       : Write a notebook to its .ipynb file
;;   - `ejn-notebook-save-as'    : Write a notebook to a new path
;;   - `ejn-notebook-rename'     : Rename a notebook file in place

;;; Code:

(require 'cl-lib)
(require 'eieio)
(require 'json)
(require 'ejn-core)

(declare-function ejn--flush-all-dirty-cells 'ejn-core (notebook))

;; ---------------------------------------------------------------------------
;; Output normalisation
;;
;; FIX #11: The original ejn--cell-to-json passed (slot-value cell 'outputs)
;; directly to json-encode.  Outputs are parsed as a list of hash-tables with
;; string keys.  json-encode emits hash-tables faithfully, but:
;;   1. The JSON library may reorder keys.
;;   2. Keys stored as symbols (not strings) would be encoded incorrectly.
;;   3. :null values from the original parse are not re-emitted as JSON null.
;; Fixed by normalising each output item through
;; `ejn--normalise-output-item', which ensures all hash-table keys are
;; strings and :null values are mapped back to JSON null before encoding.
;; ---------------------------------------------------------------------------

(defun ejn--normalise-output-item (item)
  "Return a normalised copy of output ITEM suitable for json-encode.

ITEM is expected to be a hash-table with string keys as produced by
`json-parse-buffer :object-type hash-table'.  Returns a new hash-table
with the same keys and values, except:
  - symbol keys are converted to their `symbol-name' string form.
  - :null values are converted to the symbol `json-null' which
    `json-encode' renders as JSON null.

Returns ITEM unchanged if it is not a hash-table."
  (if (not (hash-table-p item))
      item
    (let ((normalised (make-hash-table :test 'equal
                                       :size (hash-table-count item))))
      (maphash
       (lambda (key val)
         (let ((str-key (if (symbolp key) (symbol-name key) key))
               (norm-val (cond
                          ((eq val :null) json-null)
                          ((hash-table-p val) (ejn--normalise-output-item val))
                          ((vectorp val)
                           (vconcat (mapcar #'ejn--normalise-output-item val)))
                          ((listp val)
                           (mapcar #'ejn--normalise-output-item val))
                          (t val))))
           (puthash str-key norm-val normalised)))
       item)
      normalised)))

(defun ejn--normalise-outputs (outputs)
  "Normalise OUTPUTS list for JSON serialisation.

OUTPUTS is a list of output hash-tables from the cell's `:outputs' slot.
Returns a new list (or vector suitable for `json-encode') in which each
item has been passed through `ejn--normalise-output-item'.

When OUTPUTS is nil, returns the empty vector `[]' (JSON []).
When OUTPUTS is already a vector, converts to list first, then normalises."
  (cond
   ((null outputs)
    (vector))
   ((vectorp outputs)
    (vconcat (mapcar #'ejn--normalise-output-item (append outputs nil))))
   ((listp outputs)
    (vconcat (mapcar #'ejn--normalise-output-item outputs)))
   (t
    (vector))))

(defun ejn--cell-to-json (cell)
  "Serialise CELL to an nbformat 4 JSON-encodable alist.

FIX #11: Passes `:outputs' through `ejn--normalise-outputs' before
encoding to ensure string keys, nil→json-null conversion, and
vector output so `json-encode' produces a JSON array.

Returns an alist with string keys matching the nbformat 4 schema:
  cell_type, source, outputs, execution_count, metadata."
  (let* ((cell-type (slot-value cell 'type))
         (source (or (slot-value cell 'source) ""))
         (raw-outputs (slot-value cell 'outputs))
         ;; Normalise outputs: ensures string keys and null-safety
         (outputs (ejn--normalise-outputs raw-outputs))
         (exec-count (or (slot-value cell 'exec-count) json-null))
         (metadata (make-hash-table :test 'equal)))
    `(("cell_type"       . ,(symbol-name cell-type))
      ("source"          . ,source)
      ("outputs"         . ,outputs)
      ("execution_count" . ,exec-count)
      ("metadata"        . ,metadata))))

(defun ejn--notebook-to-json (notebook)
  "Serialise NOTEBOOK to a nbformat 4.5 JSON-encodable alist.

Builds the top-level .ipynb structure:
  nbformat, nbformat_minor, metadata, cells (as a vector).

All dirty cells are flushed (via `ejn--flush-all-dirty-cells') before
serialisation so that any unsaved buffer edits are included.

Returns an alist suitable for passing to `json-encode'."
  ;; Flush dirty cells first
  (ejn--flush-all-dirty-cells notebook)
  (let* ((cells (slot-value notebook 'cells))
         (cell-json-vector
          (vconcat (mapcar #'ejn--cell-to-json cells)))
         (metadata (or (slot-value notebook 'metadata)
                       (make-hash-table :test 'equal))))
    `(("nbformat"       . 4)
      ("nbformat_minor" . 5)
      ("metadata"       . ,metadata)
      ("cells"          . ,cell-json-vector))))

(defun ejn-notebook-save (notebook)
  "Save NOTEBOOK to its `:path' file in nbformat 4.5.

Flushes dirty cells, serialises the notebook via `ejn--notebook-to-json',
and writes JSON atomically to a `.tmp' file before renaming to the target
path.  Displays a message on success.  Signals on write error.

Returns the path written to."
  (let* ((path (slot-value notebook 'path))
         (tmp-path (concat path ".tmp"))
         (json-content (json-encode (ejn--notebook-to-json notebook))))
    (with-temp-file tmp-path
      (insert json-content)
      (insert "\n"))
    (rename-file tmp-path path 'replace)
    (message "Saved: %s" path)
    path))

(defun ejn-notebook-save-as (notebook new-path)
  "Save NOTEBOOK to NEW-PATH and update the notebook's `:path' slot.

Flushes dirty cells, serialises the notebook, writes JSON atomically to
NEW-PATH, updates NOTEBOOK's `:path' slot to NEW-PATH, and refreshes
the master buffer's name.
Returns NEW-PATH."
  (let* ((json-content (json-encode (ejn--notebook-to-json notebook)))
         (tmp-path (concat new-path ".tmp")))
    (with-temp-file tmp-path
      (insert json-content)
      (insert "\n"))
    (rename-file tmp-path new-path 'replace)
    ;; Update path slot
    (oset notebook path new-path)
    ;; Rename master buffer to reflect new stem
    (when-let* ((master-buf (slot-value notebook 'master-buffer))
                ((buffer-live-p master-buf)))
      (let* ((new-stem (file-name-sans-extension
                        (file-name-nondirectory new-path)))
             (new-buf-name (format "*ejn:%s*" new-stem)))
        (with-current-buffer master-buf
          (rename-buffer new-buf-name 'unique))))
    (message "Saved as: %s" new-path)
    new-path))

(defun ejn-notebook-rename (notebook new-name)
  "Rename NOTEBOOK's underlying file to NEW-NAME (a basename, not a full path).

NEW-NAME should be a filename without a path (e.g., \"analysis.ipynb\").
The notebook file is renamed to a sibling of the current `:path'.
Calls `ejn-notebook-save-as' with the new full path.
Returns the new full path."
  (let* ((current-path (slot-value notebook 'path))
         (dir (file-name-directory current-path))
         (new-path (expand-file-name new-name dir)))
    (ejn-notebook-save-as notebook new-path)))

(provide 'ejn-notebook)

;;; ejn-notebook.el ends here
