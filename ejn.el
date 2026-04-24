;;; ejn.el --- Emacs Jupyter Notebook integration -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; Copyright © 2026 Kyohei-Prj
;;
;; Keywords: jupyter, notebook, lsp, tools
;; URL: https://github.com/kyohei-prj/emacs-jupyter-notebook
;; Version: 0.0.1
;; Package-Requires: ((emacs "29.1") (jupyter) (lsp-mode "0.0") (dash "2.0") (s "1.10.0"))
;;
;;; Commentary:
;;
;; This package provides a major mode for editing Jupyter notebooks
;; in Emacs.  It manages cells as indirect buffers, integrates with
;; Jupyter kernels via `jupyter.el`, and offers LSP support through
;; `lsp-mode`.  Each notebook cell is backed by an invisible indirect
;; buffer for LSP compatibility, with a shadow buffer for cross-cell
;; language features.
;;
;;; Code:

(require 'ejn-util)
(require 'ejn-data)
(require 'ejn-io)
(require 'ejn-kernel)
(require 'ejn-buffer)
(require 'ejn-shadow)
(require 'ejn-lsp)
(require 'ejn-display)
(require 'ejn-output)
(require 'ejn-treesit)

(provide 'ejn)
;;; ejn.el ends here
