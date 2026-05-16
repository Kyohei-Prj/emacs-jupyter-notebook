;;; ejn-kernel.el --- Kernel abstraction layer  -*- lexical-binding: t; -*-

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
;; along with this program.  If not,  see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Kernel abstraction with CLOS generics.
;; Transport-specific adapters implement the generics.

;;; Code:

(require 'cl-lib)
(require 'cl-generic)
(require 'ejn-cell)

(cl-defstruct ejn-kernel
  id
  state
  client
  kernelspec)

(defun ejn-make-kernel (kernelspec)
  "Create a new kernel instance for KERNELSPEC name.
Returns an `ejn-kernel' struct in `startup' state."
  (make-ejn-kernel
   :id (ejn-generate-uuid)
   :state 'startup
   :client nil
   :kernelspec kernelspec))

(defun ejn-kernel-transition (kernel new-state)
  "Transition KERNEL to NEW-STATE."
  (setf (ejn-kernel-state kernel) new-state))

(cl-defgeneric ejn-kernel-start (kernel kernelspec)
  "Start a new kernel with KERNELSPEC.")

(cl-defgeneric ejn-kernel-execute (kernel code request-id callbacks)
  "Execute CODE on KERNEL with REQUEST-ID and CALLBACKS plist.
CALLBACKS contains :on-stream, :on-result, :on-display, :on-error, :on-complete.")

(cl-defgeneric ejn--kernel-interrupt (kernel)
  "Interrupt the running computation on KERNEL.")

(cl-defgeneric ejn--kernel-restart (kernel)
  "Restart KERNEL.")

(cl-defgeneric ejn--kernel-shutdown (kernel)
  "Shutdown KERNEL.")

(cl-defgeneric ejn-kernel-alive-p (kernel)
  "Return non-nil if KERNEL is responsive.")

(provide 'ejn-kernel)
;;; ejn-kernel.el ends here
