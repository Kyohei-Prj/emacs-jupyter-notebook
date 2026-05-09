;;; ejn.el --- Emacs Jupyter Notebook -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Kyohei

;; Author: Kyohei
;; Keywords: convenience, tools, languages
;; Version: 0.1.0
;; Package-Requires: ((emacs "29") (dash "2.19.1") (s "1.12.0") (f "0.20.0"))
;; Homepage: https://github.com/kyohei/emacs-jupyter-notebook
;; License: GPL-3.0-or-later

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

;; Emacs Jupyter Notebook (EJN) — a modular, Emacs-native notebook
;; environment for Jupyter kernels.

;;; Code:

(require 'ejn-core)
(require 'ejn-log)

(provide 'ejn)
;;; ejn.el ends here
