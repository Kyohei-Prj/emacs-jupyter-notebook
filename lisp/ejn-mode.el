;;; ejn-mode.el --- Major mode for Jupyter notebooks  -*- lexical-binding: t; -*-

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

;; Major mode for editing Jupyter notebook files.
;; Derives from text-mode, provides cell-aware editing.

;;; Code:

(require 'cl-lib)
(require 'ejn-core)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-navigation)
(require 'ejn-cell-engine)
(require 'ejn-sync)
(require 'ejn-undo)
(require 'ejn-persistence)

(defvar-local ejn--notebook nil
  "Current notebook model for this buffer.")

(defvar ejn-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Keymap for `ejn-mode'.")

(define-derived-mode ejn-mode text-mode "EJN"
  "Major mode for editing Jupyter notebooks.

This mode provides cell-aware editing for Jupyter notebook files.
Cells are identified by text properties and can be navigated,
inserted, deleted, split, merged, and moved.

\\{ejn-mode-map}"
  :group 'ejn
  (set (make-local-variable 'ejn--notebook) nil)
  (set (make-local-variable 'ejn--sync-timer) nil)
  (set (make-local-variable 'ejn--rendering-p) nil)
  (set (make-local-variable 'ejn--pending-sync-set) nil)
  (set (make-local-variable 'ejn--cell-kill-ring) nil)
  (add-to-invisibility-spec '(ejn-folded-output))
  (ejn-sync-mode))

(provide 'ejn-mode)
;;; ejn-mode.el ends here
