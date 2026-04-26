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
;; Package-Requires: ((emacs "24.1"))

;;; Code:

(require 'cl-lib)
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
  "Open a notebook via Jupyter server. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:worksheet-execute-cell-and-insert-below ()
  "Execute current cell and insert a new cell below. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:worksheet-execute-cell-and-goto-next ()
  "Execute current cell and go to next cell. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:notebook-reconnect-session ()
  "Reconnect to the current kernel session. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:notebook-kill-kernel-then-close ()
  "Kill the kernel and close the notebook. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:worksheet-execute-cell ()
  "Execute the current cell. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:worksheet-toggle-output ()
  "Toggle output visibility of current cell. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:worksheet-clear-output ()
  "Clear output of current cell. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:worksheet-clear-all-output ()
  "Clear all cell outputs. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:worksheet-toggle-cell-type ()
  "Toggle the current cell's type. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:worksheet-change-cell-type ()
  "Change the current cell's type. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:worksheet-set-output-visibility-all ()
  "Set output visibility for all cells. Not yet implemented."
  (interactive)
  (ejn--stub-error))

(defun ejn:notebook-kernel-interrupt ()
  "Interrupt the current kernel. Not yet implemented."
  (interactive)
  (ejn--stub-error))

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
  "Restart the kernel session. Not yet implemented."
  (interactive)
  (ejn--stub-error))

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
    (define-key map (kbd "C-c M-w") #'ejn:worksheet-copy-cell)
    (define-key map (kbd "C-c C-y") #'ejn:worksheet-yank-cell)

    ;; Notebook file commands (keymap.md)
    (define-key map (kbd "C-x C-s") #'ejn:notebook-save-notebook-command)
    (define-key map (kbd "C-x C-w") #'ejn:notebook-rename-command)
    (define-key map (kbd "C-c C-f") #'ejn:file-open)

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
