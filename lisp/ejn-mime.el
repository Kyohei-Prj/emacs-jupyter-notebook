;;; ejn-mime.el --- MIME handler registry  -*- lexical-binding: t; -*-

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

;;; Commentary:

;; MIME handler registry for rendering notebook outputs.
;; Handlers map MIME types to rendering functions.

;;; Code:

(eval-when-compile (require 'base64))
(require 'cl-lib)

(defvar ejn-mime-registry
  (make-hash-table :test 'equal)
  "Hash table mapping MIME type strings to handler entries.
Each entry is a plist with :handler (function) and :priority (integer).")

(cl-defun ejn-register-mime-handler (mime-type handler &key (priority 10))
  "Register HANDLER function for MIME-TYPE.
PRIORITY determines precedence when multiple handlers exist for the same type.
Higher priority wins. Default priority is 10."
  (puthash mime-type (list :handler handler :priority priority)
           ejn-mime-registry))

(defun ejn-mime-handler-for (mime-type)
  "Return the handler function for MIME-TYPE, or nil."
  (let ((entry (gethash mime-type ejn-mime-registry)))
    (when entry
      (plist-get entry :handler))))

(defun ejn-render-plain (data)
  "Render plain text DATA as a string.
DATA is a list of string fragments, as per nbformat."
  (mapconcat #'identity data ""))

(ejn-register-mime-handler "text/plain" #'ejn-render-plain :priority 10)

(defun ejn-render-markdown (data)
  "Render markdown DATA as a string.
DATA is a list of string fragments.  If markdown-mode is available,
font-lock properties may be applied in the renderer layer."
  (mapconcat #'identity data ""))

(ejn-register-mime-handler "text/markdown" #'ejn-render-markdown :priority 80)

(defun ejn-render-png (data)
  "Render PNG DATA as an Emacs image object.

DATA is a list containing a single base64-encoded string."
  (let ((encoded (car data)))
    (create-image (base64-decode-string encoded) 'png t)))

(ejn-register-mime-handler "image/png" #'ejn-render-png :priority 100)

(defun ejn-render-svg (data)
  "Render SVG DATA as an Emacs image object.
DATA is a list containing a single SVG markup string."
  (let ((svg-string (car data)))
    (create-image svg-string 'svg t)))

(ejn-register-mime-handler "image/svg+xml" #'ejn-render-svg :priority 100)

(provide 'ejn-mime)
;;; ejn-mime.el ends here
