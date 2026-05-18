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
						     (let ((region (ejn-render--full-cell-region (ejn-cell-id current-cell))))
						       (when region
							 (let ((insert-point (car region))
							       (inhibit-read-only t))
							   (delete-region (car region) (cdr region))
							   (goto-char insert-point))))
						     (let ((ejn--rendering-p t))
						       (ejn-render--insert-cell-at-point new-cell)
						       (ejn-render--insert-cell-at-point current-cell))
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
						     (let ((region (ejn-render--full-cell-region (ejn-cell-id current-cell))))
						       (when region
							 (goto-char (cdr region))))
						     (let ((ejn--rendering-p t))
						       (ejn-render--insert-cell-at-point new-cell))
						     (ejn--goto-cell-start-by-id (ejn-cell-id new-cell))))))))

(defun ejn-delete-cell ()
  "Delete the current cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((cell-id (ejn-cell-id current-cell)))
      (ejn-with-undo-group "Delete cell" notebook
			   (ejn-with-undo-boundary "Delete cell"
						   (ejn-notebook-delete-cell notebook cell-id)
						   (let ((ejn--rendering-p t))
						     (ejn-render--delete-cell-region cell-id))
						   (goto-char (point-min)))))))

(defun ejn-split-cell ()
  "Split the current cell at point into two cells."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let* ((cell-id (ejn-cell-id current-cell))
           (source (ejn-cell-source current-cell))
           (region (ejn-cell-region))
           (split-pos (- (point) (car region))))
      (when (>= split-pos (length source))
        (setq split-pos (1- (length source))))
      (when (<= split-pos 0)
        (setq split-pos 1))
      (let ((part1 (substring source 0 split-pos))
            (part2 (substring source split-pos)))
        (ejn-with-undo-group "Split cell" notebook
			     (ejn-with-undo-boundary "Split cell"
						     (ejn-notebook-set-cell-source notebook cell-id part1)
						     (let* ((idx (ejn-notebook-cell-index notebook cell-id))
							    (new-cell (ejn-notebook-insert-cell notebook (ejn-cell-type current-cell) :at (1+ idx))))
						       (setf (ejn-cell-source new-cell) part2)
						       (let ((full-region (ejn-render--full-cell-region cell-id)))
							 (when full-region
							   (let ((insert-point (car full-region))
								 (inhibit-read-only t))
							     (delete-region (car full-region) (cdr full-region))
							     (goto-char insert-point))))
						       (let ((ejn--rendering-p t))
							 (ejn-render--insert-cell-at-point current-cell)
							 (ejn-render--insert-cell-at-point new-cell))
						       (ejn--goto-cell-start-by-id (ejn-cell-id new-cell)))))))))

(defun ejn-merge-cell ()
  "Merge the current cell with the next cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let* ((current-id (ejn-cell-id current-cell))
           (idx (ejn-notebook-cell-index notebook current-id))
           (next-cell (ejn-notebook-cell-at-index notebook (1+ idx))))
      (unless next-cell
        (user-error "No next cell to merge"))
      (let ((merged-source (concat (ejn-cell-source current-cell)
                                   "\n"
                                   (ejn-cell-source next-cell)
                                   "\n"))
            (next-id (ejn-cell-id next-cell)))
        (ejn-with-undo-group "Merge cell" notebook
			     (ejn-with-undo-boundary "Merge cell"
						     (ejn-notebook-set-cell-source notebook current-id merged-source)
						     (ejn-notebook-delete-cell notebook next-id)
						     (let ((region1 (ejn-render--full-cell-region current-id))
							   (region2 (ejn-render--full-cell-region next-id)))
						       (when (and region1 region2)
							 (let ((inhibit-read-only t))
							   (delete-region (car region1) (cdr region2))
							   (goto-char (car region1)))))
						     (let ((ejn--rendering-p t))
						       (ejn-render--insert-cell-at-point current-cell))
						     (ejn--goto-cell-start-by-id current-id)))))))

(defun ejn-move-cell-up ()
  "Move the current cell up by swapping with the previous cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let* ((idx (ejn-notebook-cell-index notebook (ejn-cell-id current-cell)))
           (cells (ejn-notebook-cells notebook)))
      (unless idx
        (user-error "Already at first cell"))
      (let ((prev-cell (aref cells (1- idx)))
            (curr-cell (aref cells idx)))
        (ejn-with-undo-group "Move cell up" notebook
			     (ejn-with-undo-boundary "Move cell up"
						     (setf (ejn-notebook-cells notebook)
							   (vconcat (seq-take cells (1- idx))
								    (vector curr-cell prev-cell)
								    (seq-drop cells (+ idx 2))))
						     (let ((prev-region (ejn-render--full-cell-region (ejn-cell-id prev-cell)))
							   (curr-region (ejn-render--full-cell-region (ejn-cell-id curr-cell))))
						       (when (and prev-region curr-region)
							 (let ((inhibit-read-only t))
							   (delete-region (car prev-region) (cdr curr-region))
							   (goto-char (car prev-region)))))
						     (let ((ejn--rendering-p t))
						       (ejn-render--insert-cell-at-point curr-cell)
						       (ejn-render--insert-cell-at-point prev-cell))
						     (ejn--goto-cell-start-by-id (ejn-cell-id curr-cell))))))))

