;;; ejn-network.el --- Network utilities for EJN  -*- lexical-binding: t -*-

;; Copyright (C) 2025  EJN Contributors

;; Author: EJN Contributors
;; Version: 0.1.0
;; Keywords: jupyter, notebook, tools, convenience

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Network utilities for Emacs Jupyter Notebook - scaffolding only.

;; URL: https://github.com/emacs-jupyter-notebook/emacs-jupyter-notebook
;; Package-Requires: ((emacs "30.1"))

;;; Code:

(require 'cl-lib)
(require 'eieio)
(require 'base64)
(require 'ansi-color)

;; jupyter dependency declaration
;; autoload avoids cl-check-type expansion errors in Emacs 30
(autoload #'jupyter "jupyter" "Jupyter support" t)

;; Forward declaration for function defined in ejn-ui.el
(declare-function ejn-cell-refresh-header 'ejn-ui (cell))



(define-minor-mode ejn-kernel-manager-mode
  "Minor mode for managing Jupyter kernel in EJN master view.

This buffer-local minor mode is activated in the master view buffer
when a kernel is started.  It manages the mode-line display of kernel
status.

With a prefix argument ARG, enable the mode if ARG is positive,
disable it if ARG is zero or negative, and toggle the mode if ARG
is nil or not provided.  In Lisp code, the mode is enabled if
the optional argument is omitted or nil."
  :lighter #'ejn--kernel-status-lighter-dynamic)

(defun ejn--kernel-status-lighter-dynamic ()
  "Dynamic lighter function for `ejn-kernel-manager-mode'.

Returns the mode-line string for the current kernel status by reading
the notebook from the buffer-local `ejn--notebook' variable.  Returns
nil if no notebook is set."
  (when-let ((notebook (bound-and-true-p ejn--notebook)))
    (ejn--kernel-status-lighter notebook)))

(defun ejn--update-mode-line (notebook)
  "Update the mode-line in NOTEBOOK's master buffer with current kernel state.

Forces the mode-line to recompute, which will cause the lighter function
to read the current kernel execution state and display it.

Called by the iopub handler when kernel status changes."
  (when-let ((master-buf (slot-value notebook 'master-buffer)))
    (with-current-buffer master-buf
      (force-mode-line-update))))

(defun ejn-kernel-start (notebook &optional kernel-name)
  "Start a Jupyter kernel for NOTEBOOK and return the client.

Creates a `jupyter-kernel-client' from the kernelspec specified by
KERNEL-NAME (or the default kernelspec if KERNEL-NAME is nil).  Stores
the client in the notebook's `:kernel-id' slot.  Activates
`ejn-kernel-manager-mode' in the notebook's master buffer.

Returns the `jupyter-kernel-client' instance."
  (let* ((kernelspecs (jupyter-available-kernelspecs))
         (spec (if kernel-name
                   (cl-find-if (lambda (ks)
                                 (string= (jupyter-kernelspec-name ks)
                                          kernel-name))
                               kernelspecs)
                 (car kernelspecs)))
         (kernel (jupyter-kernel :spec spec))
         (client (jupyter-client kernel)))
    (oset notebook kernel-id client)
    (when-let* ((master-buf (slot-value notebook 'master-buffer)))
      (with-current-buffer master-buf
        (ejn-kernel-manager-mode 1)))
    client))

(defun ejn-kernel-stop (notebook)
  "Stop the Jupyter kernel for NOTEBOOK and return nil.

Calls `jupyter-shutdown-kernel' on the client stored in the notebook's
`:kernel-id' slot, then clears that slot."  (let ((client (slot-value notebook 'kernel-id)))
					      (when client
						(jupyter-shutdown-kernel client))
					      (oset notebook kernel-id nil)
					      nil))

(defun ejn-kernel-client (notebook)
  "Return the `jupyter-kernel-client' stored in NOTEBOOK's `:kernel-id' slot.

Signals a `user-error' if the slot is nil, meaning no kernel has been
started for this notebook."
  (let ((client (slot-value notebook 'kernel-id)))
    (or client
        (user-error "No kernel started for this notebook"))))

(defun ejn-kernel-execution-state (notebook)
  "Return kernel execution state string for NOTEBOOK.

Returns one of: `\"idle\"`, `\"busy\"`, `\"starting\"`, or `\"dead\"`.
If no kernel client is stored in the notebook's `:kernel-id` slot,
returns `\"dead\"`.  Otherwise, returns the client's `execution-state`
slot value."
  (let ((client (slot-value notebook 'kernel-id)))
    (if client
        (slot-value client 'execution-state)
      "dead")))

(defun ejn-kernel-alive-p (notebook)
  "Return non-nil if kernel client exists and kernel is alive.

Returns nil if the notebook has no kernel client or if the kernel
is not alive according to `jupyter-kernel-alive-p'."
  (when-let* ((client (slot-value notebook 'kernel-id)))
    (jupyter-kernel-alive-p client)))

(defun ejn-kernel-interrupt (notebook)
  "Interrupt the Jupyter kernel for NOTEBOOK and return nil.

Calls `jupyter-interrupt-kernel' on the client stored in the notebook's
`:kernel-id' slot.  Handles both message-mode and signal-mode kernels.
Signals a `user-error' if no kernel is attached."
  (let ((client (slot-value notebook 'kernel-id)))
    (or client
        (user-error "No kernel started for this notebook"))
    (jupyter-interrupt-kernel client)
    nil))

(defun ejn-kernel-restart (notebook)
  "Restart the Jupyter kernel for NOTEBOOK and return nil.

Calls `jupyter-restart-kernel' on the client stored in the notebook's
`:kernel-id' slot.  Signals a `user-error' if no kernel is attached."
  (let ((client (slot-value notebook 'kernel-id)))
    (or client
        (user-error "No kernel started for this notebook"))
    (jupyter-restart-kernel client)
    nil))

(defun ejn-kernel-reconnect (notebook)
  "Reconnect the Jupyter kernel for NOTEBOOK and return the client.

Disconnects the client stored in the notebook's `:kernel-id' slot,
then reconnects it to the same kernel.  Signals a `user-error' if
no kernel is attached.  Returns the `jupyter-kernel-client' instance."
  (let ((client (slot-value notebook 'kernel-id)))
    (or client
        (user-error "No kernel started for this notebook"))
    (jupyter-disconnect client)
    (jupyter-connect client)
    client))

(defun ejn--kernel-status-lighter (notebook)
  "Return mode-line string for NOTEBOOK showing kernel status.

Returns a string like \(EJN [LANG | \u25CFState]\) where LANG is the
kernel language name and State is the execution state.  Returns nil if
no kernel is started for NOTEBOOK."
  (when-let ((client (slot-value notebook 'kernel-id)))
    (let ((lang (jupyter-kernel-language client))
          (state (ejn-kernel-execution-state notebook)))
      (format " EJN [%s | \u25CF%s]" lang state))))

(defun ejn--cell-notebook (cell)
  "Return the notebook object for CELL.

Reads the buffer-local `ejn--notebook' variable from the cell's buffer."  (let ((buf (slot-value cell 'buffer)))
									    (when (buffer-live-p buf)
									      (buffer-local-value 'ejn--notebook buf))))

(defun ejn--iopub-handler (cell msg &optional notebook)
  "Dispatch IOPUB message MSG for CELL by message type.

Updates the mode-line on status messages.  Calls `ejn-cell-refresh-header'
on status:idle messages to update the cell header.  Calls `ejn--render-output'
for stream, execute_result, display_data, and error messages.
NOTEBOOK is the notebook containing CELL (used for mode-line update).
If NOTEBOOK is nil, it is looked up from the cell's buffer."  (when-let* ((msg-type (plist-get msg 'msg_type))
									  (nb (or notebook
										  (ejn--cell-notebook cell))))
								(pcase msg-type
								  ("status"
								   (ejn--update-mode-line nb)
								   (when-let* ((content (plist-get msg 'content))
									       (exec-state (plist-get content 'execution_state)))
								     (when (equal exec-state "idle")
								       (ejn-cell-refresh-header cell))))
								  ((or "stream" "execute_result" "display_data" "error")
								   (ejn--render-output cell msg)))))

(defun ejn--wait-idle (req &optional timeout)
  "Wait for REQ to become idle, returning REQ or nil on timeout.

TIMEOUT is the number of seconds to wait.  Returns REQ if the kernel
becomes idle within the timeout, nil if the timeout elapses."  (condition-case err
								   (jupyter-idle req timeout)
								 (jupyter-timeout-before-idle
								  (message "Kernel did not become idle within %d seconds" timeout)
								  nil)))

(defun ejn--execute-cell (cell)
  "Send the source of CELL to the kernel for execution.

Creates an execute request with the cell's source code, sends it
through the kernel client, and registers the iopub callback
`ejn--iopub-handler' to process kernel output messages.

Returns the `jupyter-request' object."  (let* ((code (slot-value cell 'source))
					       (dreq (jupyter-execute-request :code code))
					       (req (jupyter-sent dreq))
					       (notebook (ejn--cell-notebook cell)))
					  (jupyter-message-subscribed
					   req
					   (list (cons "iopub"
						       (lambda (msg)
							 (ejn--iopub-handler cell msg notebook)))))
					  req))

(defun ejn--output-overlay (cell)
  "Return (or create) the output overlay for CELL.

If CELL already has an output overlay stored in its `:output-overlay'
slot, return it.  Otherwise, create a new overlay at point-max of the
cell's buffer with an empty `:after-string', store it in the cell's
`:output-overlay' slot, and return it."
  (let* ((buf (slot-value cell 'buffer))
         (overlay (slot-value cell 'output-overlay)))
    (if (and overlay (overlayp overlay))
        overlay
      (with-current-buffer buf
        (goto-char (point-max))
        (let ((new-overlay (make-overlay (point) (point))))
          (overlay-put new-overlay 'after-string "")
          (oset cell output-overlay new-overlay)
          new-overlay)))))

(defun ejn--render-mime-data (data metadata msg-type)
  "Render MIME DATA into a styled string for overlay after-string.

DATA is a plist of MIME type -> content pairs.
METADATA is a plist of per-MIME metadata.
MSG-TYPE is the message type symbol (e.g. stream, display_data, error, execute_result).

Returns a string suitable for overlay after-string display."
  (if (equal msg-type "error")
      ;; Error messages: render ename + evalue + traceback in red
      (let* ((content (or data '()))
             (ename (plist-get content 'ename))
             (evalue (plist-get content 'evalue))
             (traceback (plist-get content 'traceback)))
        (propertize
         (concat
          (if ename (format "%s: " ename) "")
          (if evalue evalue "")
          (when (and traceback (not (string= (mapconcat #'identity (vconcat traceback) "\n") "")))
            (concat "\n" (mapconcat #'identity (vconcat traceback) "\n"))))
         'face 'error))
    ;; Non-error messages: dispatch by MIME type priority
    (when data
      (let ((preferenced-types '("text/html" "image/png" "image/jpeg"
                                 "image/svg+xml" "text/latex" "text/plain"))
            (rendered nil))
        (catch 'found
          (dolist (mime-type preferenced-types)
            (let ((content (plist-get data (intern (concat ":" mime-type)))))
              (when content
                (setq rendered (ejn--render-mime-type mime-type content metadata))
                (throw 'found rendered)))))
        ;; Fallback: use first available data
        (when (and (null rendered) (consp data))
          (let ((first-mime (car data))
                (first-content (cadr data)))
            (when (symbolp first-mime)
              (let ((mime-str (symbol-name first-mime)))
                (setq rendered (ejn--render-mime-type mime-str first-content metadata))))))
        (or rendered "")))))

(defun ejn--render-mime-type (mime-type content metadata)
  "Render a single MIME type CONTENT string.

MIME-TYPE is a string like \"text/plain\".
METADATA is the per-MIME metadata plist (unused for now).
Returns a styled string for display."
  (declare (indent 1))
  (let ((image-types '(("image/png" . png)
                        ("image/jpeg" . jpeg)
                        ("image/svg+xml" . svg))))
    (cond
     ;; Image types: handled first via explicit list check
     ((cl-assoc mime-type image-types)
      (let ((img-type (cdr (cl-assoc mime-type image-types))))
        (if (display-graphic-p)
            (condition-case nil
                (create-image (base64-decode-string content) img-type t)
              (error (format "[%s]" mime-type)))
          (format "[%s]" mime-type))))
     ;; Non-image MIME types via pcase
     (t
      (pcase mime-type
        ("text/plain"
         (ansi-color-apply content))
        ("text/html"
         (if (display-graphic-p)
             (let ((buf (generate-new-buffer " *ejn-shr-temp*")))
               (unwind-protect
                   (with-current-buffer buf
                     (insert content)
                     (require 'shr nil t)
                     (if (fboundp 'shr-render-region)
                         (progn
                           (shr-render-region (point-min) (point-max))
                           (buffer-string))
                       (buffer-substring-no-properties
                        (point-min) (point-max))))
                 (kill-buffer buf)))
           "[HTML output]"))
        ("text/latex"
         content)
        (_
         ;; Unknown MIME type: render as plain text
         content))))))

(defun ejn--render-output (cell msg)
  "Render output from MSG into CELL's output overlay.

Extracts the `:data' and `:metadata' from MSG's content plist and passes
them to `ejn--render-mime-data' for MIME dispatch.  The rendered result
is set on the output overlay's `after-string' property, leaving the
cell buffer's text unchanged.  If the message has no data or
the cell has no live buffer, does nothing.

Returns nil."
  (let* ((content (plist-get msg 'content))
         (data (plist-get content 'data))
         (metadata (plist-get content 'metadata))
         (msg-type (plist-get msg 'msg_type)))
    (if (and data (slot-value cell 'buffer)
             (buffer-live-p (slot-value cell 'buffer)))
        (let ((overlay (ejn--output-overlay cell))
              (rendered (ejn--render-mime-data data metadata msg-type)))
          (overlay-put overlay 'after-string rendered))
      ;; Handle error messages which may not have :data but have content
      (when (and (equal msg-type "error")
                 (slot-value cell 'buffer)
                 (buffer-live-p (slot-value cell 'buffer)))
        (let ((overlay (ejn--output-overlay cell))
              (rendered (ejn--render-mime-data content metadata msg-type)))
          (overlay-put overlay 'after-string rendered))))
    nil))

(defun ejn--clear-output (cell)
  "Delete the output overlay for CELL. Returns nil.

If CELL has no output overlay (nil in the `:output-overlay' slot),
does nothing.  Otherwise, removes the overlay from the buffer and
sets the slot to nil."
  (let ((overlay (slot-value cell 'output-overlay)))
    (when (overlayp overlay)
      (delete-overlay overlay)
      (oset cell output-overlay nil)))
  nil)

(defun ejn--toggle-output-visibility (cell)
  "Toggle visibility of output overlay for CELL.

If CELL has no output overlay (nil in the `:output-overlay' slot),
does nothing.  Otherwise, toggles the `invisible' text property on
the overlay's `after-string'.  If `output-visible-p' is t, the
property is set (hiding output) and the slot is set to nil.  If
`output-visible-p' is nil, the property is removed (showing output)
and the slot is set to t."
  (when-let ((overlay (slot-value cell 'output-overlay)))
    (let ((after-string (overlay-get overlay 'after-string))
          (visible-p (slot-value cell 'output-visible-p)))
      (if visible-p
          ;; Hide: set invisible property, update slot to nil
          (progn
            (overlay-put overlay 'after-string
                         (propertize after-string 'invisible 'ejn-output))
            (oset cell output-visible-p nil))
        ;; Show: remove invisible property, update slot to t
        (let ((clean-string (copy-sequence after-string)))
          (remove-text-properties 0 (length clean-string)
                                  '(invisible)
                                  clean-string)
          (overlay-put overlay 'after-string clean-string)
          (oset cell output-visible-p t))))))

(defun ejn--execute-all-cells (notebook)
  "Execute all code cells in NOTEBOOK sequentially, waiting for idle between each.

Iterates over NOTEBOOK's `:cells' slot.  For each cell of type `code' that
has a live `:buffer', calls `ejn--execute-cell' and then `ejn--wait-idle'
with a default timeout of 30 seconds.  Non-code cells and cells without
live buffers are skipped.

Returns nil."
  (dolist (cell (slot-value notebook 'cells))
    (when (and (eq (slot-value cell 'type) 'code)
               (slot-value cell 'buffer)
               (buffer-live-p (slot-value cell 'buffer)))
      (let ((req (ejn--execute-cell cell)))
        (ejn--wait-idle req 30))))
  nil)

(defun ejn--set-output-visibility-all (notebook visible-p)
  "Set output visibility to VISIBLE-P for all cells in NOTEBOOK.

VISIBLE-P is t to show output, nil to hide it.  For cells that have
an output overlay, the `invisible' text property on the overlay's
`after-string' is adjusted accordingly.  For cells without overlays,
only the `output-visible-p' slot is updated.

Returns nil."
  (dolist (cell (slot-value notebook 'cells))
    (let ((current-visible-p (slot-value cell 'output-visible-p)))
      (when (not (eq current-visible-p visible-p))
        (if (slot-value cell 'output-overlay)
            ;; Cell has an overlay: toggle to change state
            (ejn--toggle-output-visibility cell)
          ;; Cell has no overlay: just set the slot
          (oset cell output-visible-p visible-p)))))
  nil)

(provide 'ejn-network)

;;; ejn-network.el ends here
