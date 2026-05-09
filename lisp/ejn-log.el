;;; ejn-log.el --- Structured debug logging for EJN  -*- lexical-binding: t; -*-

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

;; Structured debug logging, execution tracing, and profiling hooks.
;; All logging is gated by `ejn-debug'.

;;; Code:

(defcustom ejn-debug nil
  "When non-nil, enable EJN debug logging to `*ejn-debug*' buffer."
  :type 'boolean
  :group 'ejn)

(defvar ejn-debug-buffer "*ejn-debug*"
  "Buffer used for EJN debug output.")

(defun ejn-log-message (level &rest args)
  "Log a message at LEVEL using formatted ARGS.
LEVEL is a string like \"info\", \"warn\", \"error\", \"debug\".
ARGS are formatted using `format'."
  (when ejn-debug
    (let ((timestamp (format-time-string "%H:%M:%S.%3N"))
          (message (apply #'format args)))
      (with-current-buffer (get-buffer-create ejn-debug-buffer)
        (save-excursion
          (goto-char (point-max))
          (insert (format "[%s] [%s] %s\n" timestamp level message)))))))

(defmacro ejn-log-trace (function-name &rest args)
  "Log a trace message for FUNCTION-NAME with ARGS.
Useful for tracking function entry points and parameters."
  `(when ejn-debug
     (ejn-log-message "trace"
                      "%s(%s)"
                      ',function-name
                      (mapconcat #'prin1-to-string (list ,@args) ", "))))

(defmacro ejn-log-profile (&rest body)
  "Measure and log the execution time of BODY.
Returns the elapsed time in seconds."
  (declare (indent 0))
  `(let ((start (float-time))
         (result ,@body))
     (let ((elapsed (- (float-time) start)))
       (ejn-log-message "profile" "%.4fs — profile" elapsed)
       result)))

(provide 'ejn-log)
;;; ejn-log.el ends here
