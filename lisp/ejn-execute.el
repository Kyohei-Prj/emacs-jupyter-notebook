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

(defun ejn-execute--set-cell-state (cell state)
  "Set CELL's execution-state to STATE and mark dirty."
  (setf (ejn-cell-execution-state cell) state)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (when notebook
      (ejn-notebook-mark-dirty notebook (ejn-cell-id cell))
      (ejn-render-dirty-cells notebook))))

(defun ejn-execute--find-cell (cell-id)
  "Find cell by CELL-ID in the current notebook."
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (when notebook
      (condition-case nil
          (ejn-notebook-cell-by-id notebook cell-id)
        (error nil)))))

(defun ejn-execute--dispatch-next ()
  "Dispatch the next request from the execution queue."
  nil)

(defun ejn-execute--make-callbacks (cell)
  "Build a callbacks plist for CELL's execution."
  (let ((cell-id (ejn-cell-id cell)))
    (list
     :on-stream
     (lambda (cid text name)
       (when (string= cid cell-id)
         (let ((current-cell (or (ejn-execute--find-cell cell-id) cell)))
           (when current-cell
             (ejn-execute--set-cell-state current-cell 'streaming)
             (push (make-ejn-output
                    :type 'stream
                    :mime-data (list :name name :text text)
                    :metadata nil
                    :request-id nil)
                   (ejn-cell-outputs current-cell)))))
       nil)
     :on-result
     (lambda (cid mime-data)
       (when (string= cid cell-id)
         (let ((current-cell (or (ejn-execute--find-cell cell-id) cell)))
           (when current-cell
             (ejn-execute--set-cell-state current-cell 'streaming)
             (push (make-ejn-output
                    :type 'execute-result
                    :mime-data (list :data mime-data)
                    :metadata nil
                    :request-id nil)
                   (ejn-cell-outputs current-cell))))))
     :on-display
     (lambda (cid mime-data)
       (when (string= cid cell-id)
         (let ((current-cell (or (ejn-execute--find-cell cell-id) cell)))
           (when current-cell
             (ejn-execute--set-cell-state current-cell 'streaming)
             (push (make-ejn-output
                    :type 'display-data
                    :mime-data (list :data mime-data)
                    :metadata nil
                    :request-id nil)
                   (ejn-cell-outputs current-cell))))))
     :on-error
     (lambda (cid ename evalue traceback)
       (when (string= cid cell-id)
         (let ((current-cell (or (ejn-execute--find-cell cell-id) cell)))
           (when current-cell
             (ejn-execute--set-cell-state current-cell 'error)
             (push (make-ejn-output
                    :type 'error
                    :mime-data (list :ename ename
                                     :evalue evalue
                                     :traceback traceback)
                    :metadata nil
                    :request-id nil)
                   (ejn-cell-outputs current-cell))))))
     :on-complete
     (lambda (cid status)
       (when (string= cid cell-id)
         (let ((current-cell (or (ejn-execute--find-cell cell-id) cell)))
           (when current-cell
             (ejn-execute--set-cell-state current-cell
                                          (if (string= status "ok") 'completed 'error))
             (setf (ejn-cell-execution-count current-cell)
                   (1+ (or (ejn-cell-execution-count current-cell) 0))))))
       (ejn-execute--dispatch-next)))))

(provide 'ejn-execute)
;;; ejn-execute.el ends here
