;;; ejn-kernel-jupyter.el --- Jupyter kernel adapter  -*- lexical-binding: t; -*-

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

;; Implements ejn-kernel CLOS generics using emacs-jupyter transport.
;; Defines custom message handlers that route kernel messages to EJN model.

;;; Code:

(require 'cl-lib)
(require 'ejn-kernel)
(require 'ejn-log)
(require 'subr-x)

(declare-function jupyter-client "jupyter" (&rest _args))
(declare-function jupyter-connect "jupyter" (&rest _args))
(declare-function jupyter-execute-request "jupyter" (&rest _args))
(declare-function jupyter-message-content "jupyter" (&rest _args))
(declare-function jupyter-message-type "jupyter" (&rest _args))
(declare-function jupyter-interrupt-kernel "jupyter" (&rest _args))
(declare-function jupyter-restart-kernel "jupyter" (&rest _args))
(declare-function jupyter-shutdown-kernel "jupyter" (&rest _args))
(declare-function jupyter-completion-request "jupyter" (&rest _args))
(declare-function jupyter-inspection-request "jupyter" (&rest _args))

(eval-when-compile
  (condition-case nil
      (require 'jupyter)
    (error nil)))

(cl-defmethod ejn-kernel-start ((kernel ejn-kernel) kernelspec)
  "Start a new Jupyter KERNEL with KERNELSPEC."
  (condition-case err
      (let ((client (jupyter-client kernelspec)))
        (jupyter-connect client)
        (setf (ejn-kernel-client kernel) client)
        (ejn-kernel-transition kernel 'connected)
        (ejn-kernel-start-heartbeat kernel))
    (error
     (ejn-kernel-transition kernel 'dead)
     (signal 'ejn-kernel-start-error
             (list (format "Failed to start kernel: %s"
                           (error-message-string err)))))))

(cl-defmethod ejn-kernel-alive-p ((kernel ejn-kernel))
  "Return non-nil if KERNEL is not in dead state and client exists."
  (let ((client (ejn-kernel-client kernel))
        (state (ejn-kernel-state kernel)))
    (and client
         (not (memq state '(dead startup))))))

(cl-defmethod ejn-kernel-execute ((kernel ejn-kernel) code request-id callbacks)
  "Execute CODE on the Jupyter KERNEL with REQUEST-ID and CALLBACKS."
  (let ((client (ejn-kernel-client kernel)))
    (unless client
      (error "Kernel not connected"))
    (puthash request-id callbacks (ejn-kernel-request-registry kernel))
    (jupyter-execute-request
     client
     :code code
     :silent nil
     :store-history t
     :allow-stdin nil
     :stop-on-error nil
     :callbacks
     (list :iopub
           (lambda (_client req msg)
             (ejn--handle-iopub kernel request-id req msg))))))

(defun ejn--handle-iopub (kernel request-id _req msg)
  "Handle an ioPub MSG for KERNEL and REQUEST-ID."
  (let ((callbacks (gethash request-id (ejn-kernel-request-registry kernel))))
    (when callbacks
      (let ((msg-type (jupyter-message-type msg))
            (content (jupyter-message-content msg)))
        (pcase (intern msg-type)
          ('stream
           (let ((handler (plist-get callbacks :on-stream)))
             (when handler
               (funcall handler
                        (or (plist-get content :parent-cell-id) "")
                        (plist-get content :text)
                        (plist-get content :name)))))
          ('execute_result
           (let ((handler (plist-get callbacks :on-result)))
             (when handler
               (funcall handler
                        (or (plist-get content :parent-cell-id) "")
                        (plist-get content :data)))))
          ('display_data
           (let ((handler (plist-get callbacks :on-display)))
             (when handler
               (funcall handler
                        (or (plist-get content :parent-cell-id) "")
                        (plist-get content :data)))))
          ('error
           (let ((handler (plist-get callbacks :on-error)))
             (when handler
               (funcall handler
                        (or (plist-get content :parent-cell-id) "")
                        (plist-get content :ename)
                        (plist-get content :evalue)
                        (plist-get content :traceback)))))
          ('status
           (when (string= (plist-get content :execution_state) "idle")
             (let ((handler (plist-get callbacks :on-complete)))
               (when handler
                 (funcall handler "" "ok")))
             (remhash request-id (ejn-kernel-request-registry kernel)))))))))

(cl-defmethod ejn-kernel-complete ((kernel ejn-kernel) code position)
  "Request completions from the Jupyter KERNEL for CODE at POSITION."
  (let ((client (ejn-kernel-client kernel)))
    (unless client
      (error "Kernel not connected"))
    (let ((promise (make-promise)))
      (condition-case err
          (jupyter-completion-request
           client
           :code code
           :cursor-pos position
           :success (lambda (_client _req msg)
                      (let ((content (jupyter-message-content msg)))
                        (fulfill-promise promise
                                         (list (plist-get content :matches)
                                               (plist-get content :cursor_start)
                                               (plist-get content :cursor_end)))))
           :error (lambda (_client _req _msg)
                    (fulfill-promise promise
                                     (list nil nil nil))))
	(error
	 (fulfill-promise promise
                          (list nil nil nil))
	 (ejn-log-message "warn" "Completion request failed: %s"
                          (error-message-string err))))
      promise)))

(cl-defmethod ejn-kernel-inspect ((kernel ejn-kernel) code position detail-level)
  "Request object inspection from the Jupyter KERNEL for CODE at POSITION.
DETAIL-LEVEL controls depth of information."
  (let ((client (ejn-kernel-client kernel)))
    (unless client
      (error "Kernel not connected"))
    (let ((promise (make-promise)))
      (condition-case err
          (jupyter-inspection-request
           client
           :code code
           :cursor-pos position
           :detail-level (or detail-level 0)
           :success (lambda (_client _req msg)
                      (let ((content (jupyter-message-content msg)))
                        (fulfill-promise promise
                                         (list :status (plist-get content :status)
                                               :data (plist-get content :data)
                                               :metadata (plist-get content :metadata)))))
           :error (lambda (_client _req msg)
                    (let ((content (jupyter-message-content msg)))
                      (fulfill-promise promise
                                       (list :status (plist-get content :status)
                                             :data (plist-get content :data)
                                             :metadata (plist-get content :metadata))))))
        (error
         (fulfill-promise promise
                          (list :status "error" :data nil :metadata nil))
         (ejn-log-message "warn" "Inspect request failed: %s"
                          (error-message-string err))))
      promise)))

(cl-defmethod ejn--kernel-interrupt ((kernel ejn-kernel))
  "Interrupt the running Jupyter KERNEL."
  (let ((client (ejn-kernel-client kernel)))
    (when client
      (condition-case err
          (jupyter-interrupt-kernel client)
        (error
         (ejn-log-message "warn" "Interrupt failed: %s" (error-message-string err))))
      (ejn-kernel-transition kernel 'interrupted))))

(cl-defmethod ejn--kernel-restart ((kernel ejn-kernel))
  "Restart the Jupyter KERNEL."
  (let ((client (ejn-kernel-client kernel)))
    (when client
      (condition-case err
          (jupyter-restart-kernel client)
        (error
         (ejn-log-message "warn" "Restart failed: %s" (error-message-string err))))
      (ejn-kernel-transition kernel 'startup)
      (ejn-kernel-start-heartbeat kernel))))

(cl-defmethod ejn-kernel-reconnect ((kernel ejn-kernel))
  "Reconnect the Jupyter KERNEL using its stored kernelspec."
  (setf (ejn-kernel-request-registry kernel) (make-hash-table :test 'equal))
  (ejn-kernel-stop-heartbeat)
  (let ((kernelspec (ejn-kernel-kernelspec kernel)))
    (unless kernelspec
      (error "No kernelspec stored for reconnect"))
    (condition-case err
        (let ((client (jupyter-client kernelspec)))
          (jupyter-connect client)
          (setf (ejn-kernel-client kernel) client)
          (ejn-kernel-transition kernel 'connected)
          (ejn-kernel-start-heartbeat kernel))
      (error
       (ejn-kernel-transition kernel 'dead)
       (signal 'ejn-kernel-reconnect-error
               (list (format "Failed to reconnect: %s"
                             (error-message-string err))))))))

(cl-defmethod ejn--kernel-shutdown ((kernel ejn-kernel))
  "Shutdown the Jupyter KERNEL."
  (ejn-kernel-stop-heartbeat)
  (let ((client (ejn-kernel-client kernel)))
    (when client
      (condition-case err
          (jupyter-shutdown-kernel client)
        (error
         (ejn-log-message "warn" "Shutdown failed: %s" (error-message-string err))))
      (setf (ejn-kernel-client kernel) nil)
      (ejn-kernel-transition kernel 'dead))))

(provide 'ejn-kernel-jupyter)
;;; ejn-kernel-jupyter.el ends here
