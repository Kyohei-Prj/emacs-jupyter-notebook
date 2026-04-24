;;; ejn-output.el --- Output rendering (text, images, HTML)  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;; Commentary:

;; This module renders cell outputs in the notebook display buffer as they
;; arrive from the kernel. It supports stream output, error tracebacks with
;; ANSI color, images (PNG/JPEG), and HTML, with fallback text display for
;; terminal Emacs where image display is unavailable.

;; Code:

(require 'ejn-util)
;; TODO: implementation

(provide 'ejn-output)
;;; ejn-output.el ends here
