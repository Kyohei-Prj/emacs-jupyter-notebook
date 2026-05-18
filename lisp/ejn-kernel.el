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
(require 'ejn-core)

(define-error 'ejn-kernel-error "Kernel operation error")
(define-error 'ejn-kernel-start-error "Failed to start kernel" 'ejn-kernel-error)
(define-error 'ejn-kernel-reconnect-error "Failed to reconnect kernel" 'ejn-kernel-error)

(cl-defstruct ejn-kernel
  id
  state
  client
  kernelspec
  request-registry)

(defun ejn-make-kernel (kernelspec)
  "Create a new kernel instance for KERNELSPEC name.
Returns an `ejn-kernel' struct in `startup' state."
  (make-ejn-kernel
   :id (ejn-generate-uuid)
   :state 'startup
   :client nil
   :kernelspec kernelspec
   :request-registry (make-hash-table :test 'equal)))

(defun ejn-kernel-transition (kernel new-state)
  "Transition KERNEL to NEW-STATE."
  (setf (ejn-kernel-state kernel) new-state))

(defcustom ejn-kernel-heartbeat-interval 30
  "Seconds between kernel heartbeat checks."
  :type 'number
  :group 'ejn)

(defvar ejn--kernel-heartbeat-timer nil
  "Global timer for kernel heartbeat checks.")

(defvar ejn-kernel-dead-hook nil
  "Hook run when the kernel is detected as dead.")

(defun ejn-kernel-start-heartbeat (kernel)
  "Start periodic heartbeat check for KERNEL."
  (ejn-kernel-stop-heartbeat)
  (setq ejn--kernel-heartbeat-timer
        (run-with-timer ejn-kernel-heartbeat-interval
                        ejn-kernel-heartbeat-interval
                        #'ejn-kernel--heartbeat-tick kernel)))

(defun ejn-kernel-stop-heartbeat ()
  "Stop the kernel heartbeat timer."
  (when ejn--kernel-heartbeat-timer
    (cancel-timer ejn--kernel-heartbeat-timer)
    (setq ejn--kernel-heartbeat-timer nil)))

(defun ejn-kernel--heartbeat-tick (kernel)
  "Check KERNEL health.  Transition to dead if unresponsive."
  (when kernel
    (when (eq 'connected (ejn-kernel-state kernel))
      (unless (ejn-kernel-alive-p kernel)
        (ejn-kernel-transition kernel 'dead)
        (run-hooks 'ejn-kernel-dead-hook)))))

(cl-defgeneric ejn-kernel-start (kernel kernelspec)
  "Start a new KERNEL with KERNELSPEC.")

(cl-defgeneric ejn-kernel-execute (kernel code request-id callbacks)
  "Execute CODE on KERNEL with REQUEST-ID and CALLBACKS plist.
CALLBACKS contains :on-stream, :on-result, :on-display, :on-error, :on-complete.")

(cl-defgeneric ejn--kernel-interrupt (kernel)
  "Interrupt the running computation on KERNEL.")

(cl-defgeneric ejn--kernel-restart (kernel)
  "Restart KERNEL.")

(cl-defgeneric ejn--kernel-shutdown (kernel)
  "Shutdown KERNEL.")

(cl-defgeneric ejn-kernel-reconnect (kernel)
  "Reconnect KERNEL using its stored kernelspec.")

(cl-defgeneric ejn-kernel-alive-p (kernel)
  "Return non-nil if KERNEL is responsive.")

(cl-defgeneric ejn-kernel-complete (kernel code position)
  "Request async completion for CODE at POSITION on KERNEL.
Returns a promise resolving to (list matches cursor-start cursor-end).")

(cl-defgeneric ejn-kernel-inspect (kernel code position detail-level)
  "Request async introspection for CODE at POSITION on KERNEL.
DETAIL-LEVEL controls depth of information.
Returns a promise resolving to a plist :status :data :metadata.")

(cl-defgeneric ejn-kernel-status (kernel)
  "Return status of KERNEL: \='idle | \='busy | \='starting | \='dead.")

(cl-defmethod ejn-kernel-alive-p ((_kernel ejn-kernel))
  "Base implementation: return nil.  Override in KERNEL adapter."
  nil)

(cl-defmethod ejn-kernel-status ((kernel ejn-kernel))
  "Base implementation: return the state of KERNEL."
  (ejn-kernel-state kernel))

(defun ejn-kernel-reconnect-command ()
  "Reconnect to the kernel after it has died.
Signals an error if the kernel is not in a dead state."
  (interactive)
  (let ((kernel (buffer-local-value 'ejn--kernel (current-buffer))))
    (unless kernel
      (user-error "No kernel connected"))
    (unless (eq 'dead (ejn-kernel-state kernel))
      (user-error "Kernel is not dead (state: %s).  Use restart instead"
                  (ejn-kernel-state kernel)))
    (condition-case err
        (progn
          (ejn-kernel-reconnect kernel)
          (message "Kernel reconnected"))
      (error
       (signal (car err) (cdr err))))))

(provide 'ejn-kernel)
;;; ejn-kernel.el ends here
