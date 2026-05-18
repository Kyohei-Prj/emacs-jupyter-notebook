;;; ejn-render.el --- Buffer projection renderer  -*- lexical-binding: t; -*-

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

;; Buffer projection renderer for Jupyter notebooks.

;;; Code:

(require 'cl-lib)
(require 'ejn-cell)
(require 'ejn-model)
(require 'ejn-mime)

(defface ejn-cell-idle
  '((((class color)) :foreground "grey50"))
  "Face for idle cell execution state."
  :group 'ejn)

(defface ejn-cell-queued
  '((((class color)) :foreground "blue"))
  "Face for queued cell execution state."
  :group 'ejn)

(defface ejn-cell-executing
  '((((class color)) :foreground "goldenrod1" :background "grey20"))
  "Face for executing cell execution state."
  :group 'ejn)

(defface ejn-cell-streaming
  '((((class color)) :foreground "yellow" :background "grey20"))
  "Face for streaming cell execution state."
  :group 'ejn)

(defface ejn-cell-completed
  '((((class color)) :foreground "green"))
  "Face for completed cell execution state."
  :group 'ejn)

(defface ejn-cell-error
  '((((class color)) :foreground "red"))
  "Face for error cell execution state."
  :group 'ejn)

(defface ejn-cell-interrupted
  '((((class color)) :foreground "orange"))
  "Face for interrupted cell execution state."
  :group 'ejn)

(defun ejn--execution-state-face (state)
  "Return the face symbol for execution STATE.
Returns `ejn-cell-idle' for unknown states."
  (pcase state
    ('idle 'ejn-cell-idle)
    ('queued 'ejn-cell-queued)
    ('executing 'ejn-cell-executing)
    ('streaming 'ejn-cell-streaming)
    ('completed 'ejn-cell-completed)
    ('error 'ejn-cell-error)
    ('interrupted 'ejn-cell-interrupted)
    (_ 'ejn-cell-idle)))

(defun ejn-render-cell (cell &optional buffer)
  "Render CELL into BUFFER (current buffer if nil).
Inserts source text with cell text properties and execution state face."
  (with-current-buffer (or buffer (current-buffer))
    (let* ((source (ejn-cell-source cell))
           (cell-id (ejn-cell-id cell))
           (cell-type (ejn-cell-type cell))
           (state (ejn-cell-execution-state cell))
           (face (ejn--execution-state-face state)))
      (if (string= source "")
          (progn
            (insert "\n")
            (put-text-property (1- (point)) (point) 'ejn-cell-id cell-id)
            (put-text-property (1- (point)) (point) 'ejn-cell-type cell-type)
            (put-text-property (1- (point)) (point) 'face face))
        (let* ((margin-char (propertize (substring source 0 1)
                                        'face (list face)
                                        'display '(space :width 0.8)))
               (rest (substring source 1))
               (rendered (concat margin-char rest "\n")))
          (insert rendered)
          (let ((start (- (point) (length rendered)))
                (end (1- (point))))
            (put-text-property start end 'ejn-cell-id cell-id)
            (put-text-property start end 'ejn-cell-type cell-type)))))))

(defun ejn--best-mime-data (mime-data)
  "Return (MIME-TYPE . DATA-LIST) for the best rendering of MIME-DATA.
Prefers image types, then text types."
  (let ((priority-order '("image/svg+xml" "image/png" "text/html" "text/markdown" "text/plain")))
    (cl-loop for mime in priority-order
             for data = (alist-get (intern mime) mime-data)
             when data return (cons mime data))))

(defun ejn-render-outputs (cell &optional buffer)
  "Render CELL's outputs into BUFFER (current buffer if nil).
Inserts output content in a read-only zone after the cell's source.
Preserves point position."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (let ((outputs (ejn-cell-outputs cell)))
        (when outputs
          (let ((zone-start (point)))
            (insert "\n")
            (dolist (output outputs)
              (let ((output-type (ejn-output-type output)))
                (pcase output-type
                  ('error
                   (let ((traceback (plist-get (ejn-output-mime-data output) 'traceback)))
                     (when traceback
                       (insert (mapconcat #'identity
                                          (if (listp (car traceback)) (car traceback) traceback)
                                          "")
                               "\n"))))
                  (_
                   (let ((mime-data (plist-get (or (ejn-output-mime-data output) (list)) :data)))
                     (when mime-data
                       (let ((best (ejn--best-mime-data mime-data)))
                         (when best
                           (let ((handler (ejn-mime-handler-for (car best))))
                             (when handler
                               (let ((rendered (funcall handler (cdr best))))
                                 (if (imagep rendered)
                                     (insert-image rendered " ")
                                   (insert rendered "\n")))))))))))
		) ;; end let output-type
              ) ;; end dolist
            (put-text-property zone-start (point) 'ejn-output-zone t)
            (put-text-property zone-start (point) 'rear-nonsticky t)
            (put-text-property zone-start (point) 'read-only t)
            ) ;; end let zone-start
          ) ;; end when
	) ;; end let outputs
      ) ;; end save-excursion
    ) ;; end with-current-buffer
  ) ;; end defun

(defvar-local ejn--rendering-p nil
  "Non-nil while a full notebook render is in progress.
Buffer-local.  Used to suppress incremental sync callbacks.")

(defun ejn-render-notebook (notebook &optional buffer)
  "Render all cells of NOTEBOOK into BUFFER (current buffer if nil).
Clears the buffer first.  Sets text properties for cell structure."
  (with-current-buffer (or buffer (current-buffer))
    (let ((ejn--rendering-p t))
      (let ((inhibit-read-only t))
        (erase-buffer))
      (dolist (cell (cl-coerce (ejn-notebook-cells notebook) 'list))
        (ejn-render-cell cell)
        (ejn-render-outputs cell))
      (setq ejn--rendering-p nil)
      (goto-char (point-min)))))

(defun ejn--find-cell-region (cell-id)
  "Find the source region for CELL-ID in current buffer.
Returns (START . END) or nil."
  (save-excursion
    (goto-char (point-min))
    (let ((start (point)))
      (while (and start (< start (point-max))
                  (not (string= (get-text-property start 'ejn-cell-id) cell-id)))
        (setq start (next-single-property-change start 'ejn-cell-id nil (point-max))))
      (when (and start (< start (point-max)))
        (let ((end (next-single-property-change start 'ejn-cell-id nil (point-max))))
          (cons start end))))))

(defun ejn-render-dirty-cells (notebook &optional buffer)
  "Re-render only dirty cells in NOTEBOOK within BUFFER.
Reads dirty set, re-renders affected regions, clears dirty set."
  (with-current-buffer (or buffer (current-buffer))
    (let ((ejn--rendering-p t)
          (dirty-ids (ejn-notebook-dirty-cells notebook)))
      (dolist (cell-id dirty-ids)
        (let ((cell (condition-case nil
                        (ejn-notebook-cell-by-id notebook cell-id)
                      (error nil)))
              (region (ejn--find-cell-region cell-id)))
          (when (and cell region)
            (delete-region (car region) (cdr region))
            (goto-char (car region))
            (ejn-render-cell cell)
            (let ((after-source (point)))
              (when (< after-source (point-max))
                (let ((zone-start (ejn--find-next-output-zone-start after-source)))
                  (when zone-start
                    (let ((output-region (ejn--find-output-zone-region zone-start)))
                      (when output-region
                        (let ((inhibit-read-only t))
                          (delete-region (car output-region) (cdr output-region))))))))
              (ejn-render-outputs cell)))))
      (ejn-notebook-clean-all notebook)
      (setq ejn--rendering-p nil))))

(defconst ejn-folded-output 'ejn-folded-output
  "Invisibility spec symbol for folded output zones.")

(defun ejn--find-parent-cell-id (pos)
  "Find the parent cell ID by scanning backward from POS."
  (save-excursion
    (goto-char pos)
    (cl-loop
     while (> (point) (point-min))
     do (backward-char)
     for id = (get-text-property (point) 'ejn-cell-id)
     when id return id
     finally return nil)))

(defun ejn--find-next-output-zone-start (after-source)
  "Find the start of the next output zone after AFTER-SOURCE.
Returns the position or nil."
  (save-excursion
    (goto-char after-source)
    (cl-loop
     while (< (point) (point-max))
     do (if (get-text-property (point) 'ejn-output-zone)
            (cl-return (point))
          (forward-char 1))
     finally return nil)))

(defun ejn--find-output-zone-region (start)
  "Find the output zone region starting at START.
Returns (START . END) or nil."
  (when (get-text-property start 'ejn-output-zone)
    (let ((end (next-single-property-change start 'ejn-output-zone nil (point-max))))
      (cons start end))))

(defun ejn-render--full-cell-region (cell-id)
  "Return (START . END) covering both source and output zone for CELL-ID.
Returns nil if CELL-ID is not found in the buffer."
  (let ((source-region (ejn--find-cell-region cell-id)))
    (when source-region
      (let* ((after-source (cdr source-region))
             (zone-start (and (< after-source (point-max))
                              (ejn--find-next-output-zone-start after-source)))
             (next-cell-start (and (< after-source (point-max))
                                   (save-excursion
                                     (goto-char after-source)
                                     (while (and (< (point) (point-max))
                                                 (not (get-text-property (point) 'ejn-cell-id)))
                                       (forward-char))
                                     (when (< (point) (point-max))
                                       (point))))))
        (when (and zone-start
                   (or (not next-cell-start)
                       (< zone-start next-cell-start)))
          (let ((output-region (ejn--find-output-zone-region zone-start)))
            (when output-region
              (setq source-region (cons (car source-region)
                                        (cdr output-region)))))))
      source-region)))

(defun ejn-render--delete-cell-region (cell-id)
  "Delete the buffer region for CELL-ID, including source and outputs."
  (let ((region (ejn-render--full-cell-region cell-id)))
    (when region
      (let ((inhibit-read-only t))
        (delete-region (car region) (cdr region))))))

(defun ejn-render--insert-cell-at-point (cell)
  "Render CELL's source and outputs at point."
  (ejn-render-cell cell)
  (ejn-render-outputs cell))

(defun ejn-toggle-output ()
  "Toggle visibility of the output zone for the current cell.
If output is visible, fold it.  If folded, unfold it."
  (interactive)
  (let ((cell-id (get-text-property (point) 'ejn-cell-id))
        (in-output-zone (get-text-property (point) 'ejn-output-zone)))
    (unless (or cell-id in-output-zone)
      (user-error "Not in a cell"))
    (unless cell-id
      (setq cell-id (ejn--find-parent-cell-id (point))))
    ;; Find the output zone after the cell's source region
    (let ((region (ejn--find-cell-region cell-id)))
      (when region
        (let ((after-source (cdr region)))
          (when (< after-source (point-max))
            (let ((zone-start (ejn--find-next-output-zone-start after-source)))
              (when zone-start
                (let ((output-region (ejn--find-output-zone-region zone-start)))
                  (when output-region
                    (let ((currently-folded
                           (get-text-property (car output-region) 'invisible)))
                      (let ((inhibit-read-only t))
                        (if currently-folded
                            (put-text-property (car output-region)
                                               (cdr output-region)
                                               'invisible nil)
                          (put-text-property (car output-region)
                                             (cdr output-region)
                                             'invisible ejn-folded-output)
                          (add-to-invisibility-spec
                           '(ejn-folded-output))))))))))))
      (unless (memq ejn-folded-output buffer-invisibility-spec)
        (add-to-invisibility-spec '(ejn-folded-output))))))

(provide 'ejn-render)
;;; ejn-render.el ends here
