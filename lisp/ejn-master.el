;;; ejn-master.el --- Master view buffer for EJN  -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'button)
(require 'polymode)
(require 'ejn-core)
(require 'ejn-cell)

(declare-function ejn-mode "ejn" (&optional arg))

;;; Polymode chunkmode definitions for P5-T15

;; Host mode: special-mode for the inter-chunk text (sentinel delimiters)
(define-hostmode poly-ejn-hostmode
  :mode 'special-mode)

;; Inner mode: python-mode for code cells
;; Delimiters: # %%<ejn-cell:N:code> ... # %%<ejn-cell:N:end>
(define-innermode poly-ejn-code-innermode
  :head-matcher "^# %%<ejn-cell:[0-9]+:code>"
  :tail-matcher "^# %%<ejn-cell:[0-9]+:end>"
  :mode 'python-mode)

;; Inner mode: markdown-mode for markdown cells
;; Delimiters: # %%<ejn-cell:N:markdown> ... # %%<ejn-cell:N:end>
(define-innermode poly-ejn-markdown-innermode
  :head-matcher "^# %%<ejn-cell:[0-9]+:markdown>"
  :tail-matcher "^# %%<ejn-cell:[0-9]+:end>"
  :mode 'markdown-mode)

;; Polymode: combines host + inner modes
(define-polymode poly-ejn-mode nil
  "Polymode for EJN master view buffers.
Uses special-mode as host and python-mode/markdown-mode for code/markdown chunks.
Chunk delimiters use sentinel comment format:
  # %%<ejn-cell:N:code> ... # %%<ejn-cell:N:end>
  # %%<ejn-cell:N:markdown> ... # %%<ejn-cell:N:end>"
  :hostmode 'poly-ejn-hostmode
  :innermodes '(poly-ejn-code-innermode poly-ejn-markdown-innermode))

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

(defun ejn--poly-render-cells (notebook)
  "Render NOTEBOOK's cells using polymode chunk delimiters.

Iterates NOTEBOOK's `:cells' list. For each cell at index N,
inserts:
  # %%<ejn-cell:N:code>          (for code cells)
  <cell source>
  # %%<ejn-cell:N:end>
or:
  # %%<ejn-cell:N:markdown>      (for markdown cells)
  <cell source>
  # %%<ejn-cell:N:end>
in the current buffer."
  (let ((cells (slot-value notebook 'cells))
        (idx 0))
    (dolist (cell cells)
      (let ((cell-type (slot-value cell 'type))
            (source (slot-value cell 'source)))
        (insert (format "# %%%%<ejn-cell:%d:%s>\n" idx (symbol-name cell-type)))
        (insert (or source ""))
        (insert (format "\n# %%%%<ejn-cell:%d:end>\n" idx))
        (cl-incf idx)))))

(defun ejn--poly-refresh-cells ()
  "Re-render the master view buffer with polymode chunk delimiters.

Gets the notebook from the current buffer's `ejn--notebook' variable,
clears the buffer contents, and re-renders all cells via
`ejn--poly-render-cells' using polymode sentinel format. Does not
recreate the buffer."
  (let ((notebook ejn--notebook))
    (erase-buffer)
    (ejn--poly-render-cells notebook)))

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

Creates a `poly-ejn-mode' buffer, stores NOTEBOOK as a buffer-local
variable, sets up `kill-buffer-hook' to call `ejn--cleanup-master-view',
and populates the initial cell list via `ejn--poly-render-cells'.
Returns the buffer."
 (let* ((buf-name (format "*ejn-master:%s*"
                            (file-name-nondirectory
                             (slot-value notebook 'path))))
         (existing (get-buffer buf-name))
         (buf (if (and existing (buffer-live-p existing))
                  existing
                (progn
                  (when existing (kill-buffer existing))
                  (generate-new-buffer buf-name)))))
   (with-current-buffer buf
      (condition-case err
          (poly-ejn-mode)
        (error
         (message "ejn: poly-ejn-mode failed: %s" (error-message-string err))
         (special-mode)))
      (setq buffer-read-only nil)
      (set (make-local-variable 'ejn--notebook) notebook)
      (add-hook 'kill-buffer-hook #'ejn--cleanup-master-view 'append 'local)
      (unless (memq #'ejn--master-scroll-hook window-scroll-functions)
        (add-hook 'window-scroll-functions #'ejn--master-scroll-hook 'append 'local))
      (oset notebook master-buffer buf)
      (ejn--poly-render-cells notebook)
      (ejn-mode 1))
    buf))

(defun ejn--master-scroll-hook (window)
  "Window scroll hook for lazy cell initialization.

Called by `window-scroll-functions' when the master view scrolls.
Initializes cells that scroll into the visible window area."
  (with-current-buffer (window-buffer window)
    (when-let ((notebook ejn--notebook))
      (let ((cells (slot-value notebook 'cells))
            (start (window-start window))
            (end (window-end window))
            (idx 0))
        (dolist (cell cells)
          (unless (slot-value cell 'initialized-p)
            (let ((head-marker (format "# %%%%<ejn-cell:%d:" idx)))
              (when (save-excursion
                      (goto-char start)
                      (search-forward head-marker (max start end) t))
                (ejn-cell-initialize cell notebook))))
          (cl-incf idx))))))

(provide 'ejn-master)
