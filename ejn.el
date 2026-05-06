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
(require 'ejn-ui)

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
  "Toggle the current cell's type between code and markdown.

Cycles the cell's `:type` slot between `code` and `markdown`.
Updates the cell buffer's major mode accordingly, calls
`ejn-markdown-render-cell` for markdown cells, refreshes the
cell header, and re-renders the master view.

Signals a `user-error' if there is no cell at point."
  (interactive)
  (let ((cell (bound-and-true-p ejn--cell)))
    (unless cell
      (user-error "No cell at point"))
    (let* ((notebook (ejn-notebook-of-buffer))
           (old-type (slot-value cell 'type))
           (new-type (if (eq old-type 'code) 'markdown 'code)))
      ;; Update cell type
      (oset cell type new-type)
      ;; Update buffer's major mode
      (with-current-buffer (slot-value cell 'buffer)
        (cl-case new-type
          (code (python-mode))
          (markdown
           (condition-case nil
               (markdown-mode)
             ((command-error void-function)
              (fundamental-mode)))))
      ;; Render markdown if new type is markdown
      (when (and (eq new-type 'markdown)
                 (fboundp 'ejn-markdown-render-cell))
        (ejn-markdown-render-cell cell))
      ;; Refresh cell header
      (when (fboundp 'ejn-cell-refresh-header)
        (ejn-cell-refresh-header cell))
      ;; Re-render master view
      (when-let* ((master-buf (slot-value notebook 'master-buffer)))
        (when (buffer-live-p master-buf)
          (with-current-buffer master-buf
            (when (fboundp 'ejn--poly-refresh-cells)
              (ejn--poly-refresh-cells)))))))))

(defun ejn:worksheet-change-cell-type ()
  "Change the current cell's type via `completing-read'.

Presents the user with a choice of cell types: `code', `markdown',
and `raw'.  Updates the cell's `:type' slot, sets the buffer's major
mode accordingly (`python-mode' for code, `markdown-mode' or
`fundamental-mode' for markdown, `fundamental-mode' for raw), calls
`ejn-markdown-render-cell' for markdown cells, refreshes the cell
header, and re-renders the master view.

Signals a `user-error' if there is no cell at point."
  (interactive)
  (let ((cell (bound-and-true-p ejn--cell)))
    (unless cell
      (user-error "No cell at point"))
    (let* ((notebook (ejn-notebook-of-buffer))
           (type-str (completing-read "Cell type: '(" '("code" "markdown" "raw")
                                      nil t))
           (new-type (intern type-str)))
      ;; Update cell type
      (oset cell type new-type)
      ;; Update buffer's major mode
      (with-current-buffer (slot-value cell 'buffer)
        (cl-case new-type
          (code (python-mode))
          (markdown
           (condition-case nil
               (markdown-mode)
             ((command-error void-function)
              (fundamental-mode))))
          (raw (fundamental-mode))))
      ;; Render markdown if new type is markdown
      (when (and (eq new-type 'markdown)
                 (fboundp 'ejn-markdown-render-cell))
        (ejn-markdown-render-cell cell))
      ;; Refresh cell header
      (when (fboundp 'ejn-cell-refresh-header)
        (ejn-cell-refresh-header cell))
      ;; Re-render master view
      (when-let* ((master-buf (slot-value notebook 'master-buffer)))
        (when (buffer-live-p master-buf)
          (with-current-buffer master-buf
            (when (fboundp 'ejn--poly-refresh-cells)
              (ejn--poly-refresh-cells))))))))

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
  "Close the current notebook without killing the kernel.

Kills all cell buffers and the master view buffer, then removes
the cache directory.  Prompts to save dirty cells before closing.
The kernel process is NOT stopped."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    ;; Check for dirty cells and prompt to save
    (let ((any-dirty-p (cl-some (lambda (cell)
                                  (slot-value cell 'dirty))
                                (slot-value notebook 'cells))))
      (when (and any-dirty-p
                 (y-or-n-p "Save dirty cells before closing? "))
        (ejn:notebook-save-notebook-command)))
    ;; Kill all cell buffers
    (dolist (cell (slot-value notebook 'cells))
      (let ((buf (slot-value cell 'buffer)))
        (when (buffer-live-p buf)
          (kill-buffer buf))))
    ;; Kill master view buffer
    (when-let ((master-buf (slot-value notebook 'master-buffer)))
      (when (buffer-live-p master-buf)
        (kill-buffer master-buf)))
    ;; Clean up cache directory
    (let* ((nb-path (slot-value notebook 'path))
           (nb-stem (file-name-sans-extension
                     (file-name-nondirectory nb-path)))
           (cache-dir (expand-file-name
                       (concat ".ejn-cache/" nb-stem)
                       (file-name-directory nb-path))))
      (when (file-directory-p cache-dir)
        (delete-directory cache-dir 'recursive)))))

(defun ejn:tb-show ()
  "Show the most recent kernel traceback in a dedicated buffer.

Opens a buffer named `*ejn-tb*` with `python-mode`, displaying the
traceback text from the current notebook's `:last-traceback` slot.
ANSI escape sequences are processed via `ansi-color-apply` for
syntax highlighting.  Returns the traceback buffer.

Signals `user-error` if no notebook is associated with the current
buffer, or if no traceback is available."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (let ((tb-text (slot-value notebook 'last-traceback)))
      (unless (and tb-text (> (length tb-text) 0))
        (user-error "No traceback available"))
      (let ((tb-buf (get-buffer-create "*ejn-tb*")))
        (with-current-buffer tb-buf
          (erase-buffer)
          (python-mode)
          (insert tb-text)
          (ansi-color-apply-on-region (point-min) (point-max))
          (setq buffer-read-only t)
          (use-local-map (copy-keymap python-mode-map)))
        tb-buf))))

(defun ejn:notebook-scratchsheet-open ()
  "Open a scratchsheet cell buffer for the current notebook.

Creates a transient code cell with `:scratch-p' set to t.  The cell
is NOT added to the notebook's `:cells' list, so it won't be
persisted on save.  The scratch cell's shadow file is written to
`.ejn-cache/<notebook-stem>/scratch.py'.

Signals `user-error' if no notebook is associated with the current
buffer."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    ;; Create scratch cell — NOT added to notebook's :cells list
    (let* ((scratch-cell (make-instance 'ejn-cell
                                        :type 'code
                                        :source "\n"
                                        :scratch-p t))
           (nb-stem (file-name-sans-extension
                     (file-name-nondirectory
                      (slot-value notebook 'path))))
           (cache-dir (expand-file-name
                       (concat ".ejn-cache/" nb-stem)
                       (file-name-directory
                        (slot-value notebook 'path))))
           (scratch-path (expand-file-name "scratch.py" cache-dir)))
      ;; Ensure cache directory exists and write shadow file
      (make-directory cache-dir t)
      (with-temp-file scratch-path
        (insert ""))
      (oset scratch-cell shadow-file scratch-path)
      ;; Create buffer before calling ejn-cell-open-buffer so it takes the
      ;; "buffer already exists" path and skips ejn-shadow-write-cell
      ;; (which requires the cell to be in notebook's :cells list).
      (let ((new-buf (generate-new-buffer
                       (format "*ejn-cell:%s*" (slot-value scratch-cell 'id)))))
        (with-current-buffer new-buf
          (insert "\n")
          (python-mode)
          (ejn-mode 1)
          (set (make-local-variable 'ejn--cell) scratch-cell)
          (set (make-local-variable 'ejn--notebook) notebook)
          (add-hook 'kill-buffer-hook
                    #'ejn--cell-kill-buffer-hook 'append 'local))
        (oset scratch-cell buffer new-buf)
        (switch-to-buffer new-buf)))))

(defun ejn:shared-output-show-code-cell-at-point ()
  "Show source and output of the current code cell in a dedicated buffer.

The buffer is named `*ejn-output:STEM*` where STEM is the notebook
filename without extension.  The buffer contains the cell source
followed by any text/plain outputs."
  (interactive)
  (let* ((notebook (and (boundp 'ejn--notebook) ejn--notebook))
         (cell (and (boundp 'ejn--cell) ejn--cell)))
    (or notebook (user-error "No notebook associated with this buffer"))
    (or cell (user-error "No cell at point"))
    (unless (eq (slot-value cell 'type) 'code)
      (user-error "Current cell is not a code cell"))
    (let* ((stem (file-name-sans-extension (file-name-nondirectory (slot-value notebook 'path))))
           (buf-name (format "*ejn-output:%s*" stem))
           (buf (get-buffer-create buf-name)))
      (with-current-buffer buf
        (erase-buffer)
        (insert (slot-value cell 'source))
        (let ((outputs (slot-value cell 'outputs)))
          (when outputs
            (dolist (output outputs)
              (when (consp output)
                (let ((text (cdr output)))
                  (when (stringp text)
                    (insert text)))))))
        (special-mode)
        (setq buffer-read-only nil))
      buf)))

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

(defun ejn:notebook-start-kernel (&optional kernel-name)
  "Start a Jupyter kernel for the current notebook.

Prompts for a kernelspec name via `completing-read' if KERNEL-NAME
is nil. Stores the client in the notebook's `:kernel-id' slot and
activates `ejn-kernel-manager-mode' in the master buffer.

Signals `user-error' if no notebook is associated with this buffer,
if no kernelspecs are available, or if a kernel is already running."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (when (ejn-kernel-alive-p notebook)
      (user-error "A kernel is already running. Use C-c C-r to reconnect"))
    (let* ((specs    (jupyter-available-kernelspecs))
           (names    (mapcar #'jupyter-kernelspec-name specs)))
      (unless names
        (user-error "No Jupyter kernelspecs found. Is Jupyter installed?"))
      (let* ((selected (or kernel-name
                           (completing-read "Start kernel: " names nil t
                                            nil nil (car names))))
             (client   (ejn-kernel-start notebook selected)))
        (message "EJN: kernel started (%s)" selected)
        client))))

;;;###autoload
(defun ejn-open-file ()
  "Open a Jupyter Notebook .ipynb file.

Prompts for a file path, loads the notebook via `ejn-notebook-load',
creates and displays a master view buffer via `ejn--create-master-view'.
Cells are parsed into EIEIO objects but buffers, shadow files, and
LSP connections are created lazily. The first cell is initialized
immediately for usability via `ejn-cell-initialize'.
Returns nil."
  (interactive)
  (let* ((file-path   (read-file-name "Open notebook: " nil nil t))
         (notebook    (ejn-notebook-load file-path))
         (cells       (slot-value notebook 'cells))
         (master-buf  (ejn--create-master-view notebook)))
    (switch-to-buffer master-buf)
    (when cells
      (ejn-cell-initialize (car cells) notebook))
    nil))

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
    (define-key map (kbd "C-c C-S-k") #'ejn:notebook-start-kernel)
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
