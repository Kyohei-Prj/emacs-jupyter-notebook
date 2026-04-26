;;; ejn-test.el --- Tests for EJN  -*- lexical-binding: t -*-

;; Copyright (C) 2025  EJN Contributors

;; Author: EJN Contributors
;; Version: 0.1.0
;; Keywords: jupyter, notebook, emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Test suite for Emacs Jupyter Notebook - scaffolding only.

;;; Code:

(require 'buttercup)
(require 'ejn)

;; Empty test suite - Phase 1 scaffolding only.

(describe "EJN"
  (it "loads without error"
    (expect 't :to-be-truthy)))

(describe "ejn:file-open"
  (it "is defined as an interactive command alias"
    (expect (fboundp 'ejn:file-open) :to-be-truthy)
    (expect (commandp 'ejn:file-open) :to-be-truthy)))

(describe "ejn-mode"
  (it "is defined as a minor mode with keymap"
    (expect (fboundp 'ejn-mode) :to-be-truthy)
    (expect (boundp 'ejn-mode-map) :to-be-truthy)
    (expect (keymapp ejn-mode-map) :to-be-truthy)
    (expect (lookup-key ejn-mode-map (kbd "C-c C-n"))
            :to-equal #'ejn:worksheet-goto-next-input)
    (expect (lookup-key ejn-mode-map (kbd "C-c C-a"))
            :to-equal #'ejn:worksheet-insert-cell-above)
    (expect (lookup-key ejn-mode-map (kbd "C-c C-k"))
            :to-equal #'ejn:worksheet-kill-cell)
    (expect (lookup-key ejn-mode-map (kbd "C-c C-w"))
            :to-equal #'ejn:worksheet-cut-cell)
    (expect (lookup-key ejn-mode-map (kbd "C-c M-w"))
            :to-equal #'ejn:worksheet-copy-cell)))

(describe "P2-T32 cut-cell (C-c C-w)"
  (it "defines ejn:worksheet-cut-cell as an interactive command"
    (expect (fboundp 'ejn:worksheet-cut-cell) :to-be-truthy)
    (expect (commandp 'ejn:worksheet-cut-cell) :to-be-truthy)))

(describe "P2-T29 stub commands"
  (it "defines ignore-based stubs as aliases to ignore"
    (expect (fboundp 'ejn:pytools-not-move-cell-down-km) :to-be-truthy)
    (expect (fboundp 'ejn:pytools-not-move-cell-up-km) :to-be-truthy)
    (expect (symbol-function 'ejn:pytools-not-move-cell-down-km)
            :to-equal #'ignore)
    (expect (symbol-function 'ejn:pytools-not-move-cell-up-km)
            :to-equal #'ignore))

  (it "defines Phase 4 stubs as interactive commands"
    (let ((stubs
           '(ejn:notebook-open
             ejn:worksheet-execute-cell-and-insert-below
             ejn:worksheet-execute-cell-and-goto-next
             ejn:notebook-reconnect-session
             ejn:notebook-kill-kernel-then-close
             ejn:worksheet-execute-cell
             ejn:worksheet-toggle-output
             ejn:worksheet-clear-output
             ejn:worksheet-clear-all-output
             ejn:worksheet-toggle-cell-type
             ejn:worksheet-change-cell-type
             ejn:worksheet-set-output-visibility-all
             ejn:notebook-kernel-interrupt
             ejn:notebook-close
             ejn:tb-show
             ejn:notebook-scratchsheet-open
             ejn:shared-output-show-code-cell-at-point
             ejn:notebook-restart-session)))
      (dolist (cmd stubs)
        (expect (fboundp cmd) :to-be-truthy)
        (expect (commandp cmd) :to-be-truthy))))

  (it "signals user-error when Phase 4 stubs are called"
    (should-error (ejn:notebook-open) :type 'user-error)
    (should-error (ejn:worksheet-execute-cell-and-insert-below)
                  :type 'user-error)))

;;; ejn-test.el ends here
