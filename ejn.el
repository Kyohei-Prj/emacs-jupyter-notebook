;;; ejn.el --- Emacs Jupyter Notebook  -*- lexical-binding: t -*-

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

;; Emacs Jupyter Notebook - scaffolding only.

;; URL: https://github.com/emacs-jupyter-notebook/emacs-jupyter-notebook
;; Package-Requires: ((emacs "30.1"))

;;; Code:

(require 'cl-lib)

(declare-function ejn:pytools-jump-back 'ejn-lsp ())

(require 'ejn-core)
(require 'ejn-cell)
(require 'ejn-master)
(require 'ejn-notebook)
(require 'ejn-network)
(require 'ejn-lsp)

;; ---------------------------------------------------------------------------
;; Stub commands — P2-T29
;; ---------------------------------------------------------------------------

(defun ejn--stub-error ()
  "Signal a user-error for unimplemented stub commands."
  (user-error "Not yet implemented"))

;; M-<down> / M-<up> — bound to `ignore` (pytools compatibility stubs)
(defalias 'ejn:pytools-not-move-cell-down-km #'ignore)
(defalias 'ejn:pytools-not-move-cell-up-km #'ignore)

;; Phase 4 stubs — signal `user-error` when called
(defun ejn:notebook-open ()
  "Open a notebook via Jupyter server.

Queries the Jupyter server's kernel list via `jupyter-current-server'
and `jupyter-api-get-kernel', then presents a `completing-read' of
running kernels to attach to.  The selected kernel is connected and
stored in the notebook's `:kernel-id' slot.  The kernel manager minor
mode is activated in the master buffer.

Signals `user-error' if no notebook is associated with the current
buffer, no Jupyter server is available, or no kernels are running."
  (interactive)
  (let* ((notebook (ejn-notebook-of-buffer))
         (server (jupyter-current-server))
         (kernels (jupyter-api-get-kernel server))
         (kernel-ids (mapcar (lambda (kernel)
                               (cdr (assq 'id kernel)))
                             kernels)))
    (unless server
      (user-error "No Jupyter server available"))
    (unless kernel-ids
      (user-error "No running kernels available"))
    (let* ((selected-id (completing-read "Select kernel: " kernel-ids nil t))
           (kernel (jupyter-server-kernel :server server :id selected-id))
           (client (jupyter-client kernel)))
      (oset notebook kernel-id client)
      (when-let* ((master-buf (slot-value notebook 'master-buffer)))
        (with-current-buffer master-buf
          (ejn-kernel-manager-mode 1))))))

(defun ejn:worksheet-execute-cell-and-insert-below ()
  "Execute the current cell and insert a new code cell below it.

Sends the current cell's source to the kernel via `ejn--execute-cell',
updates the mode-line via `ejn--update-mode-line', then creates a new
empty code cell below the current cell and switches to it.

Signals a `user-error' if there is no cell at point."
  (interactive)
  (let* ((cell (bound-and-true-p ejn--cell))
         (notebook (ejn-notebook-of-buffer)))
    (unless cell
      (user-error "No cell at point"))
    (let* ((cells (slot-value notebook 'cells))
           (current-index (cl-position cell cells)))
      ;; Execute the current cell
      (ejn--execute-cell cell)
      (ejn--update-mode-line notebook)
      ;; Insert a new empty code cell below
      (let ((new-cell (ejn--make-cell notebook (1+ current-index) 'code)))
        (switch-to-buffer (ejn-cell-open-buffer new-cell notebook))))))

(defun ejn:worksheet-execute-cell-and-goto-next ()
  "Execute the current cell and switch to the next cell's buffer.

Sends the current cell's source to the kernel via `ejn--execute-cell',
updates the mode-line via `ejn--update-mode-line', then switches to the
next cell's buffer using `ejn-cell-open-buffer' and `switch-to-buffer'.

Signals a `user-error' if there is no cell at point or if the current
cell is the last cell in the notebook (no next cell to navigate to)."
  (interactive)
  (let* ((cell (bound-and-true-p ejn--cell))
         (notebook (ejn-notebook-of-buffer)))
    (unless cell
      (user-error "No cell at point"))
    (let* ((cells (slot-value notebook 'cells))
           (current-index (cl-position cell cells))
           (next-index (1+ current-index)))
      (unless (< next-index (length cells))
        (user-error "No more cells below"))
      ;; Execute the current cell
      (ejn--execute-cell cell)
      (ejn--update-mode-line notebook)
      ;; Switch to the next cell's buffer
      (let ((next-cell (nth next-index cells)))
        (switch-to-buffer (ejn-cell-open-buffer next-cell notebook))))))

(defun ejn:notebook-reconnect-session ()
  "Reconnect to the current kernel session.

Calls `ejn-kernel-reconnect' on the current notebook to re-establish
the client connection, then updates the mode-line to reflect the
kernel state.  Re-activates `ejn-kernel-manager-mode' in the master
buffer if it was not already active.

Signals a `user-error' if there is no notebook or kernel attached."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (ejn-kernel-reconnect notebook)
    (ejn--update-mode-line notebook)
    (when-let* ((master-buf (slot-value notebook 'master-buffer)))
      (with-current-buffer master-buf
        (unless (bound-and-true-p ejn-kernel-manager-mode)
          (ejn-kernel-manager-mode 1))))))

(defun ejn:notebook-kill-kernel-then-close ()
  "Kill the kernel and close the notebook.

Interrupts the kernel, shuts it down, saves dirty cells, kills all
buffers, and cleans up the cache directory."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (when (slot-value notebook 'kernel-id)
      (ejn-kernel-interrupt notebook)
      (ejn-kernel-stop notebook))
    (ejn--flush-all-dirty-cells notebook)
    (dolist (cell (slot-value notebook 'cells))
      (let ((buf (slot-value cell 'buffer)))
        (when (buffer-live-p buf)
          (kill-buffer buf))))
    (when-let ((master-buf (slot-value notebook 'master-buffer)))
      (when (buffer-live-p master-buf)
        (kill-buffer master-buf)))
    (let* ((nb-stem (file-name-sans-extension
                     (file-name-nondirectory
                      (slot-value notebook 'path))))
           (cache-dir (expand-file-name
                      (concat ".ejn-cache/" nb-stem)
                      (file-name-directory
                       (slot-value notebook 'path)))))
      (when (file-directory-p cache-dir)
        (delete-directory cache-dir 'recursive)))))

(defun ejn:worksheet-execute-cell (&optional arg)
  "Execute the current cell.

With prefix argument, execute all code cells in the notebook.

Sends the cell's source to the kernel via `ejn--execute-cell',
updates the mode-line to reflect the busy state via
`ejn--update-mode-line', and registers an iopub callback
to dispatch messages by type.

Signals a `user-error' if there is no cell at point or no
kernel started for the notebook."
  (interactive "P")
  (let* ((cell (bound-and-true-p ejn--cell))
         (notebook (ejn-notebook-of-buffer)))
    (unless cell
      (user-error "No cell at point"))
    (if arg
        (progn
          (ejn--execute-all-cells notebook)
          (ejn--update-mode-line notebook))
      (ejn--execute-cell cell)
      (ejn--update-mode-line notebook))))

(defun ejn:worksheet-execute-all-cells ()
  "Execute all code cells in the current notebook.

Iterates over all cells in the notebook and executes each code cell
that has a live buffer, waiting for idle between each execution.

Signals a `user-error' if no notebook is associated with the current
buffer.

Returns nil."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (ejn--execute-all-cells notebook)))

(defun ejn:worksheet-toggle-output ()
  "Toggle output visibility of current cell.

Calls `ejn--toggle-output-visibility' for the cell at point, which
toggles the `invisible' text property on the output overlay's
`after-string'.  Output data is preserved when hidden.

Signals a `user-error' if there is no cell at point."
  (interactive)
  (let ((cell (bound-and-true-p ejn--cell)))
    (unless cell
      (user-error "No cell at point"))
    (ejn--toggle-output-visibility cell)))

(defun ejn:worksheet-clear-output ()
  "Clear output of current cell.

Calls `ejn--clear-output' for the cell at point, which deletes the
output overlay and clears the `:output-overlay' slot.

Signals a `user-error' if there is no cell at point."
  (interactive)
  (let ((cell (bound-and-true-p ejn--cell)))
    (unless cell
      (user-error "No cell at point"))
    (ejn--clear-output cell)))

(defun ejn:worksheet-clear-all-output ()
  "Clear all cell outputs in the current notebook.

Iterates over all cells in the notebook and calls `ejn--clear-output'
for each, which deletes the output overlay and clears the
`:output-overlay' slot.

Signals a `user-error' if no notebook is associated with the current
buffer."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (dolist (cell (slot-value notebook 'cells))
      (ejn--clear-output cell))))

(defun ejn:worksheet-toggle-cell-type ()
  "Toggle the current cell's type. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:worksheet-change-cell-type ()
  "Change the current cell's type. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:worksheet-set-output-visibility-all ()
  "Set output visibility for all cells to the current cell's visibility state.

Calls `ejn--set-output-visibility-all' with the notebook and the current cell's
`output-visible-p' slot value, propagating that visibility to every cell in the
notebook.

Signals a `user-error' if there is no cell at point."
  (interactive)
  (let* ((cell (bound-and-true-p ejn--cell))
         (notebook (ejn-notebook-of-buffer)))
    (unless cell
      (user-error "No cell at point"))
    (ejn--set-output-visibility-all
     notebook (slot-value cell 'output-visible-p))))

(defun ejn:notebook-kernel-interrupt ()
  "Interrupt the current kernel.

Calls `ejn-kernel-interrupt' on the current notebook, then updates
the mode-line to reflect any state change.

Signals a `user-error' if there is no notebook or no kernel attached."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (ejn-kernel-interrupt notebook)
    (ejn--update-mode-line notebook)))

(defun ejn:notebook-close ()
  "Close the current notebook. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:tb-show ()
  "Show traceback viewer. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:notebook-scratchsheet-open ()
  "Open the scratchsheet buffer. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:shared-output-show-code-cell-at-point ()
  "Show the code cell for the output at point. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:notebook-restart-session ()
  "Restart the kernel session.

Calls `ejn-kernel-restart' on the current notebook, then prompts to
re-execute all cells.  If confirmed, calls `ejn--execute-all-cells'."
  (interactive)
  (let* ((notebook (ejn-notebook-of-buffer)))
    (or notebook
        (user-error "No notebook found in current buffer"))
    (ejn-kernel-restart notebook)
    (ejn--update-mode-line notebook)
    (when (y-or-n-p "Re-execute all cells? ")
      (ejn--execute-all-cells notebook))))

(defun ejn:worksheet-cut-cell ()
  "Cut the current cell (copy to kill ring and kill).

Wraps `ejn:worksheet-copy-cell' with the `kill' flag, so the cell
is copied to the notebook's kill ring and then removed."
  (interactive)
  (ejn:worksheet-copy-cell t))

;;;###autoload
(defun ejn-open-file ()
  "Open a Jupyter Notebook .ipynb file.

Prompts for a file path, loads the notebook via `ejn-notebook-load',
creates a master view buffer via `ejn--create-master-view', and opens
the first cell's buffer via `ejn-cell-open-buffer'.
Returns nil."
  (interactive)
  (let* ((file-path (read-file-name "Open notebook: " nil nil t))
         (notebook (ejn-notebook-load file-path))
         (cells (slot-value notebook 'cells)))
    (ejn--create-master-view notebook)
    (when cells
      (ejn-cell-open-buffer (car cells) notebook))))

(defvar ejn-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Navigation (keymap.md)
    (define-key map [C-down] #'ejn:worksheet-goto-next-input)
    (define-key map [C-up] #'ejn:worksheet-goto-prev-input)
    (define-key map (kbd "C-c C-n") #'ejn:worksheet-goto-next-input)
    (define-key map (kbd "C-c C-p") #'ejn:worksheet-goto-prev-input)

    ;; Cell insertion (keymap.md)
    (define-key map (kbd "C-c C-a") #'ejn:worksheet-insert-cell-above)
    (define-key map (kbd "C-c C-b") #'ejn:worksheet-insert-cell-below)

    ;; Cell movement (keymap.md)
    (define-key map (kbd "C-c <down>") #'ejn:worksheet-move-cell-down)
    (define-key map (kbd "C-c <up>") #'ejn:worksheet-move-cell-up)

    ;; Cell deletion (keymap.md)
    (define-key map (kbd "C-c C-k") #'ejn:worksheet-kill-cell)

    ;; Cell split and merge (keymap.md)
    (define-key map (kbd "C-c C-s") #'ejn:worksheet-split-cell-at-point)
    (define-key map (kbd "C-c RET") #'ejn:worksheet-merge-cell)

    ;; Cell copy and yank (keymap.md)
    (define-key map (kbd "C-c C-w") #'ejn:worksheet-cut-cell)
    (define-key map (kbd "C-c M-w") #'ejn:worksheet-copy-cell)
    (define-key map (kbd "C-c C-y") #'ejn:worksheet-yank-cell)

    ;; Notebook file commands (keymap.md)
    (define-key map (kbd "C-x C-s") #'ejn:notebook-save-notebook-command)
    (define-key map (kbd "C-x C-w") #'ejn:notebook-rename-command)
    (define-key map (kbd "C-c C-f") #'ejn:file-open)

    ;; M-. — jump to definition (pytools compatibility)
    (define-key map (kbd "M-.") #'ejn:pytools-jump-to-source)

    ;; M-<down> / M-<up> — pytools compatibility, bound to `ignore`
    (define-key map [M-down] #'ejn:pytools-not-move-cell-down-km)
    (define-key map [M-up] #'ejn:pytools-not-move-cell-up-km)

    ;; Phase 4 stubs — interactive commands that signal `user-error`
    (define-key map [M-S-return] #'ejn:worksheet-execute-cell-and-insert-below)
    (define-key map [M-return] #'ejn:worksheet-execute-cell-and-goto-next)
    (define-key map (kbd "C-c C-o") #'ejn:notebook-open)
    (define-key map (kbd "C-c C-q") #'ejn:notebook-kill-kernel-then-close)
    (define-key map (kbd "C-c C-r") #'ejn:notebook-reconnect-session)
    (define-key map (kbd "C-c C-c") #'ejn:worksheet-execute-cell)
    (define-key map (kbd "C-c C-e") #'ejn:worksheet-toggle-output)
    (define-key map (kbd "C-c C-l") #'ejn:worksheet-clear-output)
    (define-key map (kbd "C-c C-S-l") #'ejn:worksheet-clear-all-output)
    (define-key map (kbd "C-c C-t") #'ejn:worksheet-toggle-cell-type)
    (define-key map (kbd "C-c C-u") #'ejn:worksheet-change-cell-type)
    (define-key map (kbd "C-c C-v") #'ejn:worksheet-set-output-visibility-all)
    (define-key map (kbd "C-c C-z") #'ejn:notebook-kernel-interrupt)
    (define-key map (kbd "C-c C-#") #'ejn:notebook-close)
    (define-key map (kbd "C-c C-$") #'ejn:tb-show)
    (define-key map (kbd "C-c C-/") #'ejn:notebook-scratchsheet-open)
    (define-key map (kbd "C-c C-;") #'ejn:shared-output-show-code-cell-at-point)
    (define-key map (kbd "C-c C-x C-r") #'ejn:notebook-restart-session)

    ;; LSP navigation (keymap.md)
    (define-key map (kbd "M-,") #'ejn:pytools-jump-back)
    map)
  "Keymap for `ejn-mode'.")

;;;###autoload
(define-minor-mode ejn-mode
  "Minor mode for editing Jupyter Notebook files in Emacs.

Provides keybindings for structural cell operations (insert, move,
kill, split, merge, copy, yank, navigate) and notebook file
commands (save, rename, open). Activates in master view and cell
buffers.

\\{ejn-mode-map}"
  :lighter " EJN"
  :keymap ejn-mode-map
  :global nil)

(provide 'ejn)

;;; ejn.el ends here
