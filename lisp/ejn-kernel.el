;;; ejn-kernel.el --- Kernel communication adapter  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;; Commentary:

;; This module provides a thin adapter on top of jupyter.el for managing
;; kernel lifecycle (start, stop, restart, interrupt) and executing code
;; cells with async callbacks for output, completion, and error events.

;; Code:

(require 'ejn-util)
;; TODO: implementation

(provide 'ejn-kernel)
;;; ejn-kernel.el ends here
