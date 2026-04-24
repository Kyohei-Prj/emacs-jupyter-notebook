;;; ejn-data.el --- Data model for emacs-jupyter-notebook  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;; Commentary:
;;
;; This module provides the core data model for emacs-jupyter-notebook.
;; It defines the cell, output, and notebook data structures used throughout
;; the package to represent Jupyter notebook content in Emacs.

;; Code:

(require 'cl-lib)

(cl-defstruct (ejn-cell
               (:constructor ejn-make-cell
                 (&key id
                       (type 'code)
                       (language "python")
                       (source "")
                       (outputs nil)
                       (execution-count nil)
                       (metadata (make-hash-table :test 'equal)))))
  "An immutable Jupyter notebook cell representation.

Slots:
  ID                — 36-char hyphenated UUID string
  TYPE              — symbol: 'code, 'markdown, or 'raw
  LANGUAGE          — kernel language string
  SOURCE            — raw cell source text
  OUTPUTS           — list of ejn-output structs
  EXECUTION-COUNT   — integer or nil
  METADATA          — hash-table with :test 'equal"
  id
  type
  language
  source
  outputs
  execution-count
  metadata)

(cl-defstruct (ejn-output
               (:constructor ejn-make-output
                 (&key output-type
                       (data (make-hash-table :test 'equal))
                       (metadata (make-hash-table :test 'equal))
                       (text nil)
                       (name nil)
                       (ename nil)
                       (evalue nil)
                       (traceback nil))))
  "An immutable Jupyter cell output representation.

Slots:
  OUTPUT-TYPE   — symbol: 'stream, 'display_data, 'execute_result, 'error
  DATA          — hash-table MIME-type → content
  METADATA      — hash-table output metadata passthrough
  TEXT          — string or nil
  NAME          — string or nil
  ENAME         — string or nil
  EVALUE        — string or nil
  TRACEBACK     — string or nil"
  output-type
  data
  metadata
  text
  name
  ename
  evalue
  traceback)

(cl-defstruct (ejn-notebook
               (:constructor ejn-make-notebook
                 (&key (path "")
                       (nbformat 4)
                       (nbformat-minor 5)
                       (metadata (make-hash-table :test 'equal))
                       (kernel-name "")
                       (language "")
                       (cells nil)
                       (dirty-p nil))))
  "An immutable Jupyter notebook representation.

Slots:
  PATH              — notebook file path string
  NBFORMAT          — integer (must be 4)
  NBFORMAT-MINOR    — integer
  METADATA          — hash-table
  KERNEL-NAME       — kernel name string
  LANGUAGE          — kernel language string
  CELLS             — list of ejn-cell structs
  DIRTY-P           — whether notebook has unsaved changes"
  path
  nbformat
  nbformat-minor
  metadata
  kernel-name
  language
  cells
  dirty-p)

(defun ejn-notebook-cell-by-id (notebook uuid)
  "Return first ejn-cell whose id equals UUID, or nil if not found."
  (cl-find-if (lambda (cell) (string= (ejn-cell-id cell) uuid))
              (ejn-notebook-cells notebook)))

(defun ejn-notebook-insert-cell (notebook cell index)
  "Return a new notebook with CELL inserted at INDEX.
INDEX 0 prepends, INDEX >= length appends.
Signals error if INDEX < 0."
  (cl-check-type index integer)
  (unless (<= 0 index)
    (error "Cell index out of range: %d" index))
  (let ((cells (ejn-notebook-cells notebook)))
    (if (>= index (length cells))
        (ejn-make-notebook :path (ejn-notebook-path notebook)
                           :nbformat (ejn-notebook-nbformat notebook)
                           :nbformat-minor (ejn-notebook-nbformat-minor notebook)
                           :metadata (ejn-notebook-metadata notebook)
                           :kernel-name (ejn-notebook-kernel-name notebook)
                           :language (ejn-notebook-language notebook)
                           :cells (append cells (list cell))
                           :dirty-p t)
      (ejn-make-notebook :path (ejn-notebook-path notebook)
                          :nbformat (ejn-notebook-nbformat notebook)
                          :nbformat-minor (ejn-notebook-nbformat-minor notebook)
                          :metadata (ejn-notebook-metadata notebook)
                          :kernel-name (ejn-notebook-kernel-name notebook)
                          :language (ejn-notebook-language notebook)
                          :cells (append (cl-subseq cells 0 index)
                                         (list cell)
                                         (cl-subseq cells index))
                          :dirty-p t))))

(defun ejn-notebook-delete-cell (notebook uuid)
  "Return a new notebook with the cell matching UUID removed.
If no cell matches, returns a copy of the original notebook.
Sets dirty-p to t on the returned notebook."
  (let ((cells (ejn-notebook-cells notebook)))
    (ejn-make-notebook :path (ejn-notebook-path notebook)
                       :nbformat (ejn-notebook-nbformat notebook)
                       :nbformat-minor (ejn-notebook-nbformat-minor notebook)
                       :metadata (ejn-notebook-metadata notebook)
                       :kernel-name (ejn-notebook-kernel-name notebook)
                       :language (ejn-notebook-language notebook)
                       :cells (cl-remove-if (lambda (c) (string= (ejn-cell-id c) uuid)) cells)
                       :dirty-p t)))

(defun ejn-notebook-move-cell (notebook uuid direction)
  "Return a new notebook with the cell at UUID moved in DIRECTION.
DIRECTION is \\='up or \\='down.
If cell is first and DIRECTION is \\='up, or last and DIRECTION is \\='down,
returns a copy unchanged."
   (let* ((cells (ejn-notebook-cells notebook))
          (cell (ejn-notebook-cell-by-id notebook uuid))
          (new-cells cells))
     (when cell
       (let ((idx (cl-position cell cells :test #'eq)))
         (when (eq direction 'up)
           (when (> idx 0)
             (setq new-cells
                    (append (cl-subseq cells 0 (- idx 1))
                            (list cell (elt cells (- idx 1)))
                            (cl-subseq cells (1+ idx))))))
         (when (eq direction 'down)
           (when (< idx (- (length cells) 1))
            (setq new-cells
                    (append (cl-subseq cells 0 idx)
                            (list (elt cells (1+ idx)) cell)
                            (cl-subseq cells (+ idx 2))))))))
     (ejn-make-notebook :path (ejn-notebook-path notebook)
                       :nbformat (ejn-notebook-nbformat notebook)
                       :nbformat-minor (ejn-notebook-nbformat-minor notebook)
                       :metadata (ejn-notebook-metadata notebook)
                       :kernel-name (ejn-notebook-kernel-name notebook)
                       :language (ejn-notebook-language notebook)
                       :cells new-cells
                       :dirty-p t)))

(defun ejn-notebook-update-cell-source (notebook uuid new-source)
  "Return a new notebook with the cell matching UUID having its source replaced.
If no cell matches, returns a copy of the original notebook unchanged.
Sets dirty-p to t on the returned notebook."
  (let ((cells (ejn-notebook-cells notebook)))
    (ejn-make-notebook :path (ejn-notebook-path notebook)
                       :nbformat (ejn-notebook-nbformat notebook)
                       :nbformat-minor (ejn-notebook-nbformat-minor notebook)
                       :metadata (ejn-notebook-metadata notebook)
                       :kernel-name (ejn-notebook-kernel-name notebook)
                       :language (ejn-notebook-language notebook)
                       :cells (cl-loop for c in cells
                                       if (string= (ejn-cell-id c) uuid)
                                       collect (ejn-make-cell :id (ejn-cell-id c)
                                                              :type (ejn-cell-type c)
                                                              :language (ejn-cell-language c)
                                                              :source new-source
                                                              :outputs (ejn-cell-outputs c)
                                                              :execution-count (ejn-cell-execution-count c)
                                                              :metadata (ejn-cell-metadata c))
                                       else
                                       collect c)
                       :dirty-p t)))

(provide 'ejn-data)
;;; ejn-data.el ends here
