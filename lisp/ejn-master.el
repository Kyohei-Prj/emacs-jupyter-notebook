;;; ejn-master.el --- Master view buffer for EJN  -*- lexical-binding: t; -*-

(require 'cl-lib)
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
  :head-matcher "# %%<ejn-cell:[0-9]+:code>"
  :tail-matcher "# %%<ejn-cell:[0-9]+:end>"
  :mode 'python-mode)

;; Inner mode: markdown-mode for markdown cells
;; Delimiters: # %%<ejn-cell:N:markdown> ... # %%<ejn-cell:N:end>
(define-innermode poly-ejn-markdown-innermode
  :head-matcher "# %%<ejn-cell:[0-9]+:markdown>"
  :tail-matcher "# %%<ejn-cell:[0-9]+:end>"
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

(defun ejn--cleanup-master-view ()
  "Cleanup function called when the master view buffer is killed."
  nil)

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
      (poly-ejn-mode)
      (setq buffer-read-only nil)
      (set (make-local-variable 'ejn--notebook) notebook)
      (add-hook 'kill-buffer-hook #'ejn--cleanup-master-view 'append 'local)
      (unless (memq #'ejn--master-scroll-hook
                    (buffer-local-value 'window-scroll-functions (current-buffer)))
        (add-hook 'window-scroll-functions #'ejn--master-scroll-hook 'append))
      (oset notebook master-buffer buf)
      (ejn--poly-render-cells notebook)
      (ejn-mode 1))
    buf))

(defun ejn--master-scroll-hook (window _start)
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