(defun ejn-move-cell-down ()
  "Move the current cell down by swapping with the next cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let* ((idx (ejn-notebook-cell-index notebook (ejn-cell-id current-cell)))
           (total (length (ejn-notebook-cells notebook)))
           (cells (ejn-notebook-cells notebook)))
      (when (>= idx (1- total))
        (user-error "Already at last cell"))
      (let ((curr-cell (aref cells idx))
            (next-cell (aref cells (1+ idx))))
        (ejn-with-undo-group "Move cell down" notebook
			     (ejn-with-undo-boundary "Move cell down"
						     (setf (ejn-notebook-cells notebook)
							   (vconcat (seq-take cells idx)
								    (vector next-cell curr-cell)
								    (seq-drop cells (+ idx 3))))
						     (let ((curr-region (ejn-render--full-cell-region (ejn-cell-id curr-cell)))
							   (next-region (ejn-render--full-cell-region (ejn-cell-id next-cell))))
						       (when (and curr-region next-region)
							 (let ((inhibit-read-only t))
							   (delete-region (car curr-region) (cdr next-region))
							   (goto-char (car curr-region)))))
						     (let ((ejn--rendering-p t))
						       (ejn-render--insert-cell-at-point next-cell)
						       (ejn-render--insert-cell-at-point curr-cell))
						     (ejn--goto-cell-start-by-id (ejn-cell-id curr-cell))))))))

(defun ejn-toggle-cell-type ()
  "Cycle the current cell's type: code -> markdown -> raw -> code."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((new-type (pcase (ejn-cell-type current-cell)
                      ('code 'markdown)
                      ('markdown 'raw)
                      ('raw 'code)
                      (_ 'code))))
      (ejn-with-undo-group "Toggle cell type" notebook
			   (setf (ejn-cell-type current-cell) new-type)
			   (ejn-notebook-mark-dirty notebook (ejn-cell-id current-cell))
			   (ejn-with-undo-boundary "Toggle cell type"
						   (ejn-render-dirty-cells notebook))))))

(defun ejn-change-cell-type ()
  "Prompt for a cell type and set the current cell's type."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((type-str (completing-read "Cell type: "
                                     '("code" "markdown" "raw")
                                     nil t)))
      (let ((new-type (intern type-str)))
        (ejn-with-undo-group "Change cell type" notebook
			     (setf (ejn-cell-type current-cell) new-type)
			     (ejn-notebook-mark-dirty notebook (ejn-cell-id current-cell))
			     (ejn-with-undo-boundary "Change cell type"
						     (ejn-render-dirty-cells notebook)))))))

(defun ejn-clear-output ()
  "Clear the output of the current cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (ejn-with-undo-group "Clear output" notebook
			 (setf (ejn-cell-outputs current-cell) nil)
			 (ejn-notebook-mark-dirty notebook (ejn-cell-id current-cell))
			 (ejn-with-undo-boundary "Clear output"
						 (ejn-render-dirty-cells notebook)))))

(defun ejn-clear-all-outputs ()
  "Clear outputs of all cells."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (ejn-with-undo-group "Clear all outputs" notebook
			 (cl-loop for cell across (ejn-notebook-cells notebook) do
				  (setf (ejn-cell-outputs cell) nil)
				  (ejn-notebook-mark-dirty notebook (ejn-cell-id cell)))
			 (ejn-with-undo-boundary "Clear all outputs"
						 (ejn-render-notebook notebook)))))

(defun ejn-copy-cell ()
  "Copy the current cell to the cell kill ring."
  (interactive)
  (let ((current-cell (ejn-cell-at-point)))
    (push (list :id (ejn-cell-id current-cell)
                :type (ejn-cell-type current-cell)
                :source (ejn-cell-source current-cell)
                :outputs (ejn-cell-outputs current-cell)
                :metadata (ejn-cell-metadata current-cell))
          ejn--cell-kill-ring)
    (message "Cell copied to kill ring")))

(defun ejn-yank-cell ()
  "Insert a copied cell below the current cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (unless ejn--cell-kill-ring
      (user-error "No cell in kill ring"))
    (let* ((entry (car ejn--cell-kill-ring))
           (idx (ejn-notebook-cell-index notebook (ejn-cell-id current-cell))))
      (ejn-with-undo-group "Yank cell" notebook
			   (ejn-with-undo-boundary "Yank cell"
						   (let ((new-cell (ejn-notebook-insert-cell notebook
											     (plist-get entry :type)
											     :at (1+ idx))))
						     (setf (ejn-cell-source new-cell) (plist-get entry :source))
						     (let ((region (ejn-render--full-cell-region (ejn-cell-id current-cell))))
						       (when region
							 (goto-char (cdr region))))
						     (let ((ejn--rendering-p t))
						       (ejn-render--insert-cell-at-point new-cell))
						     (ejn--goto-cell-start-by-id (ejn-cell-id new-cell))))))))

(provide 'ejn-cell-engine)
;;; ejn-cell-engine.el ends here
