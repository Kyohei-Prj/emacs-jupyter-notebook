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
(require 'ejn-kernel)
(require 'ejn-kernel-jupyter)
(require 'ejn-execute)

(defvar-local ejn--notebook nil
  "Current notebook model for this buffer.")

(defvar-local ejn--kernel nil
  "Current kernel instance for this buffer.")

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
    (define-key map (kbd "C-c C-x C-c") #'ejn-kernel-reconnect-command)
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
  (ejn-sync-mode)
  (add-hook 'ejn-kernel-dead-hook #'ejn-update-header-line nil t)
  (ejn-update-header-line))

(defun ejn--cleanup-buffer ()
  "Clean up buffer-local resources when exiting ejn-mode."
  (when (and (boundp 'ejn--sync-timer) ejn--sync-timer)
    (cancel-timer ejn--sync-timer)
    (setq ejn--sync-timer nil)))

(defun ejn-kernel-quit ()
  "Quit the kernel session."
  (interactive)
  (when (buffer-local-value 'ejn--kernel (current-buffer))
    (ejn--kernel-shutdown (buffer-local-value 'ejn--kernel (current-buffer)))
    (set (make-local-variable 'ejn--kernel) nil)
    (message "Kernel shut down")))

(defun ejn-kernel-interrupt ()
  "Interrupt the running kernel."
  (interactive)
  (let ((kernel (buffer-local-value 'ejn--kernel (current-buffer))))
    (unless kernel
      (user-error "No kernel connected"))
    (ejn--kernel-interrupt kernel)
    (message "Kernel interrupted")))

(defun ejn-kernel-restart ()
  "Restart the kernel."
  (interactive)
  (let ((kernel (buffer-local-value 'ejn--kernel (current-buffer))))
    (unless kernel
      (user-error "No kernel connected"))
    (ejn--kernel-restart kernel)
    (message "Kernel restarting")))

(defun ejn-update-header-line ()
  "Update the header line with kernel state and dirty indicator."
  (let ((kernel-state "")
        (dirty-indicator ""))
    (when ejn--kernel
      (setq kernel-state (format " [%s]" (ejn-kernel-state ejn--kernel))))
    (when (and ejn--notebook (ejn-notebook-dirty ejn--notebook))
      (setq dirty-indicator " *"))
    (setq header-line-format
          (format "EJN%s%s" kernel-state dirty-indicator))))

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
      (ejn--start-kernel notebook)
      (display-buffer (current-buffer)))))

(defun ejn--start-kernel (notebook)
  "Start a kernel for NOTEBOOK based on its kernelspec metadata."
  (let ((kernelspec (ejn--extract-kernelspec notebook)))
    (when kernelspec
      (set (make-local-variable 'ejn--kernel) (ejn-make-kernel kernelspec))
      (condition-case err
          (ejn-kernel-start (buffer-local-value 'ejn--kernel (current-buffer)) kernelspec)
        (error
         (message "Failed to start kernel (%s). Connect manually with M-x ejn-connect-to-kernel."
                  (error-message-string err)))
        (set (make-local-variable 'ejn--kernel) nil))))
  (add-hook 'kill-buffer-hook #'ejn--shutdown-kernel-on-kill nil t))

(defun ejn--extract-kernelspec (notebook)
  "Extract the kernelspec name from NOTEBOOK's metadata."
  (let ((metadata (ejn-notebook-metadata notebook)))
    (when metadata
      (let ((kernelspec (cdr (assq :kernelspec metadata))))
        (when kernelspec
          (cdr (assq :name kernelspec)))))))

(defun ejn--shutdown-kernel-on-kill ()
  "Shutdown kernel when buffer is killed."
  (let ((kernel (buffer-local-value 'ejn--kernel (current-buffer))))
    (when kernel
      (condition-case nil
          (ejn--kernel-shutdown kernel)
        (error nil))
      (set (make-local-variable 'ejn--kernel) nil))))

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
