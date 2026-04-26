;;; ejn-core.el --- Core utilities for EJN  -*- lexical-binding: t -*-

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

;; Core utilities for Emacs Jupyter Notebook.
;;
;; This file defines the EIEIO data model classes:
;;   - ejn-notebook  : top-level notebook object
;;   - ejn-cell      : individual cell object

;; URL: https://github.com/emacs-jupyter-notebook/emacs-jupyter-notebook
;; Package-Requires: ((emacs "24.1"))

;;; Code:

(require 'cl-lib)
(require 'eieio)
(require 'json)

;;;###autoload
(defclass ejn-notebook ()
  ((path :initarg :path
         :initform nil
         :type (or string null)
         :documentation "Absolute path to the .ipynb file.")
   (metadata :initarg :metadata
              :initform nil
              :type (or list hash-table null)
              :documentation "Parsed from .ipynb top-level metadata.")
   (cells :initarg :cells
          :initform nil
          :type list
          :documentation "Ordered list of ejn-cell objects.")
   (kernel-id :initarg :kernel-id
              :initform nil
              :type (or string null)
              :documentation "Kernel identifier. Reserved for Phase 4.")
   (ejn-cell-kill-ring :initarg :ejn-cell-kill-ring
                       :initform nil
                       :type list
                       :documentation "Internal kill ring for cell copy/yank.")
   (master-buffer :initarg :master-buffer
                  :initform nil
                  :type (or buffer null)
                  :documentation "Buffer-local back-pointer to the master view buffer."))
  "Top-level object representing a Jupyter notebook.")

;;;###autoload
(defclass ejn-cell ()
  ((id :initarg :id
       :initform nil
       :type (or string null)
       :documentation "Unique cell identifier generated via cl-gensym.")
   (type :initarg :type
         :initform nil
         :type (or symbol null)
         :documentation "Cell type: code, markdown, or raw.")
   (source :initarg :source
           :initform nil
           :type (or string null)
           :documentation "Cell source code or markdown text.")
   (outputs :initarg :outputs
            :initform nil
            :type list
            :documentation "Parsed from .ipynb outputs array.")
   (buffer :initarg :buffer
           :initform nil
           :type (or buffer null)
           :documentation "The dedicated cell editing buffer.")
   (shadow-file :initarg :shadow-file
                :initform nil
                :type (or string null)
                :documentation "Path to the shadow file on disk.")
   (exec-count :initarg :exec-count
               :initform nil
               :type (or integer null)
               :documentation "Execution count from .ipynb.")
   (dirty :initarg :dirty
          :initform nil
          :type boolean
          :documentation "Set by after-change-functions when buffer diverges."))
  "Individual Jupyter notebook cell.")

(defun ejn-cell--generate-id ()
  "Generate a unique cell ID via cl-gensym."
  (symbol-name (cl-gensym "cell-")))

(cl-defmethod initialize-instance :after ((cell ejn-cell) &rest _args)
  "Generate an ID for CELL if one was not provided via :id initarg."
  (unless (slot-value cell 'id)
    (oset cell id (ejn-cell--generate-id))))

(defun ejn--parse-cell-data (cell-json)
  "Parse a single cell JSON hash table CELL-JSON into an ejn-cell.

CELL-JSON is a hash table with keys:
cell_type, source, outputs, execution_count.
Returns a new ejn-cell instance."
  (let* ((cell-type (gethash "cell_type" cell-json))
          (source (gethash "source" cell-json))
          (outputs (gethash "outputs" cell-json))
          (exec-count (gethash "execution_count" cell-json)))
    ;; JSON arrays parse as vectors; convert to list for EIEIO type constraint
    (when (vectorp outputs)
      (setq outputs (append outputs nil)))
    ;; Handle source which may be a list of strings (nbformat 4) or a plain string
    (when (listp source)
      (setq source (string-join source "")))
    (make-instance 'ejn-cell
                   :type (intern cell-type)
                   :source source
                   :outputs outputs
                   :exec-count exec-count)))

(defun ejn--parse-cells-nbformat4 (notebook-json)
  "Parse cells from a nbformat 4.x NOTEBOOK-JSON hash table.

Returns a list of ejn-cell objects."
  (let* ((cells-json (gethash "cells" notebook-json))
         (cells '()))
    (when cells-json
      (cl-loop for cell-json across cells-json
               do (push (ejn--parse-cell-data cell-json) cells)))
    (nreverse cells)))

(defun ejn--parse-cells-nbformat3 (notebook-json)
  "Parse cells from a nbformat 3.x NOTEBOOK-JSON hash table.

Reads cells from `notebook[\"worksheets\"][0][\"cells\"]` and maps each
JSON cell to `ejn-cell` via `ejn--parse-cell-data`.
Returns a list of ejn-cell objects."
  (let* ((worksheets (gethash "worksheets" notebook-json))
         (worksheet (and (vectorp worksheets)
                         (> (length worksheets) 0)
                         (aref worksheets 0)))
         (cells-json (and worksheet (gethash "cells" worksheet)))
         (cells '()))
    (when cells-json
      (cl-loop for cell-json across cells-json
               do (push (ejn--parse-cell-data cell-json) cells)))
    (nreverse cells)))

(defun ejn-notebook-load (file-path)
  "Load a Jupyter notebook from FILE-PATH and return an ejn-notebook object.

FILE-PATH should be an absolute path to a .ipynb file.
Reads JSON from the file, detects nbformat version, and parses cells
into ejn-cell objects.

Signals `file-error' if the file does not exist.
Signals `json-error' if the file is not valid JSON or not a recognized nbformat."
  (unless (file-exists-p file-path)
    (signal 'file-error (list "Cannot open load file" file-path)))

  (let* ((notebook-json
         (with-temp-buffer
           (insert-file-contents file-path)
           (condition-case err
               (json-parse-buffer :object-type 'hash-table)
             (json-readtable-error
              (signal 'json-error
                      (list (format "Invalid JSON in %s" file-path)
                            err))))))
        (nbformat (gethash "nbformat" notebook-json)))
    ;; Validate nbformat
    (unless (member nbformat '(3 4))
      (signal 'json-error
              (list (format "Unrecognized nbformat: %s in %s"
                            nbformat file-path))))

    ;; Create notebook object
    (let* ((metadata (gethash "metadata" notebook-json))
           (nb (make-instance 'ejn-notebook
                              :path file-path
                              :metadata metadata))
          (cells (cond
                    ((= nbformat 4)
                     (ejn--parse-cells-nbformat4 notebook-json))
                    ((= nbformat 3)
                     (ejn--parse-cells-nbformat3 notebook-json))
                    (t
                     (signal 'json-error
                             (list (format "Unrecognized nbformat: %s in %s"
                                           nbformat file-path)))))))
      (oset nb cells cells)
      nb)))

(defun ejn-shadow-write-cell (cell notebook)
  "Write CELL's :source to a shadow file within NOTEBOOK's cache directory.

Creates `.ejn-cache/<notebook-stem>/` directory if needed.
Generates a zero-padded filename based on CELL's index in NOTEBOOK's
`:cells` list. Extension is determined by cell type:
code → .py, markdown → .md, raw → .raw.
Updates CELL's `:shadow-file` slot.
Returns the absolute path to the shadow file."
  (let* ((nb-path (slot-value notebook 'path))
         (nb-stem (file-name-sans-extension
                   (file-name-nondirectory nb-path)))
         (cache-dir (expand-file-name
                     (concat ".ejn-cache/" nb-stem)
                     (file-name-directory nb-path)))
         (cells (slot-value notebook 'cells))
         (cell-index (cl-position cell cells))
         (ext (cl-case (slot-value cell 'type)
                (code ".py")
                (markdown ".md")
                (raw ".raw")))
         (shadow-filename (format "cell_%03d%s" cell-index ext))
         (shadow-path (expand-file-name shadow-filename cache-dir)))
    (make-directory cache-dir t)
    (with-temp-file shadow-path
      (insert (slot-value cell 'source)))
    (oset cell shadow-file shadow-path)
    shadow-path))

(defun ejn-cell-dirty-p (cell)
  "Return non-nil if CELL's :dirty slot is set."
  (slot-value cell 'dirty))

(defun ejn-shadow-sync-cell (cell)
  "Sync CELL's buffer content into its :source slot and shadow file.

Reads the current content from CELL's :buffer. If it differs from
the cell's :source slot, updates :source, writes the shadow file
atomically (via .tmp + rename-file), and clears the :dirty flag.
Returns t if changes were written, nil if no changes were needed
or if CELL has no buffer."
  (let ((buf (slot-value cell 'buffer)))
    (if (not (buffer-live-p buf))
        nil
      (with-current-buffer buf
        (let* ((buffer-content
                (buffer-substring-no-properties (point-min) (point-max)))
               (current-source (slot-value cell 'source)))
          (if (string= buffer-content current-source)
              nil
            ;; Content differs: update source, write shadow file, clear dirty
            (oset cell source buffer-content)
            (let ((shadow-path (slot-value cell 'shadow-file)))
              (when shadow-path
                (let ((tmp-path (concat shadow-path ".tmp")))
                  ;; Write atomically: .tmp then rename
                  (with-temp-file tmp-path
                    (insert buffer-content))
                  (rename-file tmp-path shadow-path 'replace))))
            (oset cell dirty nil)
            t))))))

(defun ejn--flush-all-dirty-cells (notebook)
  "Flush all dirty cells in NOTEBOOK to the EIEIO model.

Iterates NOTEBOOK's `:cells` list. For each cell with `:dirty` set
and a live `:buffer`, calls `ejn-shadow-sync-cell' to flush buffer
content into the `:source` slot and shadow file, clearing the dirty
flag.
Returns nil."
  (dolist (cell (slot-value notebook 'cells))
    (when (and (slot-value cell 'dirty)
               (buffer-live-p (slot-value cell 'buffer)))
      (ejn-shadow-sync-cell cell))))

(defvar ejn--notebook nil
  "Buffer-local variable storing the ejn-notebook for the current view.")

(defun ejn-notebook-of-buffer (&optional buffer)
  "Return the ejn-notebook associated with BUFFER.

BUFFER defaults to the current buffer if not provided.
Reads the buffer-local `ejn--notebook' variable from the buffer.
Returns nil if no notebook is associated with BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (buffer-local-value 'ejn--notebook (current-buffer))))

(provide 'ejn-core)

;;; ejn-core.el ends here
