;;; ejn-undo.el --- Emacs undo integration  -*- lexical-binding: t; -*-

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

;; Bridges Emacs buffer undo with the model's transactional undo system.
;; Provides an undo boundary macro and interactive undo/redo commands.

;;; Code:

(require 'cl-lib)
(require 'ejn-model)
(require 'ejn-render)

(defmacro ejn-with-undo-boundary (_label &rest body)
  "Wrap BODY in Emacs undo boundaries.
Ensures all buffer modifications in BODY are grouped as a single undo step."
  (declare (indent 1))
  `(progn
     (undo-boundary)
     ,@body
     (undo-boundary)))

(defun ejn-undo-command ()
  "Undo the last operation on the notebook model and re-render."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (condition-case err
        (progn
          (ejn-undo notebook)
          (ejn-render-notebook notebook))
      (user-error
       (signal (car err) (cdr err))))))

(defun ejn-redo-command ()
  "Redo the last undone operation on the notebook model and re-render."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (condition-case err
        (progn
          (ejn-redo notebook)
          (ejn-render-notebook notebook))
      (user-error
       (signal (car err) (cdr err))))))

(provide 'ejn-undo)
;;; ejn-undo.el ends here
