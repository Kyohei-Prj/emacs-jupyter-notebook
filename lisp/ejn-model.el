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
  dirty-cells
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
   :dirty-cells (make-hash-table :test 'equal)
   :undo-history nil))

(provide 'ejn-model)
;;; ejn-model.el ends here
