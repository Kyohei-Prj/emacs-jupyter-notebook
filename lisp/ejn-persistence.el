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

(defvar ejn-persistence-backend-registry
  (make-hash-table :test 'equal)
  "Hash table mapping backend type symbols to backend configurations.")

(cl-defgeneric ejn-persistence-read (backend path)
  "Read a notebook from PATH using BACKEND."
  nil)

(cl-defgeneric ejn-persistence-write (backend notebook path)
  "Write NOTEBOOK to PATH using BACKEND."
  nil)

(cl-defgeneric ejn-persistence-can-handle-p (backend path)
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

(provide 'ejn-persistence)
;;; ejn-persistence.el ends here
