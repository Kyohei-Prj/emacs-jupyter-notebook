;;; ejn-cell.el --- Data structures for notebook cells and outputs  -*- lexical-binding: t; -*-

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

(eval-when-compile (require 'subr-x))

(defconst ejn-valid-output-types
  '(stream display-data execute-result error)
  "List of valid output type keywords.")

(cl-defstruct ejn-output
  type
  mime-data
  metadata
  request-id)

(defun ejn-make-output (type &rest args)
  "Create an output struct of TYPE with optional ARGS.
TYPE must be one of `ejn-valid-output-types'."
  (unless (memq type ejn-valid-output-types)
    (error "Invalid output type: %s. Must be one of %s"
           type ejn-valid-output-types))
  (apply #'make-ejn-output :type type args))

(provide 'ejn-cell)
;;; ejn-cell.el ends here
