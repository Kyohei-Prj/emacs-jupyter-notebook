;;; ejn-core.el --- EJN core utilities and configuration  -*- lexical-binding:t -*-

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

;; Prefix: ejn-
;; URL: https://github.com/emacs-jupyter-notebook/emacs-jupyter-notebook

;;; Commentary:

;; Core constants, custom group, and internal utilities for EJN.

;;; Code:

(require 'cl-lib)  ; no-check-included
(require 'dash)
(require 's)
(require 'f)

(defconst ejn-version "0.1.0"
  "Current version of emacs-jupyter-notebook.")

(defconst ejn-source-directory
  (file-name-directory (or load-file-name "."))
  "Directory containing EJN Elisp source files.")

(defgroup ejn nil
  "Emacs Jupyter Notebook integration."
  :group 'applications
  :prefix "ejn-")

(provide 'ejn-core)
;;; ejn-core.el ends here
