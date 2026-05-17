;;; ejn-sync.el --- After-change hook and debounced sync  -*- lexical-binding: t; -*-

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

;; Detects user edits in the buffer and updates the notebook model
;; with debounced batching.

;;; Code:

(require 'cl-lib)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-navigation)

(defcustom ejn-sync-debounce-seconds 0.2
  "Seconds to wait after typing before syncing buffer to model.
Set to 0 for real-time sync."
  :type 'number
  :group 'ejn)

(defcustom ejn-after-sync-hook nil
  "Hook run after buffer-to-model sync completes.
Useful for LSP integration."
  :type 'hook
  :group 'ejn)

(defvar-local ejn--sync-timer nil
  "Debounced sync timer for current buffer.")

(defvar-local ejn--pending-sync-set nil
  "Hash table of cell IDs pending sync.
Keys are cell ID strings, values are t.")

(defun ejn--after-change-handler (start _end _prepended)
  "Handle buffer change for syncing to the notebook model.
START is the start position of the change.
_END is the end position of the change (after the change).
_PREPENDED is the number of characters inserted."
  (when (not ejn--rendering-p)
    (let ((in-output-zone-p
           (save-excursion
             (goto-char start)
             (get-text-property (point) 'ejn-output-zone)))
          (cell-id
           (save-excursion
             (goto-char start)
             (ejn--find-cell-id-at-point))))
      (unless in-output-zone-p
        (when cell-id
          (unless ejn--pending-sync-set
            (setq ejn--pending-sync-set (make-hash-table :test 'equal)))
          (puthash cell-id t ejn--pending-sync-set)
          (ejn--schedule-sync))))))

(defun ejn--schedule-sync ()
  "Schedule a debounced sync of the buffer to the notebook model.
Cancels any pending sync timer and creates a new one."
  (when ejn--sync-timer
    (cancel-timer ejn--sync-timer)
    (setq ejn--sync-timer nil))
  (setq ejn--sync-timer
        (run-with-timer ejn-sync-debounce-seconds
                        nil
                        'ejn--perform-sync)))

(defun ejn--perform-sync ()
  "Sync pending cell edits from buffer to the notebook model.
Called by the debounce timer after user edits.
Reads the current buffer content for each pending cell ID
and updates the model if the source has changed."
  (setq ejn--sync-timer nil)
  (when (and ejn--pending-sync-set
             (buffer-local-value 'ejn--notebook (current-buffer)))
    (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
          (any-changed nil))
      (maphash
       (lambda (cell-id _value)
         (let ((region (ejn--find-cell-region cell-id)))
           (when region
             (let ((new-source (buffer-substring-no-properties
                                (car region) (cdr region))))
               (condition-case nil
                   (let ((cell (ejn-notebook-cell-by-id notebook cell-id)))
                     (when (not (string= new-source (ejn-cell-source cell)))
                       (ejn-notebook-set-cell-source
                        notebook cell-id new-source)
                       (setq any-changed t)))
                 (error nil))))))
       ejn--pending-sync-set)
      (when any-changed
        (run-hooks 'ejn-after-sync-hook))
      (setq ejn--pending-sync-set (make-hash-table :test 'equal)))))

(defun ejn--cleanup-sync ()
  "Clean up sync resources when buffer is killed."
  (when ejn--sync-timer
    (cancel-timer ejn--sync-timer)
    (setq ejn--sync-timer nil)))

(defun ejn-sync-mode ()
  "Enable or disable sync for the current buffer.
Toggles based on whether the after-change hook is installed."
  (interactive)
  (if (memq #'ejn--after-change-handler after-change-functions)
      (progn
        (remove-hook 'after-change-functions #'ejn--after-change-handler t)
        (ejn--cleanup-sync))
    (add-hook 'after-change-functions #'ejn--after-change-handler nil t)
    (setq ejn--pending-sync-set (make-hash-table :test 'equal))))

(provide 'ejn-sync)
;;; ejn-sync.el ends here
