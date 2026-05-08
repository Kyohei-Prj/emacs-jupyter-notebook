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

;; jupyter dependency declaration
;; autoload avoids cl-check-type expansion errors in Emacs 30
(autoload #'jupyter "jupyter" "Jupyter support" t)

;; Forward declaration for function defined in ejn-ui.el
(declare-function ejn-cell-refresh-header 'ejn-ui (cell))

;; Forward declaration for internal helper
(declare-function ejn--execute-cell--with-client
                  'ejn-network (cell code buf notebook))

;; FIX (Major #3): Changed from `defconst' to `defvar'.
;;
;; The original `defconst' declaration emits a `setting-constant' warning
;; whenever `ejn-kernel-start' pushes onto this alist, and mutating a
;; constant is considered undefined behaviour in future Emacs builds.
;; `defvar' is the correct form for a mutable alist that is written at
;; runtime.
(defvar ejn--client-to-notebook nil
  "Alist mapping jupyter kernel clients to `ejn-notebook' objects.

Each element is a cons cell (CLIENT . NOTEBOOK).  Used by
`ejn--iopub-handler' to find the notebook that owns the client
receiving the iopub message.")


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
Registers `ejn--iopub-handler' on the client's
`jupyter-iopub-message-hook' and stores the client-to-notebook
mapping in `ejn--client-to-notebook'.

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
    (push (cons client notebook) ejn--client-to-notebook)
    (jupyter-add-hook client 'jupyter-iopub-message-hook
                      #'ejn--iopub-handler)
    (when-let* ((master-buf (slot-value notebook 'master-buffer)))
      (with-current-buffer master-buf
        (ejn-kernel-manager-mode 1)))
    client))

(defun ejn-kernel-stop (notebook)
  "Stop the Jupyter kernel for NOTEBOOK and return nil.

Calls `jupyter-shutdown-kernel' on the client stored in the notebook's
`:kernel-id' slot, then clears that slot."
  (let ((client (slot-value notebook 'kernel-id)))
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

Returns one of: `\"idle\"', `\"busy\"', `\"starting\"', or `\"dead\"'.
If no kernel client is stored in the notebook's `:kernel-id' slot,
returns `\"dead\"'.  Otherwise, returns the client's `execution-state'
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

Returns a string like \\(EJN [LANG | ●State]\\) where LANG is the
kernel language name and State is the execution state.  Returns nil if
no kernel is started for NOTEBOOK."
  (when-let ((client (slot-value notebook 'kernel-id)))
    (let ((lang  (jupyter-kernel-language client))
          (state (ejn-kernel-execution-state notebook)))
      (format " EJN [%s | \u25CF%s]" lang state))))

(defun ejn--cell-notebook (cell)
  "Return the notebook object for CELL.

Reads the buffer-local `ejn--notebook' variable from the cell's buffer."
  (let ((buf (slot-value cell 'buffer)))
    (when (buffer-live-p buf)
      (buffer-local-value 'ejn--notebook buf))))

(defun ejn--iopub-handler (client msg)
  "Dispatch IOPUB message MSG received on CLIENT.

Uses `jupyter-message-type' and `jupyter-message-get' accessors
to read message content.  Correlates messages to cells by matching
the parent message ID against each cell buffer's
`ejn--pending-request-id' variable.

For status messages, updates the mode-line and refreshes the cell
header on idle state.  For other message types, calls
`ejn--render-output' to display output."
  (let* ((nb       (cdr (cl-assoc client ejn--client-to-notebook :test #'equal)))
         (msg-type (jupyter-message-type msg))
         (parent-id (jupyter-message-parent-id msg)))
    (pcase msg-type
      ("status"
       (when nb (ejn--update-mode-line nb))
       (when-let ((exec-state (jupyter-message-get msg :execution_state)))
         (when (equal exec-state "idle")
           (when-let ((cell (ejn--find-cell-by-parent-id parent-id nb)))
             (ejn-cell-refresh-header cell)))))
      ((or "stream" "execute_result" "display_data" "error"
           "execute_reply")
       (when-let ((cell (ejn--find-cell-by-parent-id parent-id nb)))
         (ejn--render-output cell msg))))))

(defun ejn--find-cell-by-parent-id (parent-id &optional notebook)
  "Find the cell whose pending request ID matches PARENT-ID.

Searches NOTEBOOK's cells, comparing PARENT-ID against each cell
buffer's `ejn--pending-request-id' variable.  Returns the matching
cell, or nil if no match is found."
  (cl-block nil
    (when notebook
      (let ((cells (slot-value notebook 'cells)))
        (cl-dolist (cell cells)
          (let ((buf (slot-value cell 'buffer)))
            (when (buffer-live-p buf)
              (let ((pending-id (buffer-local-value
                                 'ejn--pending-request-id buf)))
                (when (equal pending-id parent-id)
                  (cl-return cell))))))))))

(defun ejn--wait-idle (req &optional timeout)
  "Wait for REQ to become idle, returning REQ or nil on timeout.

TIMEOUT is the number of seconds to wait.  Returns REQ if the kernel
becomes idle within the timeout, nil if the timeout elapses."
  (condition-case err
      (jupyter-idle req timeout)
    (jupyter-timeout-before-idle
     (message "Kernel did not become idle within %d seconds" timeout)
     nil)))

(defun ejn--execute-cell--with-client (cell code buf notebook)
  "Execute CELL with CODE in NOTEBOOK, storing state in BUF.

This helper is called within `jupyter-with-client' context.
All needed values are passed as arguments to avoid lexical
closure issues with the test mocking of `jupyter-with-client'.

IOPUB messages are handled by `ejn--iopub-handler' registered via
`jupyter-add-hook' in `ejn-kernel-start'.  This function only stores
the request ID for parent-ID correlation.

Returns the `jupyter-request' object."
  (let ((req (jupyter-sent (jupyter-execute-request :code code))))
    ;; Store request-id in cell buffer for parent-ID correlation
    (with-current-buffer buf
      (make-local-variable 'ejn--pending-request-id)
      (setq ejn--pending-request-id
            (jupyter-request-id req)))
    req))

(defun ejn--execute-cell (cell)
  "Send the source of CELL to the kernel for execution.

Synchronizes CELL's buffer content to the `:source' slot via
`ejn-shadow-sync-cell', retrieves the kernel client from the
notebook's `:kernel-id' slot, and sends an execute request using
the `jupyter-with-client' macro.  Stores the request ID in the
cell's buffer-local `ejn--pending-request-id' variable.

Signals a `user-error' if no kernel is attached.

Returns the `jupyter-request' object."
  (ejn-shadow-sync-cell cell)
  (let ((notebook (ejn--cell-notebook cell))
        (code (slot-value cell 'source))
        (buf  (slot-value cell 'buffer)))
    (or notebook
        (user-error "No notebook found for this cell"))
    (let ((client (slot-value notebook 'kernel-id)))
      (or client
          (user-error "No kernel started for this notebook"))
      (jupyter-with-client client
			   (funcall #'ejn--execute-cell--with-client
				    cell code buf notebook)))))

(defun ejn--output-overlay (cell)
  "Return (or create) the output overlay for CELL.

If CELL already has a live output overlay stored in its
`:output-overlay' slot, return it.  Otherwise, create a new overlay
at point-max of the cell's buffer with an empty `:after-string', store
it in the cell's `:output-overlay' slot, and return it.

FIX (Critical #4): The original implementation used `(when ...)' as a
guard, which in Emacs Lisp discards its return value and always falls
through to the creation code.  This caused a new overlay to be stacked
on the buffer on every call, resulting in duplicate output and an
ever-growing set of live overlays.  Replaced with `(if ...)' so exactly
one branch executes: either the existing overlay is returned, or a new
one is created."
  (let* ((buf     (slot-value cell 'buffer))
         (overlay (slot-value cell 'output-overlay)))
    (if (and overlay (overlayp overlay))
        ;; Existing overlay — return it directly.
        overlay
      ;; No valid overlay yet — create one at point-max.
      (with-current-buffer buf
        (goto-char (point-max))
        (let ((new-overlay (make-overlay (point) (point))))
          (overlay-put new-overlay 'after-string "")
          (oset cell output-overlay new-overlay)
          new-overlay)))))

(defun ejn--render-output (cell msg)
  "Render output from MSG into CELL's output overlay.

Dispatches on `jupyter-message-type' to handle stream, execute_result,
display_data, error, and execute_reply messages.  Uses
`jupyter-message-get' accessors to read message content.

For stream messages, extracts `:name' and `:text' and appends text
to the overlay's after-string.

For execute_result and display_data, calls `jupyter-insert' with
`:data' and `:metadata' from the content.

For error messages, displays `:ename' and `:evalue' in the overlay,
and stores the traceback in the notebook's `:last-traceback' slot.

For execute_reply, updates the cell's `:exec-count' slot from
`:execution_count' in the content.

Returns nil."
  (let ((msg-type (jupyter-message-type msg)))
    (pcase msg-type
      ("stream"
       (ejn--render-output--stream cell msg))
      ("execute_result"
       (ejn--render-output--mime cell msg))
      ("display_data"
       (ejn--render-output--mime cell msg))
      ("error"
       (ejn--render-output--error cell msg))
      ("execute_reply"
       (ejn--render-output--execute-reply cell msg))
      (_ nil)))
  nil)

(defun ejn--render-output--stream (cell msg)
  "Render a `stream' message MSG into CELL's output overlay.

Extracts `:name' and `:text' from MSG's content and appends the text
to the overlay's after-string."
  (let* ((name (jupyter-message-get msg :name))
         (text (jupyter-message-get msg :text)))
    (when text
      (let ((display-text (format "%s%s"
                                  (propertize (or name "output")
                                              'face 'font-lock-builtin-face)
                                  text))
            (overlay (ejn--output-overlay cell)))
        (overlay-put overlay 'after-string
                     (concat (overlay-get overlay 'after-string)
                             display-text))))))

(defun ejn--render-output--mime (cell msg)
  "Render a `execute_result' or `display_data' message MSG into CELL.

Calls `jupyter-insert' with `:data' and `:metadata' from MSG's content,
positioned at the output overlay."
  (when-let* ((data     (jupyter-message-get msg :data))
              (metadata (jupyter-message-get msg :metadata))
              (buf      (slot-value cell 'buffer))
              ((buffer-live-p buf)))
    (with-current-buffer buf
      (let ((overlay (ejn--output-overlay cell)))
        (goto-char (overlay-start overlay))
        (jupyter-insert data metadata)))))

(defun ejn--render-output--error (cell msg)
  "Render an `error' message MSG into CELL's output overlay.

Displays `:ename' and `:evalue' in the overlay with error face,
and stores the joined traceback in the notebook's `:last-traceback' slot."
  (let* ((ename        (jupyter-message-get msg :ename))
         (evalue       (jupyter-message-get msg :evalue))
         (traceback    (jupyter-message-get msg :traceback))
         (display-text (format "%s: %s" ename evalue))
         (overlay      (ejn--output-overlay cell)))
    (overlay-put overlay 'after-string
                 (propertize display-text 'face 'error))
    (when-let* ((tb-text (and (listp traceback)
                              (string-join traceback "\n")))
                (buf     (slot-value cell 'buffer))
                ((buffer-live-p buf))
                (notebook (with-current-buffer buf
                            (buffer-local-value 'ejn--notebook buf))))
      (oset notebook last-traceback tb-text))))

(defun ejn--render-output--execute-reply (cell msg)
  "Handle an `execute_reply' message MSG for CELL.

Updates the cell's `:exec-count' slot from `:execution_count' in
MSG's content, and refreshes the cell header."
  (when-let ((exec-count (jupyter-message-get msg :execution_count)))
    (oset cell exec-count exec-count)
    (when (fboundp 'ejn-cell-refresh-header)
      (ejn-cell-refresh-header cell))))

(defun ejn--clear-output (cell)
  "Delete the output overlay for CELL.  Returns nil.

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
          (visible-p    (slot-value cell 'output-visible-p)))
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
