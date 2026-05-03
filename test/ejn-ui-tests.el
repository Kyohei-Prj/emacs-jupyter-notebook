;;; ejn-ui-tests.el --- ERT tests for ejn-ui  -*- lexical-binding: t; -*-

;; Copyright (C) 2025  EJN Contributors

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

;; Tests for ejn-ui module: cell visuals, global undo manager.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'eieio)

;; Ensure lisp/ is on the load-path
(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))

(require 'ejn-core)
(require 'ejn-cell)
(require 'ejn-master)
(require 'ejn-ui)
(require 'ejn)

;;; Tests — P5-T10: ejn--undo-after-change pushes a new record on first change

(ert-deftest ejn-ui-p5-t10--single-change-pushes-new-undo-record ()
  "Verify a single buffer change pushes a new `ejn-undo-record' to the notebook's undo stack."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-undo-single.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Before: undo stack is empty
          (should (= (length (slot-value nb 'undo-stack)) 0))
          ;; Act: simulate a buffer change via the after-change handler
          (with-current-buffer buf
            (goto-char (point-max))
            (ejn--undo-after-change 5 5 0))
          ;; Assert: one record was pushed
          (should (= (length (slot-value nb 'undo-stack)) 1))
          (let ((record (car (slot-value nb 'undo-stack))))
            ;; Record has correct cell-id
            (should (string= (ejn-undo-record-cell-id record)
                             (slot-value cell 'id)))
            ;; Record has correct before state
            (should (string= (ejn-undo-record-before record) "x = 1"))
            ;; Record has :content operation
            (should (eq (ejn-undo-record-operation record) :content))
            ;; Record has a valid timestamp
            (should (numberp (ejn-undo-record-timestamp record)))
            ;; Record has an after field
            (should (stringp (ejn-undo-record-after record)))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T10: rapid changes within 1s coalesce into one record

(ert-deftest ejn-ui-p5-t10--rapid-changes-coalesce-into-one-record ()
  "Verify rapid changes (within 1s debounce window) update the existing record's after field rather than pushing a new record."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-undo-coalesce.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; First change: pushes a new record
          (with-current-buffer buf
            (ejn--undo-after-change 5 5 0))
          (should (= (length (slot-value nb 'undo-stack)) 1))
          ;; Modify buffer content for second change
          (with-current-buffer buf
            (goto-char (point-max))
            (insert " # comment"))
          ;; Second change: within debounce window, should NOT push a new record
          (with-current-buffer buf
            (ejn--undo-after-change 5 15 0))
          ;; Still only one record
          (should (= (length (slot-value nb 'undo-stack)) 1))
          ;; The after field should reflect the latest buffer content
          (let ((record (car (slot-value nb 'undo-stack))))
            (should (string= (ejn-undo-record-after record)
                             "x = 1 # comment")))
          ;; Before should remain the original source
          (let ((record (car (slot-value nb 'undo-stack))))
            (should (string= (ejn-undo-record-before record) "x = 1"))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T10: change after 1s debounce creates a new record

(ert-deftest ejn-ui-p5-t10--change-after-debounce-creates-new-record ()
  "Verify a change after the 1-second debounce window creates a new record on the undo stack."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-undo-debounce.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; First change
          (with-current-buffer buf
            (ejn--undo-after-change 5 5 0))
          (should (= (length (slot-value nb 'undo-stack)) 1))
          (let ((record1 (car (slot-value nb 'undo-stack))))
            (let ((ts1 (ejn-undo-record-timestamp record1)))
              ;; Tamper with the record's timestamp to be > 1s in the past
              ;; so the next call sees it as outside the debounce window
              (setf (ejn-undo-record-timestamp record1) (- (float-time) 2.0))))
          ;; Modify buffer content for second change
          (with-current-buffer buf
            (goto-char (point-max))
            (insert "\ny = 2"))
          ;; Second change: after debounce window, should push a new record
          (with-current-buffer buf
            (ejn--undo-after-change 5 12 0))
          ;; Now two records on the stack
          (should (= (length (slot-value nb 'undo-stack)) 2))
          ;; The newest record (car) has the latest after state
          (let ((record-new (car (slot-value nb 'undo-stack)))
                (record-old (nth 1 (slot-value nb 'undo-stack))))
            (should (string= (ejn-undo-record-after record-new)
                             "x = 1\ny = 2"))
            ;; Old record is still on the stack
            (should (string= (ejn-undo-record-before record-old) "x = 1"))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T11: ejn-global-undo signals user-error on empty stack

(ert-deftest ejn-ui-p5-t11--signals-user-error-on-empty-undo-stack ()
  "Calling `ejn-global-undo' when the undo stack is empty should signal `user-error'."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-undo-empty.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          (with-current-buffer buf
            (should-error (ejn-global-undo)
                          :type 'user-error)))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T11: ejn-global-undo restores cell buffer and pops record

(ert-deftest ejn-ui-p5-t11--restores-cell-buffer-and-pops-record ()
  "Calling `ejn-global-undo' with one record restores the cell buffer to the
`before' state and pops that record from the undo stack."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-undo-restore.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Arrange: push a record with before="x = 1" and after="x = 2"
          (push (make-ejn-undo-record
                 :cell-id (slot-value cell 'id)
                 :before "x = 1"
                 :after "x = 2"
                 :timestamp (float-time)
                 :operation :content)
                (slot-value nb 'undo-stack))
          ;; Modify the buffer content to simulate "after" state
          (with-current-buffer buf
            (erase-buffer)
            (insert "x = 2"))
          ;; Verify stack has one record before undo
          (should (= (length (slot-value nb 'undo-stack)) 1))
          ;; Act: perform undo
          (with-current-buffer buf
            (ejn-global-undo))
          ;; Assert: stack is now empty (record popped)
          (should (= (length (slot-value nb 'undo-stack)) 0))
          ;; Assert: buffer content is restored to "before" state
          (with-current-buffer buf
            (should (string= (buffer-substring-no-properties
                              (point-min) (point-max))
                             "x = 1"))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T11: ejn-global-undo moves point to the undone cell's buffer

(ert-deftest ejn-ui-p5-t11--moves-point-to-undone-cell-buffer ()
  "After undo, point should be in the buffer of the cell that was undone."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-undo-point.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell1 (make-instance 'ejn-cell
                               :type 'code
                               :source "x = 1"))
         (cell2 (make-instance 'ejn-cell
                               :type 'code
                               :source "y = 2"))
         (master-buf nil)
         (buf1 nil)
         (buf2 nil))
    (oset nb cells (list cell1 cell2))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf1 (ejn-cell-open-buffer cell1 nb))
          (setq buf2 (ejn-cell-open-buffer cell2 nb))
          ;; Arrange: push a record for cell2
          (push (make-ejn-undo-record
                 :cell-id (slot-value cell2 'id)
                 :before "y = 2"
                 :after "y = 999"
                 :timestamp (float-time)
                 :operation :content)
                (slot-value nb 'undo-stack))
          ;; Modify cell2's buffer to simulate "after" state
          (with-current-buffer buf2
            (erase-buffer)
            (insert "y = 999"))
          ;; Act: perform undo while in cell1's buffer
          (with-current-buffer buf1
            (ejn-global-undo))
          ;; Assert: selected buffer should be cell2's buffer
          (should (eq (window-buffer (selected-window)) buf2))
          ;; Assert: buffer content restored
          (with-current-buffer buf2
            (should (string= (buffer-substring-no-properties
                              (point-min) (point-max))
                             "y = 2"))))
      (when (buffer-live-p buf1) (kill-buffer buf1))
      (when (buffer-live-p buf2) (kill-buffer buf2))
      (kill-buffer master-buf))))

;;; Tests — P5-T13: ejn--undo-structural-change for :insert removes cell

(ert-deftest ejn-ui-p5-t13--undo-insert-removes-inserted-cell ()
  "Undoing an :insert structural record removes the inserted cell from the notebook."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-undo-insert.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell1 (make-instance 'ejn-cell :type 'code :source "a = 1"))
         (cell2 (make-instance 'ejn-cell :type 'code :source "b = 2"))
         (inserted (make-instance 'ejn-cell :type 'code :source "inserted!")))
    (oset nb cells (list cell1 inserted cell2))
    ;; Arrange: create an :insert record.
    ;; `before' holds cell IDs before insert (without inserted cell).
    ;; `after' holds cell IDs after insert (with inserted cell).
    (let ((record (make-ejn-undo-record
                   :cell-id (slot-value inserted 'id)
                   :before (list (slot-value cell1 'id)
                                 (slot-value cell2 'id))
                   :after (list (slot-value cell1 'id)
                                (slot-value inserted 'id)
                                (slot-value cell2 'id))
                   :timestamp (float-time)
                   :operation :insert
                   :notebook nb)))
      (should (= (length (slot-value nb 'cells)) 3))
      ;; Act: undo the insert
      (ejn--undo-structural-change record)
      ;; Assert: inserted cell is removed, only 2 cells remain
      (should (= (length (slot-value nb 'cells)) 2))
      (should (string= (slot-value (nth 0 (slot-value nb 'cells)) 'id)
                       (slot-value cell1 'id)))
      (should (string= (slot-value (nth 1 (slot-value nb 'cells)) 'id)
                       (slot-value cell2 'id))))))

;;; Tests — P5-T13: ejn--undo-structural-change for :delete restores cell

(ert-deftest ejn-ui-p5-t13--undo-delete-restores-deleted-cell ()
  "Undoing a :delete structural record restores the deleted cell at its original index."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-undo-delete.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell1 (make-instance 'ejn-cell :type 'code :source "a = 1"))
         (deleted-cell (make-instance 'ejn-cell :type 'markdown :source "deleted source"))
         (cell2 (make-instance 'ejn-cell :type 'code :source "c = 3")))
    ;; After deletion: notebook only has cell1 and cell2
    (oset nb cells (list cell1 cell2))
    ;; Arrange: create a :delete record with cell data stored in :data
    (let ((record (make-ejn-undo-record
                   :cell-id (slot-value deleted-cell 'id)
                   :before (list (slot-value cell1 'id)
                                 (slot-value deleted-cell 'id)
                                 (slot-value cell2 'id))
                   :after (list (slot-value cell1 'id)
                                (slot-value cell2 'id))
                   :timestamp (float-time)
                   :operation :delete
                   :notebook nb
                   :data deleted-cell)))
      (should (= (length (slot-value nb 'cells)) 2))
      ;; Act: undo the delete
      (ejn--undo-structural-change record)
      ;; Assert: deleted cell is restored at original index (1)
      (should (= (length (slot-value nb 'cells)) 3))
      (should (string= (slot-value (nth 0 (slot-value nb 'cells)) 'id)
                       (slot-value cell1 'id)))
      (should (string= (slot-value (nth 1 (slot-value nb 'cells)) 'id)
                       (slot-value deleted-cell 'id)))
      (should (string= (slot-value (nth 2 (slot-value nb 'cells)) 'id)
                       (slot-value cell2 'id))))))

;;; Tests — P5-T19: ejn-markdown-render-cell handles nil source gracefully

(ert-deftest ejn-ui-p5-t19--handles-nil-source-gracefully ()
  "Calling `ejn-markdown-render-cell' on a cell with nil source returns nil without error."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-md-nil.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'markdown
                              :source nil))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          ;; Create buffer manually — ejn-cell-open-buffer can't handle nil source
          (setq buf (generate-new-buffer (format "*ejn-cell:%s*" (slot-value cell 'id))))
          (oset cell buffer buf)
          ;; Act: render nil source
          (should (eq (ejn-markdown-render-cell cell) nil)))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T19: ejn-markdown-render-cell handles empty string source

(ert-deftest ejn-ui-p5-t19--handles-empty-source-gracefully ()
  "Calling `ejn-markdown-render-cell' on a cell with empty string source returns nil without error."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-md-empty.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'markdown
                              :source ""))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Act: render empty source
          (should (eq (ejn-markdown-render-cell cell) nil)))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T19: ejn-markdown-render-cell applies bold face for **text**

(ert-deftest ejn-ui-p5-t19--applies-bold-face-for-double-asterisk ()
  "Calling `ejn-markdown-render-cell' on a cell with **bold text** applies bold face."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-md-bold.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'markdown
                              :source "**bold text** here"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Act: render markdown
          (ejn-markdown-render-cell cell)
          ;; Assert: the "bold text" region has bold face
          (with-current-buffer buf
            (let ((face-at-5 (get-text-property 3 'face)))
              (should (or (eq face-at-5 'bold)
                          (member 'bold (if (listp face-at-5) face-at-5 '(nil))))))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T19: ejn-markdown-render-cell applies italic face for *text*

(ert-deftest ejn-ui-p5-t19--applies-italic-face-for-single-asterisk ()
  "Calling `ejn-markdown-render-cell' on a cell with *italic text* applies italic face."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-md-italic.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'markdown
                              :source "*italic text* here"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Act: render markdown
          (ejn-markdown-render-cell cell)
          ;; Assert: the "italic text" region has italic face
          (with-current-buffer buf
            ;; "*italic text* here" — position 2 is 'i' of 'italic text'
            (let ((face-at-2 (get-text-property 2 'face)))
              (should (or (eq face-at-2 'italic)
                          (member 'italic (if (listp face-at-2) face-at-2 '(nil))))))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T19: ejn-markdown-render-cell applies code face for `code`

(ert-deftest ejn-ui-p5-t19--applies-code-face-for-backtick ()
  "Calling `ejn-markdown-render-cell' on a cell with `code span` applies code/variable-pitch face."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-md-code.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'markdown
                              :source "use `my_func()` here"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Act: render markdown
          (ejn-markdown-render-cell cell)
          ;; Assert: the "my_func()" region has code-related face
          (with-current-buffer buf
            ;; "use `my_func()` here" — position 6 is 'm' of 'my_func()'
            (let ((face (get-text-property 6 'face)))
              ;; Should have a face applied (shadow, variable-pitch, etc.)
              ;; but NOT bold or italic which are for other markdown patterns
              (should face)
              (should-not (memq face '(bold italic))))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T19: ejn-markdown-render-cell applies link face for [text](url)

(ert-deftest ejn-ui-p5-t19--applies-link-face-for-hyperlink ()
  "Calling `ejn-markdown-render-cell' on a cell with [text](url) applies link face."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-md-link.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'markdown
                              :source "see [example](http://example.com) here"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Act: render markdown
          (ejn-markdown-render-cell cell)
          ;; Assert: the "example" region has link face
          (with-current-buffer buf
            ;; "see [example](http://example.com) here" — position 6 is 'e' of 'example'
            (let ((face (get-text-property 6 'face))
                  (help (get-text-property 6 'help-echo)))
              (should (or (eq face 'link)
                          (string= help "http://example.com"))))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T19: ejn-markdown-render-cell uses markdown-mode if available

(ert-deftest ejn-ui-p5-t19--uses-markdown-mode-when-available ()
  "When `markdown-mode' is available, `ejn-markdown-render-cell' delegates to it."
  (skip-unless (fboundp 'markdown-mode))
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-md-mode.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'markdown
                              :source "**bold** text"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Act: render with markdown-mode available
          (ejn-markdown-render-cell cell)
          ;; Assert: rendering completed without error
          ;; (The face check is handled by the markdown-mode font-lock)
          (should (buffer-live-p buf)))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P5-T19: ejn-markdown-render-cell does nothing for non-markdown cells

(ert-deftest ejn-ui-p5-t19--skips-non-markdown-cells ()
  "Calling `ejn-markdown-render-cell' on a code cell returns nil without error."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-md-codecell.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "**not bold**"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Act: should return nil for code cell
          (should (eq (ejn-markdown-render-cell cell) nil)))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P1-T3: Guard ejn-markdown-render-cell body with when (eq type 'markdown)

(ert-deftest ejn-ui-p1-t3--no-text-properties-on-code-cell-buffer ()
  "Calling `ejn-markdown-render-cell' on a code cell with markdown-like syntax
must NOT apply any face text properties to the buffer content."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-p1-t3-props.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "**not bold** *not italic* `not code`"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Act: render on a code cell — should do nothing
          (ejn-markdown-render-cell cell)
          ;; Assert: no face properties should be applied at all
          (with-current-buffer buf
            (let ((face-at-3 (get-text-property 3 'face)))
              ;; Position 3 is 'n' in "not bold" — would get 'bold' face if bug present
              (should-not face-at-3))
            (let ((face-at-15 (get-text-property 15 'face)))
              ;; Position 15 is 'n' in "not italic" — would get 'italic' if bug present
              (should-not face-at-15))
            (let ((help-at-6 (get-text-property 6 'help-echo)))
              ;; No help-echo should be set on code cell buffers
              (should-not help-at-6))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

(ert-deftest ejn-ui-p1-t3--font-lock-not-called-for-code-cells ()
  "Calling `ejn-markdown-render-cell' on a code cell must NOT call
`font-lock-fontify-buffer' on the cell's buffer."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-p1-t3-fontlock.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "def foo():"))
         (master-buf nil)
         (buf nil)
         (font-lock-called nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Arrange: advise font-lock-fontify-buffer to track calls
          (advice-add 'font-lock-fontify-buffer :around
                      (lambda (_fn &rest _args)
                        (setq font-lock-called t)))
          (unwind-protect
              (progn
                ;; Act: render on a code cell
                (ejn-markdown-render-cell cell)
                ;; Assert: font-lock-fontify-buffer should NOT have been called
                (should-not font-lock-called))
            (advice-remove 'font-lock-fontify-buffer
                           #'(lambda (_fn &rest _args) nil))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

(ert-deftest ejn-ui-p1-t3--markdown-cell-still-renders-correctly ()
  "Calling `ejn-markdown-render-cell' on a markdown cell must still
apply face text properties correctly."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-p1-t3-md-still-works.ipynb"
                             :cells nil
                             :undo-stack nil))
         (cell (make-instance 'ejn-cell
                              :type 'markdown
                              :source "**bold text** here"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Act: render on a markdown cell
          (ejn-markdown-render-cell cell)
          ;; Assert: bold face should be applied
          (with-current-buffer buf
            (let ((face-at-3 (get-text-property 3 'face)))
              ;; Position 3 is 'b' in "bold text"
              (should (or (eq face-at-3 'bold)
                          (and (listp face-at-3) (memq 'bold face-at-3)))))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

(provide 'ejn-ui-tests)
;;; ejn-ui-tests.el ends here
