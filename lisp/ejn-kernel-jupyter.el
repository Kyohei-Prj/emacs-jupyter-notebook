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

(eval-when-compile
  (condition-case nil
      (require 'jupyter)
    (error nil)))

(defvar ejn--request-registry
  (make-hash-table :test 'equal)
  "Hash table mapping request-IDs to callback plists.")

(cl-defmethod ejn-kernel-start ((kernel ejn-kernel) kernelspec)
  "Start a new Jupyter kernel with KERNELSPEC."
  (condition-case err
      (let ((client (jupyter-client kernelspec)))
        (jupyter-connect client)
        (setf (ejn-kernel-client kernel) client)
        (ejn-kernel-transition kernel 'connected))
    (error
     (ejn-kernel-transition kernel 'dead)
     (signal 'ejn-kernel-start-error
             (list (format "Failed to start kernel: %s"
                           (error-message-string err)))))))

(cl-defmethod ejn-kernel-alive-p ((kernel ejn-kernel))
  "Return non-nil if kernel is not in dead state."
  (not (memq (ejn-kernel-state kernel) '(dead startup))))

(cl-defmethod ejn-kernel-execute ((kernel ejn-kernel) code request-id callbacks)
  "Execute CODE on the Jupyter kernel."
  (let ((client (ejn-kernel-client kernel)))
    (unless client
      (error "Kernel not connected"))
    (puthash request-id callbacks ejn--request-registry)
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
             (ejn--handle-iopub request-id req msg))))))

(defun ejn--handle-iopub (request-id _req msg)
  "Handle an ioPub message for REQUEST-ID."
  (let ((callbacks (gethash request-id ejn--request-registry)))
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
                 (funcall handler "" "ok"))
               (remhash request-id ejn--request-registry)))))))))

(provide 'ejn-kernel-jupyter)
;;; ejn-kernel-jupyter.el ends here
