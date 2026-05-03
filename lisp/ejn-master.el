;;; ejn-master.el --- Master view for EJN  -*- lexical-binding: t -*-

;; Copyright (C) 2025  EJN Contributors

;; Author: EJN Contributors
;; Version: 0.1.0
;; Keywords: jupyter, notebook, tools, convenience

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Master view (polymode-based composite buffer) for Emacs Jupyter Notebook.
;;
;; This file provides:
;;   - `poly-ejn-mode'  : A polymode major mode for the composite notebook view.
;;   - `ejn--create-master-view'   : Creates the master view buffer.
;;   - `ejn--refresh-master-cells' : Rewrites the master view from the EIEIO model.
;;   - `ejn--master-scroll-hook'   : Lazy-loads cells as they scroll into view.

;;; Code:

(require 'cl-lib)
(require 'eieio)
(require 'polymode)
(require 'ejn-core)

(declare-function ejn-cell-initialize 'ejn-cell (cell notebook))
(declare-function ejn-lsp-generate-composite 'ejn-lsp (notebook))

;; ---------------------------------------------------------------------------
;; Polymode configuration
;; ---------------------------------------------------------------------------

;; Cell delimiter format used in the master view buffer.
;;
;; Each cell block is delimited by:
;;   # %%<ejn-cell:N:TYPE>    ← head
;;   <source content>
;;   # %%<ejn-cell:N:end>     ← tail
;;
;; NOTE on `%%' in format strings: inside a `format' call, `%%%%' produces
;; a literal `%%' in the output string.  So (format "# %%%%<...>") → "# %%<...>".
;; The polymode head/tail regexps below use the literal string "# %%<",
;; which is what the generator writes.  These two must always be kept in sync.

(defvar ejn--polymode-head-regexp
  "^# %%<ejn-cell:\\([0-9]+\\):\\([a-z]+\\)>"
  "Regexp matching the head delimiter of a cell block in the master view.

Group 1 captures the cell index.
Group 2 captures the cell type (code, markdown, raw).")

(defvar ejn--polymode-tail-regexp
  "^# %%<ejn-cell:\\([0-9]+\\):end>"
  "Regexp matching the tail delimiter of a cell block in the master view.

Group 1 captures the cell index.")

(define-hostmode poly-ejn-hostmode
  :mode 'fundamental-mode)

(define-innermode poly-ejn-python-innermode
  :mode 'python-mode
  :head-matcher ejn--polymode-head-regexp
  :tail-matcher ejn--polymode-tail-regexp
  :head-mode 'host
  :tail-mode 'host)

(define-innermode poly-ejn-markdown-innermode
  :mode 'markdown-mode
  :head-matcher ejn--polymode-head-regexp
  :tail-matcher ejn--polymode-tail-regexp
  :head-mode 'host
  :tail-mode 'host)

(define-polymode poly-ejn-mode
  :hostmode 'poly-ejn-hostmode
  :innermodes '(poly-ejn-python-innermode
                poly-ejn-markdown-innermode))

;; ---------------------------------------------------------------------------
;; Master view buffer rendering
;; ---------------------------------------------------------------------------

(defun ejn--cell-head-line (index cell)
  "Return the head delimiter string for CELL at INDEX.

INDEX is the 0-based position of CELL in the notebook's `:cells' list.
CELL is an `ejn-cell' instance.

The head delimiter format is:
  # %%<ejn-cell:N:TYPE>

where N is INDEX and TYPE is the cell's `:type' slot (code/markdown/raw).
Note: `%%%%' in the format string produces literal `%%' in the output."
  (format "# %%%%<ejn-cell:%d:%s>\n" index (slot-value cell 'type)))

(defun ejn--cell-tail-line (index)
  "Return the tail delimiter string for the cell at INDEX.

INDEX is the 0-based position of the cell in the notebook's `:cells' list.

The tail delimiter format is:
  # %%<ejn-cell:N:end>

Note: `%%%%' in the format string produces literal `%%' in the output."
  (format "# %%%%<ejn-cell:%d:end>\n" index))

(defun ejn--poly-render-cells (notebook)
  "Return a string containing all cells in NOTEBOOK formatted for the master view.

Iterates NOTEBOOK's `:cells' list.  For each cell at index N, emits:
  # %%<ejn-cell:N:TYPE>\\n
  <source>\\n
  # %%<ejn-cell:N:end>\\n

This string is used by `ejn--refresh-master-cells' to replace the master
buffer's contents.  It is also used when first creating the master view
via `ejn--create-master-view'.

The double-percent (%%%%%) in the format strings is intentional: inside
`format', `%%%%' produces a literal `%%' which is the polymode delimiter
prefix.  The head/tail regexps in `ejn--polymode-head-regexp' and
`ejn--polymode-tail-regexp' match these literal `%%' strings."
  (let ((cells (slot-value notebook 'cells)))
    (with-output-to-string
      (cl-loop for idx from 0
               for cell in cells
               do (progn
                    (princ (ejn--cell-head-line idx cell))
                    ;; Ensure source ends with a newline before the tail
                    (let ((source (or (slot-value cell 'source) "")))
                      (princ source)
                      (unless (string-suffix-p "\n" source)
                        (princ "\n")))
                    (princ (ejn--cell-tail-line idx)))))))

(defun ejn--refresh-master-cells ()
  "Rewrite the master view buffer from the EIEIO model.

Reads `ejn--notebook' from the current (master view) buffer.
Replaces the entire buffer contents with the output of
`ejn--poly-render-cells', preserving point position as closely
as possible.  Uses `inhibit-read-only' to bypass read-only protection.
Should be called from the master buffer's context."
  (let* ((notebook ejn--notebook)
         (new-content (ejn--poly-render-cells notebook))
         (old-point (point)))
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert new-content))
    (goto-char (min old-point (point-max)))))

;; ---------------------------------------------------------------------------
;; Lazy loading via scroll hook
;;
;; FIX #12: The original implementation used:
;;   (add-hook 'window-scroll-functions #'ejn--master-scroll-hook 'append)
;; without specifying LOCAL, which registered the hook globally.  Every
;; window scroll in all buffers triggered ejn--master-scroll-hook.  Fixed
;; by passing the LOCAL argument (the 4th positional arg to `add-hook'):
;;   (add-hook 'window-scroll-functions #'ejn--master-scroll-hook 'append 'local)
;; This confines the hook to the master view buffer only.
;; ---------------------------------------------------------------------------

(defun ejn--visible-cell-range (window)
  "Return (FIRST-IDX . LAST-IDX) of cells visible in WINDOW.

Reads `ejn--notebook' from the buffer displayed in WINDOW.
Scans the buffer from `window-start' to `window-end' for head delimiter
lines matching `ejn--polymode-head-regexp' and collects their cell indices.
Returns a cons `(MIN-IDX . MAX-IDX)' of visible cell indices, or nil if
no cells are visible.

This is a pure read operation — no side effects."
  (with-current-buffer (window-buffer window)
    (when-let ((notebook ejn--notebook))
      (let ((indices '())
            (start (window-start window))
            (end (window-end window t)))
        (save-excursion
          (goto-char start)
          (while (re-search-forward ejn--polymode-head-regexp end t)
            (let ((idx (string-to-number (match-string 1))))
              (push idx indices))))
        (when indices
          (cons (apply #'min indices) (apply #'max indices)))))))

(defun ejn--master-scroll-hook (window _display-start)
  "Lazy-load cells that have scrolled into view in WINDOW.

FIX #12: Registered as a buffer-local hook on `window-scroll-functions'
so it only fires when scrolling in the master view buffer, not globally.

_DISPLAY-START is the new window start position (provided by the hook
framework but unused — we call `window-end' with UPDATE to get the
actual visible range).

Calls `ejn--visible-cell-range' to determine which cell indices are
visible.  For each visible cell that has not yet been initialized
(`initialized-p' nil), calls `ejn-cell-initialize' to set up its buffer,
shadow file, and LSP connection."
  (when-let* ((buf (window-buffer window))
              (notebook (buffer-local-value 'ejn--notebook buf))
              (range (ejn--visible-cell-range window)))
    (let ((cells (slot-value notebook 'cells))
          (first-idx (car range))
          (last-idx (cdr range)))
      (cl-loop for idx from first-idx to last-idx
               for cell = (nth idx cells)
               when (and cell (not (slot-value cell 'initialized-p)))
               do (ejn-cell-initialize cell notebook)))))

;; ---------------------------------------------------------------------------
;; Master view creation
;; ---------------------------------------------------------------------------

(defun ejn--create-master-view (notebook)
  "Create the master view buffer for NOTEBOOK and return it.

Creates a buffer named `*ejn:<stem>*' where stem is the notebook filename
without its extension.  Sets up `poly-ejn-mode', sets `ejn--notebook'
buffer-locally, populates the buffer via `ejn--poly-render-cells', stores
the buffer in the notebook's `:master-buffer' slot, and registers the
scroll hook buffer-locally (FIX #12).

Returns the master view buffer."
  (let* ((nb-path (slot-value notebook 'path))
         (nb-stem (file-name-sans-extension
                   (file-name-nondirectory nb-path)))
         (buf-name (format "*ejn:%s*" nb-stem))
         (master-buf (get-buffer-create buf-name)))
    (with-current-buffer master-buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (ejn--poly-render-cells notebook)))
      ;; Set buffer-local notebook reference before activating the mode
      (set (make-local-variable 'ejn--notebook) notebook)
      (poly-ejn-mode 1)
      ;; FIX #12: Register scroll hook buffer-locally so it does NOT fire
      ;; for every window scroll in unrelated buffers.
      (add-hook 'window-scroll-functions
                #'ejn--master-scroll-hook 'append 'local))
    ;; Store master buffer reference in notebook
    (oset notebook master-buffer master-buf)
    master-buf))

(provide 'ejn-master)

;;; ejn-master.el ends here
