;;; ejn-util.el --- Shared utility functions for ejn  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file provides shared utility functions used by all ejn modules:
;; a debug flag and logger, a UUID generator, and an assertion helper.
;; It is the only module with zero inter-module dependencies and must
;; be loadable on its own before any other ejn-* module.

;;; Code:

(require 'cl-lib)

(defvar ejn--debug-p
  nil
  "Non-nil to enable debug logging in ejn modules.")

(defun ejn--log (fmt &rest args)
  "Write a formatted log message to the *ejn-log* buffer.
The message is only written when `ejn--debug-p' is non-nil.
FMT and ARGS are passed to `format'."
  (when ejn--debug-p
    (with-current-buffer (get-buffer-create "*ejn-log*")
      (goto-char (point-max))
      (insert (apply #'format fmt args))
      (insert "\n"))))

(defun ejn--uuid ()
  "Return a 36-character hyphenated UUID-like string.
The string uses lowercase hexadecimal characters in 8-4-4-4-12 format."
  (let ((hex "0123456789abcdef")
         (result ""))
     (cl-loop for i from 1 to 32
              do (setq result (concat result (string (aref hex (random (length hex)))))))
     (setq result (format "%s-%s-%s-%s-%s"
                          (substring result 0 8)
                          (substring result 8 12)
                          (substring result 12 16)
                          (substring result 16 20)
                          (substring result 20)))
     result))

(defun ejn--assert (condition message)
  "Signal an error if CONDITION is nil, with the given MESSAGE.
This is a private assertion helper for use inside ejn modules."
  (unless condition
    (error message)))

(provide 'ejn-util)
;;; ejn-util.el ends here
