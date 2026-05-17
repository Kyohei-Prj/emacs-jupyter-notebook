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
  "Dispatch the next queued request if kernel is connected."
  (let ((kernel (buffer-local-value 'ejn--kernel (current-buffer))))
    (when (and kernel (eq 'connected (ejn-kernel-state kernel)))
      (let ((request (ejn-execute--dequeue)))
        (if request
            (progn
              (ejn-kernel-transition kernel 'busy)
              (let ((cell (ejn-execute--find-cell (plist-get request :cell-id))))
                (when cell
                  (ejn-execute--set-cell-state cell 'executing))
                (ejn-kernel-execute
                 kernel
                 (plist-get request :source)
                 (plist-get request :request-id)
		 (if cell
                     (ejn-execute--make-callbacks cell)
                   nil))))
          (ejn-kernel-transition kernel 'connected)))))
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (when notebook
      (ejn-render-dirty-cells notebook))))

(defun ejn-execute--enqueue-and-maybe-run (cell-id source request-id version)
  "Enqueue an execution request and dispatch if kernel is idle."
  (let ((kernel (buffer-local-value 'ejn--kernel (current-buffer)))
        (cell (ejn-execute--find-cell cell-id)))
    (unless kernel
      (user-error "Kernel not connected"))
    (when cell
      (if (eq 'connected (ejn-kernel-state kernel))
          (progn
            (ejn-kernel-transition kernel 'busy)
            (ejn-execute--set-cell-state cell 'executing)
            (ejn-kernel-execute
             kernel source request-id
             (ejn-execute--make-callbacks cell)))
        (ejn-execute--set-cell-state cell 'queued)
        (ejn-execute--enqueue (list :cell-id cell-id
                                    :source source
                                    :request-id request-id
                                    :execution-version version))))))

(defun ejn-execute--make-callbacks (cell)
  "Build a callbacks plist for CELL's execution."
  (let ((cell-id (ejn-cell-id cell)))
    (list
     :on-stream
     (lambda (_cid text name)
       (let ((current-cell (or (ejn-execute--find-cell cell-id) cell)))
         (when current-cell
           (ejn-execute--set-cell-state current-cell 'streaming)
           (push (make-ejn-output
                  :type 'stream
                  :mime-data (list :name name :text text)
                  :metadata nil
                  :request-id nil)
                 (ejn-cell-outputs current-cell)))))
     :on-result
     (lambda (_cid mime-data)
       (let ((current-cell (or (ejn-execute--find-cell cell-id) cell)))
         (when current-cell
           (ejn-execute--set-cell-state current-cell 'streaming)
           (push (make-ejn-output
                  :type 'execute-result
                  :mime-data (list :data mime-data)
                  :metadata nil
                  :request-id nil)
                 (ejn-cell-outputs current-cell)))))
     :on-display
     (lambda (_cid mime-data)
       (let ((current-cell (or (ejn-execute--find-cell cell-id) cell)))
         (when current-cell
           (ejn-execute--set-cell-state current-cell 'streaming)
           (push (make-ejn-output
                  :type 'display-data
                  :mime-data (list :data mime-data)
                  :metadata nil
                  :request-id nil)
                 (ejn-cell-outputs current-cell)))))
     :on-error
     (lambda (_cid ename evalue traceback)
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
                 (ejn-cell-outputs current-cell)))))
     :on-complete
     (lambda (_cid status)
       (let ((current-cell (or (ejn-execute--find-cell cell-id) cell)))
         (when current-cell
           (ejn-execute--set-cell-state current-cell
                                        (if (string= status "ok") 'completed 'error))
           (setf (ejn-cell-execution-count current-cell)
                 (1+ (or (ejn-cell-execution-count current-cell) 0)))))
       (ejn-execute--dispatch-next)))))

(defun ejn-execute--validate-cell (cell)
  "Signal an error if CELL cannot be executed."
  (unless (eq (ejn-cell-type cell) 'code)
    (user-error "Cannot execute %s cells" (ejn-cell-type cell))))

(defun ejn-execute-cell ()
  "Execute the current cell."
  (interactive)
  (let ((cell (ejn-cell-at-point)))
    (ejn-execute--validate-cell cell)
    (let ((cell-id (ejn-cell-id cell))
          (source (buffer-substring-no-properties
                   (car (ejn-cell-region)) (cdr (ejn-cell-region)))))
      (setf (ejn-cell-execution-version cell) (1+ (ejn-cell-execution-version cell)))
      (ejn-execute--enqueue-and-maybe-run
       cell-id source (ejn-generate-uuid) (ejn-cell-execution-version cell)))))

(defun ejn-execute-cell-and-goto-next ()
  "Execute the current cell and move to the next cell."
  (interactive)
  (ejn-execute-cell)
  (condition-case nil
      (ejn-goto-next-cell)
    (error nil)))

(defun ejn-execute-cell-and-insert-below ()
  "Execute the current cell and insert a new cell below."
  (interactive)
  (ejn-execute-cell)
  (require 'ejn-cell-engine)
  (ejn-insert-cell-below))

(defun ejn-execute-all-above ()
  "Execute all cells above the current cell."
  (interactive)
  (let ((current-id (ejn-cell-id (ejn-cell-at-point)))
        (notebook ejn--notebook))
    (cl-loop for cell across (ejn-notebook-cells notebook)
             until (string= (ejn-cell-id cell) current-id)
             when (eq (ejn-cell-type cell) 'code)
             do (let ((cell-id (ejn-cell-id cell))
                      (source (ejn-cell-source cell)))
                  (setf (ejn-cell-execution-version cell)
                        (1+ (ejn-cell-execution-version cell)))
                  (ejn-execute--enqueue-and-maybe-run
                   cell-id source (ejn-generate-uuid)
                   (ejn-cell-execution-version cell))))))

(defun ejn-execute-all-below ()
  "Execute all cells below the current cell."
  (interactive)
  (let ((current-id (ejn-cell-id (ejn-cell-at-point)))
        (notebook ejn--notebook)
        (started nil))
    (cl-loop for cell across (ejn-notebook-cells notebook)
             do (progn
                  (when (string= (ejn-cell-id cell) current-id)
                    (setq started t))
                  (when (and started (eq (ejn-cell-type cell) 'code))
                    (let ((cell-id (ejn-cell-id cell))
                          (source (ejn-cell-source cell)))
                      (setf (ejn-cell-execution-version cell)
                            (1+ (ejn-cell-execution-version cell)))
                      (ejn-execute--enqueue-and-maybe-run
                       cell-id source (ejn-generate-uuid)
                       (ejn-cell-execution-version cell))))))))

(provide 'ejn-execute)
;;; ejn-execute.el ends here
