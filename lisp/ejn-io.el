;;; ejn-io.el --- Notebook I/O (parse and serialize .ipynb)  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;; Commentary:

;; This module handles reading and writing Jupyter notebook (.ipynb) files
;; in nbformat 4. It uses Emacs's built-in json library to parse and
;; serialize notebook data to and from the ejn data structures.

;; Code:

(require 'cl-lib)
(require 'json)
(require 'ejn-util)
(require 'ejn-data)

;;;; Private helpers

(defun ejn-io--parse-output (raw-output)
  "Map RAW-OUTPUT (a hash-table) to an ejn-output struct."
  (let* ((output-type (or (gethash "output_type" raw-output) "unknown"))
         (data (or (gethash "data" raw-output) (make-hash-table :test 'equal)))
         (metadata (or (gethash "metadata" raw-output) (make-hash-table :test 'equal)))
         (text (gethash "text" raw-output))
         (name (gethash "name" raw-output))
         (ename (gethash "ename" raw-output))
         (evalue (gethash "evalue" raw-output))
         (traceback (gethash "traceback" raw-output)))
    ;; Join text/traceback arrays to strings if needed
    (when (and text (sequencep text))
      (setq text (mapconcat #'identity text "\n")))
    (when (and traceback (sequencep traceback))
      (setq traceback (mapconcat #'identity traceback "\n")))
    (ejn-make-output :output-type (intern output-type)
                     :data data
                     :metadata metadata
                     :text text
                     :name name
                     :ename ename
                     :evalue evalue
                     :traceback traceback)))

(defun ejn-io--parse-cell (raw-cell)
  "Map RAW-CELL (a hash-table) to an ejn-cell struct."
  (unless (gethash "id" raw-cell)
    (error "Cell missing required 'id' field"))
  (let* ((cell-type (or (gethash "cell_type" raw-cell) "code"))
         (source (gethash "source" raw-cell))
         (execution-count (gethash "execution_count" raw-cell))
         (outputs (or (gethash "outputs" raw-cell) nil))
         (metadata (or (gethash "metadata" raw-cell) (make-hash-table :test 'equal))))
    ;; Join source array to string
    (when (and source (sequencep source))
      (setq source (mapconcat #'identity source "\n")))
    ;; Determine language based on cell type
    (let ((language (cond
                      ((string= cell-type "markdown") "markdown")
                      ((string= cell-type "raw") "raw")
                      (t (or (gethash "language" metadata) "python")))))
      (ejn-make-cell :id (gethash "id" raw-cell)
                     :type (intern cell-type)
                     :language language
                     :source (or source "")
                     :outputs (when (sequencep outputs)
                                   (cl-loop for out across outputs
                                            when (hash-table-p out)
                                            collect (ejn-io--parse-output out)))
                     :execution-count execution-count
                     :metadata metadata))))

(defun ejn-io--hash-to-json (hash-table)
  "Convert a hash-table to a format suitable for JSON encoding.
Converts hash-tables to alists for json-encode compatibility."
  (let ((result (make-hash-table :test 'equal)))
    (maphash (lambda (k v)
               (setf (gethash k result)
                     (if (hash-table-p v)
                         (ejn-io--hash-to-json v)
                       v)))
             hash-table)
    result))

(defun ejn-io--output-to-hash (output)
  "Convert OUTPUT (ejn-output struct) to a hash-table for JSON serialization."
  (let ((out-hash (make-hash-table :test 'equal)))
    (setf (gethash "output_type" out-hash) (symbol-name (ejn-output-output-type output)))
    (setf (gethash "data" out-hash) (ejn-io--hash-to-json (ejn-output-data output)))
    (setf (gethash "metadata" out-hash) (ejn-io--hash-to-json (ejn-output-metadata output)))
    (when (ejn-output-text output)
      (setf (gethash "text" out-hash) (ejn-output-text output)))
    (when (ejn-output-name output)
      (setf (gethash "name" out-hash) (ejn-output-name output)))
    (when (ejn-output-ename output)
      (setf (gethash "ename" out-hash) (ejn-output-ename output)))
    (when (ejn-output-evalue output)
      (setf (gethash "evalue" out-hash) (ejn-output-evalue output)))
    (when (ejn-output-traceback output)
      (setf (gethash "traceback" out-hash) (ejn-output-traceback output)))
    out-hash))

(defun ejn-io--cell-to-hash (cell)
  "Convert CELL (ejn-cell struct) to a hash-table for JSON serialization."
  (let ((cell-hash (make-hash-table :test 'equal)))
    (setf (gethash "cell_type" cell-hash) (symbol-name (ejn-cell-type cell)))
    (setf (gethash "id" cell-hash) (ejn-cell-id cell))
    (setf (gethash "source" cell-hash)
          (let ((src (ejn-cell-source cell)))
            (if (string= src "")
                nil
              (split-string src "\n" t))))
    (setf (gethash "outputs" cell-hash)
          (cl-loop for out in (ejn-cell-outputs cell)
                   collect (ejn-io--output-to-hash out)))
    (setf (gethash "execution_count" cell-hash) (ejn-cell-execution-count cell))
    (setf (gethash "metadata" cell-hash) (ejn-io--hash-to-json (ejn-cell-metadata cell)))
    cell-hash))

(defun ejn-io--nb-to-hash (notebook)
  "Convert NOTEBOOK (ejn-notebook struct) to a hash-table for JSON serialization."
  (let ((nb-hash (make-hash-table :test 'equal)))
    (setf (gethash "cells" nb-hash)
          (cl-loop for cell in (ejn-notebook-cells notebook)
                   collect (ejn-io--cell-to-hash cell)))
    (setf (gethash "metadata" nb-hash) (ejn-io--hash-to-json (ejn-notebook-metadata notebook)))
    (setf (gethash "nbformat" nb-hash) (ejn-notebook-nbformat notebook))
    (setf (gethash "nbformat_minor" nb-hash) (ejn-notebook-nbformat-minor notebook))
    nb-hash))

;;;; Public API

(defun ejn-io-read (path)
  "Read a Jupyter notebook file at PATH and return an ejn-notebook struct."
  (unless (file-exists-p path)
    (error "File not found: %s" path))
  (let* ((content (with-temp-buffer
                    (insert-file-contents path)
                    (buffer-string)))
         (json (ignore-errors (json-parse-string content :object-type 'hash-table))))
    (unless json
      (error "Invalid JSON: could not parse file content"))
    (let* ((nbformat (gethash "nbformat" json))
           (cells-json (gethash "cells" json))
           (metadata (or (gethash "metadata" json) (make-hash-table :test 'equal))))
      (unless (eq nbformat 4)
        (error "Unsupported nbformat: %s" nbformat))
      ;; Extract kernel info
      (let ((kernel-name "")
            (language ""))
        (when (hash-table-p metadata)
          (let ((kernelspec (gethash "kernelspec" metadata)))
            (when (hash-table-p kernelspec)
              (setq kernel-name (or (gethash "name" kernelspec) ""))
              (setq language (or (gethash "language" kernelspec) "")))))
        (ejn-make-notebook :path path
                           :nbformat nbformat
                           :nbformat-minor (or (gethash "nbformat_minor" json) 5)
                           :metadata metadata
                           :kernel-name kernel-name
                           :language language
                           :cells (cl-loop for cell-json across cells-json
                                           when (hash-table-p cell-json)
                                           collect (ejn-io--parse-cell cell-json))
                           :dirty-p nil)))))

(defun ejn-io-write (notebook path)
  "Write NOTEBOOK (ejn-notebook struct) to PATH as a .ipynb file."
  (when (file-exists-p path)
    (unless (file-writable-p path)
      (error "Cannot write to read-only file: %s" path)))
  (let* ((nb-hash (ejn-io--nb-to-hash notebook))
         (json-str (json-encode nb-hash))
         (formatted (format "%s\n" json-str)))
    (with-temp-file path
      (insert formatted))
    (setf (ejn-notebook-dirty-p notebook) nil)
    notebook))

(provide 'ejn-io)
;;; ejn-io.el ends here
