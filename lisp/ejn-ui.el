;;; ejn-ui.el --- UI utilities for EJN  -*- lexical-binding: t -*-

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

;; UI utilities for Emacs Jupyter Notebook.
;;
;; This file provides:
;;   - Visual cell styling (cell headers, margin indicators)
;;   - Global undo manager (undo records, after-change handler, global undo command)
;;   - Structural undo functions
;;   - Markdown rendering

;;; Code:

(require 'cl-lib)
(require 'ejn-core)
(require 'ejn-cell)

(cl-defstruct ejn-undo-record
  "Record of a single undoable change to a notebook cell.

Fields:
  CELL-ID — which cell was affected (string).
  BEFORE — cell source before the change (string) or cell-ID list for
      structural ops (list).
  AFTER — cell source after the change (string) or cell-ID list for
      structural ops (list).
  TIMESTAMP — (float-time) for debounce window (float).
  OPERATION — :content for typing, :insert/:delete/:move/:split/:merge for
      structural operations (symbol).
  NOTEBOOK — ejn-notebook instance for structural undo (object).
  DATA — additional data for structural undo, e.g., cell object for
      :delete undo (object)."
  cell-id
  before
  after
  timestamp
  operation
  notebook
  data)

(defun ejn--cell-header-string (cell)
  "Return a styled header string for CELL, always 50 characters long.
CELL is an ejn-cell EIEIO object.

For code cells: \"╔══ In [N]: ...╗\" or \"╔══ In []: ...╗\"
For markdown cells: \"╔══ Markdown ...╗\"
For raw cells: \"╔══ Raw ...╗\""
  (let* ((cell-type (slot-value cell 'type))
         (exec-count (slot-value cell 'exec-count))
         (label (cond
                 ((eq cell-type 'code)
                  (if exec-count
                      (format "In [%d]:" exec-count)
                    "In []:"))
                 ((eq cell-type 'markdown)
                  "Markdown")
                 ((eq cell-type 'raw)
                  "Raw")
                 (t
                  "Unknown")))
         (header (format "╔══ %s " label))
         (padding (make-string (- 50 (length header) 1) ?═))
         (result (concat header padding "╗")))
    result))

(defun ejn--setup-cell-visuals (cell)
  "Set up visual decorations for CELL's buffer.

Applies a `before-string` text property on the first line of the cell's
buffer with the header string from `ejn--cell-header-string`.
Calls `ejn--setup-cell-margin` if it is defined.

This function is idempotent: calling it multiple times does not produce
duplicate decorations.

CELL is an ejn-cell EIEIO object."
  (let ((buf (slot-value cell 'buffer)))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (save-excursion
          (goto-char (point-min))
          ;; Remove any existing before-string on the first line
          (let ((first-line-end (line-end-position)))
            (remove-text-properties (point-min)
                                    first-line-end
                                    '(before-string nil)))
          ;; Apply the header as before-string on the first character
          (put-text-property (point-min)
                             (min (1+ (point-min)) (point-max))
                             'before-string
                             (ejn--cell-header-string cell))))))
  ;; Call margin setup if available (Phase 5, later task)
  (when (fboundp 'ejn--setup-cell-margin)
    (ejn--setup-cell-margin cell)))

(defun ejn-cell-refresh-header (cell)
  "Update the before-string on the first line of CELL's buffer.

Re-applies the header string from `ejn--cell-header-string` using the
current state of CELL, reflecting any changes to exec-count.

CELL is an ejn-cell EIEIO object."
  (let ((buf (slot-value cell 'buffer)))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (save-excursion
          (goto-char (point-min))
          ;; Remove any existing before-string on the first line
          (let ((first-line-end (line-end-position)))
            (remove-text-properties (point-min)
                                    first-line-end
                                    '(before-string nil)))
          ;; Apply the updated header as before-string
          (put-text-property (point-min)
                             (min (1+ (point-min)) (point-max))
                             'before-string
                             (ejn--cell-header-string cell)))))))

(defun ejn--setup-cell-margin (cell)
  "Set up display-margin text property for CELL's buffer.

Sets the `display-margin` text property on the first line of the cell
buffer to show an \"In [N]: \" indicator for code cells with an
execution count, or \"In []: \" for code cells without one.

Uses `set-window-margins` to ensure the margin width is sufficient
(12 characters, enough for \"In [999]: \").

For non-code cells (markdown, raw), this is a no-op.

CELL is an ejn-cell EIEIO object."
  (let ((cell-type (slot-value cell 'type))
        (buf (slot-value cell 'buffer)))
    (when (and (eq cell-type 'code) (buffer-live-p buf))
      (with-current-buffer buf
        (save-excursion
          (goto-char (point-min))
          (let* ((exec-count (slot-value cell 'exec-count))
                 (margin-str (if exec-count
                                 (format "In [%d]: " exec-count)
                               "In []: ")))
            ;; Set display-margin text property on the first character
            (put-text-property (point-min)
                               (1+ (point-min))
                               'display-margin
                               margin-str)
            ;; Ensure window margins are wide enough
            (set-window-margins (selected-window) 12)))))))

(defvar ejn--undo-debounce-seconds 1
  "Seconds within which rapid changes are coalesced into one undo record.")

(defun ejn--undo-after-change (start end pre-change-length)
  "After-change wrapper that coalesces rapid typing into single undo records.

Receives standard after-change arguments START, END, PRE-CHANGE-LENGTH.
Determines which cell and notebook the current buffer belongs to.
Reconstructs the before-state by removing the changed region from the
current buffer content. Captures the after-state from the current buffer.
Checks the notebook's undo stack for a pending record on the same cell
within `ejn--undo-debounce-seconds'. If found, updates its after field.
Otherwise, pushes a new `ejn-undo-record' with operation `:content'.

Returns nil."
  (let* ((cell (and (boundp 'ejn--cell) ejn--cell))
         (notebook (and cell (buffer-local-value 'ejn--notebook (current-buffer))))
         (cell-id (and notebook (slot-value cell 'id)))
         (now (float-time)))
    (when (and cell notebook cell-id)
      (let* ((undo-stack (slot-value notebook 'undo-stack))
             (full (buffer-substring-no-properties (point-min) (point-max)))
             (buf-len (length full))
             (after-text full)
             (start-clamped (min start buf-len))
             (end-clamped (min end buf-len))
             (before-text (concat (substring full 0 start-clamped)
                                  (substring full end-clamped)))
             (top-record (car undo-stack)))
        (if (and top-record
                 (string= (ejn-undo-record-cell-id top-record) cell-id)
                 (< (- now (ejn-undo-record-timestamp top-record))
                    ejn--undo-debounce-seconds))
            ;; Update existing record's after field
            (setf (ejn-undo-record-after top-record) after-text)
          ;; Push new record
          (push (make-ejn-undo-record
                 :cell-id cell-id
                 :before before-text
                 :after after-text
                 :timestamp now
                 :operation :content)
                undo-stack)
          (oset notebook undo-stack undo-stack))
        ;; Mark cell dirty (replaces ejn--cell-after-change-hook)
        (oset cell dirty t))))
  nil)

;;;###autoload
(defun ejn-global-undo ()
  "Undo the last change in the current notebook.

Pops the top `ejn-undo-record' from the notebook's undo stack,
restores the affected cell's buffer to its `before' state, and
moves point to that cell's buffer.

Signals `user-error' if there is no associated notebook or if the
undo stack is empty."
  (interactive)
  (let* ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
         (undo-stack (and notebook (slot-value notebook 'undo-stack))))
    (unless notebook
      (user-error "No notebook associated with this buffer"))
    (unless undo-stack
      (user-error "Undo stack is empty"))
    ;; Pop the top record
    (let* ((record (car undo-stack))
           (new-stack (cdr undo-stack))
           (cell-id (ejn-undo-record-cell-id record))
           (before-text (ejn-undo-record-before record))
           (target-cell
            (cl-find cell-id (slot-value notebook 'cells)
                     :key (lambda (c) (slot-value c 'id))
                     :test #'string=))
           (target-buf (and target-cell (slot-value target-cell 'buffer))))
      (unless target-cell
        (user-error "Cannot find cell with id %s" cell-id))
      (unless (and target-buf (buffer-live-p target-buf))
        (user-error "Buffer for cell %s is not live" cell-id))
      ;; Update the undo stack
      (oset notebook undo-stack new-stack)
      ;; Restore the cell buffer to the before state using temp buffer
      ;; (per P2-T14 lesson: with-temp-buffer kills before replace-buffer-contents)
      (let ((temp-buf (generate-new-buffer " *ejn-undo-temp*")))
        (unwind-protect
            (progn
              (with-current-buffer temp-buf
                (insert before-text))
              (with-current-buffer target-buf
                (erase-buffer)
                (replace-buffer-contents temp-buf)))
          (kill-buffer temp-buf)))
      ;; Also update the cell's :source slot to match
      (oset target-cell source before-text)
      ;; Move point to the target cell's buffer
      (switch-to-buffer target-buf))))

(defun ejn--undo-structural-change (record)
  "Reverse a structural undo RECORD (an `ejn-undo-record' struct).

The RECORD's `operation' field indicates which operation to reverse:
  :insert — removes the inserted cell from the notebook's cell list.
  :delete — re-inserts the deleted cell at its original index
            (cell data must be in RECORD's `data' field).
  :move — restores the cell's original position (stub).
  :split — merges the split cells back (stub).
  :merge — splits the merged cells back (stub).

Returns nil."
  (let* ((operation (ejn-undo-record-operation record))
         (notebook (ejn-undo-record-notebook record))
         (before (ejn-undo-record-before record))
         (after (ejn-undo-record-after record)))
    (when notebook
      (cl-case operation
        (:insert
         ;; Undo insert: remove the cell that was added.
         ;; The inserted cell has an ID that appears in `after' but not in `before'.
         (let* ((cells (slot-value notebook 'cells))
                (before-ids (or before '()))
                (removed-cell
                 (cl-find-if (lambda (c)
                               (let ((id (slot-value c 'id)))
                                 (not (member id before-ids))))
                             cells)))
           (when removed-cell
             (oset notebook cells (delq removed-cell cells)))))
       ((:delete :kill)
         ;; Undo delete/kill: restore the cell at its original index.
         ;; The deleted cell object is stored in RECORD's `data' field.
         (let* ((cell-data (ejn-undo-record-data record))
                (cells (slot-value notebook 'cells))
                (before-ids (or before '()))
                (after-ids (or after '()))
                ;; Find index where the cell was deleted:
                ;; It's the position where before has more elements than after
                ;; by comparing element-by-element.
                (insert-index
                 (cl-loop for i from 0
                          for bid in before-ids
                          for aid in after-ids
                          when (not (string= bid aid))
                          return i
                          finally return (length after-ids)))
                (before-sub (cl-subseq cells 0 insert-index))
                (after-sub (cl-subseq cells insert-index)))
            (when cell-data
              (oset notebook cells
                    (append before-sub (list cell-data) after-sub)))))
        (:move
         (message "Undo move stub — not yet implemented"))
        (:split
         (message "Undo split stub — not yet implemented"))
        (:merge
         (message "Undo merge stub — not yet implemented")))))
  nil)

(defun ejn--markdown-apply-text-properties (buf)
  "Apply markdown text properties in the current buffer BUF.

Scans for **bold**, *italic*, `code`, and [link](url) patterns
and applies corresponding face text properties.
Returns nil."
  (with-current-buffer buf
    ;; Clear existing face properties so we can re-render cleanly
    (remove-text-properties (point-min) (point-max) '(face nil))
    (remove-text-properties (point-min) (point-max) '(help-echo nil))
    (remove-text-properties (point-min) (point-max) '(mouse-face nil))
  ;; Apply bold: **text**
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\*\\*\\([^*\n]+\\)\\*\\*" nil t)
        (put-text-property (match-beginning 1) (match-end 1) 'face 'bold)))
    ;; Apply italic: *text* (single asterisk, skip if part of **bold)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\*\\([^*\n]+\\)\\*" nil t)
        (let* ((prev-pos (1- (match-beginning 0)))
               (prev-char (and (>= prev-pos (point-min)) (char-after prev-pos)))
               (next-pos (1+ (match-end 0)))
               (next-char (and (< next-pos (point-max)) (char-after next-pos))))
          ;; Skip if preceded or followed by another asterisk (part of **bold)
          (unless (or (eq prev-char ?\*) (eq next-char ?\*))
            (put-text-property (match-beginning 1) (match-end 1) 'face 'italic)))))
    ;; Apply code span: `code`
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "`\\([^\n`]+\\)`" nil t)
        (put-text-property (match-beginning 1) (match-end 1) 'face 'shadow)))
    ;; Apply links: [text](url)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\[\\([^]]+\\)\\](\\([^)]+\\))" nil t)
        (let ((link-start (match-beginning 1))
              (link-end (match-end 1))
              (url (match-string-no-properties 2)))
          (put-text-property link-start link-end 'face 'link)
          (put-text-property link-start link-end 'help-echo url)
          (put-text-property link-start link-end 'mouse-face 'highlight))))))

(defun ejn-markdown-render-cell (cell)
  "Render markdown content of CELL in place using text properties.

Applies markdown-style text property rendering to the cell buffer:
bold for `**text**`, italics for `*text*`, code spans for
`` `code` '', and links for `[text](url)`.

If `markdown-mode' is available, uses its font-lock for enhanced
rendering. Falls back to regex-based text property rendering
otherwise.

Returns nil if CELL is not a markdown cell, has no source, or
has no live buffer."
  (when (eq (slot-value cell 'type) 'markdown)
    (let* ((source (slot-value cell 'source))
           (buf (and source (slot-value cell 'buffer))))
      (if (not (and source (> (length source) 0) buf (buffer-live-p buf)))
          nil
        ;; If markdown-mode is available, run font-lock first for base rendering
        (when (fboundp 'markdown-mode)
          (with-current-buffer buf
            (font-lock-fontify-buffer)))
        ;; Apply our regex-based text property rendering AFTER font-lock
        ;; so our faces override font-lock's where applicable
        (ejn--markdown-apply-text-properties buf)
        nil))))

(provide 'ejn-ui)
;;; ejn-ui.el ends here
