;;; ejn-shadow.el --- Shadow document for cross-cell LSP  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;; Commentary:

;; This module maintains a shadow (virtual) document that concatenates all
;; same-language cells in notebook order. It handles incremental updates
;; and position translation between shadow and cell buffers for cross-cell
;; LSP features like go-to-definition and cross-cell completions.

;; Code:

(require 'ejn-util)
;; TODO: implementation

(provide 'ejn-shadow)
;;; ejn-shadow.el ends here
