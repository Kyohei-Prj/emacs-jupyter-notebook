;;; ejn-persistence.el --- Notebook persistence layer  -*- lexical-binding: t; -*-

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
(require 'json)
(require 'ejn-model)

(define-error 'ejn-invalid-notebook "Invalid notebook format" nil)
(define-error 'ejn-unsupported-format "Unsupported notebook format" 'ejn-invalid-notebook)

(defvar ejn-persistence-backend-registry
  (make-hash-table :test 'equal)
  "Hash table mapping backend type symbols to backend configurations.")

(cl-defgeneric ejn-persistence-read (_backend _path)
  "Read a notebook from PATH using BACKEND."
  nil)

(cl-defgeneric ejn-persistence-write (_backend _notebook _path)
  "Write NOTEBOOK to PATH using BACKEND."
  nil)

(cl-defgeneric ejn-persistence-can-handle-p (_backend _path)
  "Return non-nil if BACKEND can handle PATH."
  nil)

(cl-defun ejn-register-persistence-backend (type constructor &key predicate)
  "Register a persistence backend of TYPE with CONSTRUCTOR.
PREDICATE is a function that takes a path and returns non-nil if
the backend can handle it."
  (puthash type (list :constructor constructor
                      :predicate (or predicate
                                     (lambda (_path) nil)))
           ejn-persistence-backend-registry))

(defun ejn-persistence-backend-for (path)
  "Return the best persistence backend for PATH, or nil."
  (let ((result nil))
    (maphash (lambda (_type config)
               (let ((predicate (plist-get config :predicate)))
                 (when (funcall predicate path)
                   (setq result
                         (funcall (plist-get config :constructor))))))
             ejn-persistence-backend-registry)
    result))

;; Define ipynb backend struct
(cl-defstruct ejn-ipynb-backend)

(defun ejn-ipynb-parse-source (source)
  "Normalize nbformat SOURCE field to a string.
SOURCE can be a string or a list of strings (line segments)."
  (cond
   ((stringp source) source)
   ((listp source) (mapconcat #'identity source ""))
   (t "")))

(defun ejn-ipynb-parse-output (json-alist)
  "Parse a JSON output JSON-ALIST into an `ejn-output' struct."
  (let ((output-type (intern (replace-regexp-in-string "_" "-" (cdr (assq :output_type json-alist))))))
    (make-ejn-output
     :type output-type
     :mime-data (cdr (assq :data json-alist))
     :metadata (cdr (assq :metadata json-alist))
     :request-id nil)))

(defun ejn-ipynb-parse-cell (json-alist)
  "Parse a JSON cell JSON-ALIST into an `ejn-cell' struct."
  (let ((cell-type (intern (replace-regexp-in-string "_" "-" (cdr (assq :cell_type json-alist))))))
    (make-ejn-cell
     :id (cdr (assq :id json-alist))
     :type cell-type
     :source (ejn-ipynb-parse-source (cdr (assq :source json-alist)))
     :outputs (mapcar #'ejn-ipynb-parse-output
                      (cdr (assq :outputs json-alist)))
     :metadata (cdr (assq :metadata json-alist))
     :execution-count (cdr (assq :execution_count json-alist))
     :execution-state 'idle
     :execution-version 0)))

(defun ejn-ipynb-parse-notebook (path)
  "Parse an .ipynb file at PATH into an `ejn-notebook' struct.
Signals `ejn-invalid-notebook' for malformed files.
Signals `ejn-unsupported-format' for unsupported nbformat versions."
  (let ((json-data)
        (json-object-type 'alist)
        (json-array-type 'list)
        (json-key-type 'keyword))
    (condition-case err
        (with-temp-buffer
          (insert-file-contents path)
          (goto-char (point-min))
          (setq json-data (json-read-object)))
      (error
       (signal 'ejn-invalid-notebook
               (list (format "Failed to parse %s: %s" path (error-message-string err))))))
    (let ((nbformat (cdr (assq :nbformat json-data)))
          (nbformat-minor (cdr (assq :nbformat_minor json-data))))
      (unless (= nbformat 4)
        (signal 'ejn-unsupported-format
                (list (format "Unsupported nbformat version: %s (only v4 supported)"
                              nbformat))))
      (make-ejn-notebook
       :id (cdr (assq :id json-data))
       :path path
       :metadata (cdr (assq :metadata json-data))
       :cells (cl-loop for cell-json in (cdr (assq :cells json-data))
                       collect (ejn-ipynb-parse-cell cell-json)
                       into cells-list
                       finally return (vconcat cells-list))
       :dirty nil
       :nbformat nbformat
       :nbformat-minor nbformat-minor
       :dirty-set (make-hash-table :test 'equal)
       :undo-history nil))))

(defun ejn-ipynb-serialize-output (output)
  "Serialize an OUTPUT `ejn-output' struct to a JSON-compatible plist."
  (let ((result (list :output_type (symbol-name (ejn-output-type output)))))
    (when (ejn-output-mime-data output)
      (plist-put result :data (ejn-output-mime-data output)))
    (when (ejn-output-metadata output)
      (plist-put result :metadata (ejn-output-metadata output)))
    result))

(defun ejn-ipynb-serialize-cell (cell)
  "Serialize an CELL `ejn-cell' struct to a JSON-compatible plist."
  (list :id (ejn-cell-id cell)
        :cell_type (symbol-name (ejn-cell-type cell))
        :source (ejn-cell-source cell)
        :outputs (vconcat (mapcar #'ejn-ipynb-serialize-output
                                  (ejn-cell-outputs cell)))
        :metadata (or (ejn-cell-metadata cell) nil)
        :execution_count (ejn-cell-execution-count cell)))

(defun ejn-ipynb-serialize-notebook (notebook &optional path)
  "Serialize NOTEBOOK to nbformat v4 JSON.
If PATH is given, write to that file.  Otherwise return the JSON string."
  (let ((data (list :nbformat (ejn-notebook-nbformat notebook)
                    :nbformat_minor (ejn-notebook-nbformat-minor notebook)
                    :metadata (or (ejn-notebook-metadata notebook) nil)
                    :cells (vconcat (mapcar #'ejn-ipynb-serialize-cell
                                            (ejn-notebook-cells notebook))))))
    (when (ejn-notebook-id notebook)
      (plist-put data :id (ejn-notebook-id notebook)))
    (let ((json-string (json-encode data)))
      (if path
          (with-temp-buffer
            (insert json-string)
            (json-pretty-print (point-min) (point-max))
            (write-region (point-min) (point-max) path nil 'nomessage))
        json-string))))

(cl-defmethod ejn-persistence-read ((_backend ejn-ipynb-backend) path)
  "Read an .ipynb notebook from PATH using BACKEND."
  (ejn-ipynb-parse-notebook path))

(cl-defmethod ejn-persistence-write ((_backend ejn-ipynb-backend) notebook path)
  "Write NOTEBOOK to PATH as .ipynb using BACKEND."
  (ejn-ipynb-serialize-notebook notebook path))

(cl-defmethod ejn-persistence-can-handle-p ((_backend ejn-ipynb-backend) path)
  "Return t if BACKEND can handle PATH (ends with .ipynb)."
  (string-suffix-p ".ipynb" path))

(defun ejn-model-from-file (path)
  "Load a notebook from PATH using the appropriate backend.
Signals an error if no backend can handle PATH or loading fails."
  (let ((backend (ejn-persistence-backend-for path)))
    (unless backend
      (error "No persistence backend for: %s" path))
    (ejn-persistence-read backend path)))

(defun ejn-model-to-file (notebook path)
  "Save NOTEBOOK to PATH using the appropriate backend.
Signals an error if no backend can handle PATH or saving fails."
  (let ((backend (ejn-persistence-backend-for path)))
    (unless backend
      (error "No persistence backend for: %s" path))
    (ejn-persistence-write backend notebook path)))

;; Auto-register the .ipynb backend
(ejn-register-persistence-backend 'ipynb #'make-ejn-ipynb-backend
                                  :predicate (lambda (path)
                                               (string-suffix-p ".ipynb" path)))

(provide 'ejn-persistence)
;;; ejn-persistence.el ends here
