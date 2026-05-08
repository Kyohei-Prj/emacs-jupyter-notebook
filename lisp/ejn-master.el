;;; ejn-master.el --- Master view buffer for EJN  -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'polymode)
(require 'ejn-core)
(require 'ejn-cell)

(declare-function ejn-mode "ejn" (&optional arg))

;;; Polymode chunkmode definitions

;; FIX (Critical #1): Use fundamental-mode instead of special-mode as the
;; host mode.  special-mode is a read-only help-viewer mode that prevents
;; editing and does not set up a notebook-style environment.  fundamental-mode
;; is a neutral host that lets polymode and ejn-mode do their work cleanly.
(define-hostmode poly-ejn-hostmode
  :mode 'fundamental-mode)

;; Inner mode: python-ts-mode for code cells
;; Delimiters: # %%<ejn-cell:N:code> ... # %%<ejn-cell:N:end>
(define-innermode poly-ejn-code-innermode
  :head-matcher "# %%<ejn-cell:[0-9]+:code>"
  :tail-matcher "# %%<ejn-cell:[0-9]+:end>"
  :mode 'python-ts-mode)

;; Inner mode: markdown-mode for markdown cells
;; Delimiters: # %%<ejn-cell:N:markdown> ... # %%<ejn-cell:N:end>
(define-innermode poly-ejn-markdown-innermode
  :head-matcher "# %%<ejn-cell:[0-9]+:markdown>"
  :tail-matcher "# %%<ejn-cell:[0-9]+:end>"
  :mode 'markdown-mode)

;; Polymode: combines host + inner modes
(define-polymode poly-ejn-mode nil
  "Polymode for EJN master view buffers.
Uses fundamental-mode as host and python-ts-mode/markdown-mode for
code/markdown chunks.  Chunk delimiters use sentinel comment format:
  # %%<ejn-cell:N:code> ... # %%<ejn-cell:N:end>
  # %%<ejn-cell:N:markdown> ... # %%<ejn-cell:N:end>"
  :hostmode 'poly-ejn-hostmode
  :innermodes '(poly-ejn-code-innermode poly-ejn-markdown-innermode))

(defconst ejn--cell-chunk-head-prefix "# %%<ejn-cell:"
  "Prefix string for polymode chunk head delimiters in master view buffers.")

;; Full regex for a chunk head delimiter line, capturing the cell index.
;; Used by scroll hook and navigation helpers to avoid matching end delimiters.
(defconst ejn--cell-chunk-head-regexp
  "^# %%<ejn-cell:\\([0-9]+\\):\\(code\\|markdown\\|raw\\)>"
  "Regexp matching a chunk head delimiter line in the master view buffer.
Group 1 captures the cell index (decimal).
Group 2 captures the cell type (code, markdown, or raw).")

(defun ejn--cleanup-master-view ()
  "Cleanup function called when the master view buffer is killed."
  nil)

(defun ejn--poly-render-cells (notebook)
  "Render NOTEBOOK's cells using polymode chunk delimiters.

Iterates NOTEBOOK's `:cells' list.  For each cell at index N, inserts:
  # %%<ejn-cell:N:code>          (for code cells)
  <cell source>
  # %%<ejn-cell:N:end>
or the corresponding markdown variant.  The delimiter lines use the
`invisible' text property (symbol `ejn-chunk-delim') so they do not
clutter the user-visible display; users navigate and edit via cell
buffers, not by reading raw delimiters."
  (let ((cells (slot-value notebook 'cells))
        (idx 0))
    (dolist (cell cells)
      (let* ((cell-type (slot-value cell 'type))
             (source    (or (slot-value cell 'source) ""))
             (head (format "%s%d:%s>\n"
                           ejn--cell-chunk-head-prefix
                           idx
                           (symbol-name cell-type)))
             (tail (format "\n%s%d:end>\n"
                           ejn--cell-chunk-head-prefix
                           idx))
             (head-start (point)))
        (insert head)
        ;; Make the head delimiter line invisible so users see the cell
        ;; visuals (applied in cell buffers) rather than raw comments.
        (put-text-property head-start (point) 'invisible 'ejn-chunk-delim)
        (insert source)
        (let ((tail-start (point)))
          (insert tail)
          (put-text-property tail-start (point) 'invisible 'ejn-chunk-delim))
        (cl-incf idx)))))

(defun ejn--poly-refresh-cells ()
  "Re-render the master view buffer with polymode chunk delimiters.

Gets the notebook from the current buffer's `ejn--notebook' variable,
clears the buffer contents, and re-renders all cells via
`ejn--poly-render-cells'.  Does not recreate the buffer."
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
        (add-hook 'window-scroll-functions #'ejn--master-scroll-hook 'append 'local))
      (oset notebook master-buffer buf)
      (ejn--poly-render-cells notebook)
      (ejn-mode 1))
    buf))

(defun ejn--master-scroll-hook (window _start)
  "Window scroll hook for lazy cell initialization.

Called by `window-scroll-functions' when the master view scrolls.
Initializes cells that scroll into the visible window area.

FIX (Minor #4): Uses the full `ejn--cell-chunk-head-regexp' instead of
a bare prefix string search, so end-delimiter lines (which share the
same prefix) are never mistakenly treated as head delimiters."
  (with-current-buffer (window-buffer window)
    (when-let ((notebook ejn--notebook))
      (let ((cells (slot-value notebook 'cells))
            (start (window-start window))
            (end   (window-end window))
            (idx   0))
        (dolist (cell cells)
          (unless (slot-value cell 'initialized-p)
            (when (save-excursion
                    (goto-char start)
                    ;; Use the full head regexp so we only match actual head
                    ;; delimiter lines, not end delimiters.
                    (re-search-forward ejn--cell-chunk-head-regexp
                                       (max start end) t))
              (ejn-cell-initialize cell notebook)))
          (cl-incf idx))))))

(provide 'ejn-master)
;;; ejn-master.el ends here
