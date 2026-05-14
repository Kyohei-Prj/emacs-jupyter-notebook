;;; ejn-cell-engine.el --- Cell structural operations  -*- lexical-binding: t; -*-

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

;; Cell insert, delete, split, merge, move, copy, and yank operations.
;; Model-first: mutate the model, then render.

;;; Code:

(require 'cl-lib)
(require 'ejn-cell)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-navigation)
(require 'ejn-undo)

(defvar-local ejn--cell-kill-ring nil
  "Kill ring for copied cells.  Each entry is a serialized cell plist.")

(defun ejn--goto-cell-start-by-id (cell-id)
  "Move point to the start of the cell with CELL-ID."
  (goto-char (point-min))
  (while (and (< (point) (point-max))
              (not (string= (get-text-property (point) 'ejn-cell-id) cell-id)))
    (forward-char)))

(defun ejn-insert-cell-above ()
  "Insert a new code cell above the current cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((idx (ejn-notebook-cell-index notebook (ejn-cell-id current-cell))))
      (ejn-with-undo-group "Insert cell above" notebook
        (ejn-with-undo-boundary "Insert cell above"
          (let ((new-cell (ejn-notebook-insert-cell notebook 'code :at idx)))
            (ejn-render-notebook notebook)
            (ejn--goto-cell-start-by-id (ejn-cell-id new-cell))))))))

(defun ejn-insert-cell-below ()
  "Insert a new code cell below the current cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((idx (ejn-notebook-cell-index notebook (ejn-cell-id current-cell))))
      (ejn-with-undo-group "Insert cell below" notebook
        (ejn-with-undo-boundary "Insert cell below"
          (let ((new-cell (ejn-notebook-insert-cell notebook 'code :at (1+ idx))))
            (ejn-render-notebook notebook)
            (ejn--goto-cell-start-by-id (ejn-cell-id new-cell))))))))

(provide 'ejn-cell-engine)
;;; ejn-cell-engine.el ends here
