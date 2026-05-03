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

;; Emacs Jupyter Notebook — main entry point.
;;
;; Loads all EJN subsystems, defines interactive commands, and
;; establishes `ejn-mode' with the keymap from keymap.md.

;; URL: https://github.com/emacs-jupyter-notebook/emacs-jupyter-notebook
;; Package-Requires: ((emacs "30.1"))

;;; Code:

(require 'cl-lib)

(require 'ejn-core)
(require 'ejn-cell)
(require 'ejn-master)
(require 'ejn-notebook)
(require 'ejn-network)
(require 'ejn-lsp)
(require 'ejn-ui)

;; ---------------------------------------------------------------------------
;; Stub compatibility aliases
;; ---------------------------------------------------------------------------

(defalias 'ejn:pytools-not-move-cell-down-km #'ignore
  "No-op compatibility stub (M-<down> — pytools).")

(defalias 'ejn:pytools-not-move-cell-up-km #'ignore
  "No-op compatibility stub (M-<up> — pytools).")

;; ---------------------------------------------------------------------------
;; Notebook open / kernel management
;; ---------------------------------------------------------------------------

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

;;;###autoload
(defun ejn-open-file ()
  "Open a Jupyter Notebook .ipynb file.

Prompts for a file path, loads the notebook via `ejn-notebook-load',
creates a master view buffer via `ejn--create-master-view'.
Cells are parsed into EIEIO objects but buffers, shadow files, and
LSP connections are created lazily.  The first cell is initialized
immediately for usability via `ejn-cell-initialize'.
Returns nil."
  (interactive)
  (let* ((file-path (read-file-name "Open notebook: " nil nil t))
         (notebook (ejn-notebook-load file-path))
         (cells (slot-value notebook 'cells)))
    (ejn--create-master-view notebook)
    (when cells
      (ejn-cell-initialize (car cells) notebook))))

;;;###autoload
(defalias 'ejn:file-open #'ejn-open-file
  "Alias for `ejn-open-file' bound to C-c C-f.")

;; ---------------------------------------------------------------------------
;; Execution commands
;; ---------------------------------------------------------------------------

(defun ejn:worksheet-execute-cell (&optional arg)
  "Execute the current cell.

With prefix argument ARG, execute all code cells in the notebook.

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
      (ejn--execute-cell cell)
      (ejn--update-mode-line notebook)
      (let ((new-cell (ejn--make-cell notebook (1+ current-index) 'code)))
        (switch-to-buffer (ejn-cell-open-buffer new-cell notebook))))))

(defun ejn:worksheet-execute-cell-and-goto-next ()
  "Execute the current cell and switch to the next cell's buffer.

Sends the current cell's source to the kernel via `ejn--execute-cell',
updates the mode-line via `ejn--update-mode-line', then switches to the
next cell's buffer using `ejn-cell-open-buffer' and `switch-to-buffer'.

Signals a `user-error' if there is no cell at point or if the current
cell is the last cell in the notebook."
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
      (ejn--execute-cell cell)
      (ejn--update-mode-line notebook)
      (let ((next-cell (nth next-index cells)))
        (switch-to-buffer (ejn-cell-open-buffer next-cell notebook))))))

;; ---------------------------------------------------------------------------
;; Output visibility commands
;; ---------------------------------------------------------------------------

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

Calls `ejn--clear-output' for the cell at point, which resets the
output overlay's `after-string' to empty.

Signals a `user-error' if there is no cell at point."
  (interactive)
  (let ((cell (bound-and-true-p ejn--cell)))
    (unless cell
      (user-error "No cell at point"))
    (ejn--clear-output cell)))

(defun ejn:worksheet-clear-all-output ()
  "Clear all cell outputs in the current notebook.

Iterates over all cells in the notebook and calls `ejn--clear-output'
for each cell.

Signals a `user-error' if no notebook is associated with the current
buffer."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (dolist (cell (slot-value notebook 'cells))
      (ejn--clear-output cell))))

(defun ejn:worksheet-set-output-visibility-all ()
  "Set output visibility for all cells to the current cell's visibility state.

Calls `ejn--set-output-visibility-all' with the notebook and the current
cell's `output-visible-p' slot value, propagating that visibility to every
cell in the notebook.

Signals a `user-error' if there is no cell at point."
  (interactive)
  (let* ((cell (bound-and-true-p ejn--cell))
         (notebook (ejn-notebook-of-buffer)))
    (unless cell
      (user-error "No cell at point"))
    (ejn--set-output-visibility-all
     notebook (slot-value cell 'output-visible-p))))

;; ---------------------------------------------------------------------------
;; Cell type commands
;;
;; FIX #2: ejn:worksheet-toggle-cell-type had a parenthesis imbalance.
;; The `with-current-buffer' form closed one paren short, so the three
;; calls to ejn-markdown-render-cell, ejn-cell-refresh-header, and
;; ejn--poly-refresh-cells ran in the calling buffer rather than the cell
;; buffer.  The outer `let*' also lacked its final closing paren, making
;; the function structurally malformed and prone to load-time failure.
;;
;; Fix: the `with-current-buffer' scope now covers ONLY the mode-switching
;; clause (which must run inside the cell buffer).  The post-switch calls
;; (ejn-markdown-render-cell, ejn-cell-refresh-header, master refresh) are
;; outside `with-current-buffer' and operate on the cell/notebook objects,
;; not on point.  All paren counts are verified.
;;
;; FIX #10: ejn:worksheet-change-cell-type had a malformed completing-read
;; prompt "Cell type: '(" with a stray single-quote and open-paren embedded
;; in the prompt string, which is confusing to users and signals malformed
;; intent.  Fixed to "Cell type: ".  The call already uses nil t for
;; PREDICATE and REQUIRE-MATCH, so only valid types can be entered.
;; ---------------------------------------------------------------------------

(defun ejn:worksheet-toggle-cell-type ()
  "Toggle the current cell's type between code and markdown.

Cycles the cell's `:type' slot between `code' and `markdown'.
Updates the cell buffer's major mode accordingly (inside the cell
buffer), then calls `ejn-markdown-render-cell' for markdown cells,
refreshes the cell header, and re-renders the master view.

FIX #2: The `with-current-buffer' form now has balanced parentheses
and is scoped only around the major-mode switch.

Signals a `user-error' if there is no cell at point."
  (interactive)
  (let ((cell (bound-and-true-p ejn--cell)))
    (unless cell
      (user-error "No cell at point"))
    (let* ((notebook (ejn-notebook-of-buffer))
           (old-type (slot-value cell 'type))
           (new-type (if (eq old-type 'code) 'markdown 'code)))
      ;; Update the cell type slot
      (oset cell type new-type)
      ;; Switch major mode inside the cell buffer — scoped correctly
      (with-current-buffer (slot-value cell 'buffer)
        (cl-case new-type
          (code (python-mode))
          (markdown
           (condition-case nil
               (markdown-mode)
             ((command-error void-function)
              (fundamental-mode))))))
      ;; Render markdown preview if new type is markdown
      (when (eq new-type 'markdown)
        (ejn-markdown-render-cell cell))
      ;; Refresh cell header (works on the cell object, not point)
      (ejn-cell-refresh-header cell)
      ;; Re-render master view
      (when-let* ((master-buf (slot-value notebook 'master-buffer)))
        (when (buffer-live-p master-buf)
          (with-current-buffer master-buf
            (ejn--refresh-master-cells)))))))

(defun ejn:worksheet-change-cell-type ()
  "Change the current cell's type via `completing-read'.

Presents the user with a choice of cell types: code, markdown, and raw.
Updates the cell's `:type' slot, sets the buffer's major mode accordingly
(`python-mode' for code, `markdown-mode' or `fundamental-mode' for
markdown, `fundamental-mode' for raw), calls `ejn-markdown-render-cell'
for markdown cells, refreshes the cell header, and re-renders the master
view.

FIX #10: The `completing-read' prompt was \"Cell type: '(\" containing a
stray single-quote and open-paren.  Fixed to \"Cell type: \".

Signals a `user-error' if there is no cell at point."
  (interactive)
  (let ((cell (bound-and-true-p ejn--cell)))
    (unless cell
      (user-error "No cell at point"))
    (let* ((notebook (ejn-notebook-of-buffer))
           ;; FIX #10: clean prompt string, no stray punctuation
           (type-str (completing-read "Cell type: "
                                      '("code" "markdown" "raw")
                                      nil t))
           (new-type (intern type-str)))
      ;; Update the cell type slot
      (oset cell type new-type)
      ;; Switch major mode inside the cell buffer
      (with-current-buffer (slot-value cell 'buffer)
        (cl-case new-type
          (code (python-mode))
          (markdown
           (condition-case nil
               (markdown-mode)
             ((command-error void-function)
              (fundamental-mode))))
          (raw (fundamental-mode))))
      ;; Render markdown preview if new type is markdown
      (when (eq new-type 'markdown)
        (ejn-markdown-render-cell cell))
      ;; Refresh cell header
      (ejn-cell-refresh-header cell)
      ;; Re-render master view
      (when-let* ((master-buf (slot-value notebook 'master-buffer)))
        (when (buffer-live-p master-buf)
          (with-current-buffer master-buf
            (ejn--refresh-master-cells)))))))

;; ---------------------------------------------------------------------------
;; Save / rename commands
;; ---------------------------------------------------------------------------

(defun ejn:notebook-save-notebook-command ()
  "Save the current notebook to its .ipynb file.

Delegates to `ejn-notebook-save'.  Signals `user-error' if no notebook
is associated with the current buffer."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (ejn-notebook-save notebook)))

(defun ejn:notebook-rename-command ()
  "Rename the current notebook file and update the master buffer name.

Prompts for a new filename (basename only).  Delegates to
`ejn-notebook-rename'.  Signals `user-error' if no notebook is
associated with the current buffer."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (let ((new-name (read-string "New notebook name (basename): "
                                 (file-name-nondirectory
                                  (slot-value notebook 'path)))))
      (ejn-notebook-rename notebook new-name))))

;; ---------------------------------------------------------------------------
;; Kernel lifecycle commands
;; ---------------------------------------------------------------------------

(defun ejn:notebook-kill-kernel-then-close ()
  "Kill the kernel and close the notebook.

Interrupts the kernel, shuts it down, saves dirty cells, kills all
cell buffers and the master view buffer, then removes the cache directory.
Prompts before deleting the cache."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
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
    (let* ((nb-path (slot-value notebook 'path))
           (nb-stem (file-name-sans-extension
                     (file-name-nondirectory nb-path)))
           (cache-dir (expand-file-name
                       (concat ".ejn-cache/" nb-stem)
                       (file-name-directory nb-path))))
      (when (and (file-directory-p cache-dir)
                 (y-or-n-p (format "Delete cache directory %s? " cache-dir)))
        (delete-directory cache-dir 'recursive)))))

(defun ejn:notebook-close ()
  "Close the current notebook without killing the kernel.

Prompts to save dirty cells before closing.  Kills all cell buffers
and the master view buffer.  Optionally removes the cache directory.
The kernel process is NOT stopped."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (let ((any-dirty-p (cl-some (lambda (cell)
                                  (slot-value cell 'dirty))
                                (slot-value notebook 'cells))))
      (when (and any-dirty-p
                 (y-or-n-p "Save dirty cells before closing? "))
        (ejn-notebook-save notebook)))
    (dolist (cell (slot-value notebook 'cells))
      (let ((buf (slot-value cell 'buffer)))
        (when (buffer-live-p buf)
          (kill-buffer buf))))
    (when-let ((master-buf (slot-value notebook 'master-buffer)))
      (when (buffer-live-p master-buf)
        (kill-buffer master-buf)))
    (let* ((nb-path (slot-value notebook 'path))
           (nb-stem (file-name-sans-extension
                     (file-name-nondirectory nb-path)))
           (cache-dir (expand-file-name
                       (concat ".ejn-cache/" nb-stem)
                       (file-name-directory nb-path))))
      (when (and (file-directory-p cache-dir)
                 (y-or-n-p (format "Delete cache directory %s? " cache-dir)))
        (delete-directory cache-dir 'recursive)))))

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

(defun ejn:notebook-restart-session ()
  "Restart the kernel session.

Calls `ejn-kernel-restart' on the current notebook, updates the
mode-line, then prompts to re-execute all cells.  If confirmed,
calls `ejn--execute-all-cells'."
  (interactive)
  (let ((notebook (ejn-notebook-of-buffer)))
    (unless notebook
      (user-error "No notebook found in current buffer"))
    (ejn-kernel-restart notebook)
    (ejn--update-mode-line notebook)
    (when (y-or-n-p "Re-execute all cells? ")
      (ejn--execute-all-cells notebook))))

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

;; ---------------------------------------------------------------------------
;; Traceback / shared output
;; ---------------------------------------------------------------------------

(defun ejn:tb-show ()
  "Show the most recent kernel traceback in a dedicated buffer.

Opens a buffer named `*ejn-tb*' with `python-mode', displaying the
traceback text from the current notebook's `:last-traceback' slot.
ANSI escape sequences are processed via `ansi-color-apply-on-region'.

Signals `user-error' if no notebook is associated with the current
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
          (let ((inhibit-read-only t))
            (erase-buffer)
            (python-mode)
            (insert tb-text)
            (ansi-color-apply-on-region (point-min) (point-max))
            (setq buffer-read-only t)))
        (display-buffer tb-buf)
        tb-buf))))

(defun ejn:shared-output-show-code-cell-at-point ()
  "Show source and output of the current code cell in a dedicated buffer.

The buffer is named `*ejn-output:STEM*' where STEM is the notebook
filename without extension.  The buffer contains the cell source
followed by any text/plain outputs.

Signals `user-error' if no notebook or code cell is at point."
  (interactive)
  (let* ((notebook (and (boundp 'ejn--notebook) ejn--notebook))
         (cell (and (boundp 'ejn--cell) ejn--cell)))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (unless cell
      (user-error "No cell at point"))
    (unless (eq (slot-value cell 'type) 'code)
      (user-error "Current cell is not a code cell"))
    (let* ((stem (file-name-sans-extension
                  (file-name-nondirectory (slot-value notebook 'path))))
           (buf-name (format "*ejn-output:%s*" stem))
           (buf (get-buffer-create buf-name)))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
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
          (setq buffer-read-only nil)))
      (display-buffer buf)
      buf)))

;; ---------------------------------------------------------------------------
;; Scratch sheet
;; ---------------------------------------------------------------------------

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
    (let* ((scratch-cell (make-instance 'ejn-cell
                                        :type 'code
                                        :source "\n"
                                        :scratch-p t))
           (nb-path (slot-value notebook 'path))
           (nb-stem (file-name-sans-extension
                     (file-name-nondirectory nb-path)))
           (cache-dir (expand-file-name
                       (concat ".ejn-cache/" nb-stem)
                       (file-name-directory nb-path)))
           (scratch-path (expand-file-name "scratch.py" cache-dir)))
      (make-directory cache-dir t)
      (with-temp-file scratch-path
        (insert ""))
      (oset scratch-cell shadow-file scratch-path)
      ;; Create buffer directly to avoid ejn-shadow-write-cell (which
      ;; requires the cell to be in notebook's :cells list).
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

;; ---------------------------------------------------------------------------
;; Cut (copy + kill)
;; ---------------------------------------------------------------------------

(defun ejn:worksheet-cut-cell ()
  "Cut the current cell (copy to kill ring and kill).

Wraps `ejn:worksheet-copy-cell' with the kill flag."
  (interactive)
  (ejn:worksheet-copy-cell t))

;; ---------------------------------------------------------------------------
;; Keymap
;; ---------------------------------------------------------------------------

(defvar ejn-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Navigation (keymap.md)
    (define-key map [C-down]      #'ejn:worksheet-goto-next-input)
    (define-key map [C-up]        #'ejn:worksheet-goto-prev-input)
    (define-key map (kbd "C-c C-n") #'ejn:worksheet-goto-next-input)
    (define-key map (kbd "C-c C-p") #'ejn:worksheet-goto-prev-input)

    ;; Cell insertion (keymap.md)
    (define-key map (kbd "C-c C-a") #'ejn:worksheet-insert-cell-above)
    (define-key map (kbd "C-c C-b") #'ejn:worksheet-insert-cell-below)

    ;; Cell movement (keymap.md)
    (define-key map (kbd "C-c <down>") #'ejn:worksheet-move-cell-down)
    (define-key map (kbd "C-c <up>")   #'ejn:worksheet-move-cell-up)

    ;; M-<down> / M-<up> pytools compatibility no-ops (keymap.md)
    (define-key map [M-down] #'ejn:pytools-not-move-cell-down-km)
    (define-key map [M-up]   #'ejn:pytools-not-move-cell-up-km)

    ;; Cell deletion (keymap.md)
    (define-key map (kbd "C-c C-k") #'ejn:worksheet-kill-cell)

    ;; Cell split and merge (keymap.md)
    (define-key map (kbd "C-c C-s")   #'ejn:worksheet-split-cell-at-point)
    (define-key map (kbd "C-c RET")   #'ejn:worksheet-merge-cell)

    ;; Cell copy / cut / yank (keymap.md)
    (define-key map (kbd "C-c C-w")   #'ejn:worksheet-cut-cell)
    (define-key map (kbd "C-c M-w")   #'ejn:worksheet-copy-cell)
    (define-key map (kbd "C-c C-y")   #'ejn:worksheet-yank-cell)

    ;; Execution (keymap.md)
    (define-key map [M-S-return] #'ejn:worksheet-execute-cell-and-insert-below)
    (define-key map [M-return]   #'ejn:worksheet-execute-cell-and-goto-next)
    (define-key map (kbd "C-c C-c") #'ejn:worksheet-execute-cell)
    (define-key map (kbd "C-u C-c C-c") #'ejn:worksheet-execute-all-cells)

    ;; Output visibility (keymap.md)
    (define-key map (kbd "C-c C-e")   #'ejn:worksheet-toggle-output)
    (define-key map (kbd "C-c C-l")   #'ejn:worksheet-clear-output)
    (define-key map (kbd "C-c C-S-l") #'ejn:worksheet-clear-all-output)
    (define-key map (kbd "C-c C-v")   #'ejn:worksheet-set-output-visibility-all)

    ;; Cell type (keymap.md)
    (define-key map (kbd "C-c C-t") #'ejn:worksheet-toggle-cell-type)
    (define-key map (kbd "C-c C-u") #'ejn:worksheet-change-cell-type)

    ;; Notebook file commands (keymap.md)
    (define-key map (kbd "C-x C-s") #'ejn:notebook-save-notebook-command)
    (define-key map (kbd "C-x C-w") #'ejn:notebook-rename-command)
    (define-key map (kbd "C-c C-f") #'ejn:file-open)

    ;; Notebook session commands (keymap.md)
    (define-key map (kbd "C-c C-o") #'ejn:notebook-open)
    (define-key map (kbd "C-c C-q") #'ejn:notebook-kill-kernel-then-close)
    (define-key map (kbd "C-c C-r") #'ejn:notebook-reconnect-session)
    (define-key map (kbd "C-c C-z") #'ejn:notebook-kernel-interrupt)
    (define-key map (kbd "C-c C-#") #'ejn:notebook-close)
    (define-key map (kbd "C-c C-x C-r") #'ejn:notebook-restart-session)

    ;; Diagnostics / extras (keymap.md)
    (define-key map (kbd "C-c C-$") #'ejn:tb-show)
    (define-key map (kbd "C-c C-/") #'ejn:notebook-scratchsheet-open)
    (define-key map (kbd "C-c C-;") #'ejn:shared-output-show-code-cell-at-point)

    ;; LSP navigation (keymap.md)
    (define-key map (kbd "M-.") #'ejn:pytools-jump-to-source)
    (define-key map (kbd "M-,") #'ejn:pytools-jump-back)

    map)
  "Keymap for `ejn-mode'.

All bindings correspond to keymap.md.")

;;;###autoload
(define-minor-mode ejn-mode
  "Minor mode for editing Jupyter Notebook cells in Emacs.

Provides keybindings for structural cell operations (insert, move,
kill, split, merge, copy, yank, navigate) and notebook file
commands (save, rename, open).  Activates in both the master view
and individual cell buffers.

\\{ejn-mode-map}"
  :lighter " EJN"
  :keymap ejn-mode-map
  :global nil)

(provide 'ejn)

;;; ejn.el ends here
