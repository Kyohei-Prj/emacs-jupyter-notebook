;;; ejn-test-util.el --- Test fixtures and utilities  -*- lexical-binding: t; -*-

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

;; Test fixture loading utilities and ERT helpers for EJN tests.

;;; Code:

(require 'json)
(require 'f)

(defconst ejn-test-fixtures-directory
  (f-join (f-parent (f-parent load-file-name)) "test" "fixtures")
  "Directory containing test fixture files.")

(defun ejn-test-load-fixture (filename)
  "Load a JSON fixture FILENAME from the fixtures directory.
Returns the parsed JSON data structure."
  (let ((path (f-join ejn-test-fixtures-directory filename)))
    (unless (f-file? path)
      (error "Fixture not found: %s" path))
    (with-temp-buffer
      (insert-file-contents path)
      (json-read-object))))

(defmacro ejn-test-with-temp-buffer (name &rest body)
  "Execute BODY in a temporary buffer named NAME.
The buffer is killed after BODY completes."
  (declare (indent 1))
  `(let ((buf (generate-new-buffer ,name)))
     (unwind-protect
         (progn
           (with-current-buffer buf
             ,@body))
       (kill-buffer buf))))

(defmacro ejn-test-with-notebook-buffer (notebook &rest body)
  "Execute BODY in a temporary buffer with NOTEBOOK rendered in ejn-mode.
The buffer is killed after BODY completes."
  (declare (indent 1))
  `(let ((buf (generate-new-buffer " *ejn-test*")))
     (unwind-protect
         (with-current-buffer buf
           (ejn-mode)
           (set (make-local-variable 'ejn--notebook) ,notebook)
           (ejn-render-notebook ,notebook)
           ,@body)
       (kill-buffer buf))))

(defmacro ejn-test-wait-for-sync ()
  "Force an immediate sync for testing.
Cancels any pending timer and runs sync now."
  (declare (indent 0))
  `(progn
     (when (and (boundp 'ejn--sync-timer) ejn--sync-timer)
       (cancel-timer ejn--sync-timer)
       (setq ejn--sync-timer nil))
     (when (fboundp 'ejn--perform-sync)
       (funcall (symbol-function 'ejn--perform-sync)))))

(provide 'ejn-test-util)
;;; ejn-test-util.el ends here
