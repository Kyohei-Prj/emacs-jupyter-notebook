;;; ejn-mode.el --- Major mode for Jupyter notebooks  -*- lexical-binding: t; -*-

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
;; along with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Major mode for editing Jupyter notebook files.
;; Derives from text-mode, provides cell-aware editing.

;;; Code:

(require 'cl-lib)
(require 'ejn-core)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-navigation)
(require 'ejn-cell-engine)
(require 'ejn-sync)
(require 'ejn-undo)
(require 'ejn-persistence)

(defvar-local ejn--notebook nil
  "Current notebook model for this buffer.")

(defvar ejn-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-a") #'ejn-insert-cell-above)
    (define-key map (kbd "C-c C-b") #'ejn-insert-cell-below)
    (define-key map (kbd "C-c C-c") #'ejn-execute-cell)
    (define-key map (kbd "C-c RET") #'ejn-merge-cell)
    (define-key map (kbd "C-c C-k") #'ejn-delete-cell)
    (define-key map (kbd "C-c C-l") #'ejn-clear-output)
    (define-key map (kbd "C-c C-n") #'ejn-goto-next-cell)
    (define-key map (kbd "C-c C-p") #'ejn-goto-prev-cell)
    (define-key map (kbd "C-c C-r") #'ejn-split-cell)
    (define-key map (kbd "C-c C-t") #'ejn-toggle-cell-type)
    (define-key map (kbd "C-c C-u") #'ejn-change-cell-type)
    (define-key map (kbd "C-c C-e") #'ejn-toggle-output)
    (define-key map (kbd "C-c C-w") #'ejn-copy-cell)
    (define-key map (kbd "C-c C-y") #'ejn-yank-cell)
    (define-key map (kbd "C-c <down>") #'ejn-move-cell-down)
    (define-key map (kbd "C-c <up>") #'ejn-move-cell-up)
    (define-key map (kbd "C-<down>") #'ejn-goto-next-cell)
    (define-key map (kbd "C-<up>") #'ejn-goto-prev-cell)
    (define-key map (kbd "M-<down>") #'ejn-move-cell-down)
    (define-key map (kbd "M-<up>") #'ejn-move-cell-up)
    (define-key map (kbd "M-RET") #'ejn-execute-cell-and-goto-next)
    (define-key map (kbd "M-S-<return>") #'ejn-execute-cell-and-insert-below)
    (define-key map (kbd "C-x C-s") #'ejn-save-notebook)
    (define-key map (kbd "C-c C-S-l") #'ejn-clear-all-outputs)
    (define-key map (kbd "C-c C-q") #'ejn-kernel-quit)
    (define-key map (kbd "C-c C-z") #'ejn-kernel-interrupt)
    (define-key map (kbd "C-c C-x C-r") #'ejn-kernel-restart)
    map)
  "Keymap for `ejn-mode'.")

(define-derived-mode ejn-mode text-mode "EJN"
  "Major mode for editing Jupyter notebooks.

This mode provides cell-aware editing for Jupyter notebook files.
Cells are identified by text properties and can be navigated,
inserted, deleted, split, merged, and moved.

\\{ejn-mode-map}"
  :group 'ejn
  (set (make-local-variable 'ejn--notebook) nil)
  (set (make-local-variable 'ejn--sync-timer) nil)
  (set (make-local-variable 'ejn--rendering-p) nil)
  (set (make-local-variable 'ejn--pending-sync-set) nil)
  (set (make-local-variable 'ejn--cell-kill-ring) nil)
  (add-to-invisibility-spec '(ejn-folded-output))
  (add-hook 'kill-buffer-hook #'ejn--cleanup-buffer nil t)
  (ejn-sync-mode))

(defun ejn--cleanup-buffer ()
  "Clean up buffer-local resources when exiting ejn-mode."
  (when (and (boundp 'ejn--sync-timer) ejn--sync-timer)
    (cancel-timer ejn--sync-timer)
    (setq ejn--sync-timer nil)))

(defun ejn-kernel-quit ()
  "Quit the kernel session.  Not yet implemented."
  (interactive)
  (user-error "Kernel not connected. Available in Phase 4."))

(defun ejn-kernel-interrupt ()
  "Interrupt the kernel.  Not yet implemented."
  (interactive)
  (user-error "Kernel not connected. Available in Phase 4."))

(defun ejn-kernel-restart ()
  "Restart the kernel.  Not yet implemented."
  (interactive)
  (user-error "Kernel not connected. Available in Phase 4."))

(defun ejn-open (file-path)
  "Open a Jupyter notebook file at FILE-PATH.
Loads the notebook, creates a buffer in ejn-mode, and renders it."
  (interactive "fOpen notebook: ")
  (unless (file-exists-p file-path)
    (user-error "File not found: %s" file-path))
  (let ((notebook (ejn-model-from-file file-path)))
    (with-current-buffer (get-buffer-create (concat "*ejn: " (file-name-nondirectory file-path) "*"))
      (ejn-mode)
      (set (make-local-variable 'ejn--notebook) notebook)
      (set (make-local-variable 'buffer-file-name) file-path)
      (ejn-render-notebook notebook)
      (display-buffer (current-buffer)))))

(defun ejn-save-notebook ()
  "Save the current notebook to its file."
  (interactive)
  (let ((notebook ejn--notebook)
        (path buffer-file-name))
    (unless notebook
      (user-error "No notebook loaded in this buffer"))
    (unless path
      (user-error "No file path set for this notebook"))
    (ejn-model-to-file notebook path)
    (ejn-notebook-clean-all notebook)
    (message "Notebook saved: %s" path)))

(provide 'ejn-mode)
;;; ejn-mode.el ends here
