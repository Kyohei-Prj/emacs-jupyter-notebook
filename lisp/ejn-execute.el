;;; ejn-execute.el --- Cell execution pipeline  -*- lexical-binding: t; -*-

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
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Execution pipeline: FIFO queue, cell state machine, output routing.
;; User-facing commands for cell execution.

;;; Code:

(require 'cl-lib)
(require 'ejn-kernel)
(require 'ejn-kernel-jupyter)
(require 'ejn-model)
(require 'ejn-cell)
(require 'ejn-render)
(require 'ejn-navigation)

(defvar-local ejn--kernel nil
  "Current kernel instance for this buffer.")

(defvar-local ejn--execution-queue nil
  "FIFO queue of pending execution requests.")

(defun ejn-execute--enqueue (request)
  "Add REQUEST to the end of the execution queue."
  (setq ejn--execution-queue
        (append ejn--execution-queue (list request))))

(defun ejn-execute--dequeue ()
  "Remove and return the first request from the execution queue."
  (if ejn--execution-queue
      (prog1 (car ejn--execution-queue)
        (setq ejn--execution-queue (cdr ejn--execution-queue)))
    nil))

(provide 'ejn-execute)
;;; ejn-execute.el ends here
