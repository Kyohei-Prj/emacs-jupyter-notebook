;;; ejn-master.el --- Master view buffer for EJN  -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'button)
(require 'ejn-core)
(require 'ejn-cell)

(declare-function ejn-mode "ejn" (&optional arg))

(defvar ejn--notebook nil
  "Buffer-local variable storing the ejn-notebook for the master view.")
(make-variable-buffer-local 'ejn--notebook)

(defun ejn--cleanup-master-view ()
  "Cleanup function called when the master view buffer is killed."
  nil)

(defun ejn--truncate-source (source &optional max-length)
  "Truncate SOURCE to MAX-LENGTH characters, appending '...' if truncated."
  (or max-length (setq max-length 50))
  (if (<= (length source) max-length)
      source
    (concat (substring source 0 max-length) "...")))

(defun ejn--make-cell-button (cell)
  "Create and insert a button for CELL at point.
Returns the end position of the inserted button."
  (let* ((cell-type (slot-value cell 'type))
         (exec-count (slot-value cell 'exec-count))
         (source (slot-value cell 'source))
         (type-str (symbol-name cell-type))
         (count-str (if exec-count
                        (number-to-string exec-count)
                      "(none)"))
         (preview (ejn--truncate-source source))
         (button-text (format "[%s | In [%s]] %s"
                              type-str count-str preview))
         (start (point))
         (action (lambda (_)
                   (ejn-cell-open-buffer cell))))
    (insert button-text)
    (put-text-property start (point) 'category 'ejn-cell-btn)
    (put-text-property start (point) 'button '(t))
    (put-text-property start (point) 'action action)
    (put-text-property start (point) 'help-echo "Click to open cell buffer")))

(defun ejn--render-master-cells (notebook)
  "Render NOTEBOOK's cells in the current buffer.

Iterates NOTEBOOK's `:cells' list. For each cell, creates a
text button displaying cell type, execution count, and a truncated
source preview. The button action calls `ejn-cell-open-buffer'.
Cells are separated by newline characters."
  (let ((cells (slot-value notebook 'cells))
        (first-p t))
    (dolist (cell cells)
      (unless first-p
        (insert "\n"))
      (ejn--make-cell-button cell)
      (setq first-p nil))))

(defun ejn--refresh-master-cells ()
  "Re-render the master view buffer with updated cell buttons.

Gets the notebook from the current buffer's `ejn--notebook' variable,
clears the buffer contents, and re-renders all cell buttons via
`ejn--render-master-cells'. Does not recreate the buffer."
  (let ((notebook ejn--notebook))
    (erase-buffer)
    (ejn--render-master-cells notebook)))

(defun ejn--create-master-view (notebook)
  "Create and return a master view buffer for NOTEBOOK.

Creates a `special-mode' buffer, stores NOTEBOOK as a buffer-local
variable, sets up `kill-buffer-hook' to call `ejn--cleanup-master-view',
and populates the initial cell list via `ejn--render-master-cells'.
Returns the buffer."
  (let ((buf (get-buffer-create (format "*ejn-master:%s*"
                                         (file-name-nondirectory
                                          (slot-value notebook 'path))))))
    (with-current-buffer buf
      (special-mode)
      (setq buffer-read-only nil)
      (set (make-local-variable 'ejn--notebook) notebook)
      (add-hook 'kill-buffer-hook #'ejn--cleanup-master-view 'append 'local)
      (oset notebook master-buffer buf)
      (ejn--render-master-cells notebook)
      (ejn-mode 1))
    buf))

(provide 'ejn-master)
