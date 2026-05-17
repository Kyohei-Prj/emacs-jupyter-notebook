;;; ejn-navigation.el --- Cell navigation commands  -*- lexical-binding: t; -*-

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

;; Structural motion commands operating on cell boundaries.

;;; Code:

(require 'cl-lib)
(require 'ejn-cell)
(require 'ejn-model)

(defun ejn--find-cell-id-at-point ()
  "Return the cell ID text property at point.
If point is not in a source region (e.g., in an output zone),
scans backward to find the nearest cell ID."
  (let ((cell-id (get-text-property (point) 'ejn-cell-id)))
    (unless cell-id
      (save-excursion
        (while (and (> (point) (point-min)) (not cell-id))
          (backward-char)
          (setq cell-id (get-text-property (point) 'ejn-cell-id)))))
    cell-id))

(defun ejn-cell-at-point ()
  "Return the `ejn-cell' struct at point, or signal an error.
If point is in an output zone, finds the parent cell by scanning backward."
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((cell-id (ejn--find-cell-id-at-point)))
      (unless cell-id
        (user-error "Not in a cell"))
      (ejn-notebook-cell-by-id notebook cell-id))))

(defun ejn-cell-region ()
  "Return (START . END) of the current cell's source region.
Excludes the output zone."
  (let ((cell-id (ejn--find-cell-id-at-point)))
    (unless cell-id
      (user-error "Not in a cell"))
    (save-excursion
      (goto-char (point-min))
      (let ((start (point)))
        (while (and (< start (point-max))
                    (not (string= (get-text-property start 'ejn-cell-id)
                                  cell-id)))
          (setq start (next-single-property-change
                       start 'ejn-cell-id nil (point-max))))
        (when (< start (point-max))
          (let ((end (next-single-property-change
                      start 'ejn-cell-id nil (point-max))))
            (cons start end)))))))

(defun ejn-cell-full-region ()
  "Return (START . END) of the current cell including output zone."
  (let* ((source-region (ejn-cell-region))
         (start (car source-region))
         (end (cdr source-region)))
    (save-excursion
      (goto-char end)
      (while (and (< (point) (point-max))
                  (not (get-text-property (point) 'ejn-output-zone)))
        (forward-char))
      (when (get-text-property (point) 'ejn-output-zone)
        (while (and (< (point) (point-max))
                    (get-text-property (point) 'ejn-output-zone))
          (forward-char))
        (setq end (point))))
    (cons start end)))

(defun ejn--goto-cell-by-id (cell-id)
  "Move point to the end of the cell with CELL-ID."
  (goto-char (point-min))
  (while (and (< (point) (point-max))
              (not (string= (get-text-property (point) 'ejn-cell-id) cell-id)))
    (forward-char))
  (when (string= (get-text-property (point) 'ejn-cell-id) cell-id)
    (while (and (< (point) (point-max))
                (string= (get-text-property (point) 'ejn-cell-id) cell-id))
      (forward-char))))

(defun ejn-goto-next-cell ()
  "Move point to the start of the next cell's source region."
  (interactive)
  (let ((current-id (get-text-property (point) 'ejn-cell-id))
        (next-id nil))
    (unless current-id
      (setq current-id (ejn--find-cell-id-at-point)))
    (save-excursion
      (goto-char (1+ (point)))
      (while (and (< (point) (point-max)) (not next-id))
        (let ((id (get-text-property (point) 'ejn-cell-id)))
          (when (and id (not (string= id current-id)))
            (setq next-id id)))
        (forward-char)))
    (if next-id
        (ejn--goto-cell-by-id next-id)
      (user-error "Already at last cell"))))

(defun ejn-goto-prev-cell ()
  "Move point to the start of the previous cell's source region."
  (interactive)
  (let ((current-id (get-text-property (point) 'ejn-cell-id))
        (prev-id nil))
    (unless current-id
      (setq current-id (ejn--find-cell-id-at-point)))
    (save-excursion
      (while (and (> (point) (point-min)) (not prev-id))
        (backward-char)
        (let ((id (get-text-property (point) 'ejn-cell-id)))
          (when (and id (not (string= id current-id)))
            (setq prev-id id)))))
    (if prev-id
        (ejn--goto-cell-by-id prev-id)
      (user-error "Already at first cell"))))

(defun ejn-goto-first-cell ()
  "Move point to the start of the first cell."
  (interactive)
  (goto-char (point-min)))

(defun ejn-goto-last-cell ()
  "Move point to the start of the last cell's source region."
  (interactive)
  (let ((last-id nil))
    (save-excursion
      (goto-char (1- (point-max)))
      (while (and (> (point) (point-min)) (not last-id))
        (let ((id (get-text-property (point) 'ejn-cell-id)))
          (when id (setq last-id id)))
        (backward-char)))
    (if last-id
        (ejn--goto-cell-by-id last-id)
      (goto-char (point-min)))))

(provide 'ejn-navigation)
;;; ejn-navigation.el ends here
