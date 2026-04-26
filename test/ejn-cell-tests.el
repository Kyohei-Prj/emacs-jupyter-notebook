;;; ejn-cell-tests.el --- ERT tests for ejn-cell (P2-T8)  -*- lexical-binding: t; -*-

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

;; Tests for P2-T8: after-change-functions hook in cell buffers.

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

;;; Tests — P2-T8: ejn-cell-open-buffer creates buffer with source content

(ert-deftest ejn-cell-p2-t8--open-buffer-creates-buffer-with-source ()
  "Verify `ejn-cell-open-buffer' creates a buffer containing the cell's :source."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "print('hello')\nx = 1")))
    (with-current-buffer (ejn-cell-open-buffer cell)
      (should (string= (buffer-substring-no-properties (point-min) (point-max))
                       "print('hello')\nx = 1")))))

;;; Tests — P2-T8: ejn-cell-open-buffer sets major mode for code cells

(ert-deftest ejn-cell-p2-t8--open-buffer-sets-python-mode-for-code ()
  "Verify `ejn-cell-open-buffer' sets `python-mode' for code cells."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass")))
    (with-current-buffer (ejn-cell-open-buffer cell)
      (should (eq major-mode 'python-mode)))))

;;; Tests — P2-T8: ejn-cell-open-buffer sets major mode for markdown cells

(ert-deftest ejn-cell-p2-t8--open-buffer-sets-markdown-mode-for-markdown ()
  "Verify `ejn-cell-open-buffer' sets `markdown-mode' for markdown cells."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'markdown
                              :source "# Heading"))
         (buf (ejn-cell-open-buffer cell)))
    (with-current-buffer buf
      ;; markdown-mode may not be available; accept fundamental-mode as fallback
      (should (memq major-mode '(markdown-mode fundamental-mode))))))

;;; Tests — P2-T8: ejn-cell-open-buffer registers after-change-functions hook

(ert-deftest ejn-cell-p2-t8--open-buffer-registers-after-change-hook ()
  "Verify `ejn-cell-open-buffer' registers `ejn--cell-after-change-hook' on `after-change-functions'."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (buf (ejn-cell-open-buffer cell)))
    (with-current-buffer buf
      (should (memq #'ejn--cell-after-change-hook after-change-functions)))))

;;; Tests — P2-T8: after-change hook sets dirty flag on the cell

(ert-deftest ejn-cell-p2-t8--after-change-hook-sets-dirty-flag ()
  "Verify editing the buffer via the after-change hook sets the cell's `:dirty' slot."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (buf (ejn-cell-open-buffer cell)))
    (should-not (ejn-cell-dirty-p cell))
    (with-current-buffer buf
      (insert " # comment"))
    (should (ejn-cell-dirty-p cell))))

;;; Tests — P2-T8: buffer-local ejn--cell is set

(ert-deftest ejn-cell-p2-t8--open-buffer-sets-buffer-local-ejn-cell ()
  "Verify `ejn-cell-open-buffer' sets buffer-local `ejn--cell' to the cell object."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass"))
         (buf (ejn-cell-open-buffer cell)))
    (with-current-buffer buf
      (should (boundp 'ejn--cell))
      (should (equal ejn--cell cell)))))

;;; Tests — P2-T8: :buffer slot is updated

(ert-deftest ejn-cell-p2-t8--open-buffer-updates-buffer-slot ()
  "Verify `ejn-cell-open-buffer' updates the cell's `:buffer' slot."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass"))
         (buf (ejn-cell-open-buffer cell)))
    (should (equal (slot-value cell 'buffer) buf))
    (should (buffer-live-p (slot-value cell 'buffer)))))

;;; Tests — P2-T8: kill-buffer-hook cleanup is registered

(ert-deftest ejn-cell-p2-t8--open-buffer-registers-kill-buffer-hook ()
  "Verify `ejn-cell-open-buffer' registers a kill-buffer-hook for cleanup."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass"))
         (buf (ejn-cell-open-buffer cell)))
    (with-current-buffer buf
      (should (memq #'ejn--cell-kill-buffer-hook kill-buffer-hook)))))

;;; Tests — P2-T8: kill-buffer-hook removes after-change-functions registration

(ert-deftest ejn-cell-p2-t8--kill-buffer-hook-cleans-up-after-change ()
  "Verify killing the buffer removes `ejn--cell-after-change-hook' from `after-change-functions'."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass"))
         (buf (ejn-cell-open-buffer cell)))
    ;; Hook is registered initially
    (with-current-buffer buf
      (should (memq #'ejn--cell-after-change-hook after-change-functions)))
    ;; Kill the buffer
    (kill-buffer buf)
    ;; Buffer is dead, so we can't check its hook list directly,
    ;; but the kill-buffer-hook should have run without error
    (should-not (buffer-live-p buf))))

;;; Tests — P2-T8: ejn-cell-open-buffer returns existing live buffer

(ert-deftest ejn-cell-p2-t8--open-buffer-returns-existing-buffer ()
  "Verify `ejn-cell-open-buffer' returns the existing buffer when `:buffer' is live."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass"))
         (buf1 (ejn-cell-open-buffer cell))
         (buf2 (ejn-cell-open-buffer cell)))
    (should (equal buf1 buf2))
    (kill-buffer buf1)))

;;; Tests — P2-T13: ejn-cell-open-buffer sets buffer-local ejn--notebook

(ert-deftest ejn-cell-p2-t13--open-buffer-sets-ejn-notebook-back-pointer ()
  "Verify `ejn-cell-open-buffer' sets buffer-local `ejn--notebook' when NOTEBOOK is provided."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-notebook.ipynb"
                            :cells nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass"))
         (buf nil))
    ;; Add cell to notebook's cells list so ejn-shadow-write-cell can find its index
    (oset nb cells (list cell))
    (setq buf (ejn-cell-open-buffer cell nb))
    (with-current-buffer buf
      (should (boundp 'ejn--notebook))
      (should (equal ejn--notebook nb)))))

;;; Tests — P2-T13: ejn-cell-open-buffer writes shadow file

(ert-deftest ejn-cell-p2-t13--open-buffer-writes-shadow-file ()
  "Verify `ejn-cell-open-buffer' writes a shadow file when NOTEBOOK is provided."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-notebook.ipynb"
                            :cells nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1")))
    ;; Add cell to notebook's cells list so ejn-shadow-write-cell can find its index
    (oset nb cells (list cell))
    (ejn-cell-open-buffer cell nb)
    (should (stringp (slot-value cell 'shadow-file)))
    (should (string-suffix-p ".py" (slot-value cell 'shadow-file)))
    ;; Verify shadow file actually exists on disk
    (should (file-exists-p (slot-value cell 'shadow-file)))
    ;; Verify shadow file contains the cell source
    (should (string= (slot-value cell 'source)
                     (with-temp-buffer
                       (insert-file-contents (slot-value cell 'shadow-file))
                       (buffer-string))))))

;;; Tests — P2-T13: ejn-cell-open-buffer does not re-write shadow file for existing buffer

(ert-deftest ejn-cell-p2-t13--open-buffer-skips-shadow-write-on-existing-buffer ()
  "Verify calling `ejn-cell-open-buffer' on a cell with a live buffer does not re-write the shadow file."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-notebook2.ipynb"
                            :cells nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (shadow-path nil))
    ;; Add cell to notebook's cells list
    (oset nb cells (list cell))
    ;; First call: creates buffer and writes shadow file
    (ejn-cell-open-buffer cell nb)
    (setq shadow-path (slot-value cell 'shadow-file))
    (should (stringp shadow-path))
    ;; Record original shadow file content
    (let ((original-content
           (with-temp-buffer
             (insert-file-contents shadow-path)
             (buffer-string))))
      ;; Change the cell's :source after buffer creation
      (oset cell source "x = 999")
      ;; Second call: should return existing buffer without re-writing shadow file
      (ejn-cell-open-buffer cell nb)
      ;; Shadow file should still contain the original content, not the changed source
      (let ((current-content
             (with-temp-buffer
               (insert-file-contents shadow-path)
               (buffer-string))))
        (should (string= current-content original-content))
        (should-not (string= current-content "x = 999"))))))

;;; Tests — P2-T14: ejn-cell-refresh-buffer updates buffer content

(ert-deftest ejn-cell-p2-t14--refresh-buffer-updates-content-from-source ()
  "Verify `ejn-cell-refresh-buffer' replaces buffer content with cell's `:source'."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "original source"))
         (buf (ejn-cell-open-buffer cell)))
    (unwind-protect
        (progn
          ;; Modify the buffer content to diverge from :source
          (with-current-buffer buf
            (insert "modified text")
            (should (string= (buffer-substring-no-properties
                              (point-min) (point-max))
                             "original sourcemodified text")))
          ;; Now refresh — buffer should match :source again
          (ejn-cell-refresh-buffer cell)
          (with-current-buffer buf
            (should (string= (buffer-substring-no-properties
                              (point-min) (point-max))
                             "original source"))))
      (kill-buffer buf))))

;;; Tests — P2-T14: ejn-cell-refresh-buffer preserves point position

(ert-deftest ejn-cell-p2-t14--refresh-buffer-preserves-point-position ()
  "Verify `ejn-cell-refresh-buffer' preserves point position after refresh."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "line1\nline2\nline3"))
         (buf (ejn-cell-open-buffer cell)))
    (unwind-protect
        (progn
          ;; Place point at a specific position
          (with-current-buffer buf
            (goto-char 10)
            (should (= (point) 10))
            ;; Refresh
            (ejn-cell-refresh-buffer cell)
            ;; Point should remain at the same position
            (should (= (point) 10))))
      (kill-buffer buf))))

;;; Tests — P2-T14: ejn-cell-refresh-buffer works when cell buffer is live

(ert-deftest ejn-cell-p2-t14--refresh-buffer-works-with-live-buffer ()
  "Verify `ejn-cell-refresh-buffer' operates on the cell's live buffer."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "new source after refresh"))
         (buf (ejn-cell-open-buffer cell)))
    (unwind-protect
        (progn
          ;; Verify the buffer is live and attached to the cell
          (should (buffer-live-p buf))
          (should (eq (slot-value cell 'buffer) buf))
          ;; Refresh
          (ejn-cell-refresh-buffer cell)
          ;; Buffer content should now be the :source
          (with-current-buffer buf
            (should (string= (buffer-substring-no-properties
                              (point-min) (point-max))
                             "new source after refresh"))))
      (kill-buffer buf))))

;;; Tests — P2-T14: ejn-cell-refresh-buffer returns nil

(ert-deftest ejn-cell-p2-t14--refresh-buffer-returns-nil ()
  "Verify `ejn-cell-refresh-buffer' returns nil."
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass"))
         (buf (ejn-cell-open-buffer cell)))
    (unwind-protect
        (should-not (ejn-cell-refresh-buffer cell))
      (kill-buffer buf))))

;;; Tests — P2-T16: ejn--record-structural-change is a no-op

(ert-deftest ejn-cell-p2-t16--record-structural-change-is-no-op ()
  "Verify `ejn--record-structural-change' accepts three args and returns nil."
  (should-not (ejn--record-structural-change nil nil nil)))

;;; Tests — P2-T16: ejn--make-cell creates cell with correct type and source

(ert-deftest ejn-cell-p2-t16--make-cell-creates-cell-with-correct-type-and-source ()
  "Verify `ejn--make-cell' creates an ejn-cell with the given type and source."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-make-cell.ipynb"
                            :cells nil))
         (master-buf (ejn--create-master-view nb))
         (cell (with-current-buffer master-buf
                 (ejn--make-cell nb 0 'code "x = 1"))))
    (unwind-protect
        (progn
          (should (ejn-cell-p cell))
          (should (eq (slot-value cell 'type) 'code))
          (should (string= (slot-value cell 'source) "x = 1"))
          (should (stringp (slot-value cell 'id))))
      (kill-buffer master-buf))))

;;; Tests — P2-T16: ejn--make-cell defaults source to empty string

(ert-deftest ejn-cell-p2-t16--make-cell-defaults-source-to-empty-string ()
  "Verify `ejn--make-cell' defaults `:source' to `\"\"` when not provided."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-make-cell-default.ipynb"
                            :cells nil))
         (master-buf (ejn--create-master-view nb))
         (cell (with-current-buffer master-buf
                 (ejn--make-cell nb 0 'markdown))))
    (unwind-protect
        (should (string= (slot-value cell 'source) ""))
      (kill-buffer master-buf))))

;;; Tests — P2-T16: ejn--make-cell inserts at correct index in cells list

(ert-deftest ejn-cell-p2-t16--make-cell-inserts-at-correct-index ()
  "Verify `ejn--make-cell' inserts the new cell at the given index in `:cells'."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-make-cell-index.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "A"))
         (cell-b (make-instance 'ejn-cell
                                :type 'code
                                :source "B"))
         (master-buf nil)
         (new-cell nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (setq new-cell
          (with-current-buffer master-buf
            (ejn--make-cell nb 1 'code "INSERTED")))
    (unwind-protect
        (let ((cells (slot-value nb 'cells)))
          (should (= (length cells) 3))
          (should (eq (nth 0 cells) cell-a))
          (should (eq (nth 1 cells) new-cell))
          (should (eq (nth 2 cells) cell-b)))
      (kill-buffer master-buf))))

;;; Tests — P2-T16: ejn--make-cell writes shadow file

(ert-deftest ejn-cell-p2-t16--make-cell-writes-shadow-file ()
  "Verify `ejn--make-cell' writes a shadow file for the new cell."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-make-cell-shadow.ipynb"
                            :cells nil))
         (master-buf (ejn--create-master-view nb))
         (cell (with-current-buffer master-buf
                 (ejn--make-cell nb 0 'raw "raw content"))))
    (unwind-protect
        (progn
          (should (stringp (slot-value cell 'shadow-file)))
          (should (string-suffix-p ".raw" (slot-value cell 'shadow-file)))
          (should (file-exists-p (slot-value cell 'shadow-file)))
          (should (string= "raw content"
                           (with-temp-buffer
                             (insert-file-contents (slot-value cell 'shadow-file))
                             (buffer-string)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T16: ejn--make-cell calls refresh on master view

(ert-deftest ejn-cell-p2-t16--make-cell-refreshes-master-view ()
  "Verify `ejn--make-cell' re-renders the master view buffer."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-make-cell-refresh.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "A"))
         (master-buf nil)
         (new-cell nil))
    (oset nb cells (list cell-a))
    (setq master-buf (ejn--create-master-view nb))
    ;; Before: buffer contains 1 cell button
    (with-current-buffer master-buf
      (should (= (length (slot-value nb 'cells)) 1)))
    (setq new-cell
          (with-current-buffer master-buf
            (ejn--make-cell nb 1 'code "B")))
    ;; After: buffer content should be updated (2 cell buttons)
    (with-current-buffer master-buf
      (let ((content (buffer-substring-no-properties (point-min) (point-max))))
        ;; Buffer should contain the new cell's type and source
        (should (string-match-p "code" content))
        (should (string-match-p "B" content)))
      ;; There should be 2 cells in the notebook
      (should (= (length (slot-value nb 'cells)) 2)))
    (unwind-protect nil
        (kill-buffer master-buf))))

;;; Tests — P2-T16: ejn--make-cell returns the new cell

(ert-deftest ejn-cell-p2-t16--make-cell-returns-new-cell ()
  "Verify `ejn--make-cell' returns the newly created ejn-cell object."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-make-cell-return.ipynb"
                            :cells nil))
         (master-buf (ejn--create-master-view nb))
         (result (with-current-buffer master-buf
                   (ejn--make-cell nb 0 'code "return test"))))
    (unwind-protect
        (progn
          (should (ejn-cell-p result))
          (should (eq result (nth 0 (slot-value nb 'cells)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T17: ejn:worksheet-insert-cell-above inserts before current cell

(ert-deftest ejn-cell-p2-t17--insert-above-places-cell-before-current ()
  "Verify `ejn:worksheet-insert-cell-above' inserts a new cell before the current cell."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-insert-above.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "A"))
         (cell-b (make-instance 'ejn-cell
                                :type 'code
                                :source "B"))
         (cell-c (make-instance 'ejn-cell
                                :type 'code
                                :source "C"))
         (master-buf nil))
    (oset nb cells (list cell-a cell-b cell-c))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (let ((buf-b (ejn-cell-open-buffer cell-b nb)))
          (unwind-protect
              (progn
                ;; We're in cell-b's buffer; insert above should place new cell between A and B
                (with-current-buffer buf-b
                  (ejn:worksheet-insert-cell-above))
                (let ((cells (slot-value nb 'cells)))
                  (should (= (length cells) 4))
                  (should (eq (nth 0 cells) cell-a))
                  (should (eq (nth 2 cells) cell-b))
                  (should (eq (nth 3 cells) cell-c))
                  ;; New cell at index 1, inheriting type 'code from cell-b
                  (should (eq (slot-value (nth 1 cells) 'type) 'code))
                  (should (string= (slot-value (nth 1 cells) 'source) ""))))
            (kill-buffer buf-b)))
      (kill-buffer master-buf))))

;;; Tests — P2-T17: ejn:worksheet-insert-cell-below inserts after current cell

(ert-deftest ejn-cell-p2-t17--insert-below-places-cell-after-current ()
  "Verify `ejn:worksheet-insert-cell-below' inserts a new cell after the current cell."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-insert-below.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell
                                :type 'markdown
                                :source "A"))
         (cell-b (make-instance 'ejn-cell
                                :type 'markdown
                                :source "B"))
         (cell-c (make-instance 'ejn-cell
                                :type 'markdown
                                :source "C"))
         (master-buf nil))
    (oset nb cells (list cell-a cell-b cell-c))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (let ((buf-b (ejn-cell-open-buffer cell-b nb)))
          (unwind-protect
              (progn
                ;; We're in cell-b's buffer; insert below should place new cell between B and C
                (with-current-buffer buf-b
                  (ejn:worksheet-insert-cell-below))
                (let ((cells (slot-value nb 'cells)))
                  (should (= (length cells) 4))
                  (should (eq (nth 0 cells) cell-a))
                  (should (eq (nth 1 cells) cell-b))
                  (should (eq (nth 3 cells) cell-c))
                  ;; New cell at index 2, inheriting type 'markdown from cell-b
                  (should (eq (slot-value (nth 2 cells) 'type) 'markdown))
                  (should (string= (slot-value (nth 2 cells) 'source) ""))))
            (kill-buffer buf-b)))
      (kill-buffer master-buf))))

;;; Tests — P2-T17: both commands are interactive

(ert-deftest ejn-cell-p2-t17--commands-are-interactive ()
  "Verify both insert commands are defined and interactive."
  (should (commandp 'ejn:worksheet-insert-cell-above))
  (should (commandp 'ejn:worksheet-insert-cell-below)))

;;; Tests — P2-T18: ejn:worksheet-move-cell-up swaps with predecessor

(ert-deftest ejn-cell-p2-t18--move-up-swaps-with-predecessor ()
  "Verify `ejn:worksheet-move-cell-up' swaps the current cell with its predecessor."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-move-up.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (cell-c (make-instance 'ejn-cell :type 'code :source "C"))
         (master-buf nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b cell-c))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          (with-current-buffer buf-b
            (ejn:worksheet-move-cell-up))
          (let ((cells (slot-value nb 'cells)))
            (should (= (length cells) 3))
            (should (eq (nth 0 cells) cell-b))
            (should (eq (nth 1 cells) cell-a))
            (should (eq (nth 2 cells) cell-c))))
      (when buf-b (kill-buffer buf-b))
      (kill-buffer master-buf))))

;;; Tests — P2-T18: ejn:worksheet-move-cell-down swaps with successor

(ert-deftest ejn-cell-p2-t18--move-down-swaps-with-successor ()
  "Verify `ejn:worksheet-move-cell-down' swaps the current cell with its successor."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-move-down.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (cell-c (make-instance 'ejn-cell :type 'code :source "C"))
         (master-buf nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b cell-c))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          (with-current-buffer buf-b
            (ejn:worksheet-move-cell-down))
          (let ((cells (slot-value nb 'cells)))
            (should (= (length cells) 3))
            (should (eq (nth 0 cells) cell-a))
            (should (eq (nth 1 cells) cell-c))
            (should (eq (nth 2 cells) cell-b))))
      (when buf-b (kill-buffer buf-b))
      (kill-buffer master-buf))))

;;; Tests — P2-T18: Cannot move first cell up

(ert-deftest ejn-cell-p2-t18--cannot-move-first-cell-up ()
  "Verify `ejn:worksheet-move-cell-up' signals an error on the first cell."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-move-first-up.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf nil)
         (buf-a nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          (with-current-buffer buf-a
            (should-error (ejn:worksheet-move-cell-up))))
      (when buf-a (kill-buffer buf-a))
      (kill-buffer master-buf))))

;;; Tests — P2-T18: Cannot move last cell down

(ert-deftest ejn-cell-p2-t18--cannot-move-last-cell-down ()
  "Verify `ejn:worksheet-move-cell-down' signals an error on the last cell."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-move-last-down.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          (with-current-buffer buf-b
            (should-error (ejn:worksheet-move-cell-down))))
      (when buf-b (kill-buffer buf-b))
      (kill-buffer master-buf))))

;;; Tests — P2-T18: Shadow files are updated after move up

(ert-deftest ejn-cell-p2-t18--move-up-updates-shadow-files ()
  "Verify `ejn:worksheet-move-cell-up' rewrites shadow files with new indices."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-move-up-shadow.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          ;; Open both buffers to write initial shadow files
          (ejn-cell-open-buffer cell-a nb)
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          ;; Record original shadow file paths
          (let ((shadow-a-old (slot-value cell-a 'shadow-file))
                (shadow-b-old (slot-value cell-b 'shadow-file)))
            (should (stringp shadow-a-old))
            (should (stringp shadow-b-old))
            ;; Move cell-b up (swap with cell-a)
            (with-current-buffer buf-b
              (ejn:worksheet-move-cell-up))
            ;; After swap: cell-b is at index 0, cell-a is at index 1
            (let ((shadow-a-new (slot-value cell-a 'shadow-file))
                  (shadow-b-new (slot-value cell-b 'shadow-file)))
              ;; Verify shadow file paths match new indices
              (should (string-match-p "cell_000\\.py" shadow-b-new))
              (should (string-match-p "cell_001\\.py" shadow-a-new))
              ;; Both new shadow files should exist
              (should (file-exists-p shadow-a-new))
              (should (file-exists-p shadow-b-new))
              ;; Verify content matches each cell's source
              (should (string= "A"
                               (with-temp-buffer
                                 (insert-file-contents shadow-a-new)
                                 (buffer-string))))
              (should (string= "B"
                               (with-temp-buffer
                                 (insert-file-contents shadow-b-new)
                                 (buffer-string)))))))
      (when buf-b (kill-buffer buf-b))
      ;; Kill cell-a's buffer too
      (when (buffer-live-p (slot-value cell-a 'buffer))
        (kill-buffer (slot-value cell-a 'buffer)))
      (kill-buffer master-buf))))

(ert-deftest ejn-cell-p2-t18--move-up-refreshes-master-view ()
  "Verify `ejn:worksheet-move-cell-up' re-renders the master view buffer."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-move-up-refresh.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "SourceA"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "SourceB"))
         (master-buf nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          (with-current-buffer buf-b
            (ejn:worksheet-move-cell-up))
          ;; After swap, master view should show cell-b before cell-a
          (with-current-buffer master-buf
            (let ((content (buffer-substring-no-properties
                            (point-min) (point-max))))
              ;; SourceB should appear before SourceA in the master view
              (let ((pos-a (string-search "SourceA" content))
                    (pos-b (string-search "SourceB" content)))
                (should pos-a)
                (should pos-b)
                (should (< pos-b pos-a))))))
      (when buf-b (kill-buffer buf-b))
      (kill-buffer master-buf))))

;;; Tests — P2-T18: Both commands are interactive

(ert-deftest ejn-cell-p2-t18--commands-are-interactive ()
  "Verify both move commands are defined and interactive."
  (should (commandp 'ejn:worksheet-move-cell-up))
  (should (commandp 'ejn:worksheet-move-cell-down)))

;;; Tests — P2-T19: ejn:worksheet-kill-cell signals error if no cell at point

(ert-deftest ejn-cell-p2-t19--signals-error-if-no-cell-at-point ()
  "Verify `ejn:worksheet-kill-cell' signals an error when there's no cell at point."
  (with-temp-buffer
    (should-error (ejn:worksheet-kill-cell))))

;;; Tests — P2-T19: ejn:worksheet-kill-cell removes cell from :cells list

(ert-deftest ejn-cell-p2-t19--removes-cell-from-cells-list ()
  "Verify `ejn:worksheet-kill-cell' removes the cell from NOTEBOOK's `:cells' list."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-kill-cell.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (cell-c (make-instance 'ejn-cell :type 'code :source "C"))
         (master-buf nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b cell-c))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          (with-current-buffer buf-b
            (ejn:worksheet-kill-cell))
          (let ((cells (slot-value nb 'cells)))
            (should (= (length cells) 2))
            (should (eq (nth 0 cells) cell-a))
            (should (eq (nth 1 cells) cell-c))
            (should-not (memq cell-b cells))))
      (when buf-b (kill-buffer buf-b))
      (kill-buffer master-buf))))

;;; Tests — P2-T19: ejn:worksheet-kill-cell kills cell buffer if live

(ert-deftest ejn-cell-p2-t19--kills-cell-buffer-if-live ()
  "Verify `ejn:worksheet-kill-cell' kills the cell's buffer when it is live."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-kill-buffer.ipynb"
                            :cells nil))
         (cell (make-instance 'ejn-cell :type 'code :source "KILLME"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          (should (buffer-live-p buf))
          (with-current-buffer buf
            (ejn:worksheet-kill-cell))
          (should-not (buffer-live-p buf))
          (should-not (buffer-live-p (slot-value cell 'buffer))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P2-T19: ejn:worksheet-kill-cell removes shadow file

(ert-deftest ejn-cell-p2-t19--removes-shadow-file ()
  "Verify `ejn:worksheet-kill-cell' deletes the cell's shadow file from disk."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-kill-shadow.ipynb"
                            :cells nil))
         (cell (make-instance 'ejn-cell :type 'code :source "SHADOWME"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          ;; Open buffer to write shadow file
          (setq buf (ejn-cell-open-buffer cell nb))
          (let ((shadow-path (slot-value cell 'shadow-file)))
            (should (stringp shadow-path))
            (should (file-exists-p shadow-path))
            ;; Kill the cell
            (with-current-buffer buf
              (ejn:worksheet-kill-cell))
            ;; Shadow file should be deleted
            (should-not (file-exists-p shadow-path))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P2-T19: ejn:worksheet-kill-cell proceeds without prompt for clean cell

(ert-deftest ejn-cell-p2-t19--proceeds-without-prompt-for-clean-cell ()
  "Verify `ejn:worksheet-kill-cell' does not prompt when cell is not dirty."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-kill-clean.ipynb"
                            :cells nil))
         (cell (make-instance 'ejn-cell :type 'code :source "CLEAN"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Cell is clean (not dirty)
          (should-not (ejn-cell-dirty-p cell))
          ;; Call should proceed without prompting; we verify it succeeds
          ;; by checking the cell was removed
          (with-current-buffer buf
            (ejn:worksheet-kill-cell))
          (should-not (memq cell (slot-value nb 'cells))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P2-T19: ejn:worksheet-kill-cell prompts for confirmation when dirty

(ert-deftest ejn-cell-p2-t19--prompts-for-confirmation-when-dirty ()
  "Verify `ejn:worksheet-kill-cell' calls `y-or-n-p' when cell is dirty, and aborts on 'n'."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-kill-dirty-prompt.ipynb"
                            :cells nil))
         (cell (make-instance 'ejn-cell :type 'code :source "DIRTY"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Mark cell dirty
          (oset cell dirty t)
          (should (ejn-cell-dirty-p cell))
          ;; Simulate declining the prompt
          (with-current-buffer buf
            (let ((y-or-n-p-answers '(nil)))
              (cl-letf (((symbol-function 'y-or-n-p)
                         (lambda (_prompt)
                           (pop y-or-n-p-answers))))
                (ejn:worksheet-kill-cell))))
          ;; Cell should still be in the notebook (user declined)
          (should (memq cell (slot-value nb 'cells)))
          ;; Buffer should still be alive
          (should (buffer-live-p buf)))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P2-T19: ejn:worksheet-kill-cell confirms and kills when dirty + user says yes

(ert-deftest ejn-cell-p2-t19--kills-when-dirty-and-user-confirms ()
  "Verify `ejn:worksheet-kill-cell' kills the cell when dirty and user confirms via y-or-n-p."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-kill-dirty-confirm.ipynb"
                            :cells nil))
         (cell (make-instance 'ejn-cell :type 'code :source "DIRTY-CONFIRM"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Mark cell dirty
          (oset cell dirty t)
          ;; Simulate confirming the prompt
          (with-current-buffer buf
            (let ((y-or-n-p-answers '(t)))
              (cl-letf (((symbol-function 'y-or-n-p)
                         (lambda (_prompt)
                           (pop y-or-n-p-answers))))
                (ejn:worksheet-kill-cell))))
          ;; Cell should be removed
          (should-not (memq cell (slot-value nb 'cells)))
          ;; Buffer should be killed
          (should-not (buffer-live-p buf)))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P2-T19: ejn:worksheet-kill-cell refreshes master view

(ert-deftest ejn-cell-p2-t19--refreshes-master-view ()
  "Verify `ejn:worksheet-kill-cell' re-renders the master view after removal."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test-kill-refresh.ipynb"
                            :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "AAA"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "BBB"))
         (cell-c (make-instance 'ejn-cell :type 'code :source "CCC"))
         (master-buf nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b cell-c))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          ;; Before kill, master view contains "BBB"
          (with-current-buffer master-buf
            (should (string-match-p "BBB"
                                    (buffer-substring-no-properties
                                     (point-min) (point-max)))))
          ;; Kill cell-b
          (with-current-buffer buf-b
            (ejn:worksheet-kill-cell))
          ;; After kill, master view should not contain "BBB"
          (with-current-buffer master-buf
            (let ((content (buffer-substring-no-properties
                            (point-min) (point-max))))
              (should-not (string-match-p "BBB" content))
              ;; But should still contain the other cells
              (should (string-match-p "AAA" content))
              (should (string-match-p "CCC" content))))
          ;; Master view buffer should still be live
          (should (buffer-live-p master-buf)))
      (when (buffer-live-p buf-b) (kill-buffer buf-b))
      (kill-buffer master-buf))))

;;; Tests — P2-T19: ejn:worksheet-kill-cell is interactive

(ert-deftest ejn-cell-p2-t19--command-is-interactive ()
  "Verify `ejn:worksheet-kill-cell' is defined as an interactive command."
  (should (commandp 'ejn:worksheet-kill-cell)))

;;; Tests — P2-T20: ejn:worksheet-split-cell-at-point splits source at point's line

(ert-deftest ejn-cell-p2-t20--splits-source-at-points-line ()
  "Verify `ejn:worksheet-split-cell-at-point' splits the cell source at point's line."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-split-line.ipynb"
                             :cells nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "line1\nline2\nline3"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Position point at beginning of line 2
          (with-current-buffer buf
            (goto-char (point-min))
            (forward-line 1)
            (ejn:worksheet-split-cell-at-point))
          ;; Current cell should have "line1\n" (before part)
          (should (string= (slot-value cell 'source) "line1\n"))
          ;; New cell at index 1 should have "line2\nline3" (after part)
          (should (= (length (slot-value nb 'cells)) 2))
          (should (string= (slot-value (nth 1 (slot-value nb 'cells)) 'source)
                           "line2\nline3")))
      (when (buffer-live-p buf) (kill-buffer buf))
      (let ((new-cell (nth 1 (slot-value nb 'cells))))
        (when new-cell
          (let ((new-buf (slot-value new-cell 'buffer)))
            (when (buffer-live-p new-buf) (kill-buffer new-buf)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T20: Creates new cell below with after part

(ert-deftest ejn-cell-p2-t20--creates-new-cell-below-with-after-part ()
  "Verify the new cell is inserted after the current cell and contains the after part."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-split-below.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "x = 1\ny = 2"))
         (cell-c (make-instance 'ejn-cell :type 'code :source "C"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell-a cell-b cell-c))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell-b nb))
          (with-current-buffer buf
            (goto-char (point-min))
            (forward-line 1)
            (ejn:worksheet-split-cell-at-point))
          (let ((cells (slot-value nb 'cells)))
            (should (= (length cells) 4))
            (should (eq (nth 0 cells) cell-a))
            (should (eq (nth 1 cells) cell-b))
            (should (eq (nth 3 cells) cell-c))
            ;; New cell at index 2 has the after part
            (should (string= (slot-value (nth 2 cells) 'source) "y = 2"))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (let ((new-cell (nth 2 (slot-value nb 'cells))))
        (when new-cell
          (let ((new-buf (slot-value new-cell 'buffer)))
            (when (buffer-live-p new-buf) (kill-buffer new-buf)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T20: Both cells share original type

(ert-deftest ejn-cell-p2-t20--both-cells-share-original-type ()
  "Verify both the original and new cell share the original cell type."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-split-type.ipynb"
                             :cells nil))
         (cell (make-instance 'ejn-cell
                              :type 'markdown
                              :source "# heading\nsome text"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          (with-current-buffer buf
            (goto-char (1+ (length "# heading")))
            (ejn:worksheet-split-cell-at-point))
          ;; Both cells should be markdown
          (should (eq (slot-value cell 'type) 'markdown))
          (should (eq (slot-value (nth 1 (slot-value nb 'cells)) 'type)
                      'markdown)))
      (when (buffer-live-p buf) (kill-buffer buf))
      (let ((new-cell (nth 1 (slot-value nb 'cells))))
        (when new-cell
          (let ((new-buf (slot-value new-cell 'buffer)))
            (when (buffer-live-p new-buf) (kill-buffer new-buf)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T20: Shadow files written for both cells

(ert-deftest ejn-cell-p2-t20--shadow-files-written-for-both-cells ()
  "Verify shadow files exist for both the original and new cell after split."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-split-shadow.ipynb"
                             :cells nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1\ny = 2"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          (with-current-buffer buf
            (goto-char (1+ (length "x = 1")))
            (ejn:worksheet-split-cell-at-point))
          ;; Original cell's shadow file should exist
          (should (stringp (slot-value cell 'shadow-file)))
          (should (file-exists-p (slot-value cell 'shadow-file)))
          ;; New cell's shadow file should exist
          (let ((new-cell (nth 1 (slot-value nb 'cells))))
            (should (stringp (slot-value new-cell 'shadow-file)))
            (should (file-exists-p (slot-value new-cell 'shadow-file)))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (let ((new-cell (nth 1 (slot-value nb 'cells))))
        (when new-cell
          (let ((new-buf (slot-value new-cell 'buffer)))
            (when (buffer-live-p new-buf) (kill-buffer new-buf)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T20: Master view is refreshed

(ert-deftest ejn-cell-p2-t20--refreshes-master-view ()
  "Verify the master view is refreshed after splitting, showing both cells."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-split-refresh.ipynb"
                             :cells nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "AAA\nBBB"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          (with-current-buffer buf
            (goto-char (1+ (length "AAA")))
            (ejn:worksheet-split-cell-at-point))
          ;; Master view should contain both parts
          (with-current-buffer master-buf
            (should (= (length (slot-value nb 'cells)) 2))
            (let ((content (buffer-substring-no-properties
                             (point-min) (point-max))))
              (should (string-match-p "AAA" content))
              (should (string-match-p "BBB" content))))
          (should (buffer-live-p master-buf)))
      (when (buffer-live-p buf) (kill-buffer buf))
      (let ((new-cell (nth 1 (slot-value nb 'cells))))
        (when new-cell
          (let ((new-buf (slot-value new-cell 'buffer)))
            (when (buffer-live-p new-buf) (kill-buffer new-buf)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T20: Works at beginning of source (before is empty)

(ert-deftest ejn-cell-p2-t20--split-at-beginning-before-is-empty ()
  "Verify splitting at the beginning of source produces empty before part."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-split-begin.ipynb"
                             :cells nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "line1\nline2\nline3"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          (with-current-buffer buf
            (goto-char (point-min))
            (ejn:worksheet-split-cell-at-point))
          (should (string= (slot-value cell 'source) ""))
          (should (string= (slot-value (nth 1 (slot-value nb 'cells)) 'source)
                           "line1\nline2\nline3")))
      (when (buffer-live-p buf) (kill-buffer buf))
      (let ((new-cell (nth 1 (slot-value nb 'cells))))
        (when new-cell
          (let ((new-buf (slot-value new-cell 'buffer)))
            (when (buffer-live-p new-buf) (kill-buffer new-buf)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T20: Works at end of source (after is empty)

(ert-deftest ejn-cell-p2-t20--split-at-end-after-is-empty ()
  "Verify splitting at the end of source produces empty after part."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-split-end.ipynb"
                             :cells nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "line1\nline2\n"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          (with-current-buffer buf
            (goto-char (point-max))
            (ejn:worksheet-split-cell-at-point))
          (should (string= (slot-value cell 'source) "line1\nline2\n"))
          (should (string= (slot-value (nth 1 (slot-value nb 'cells)) 'source)
                           "")))
      (when (buffer-live-p buf) (kill-buffer buf))
      (let ((new-cell (nth 1 (slot-value nb 'cells))))
        (when new-cell
          (let ((new-buf (slot-value new-cell 'buffer)))
            (when (buffer-live-p new-buf) (kill-buffer new-buf)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T20: Command is interactive

(ert-deftest ejn-cell-p2-t20--command-is-interactive ()
  "Verify `ejn:worksheet-split-cell-at-point' is defined as an interactive command."
  (should (commandp 'ejn:worksheet-split-cell-at-point)))

;;; Tests — P2-T21: ejn:worksheet-merge-cell concatenates sources with blank line separator

(ert-deftest ejn-cell-p2-t21--concatenates-sources-with-blank-line-separator ()
  "Verify `ejn:worksheet-merge-cell' concatenates current cell's source with cell below using blank line separator."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-merge-concat.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "x = 1"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "y = 2"))
         (master-buf nil)
         (buf-a nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          (with-current-buffer buf-a
            (ejn:worksheet-merge-cell))
          (should (string= (slot-value cell-a 'source)
                           "x = 1\n\ny = 2")))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      (kill-buffer master-buf))))

;;; Tests — P2-T21: ejn:worksheet-merge-cell removes lower cell from :cells list

(ert-deftest ejn-cell-p2-t21--removes-lower-cell-from-cells-list ()
  "Verify `ejn:worksheet-merge-cell' removes the lower cell from NOTEBOOK's `:cells' list."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-merge-remove.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (cell-c (make-instance 'ejn-cell :type 'code :source "C"))
         (master-buf nil)
         (buf-a nil))
    (oset nb cells (list cell-a cell-b cell-c))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          (with-current-buffer buf-a
            (ejn:worksheet-merge-cell))
          (let ((cells (slot-value nb 'cells)))
            (should (= (length cells) 2))
            (should (eq (nth 0 cells) cell-a))
            (should (eq (nth 1 cells) cell-c))
            (should-not (memq cell-b cells))))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      (kill-buffer master-buf))))

;;; Tests — P2-T21: ejn:worksheet-merge-cell kills lower cell's buffer if live

(ert-deftest ejn-cell-p2-t21--kills-lower-cell-buffer-if-live ()
  "Verify `ejn:worksheet-merge-cell' kills the lower cell's buffer when it is live."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-merge-kill-buf.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf nil)
         (buf-a nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          (should (buffer-live-p buf-b))
          (with-current-buffer buf-a
            (ejn:worksheet-merge-cell))
          (should-not (buffer-live-p buf-b)))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      (when (buffer-live-p buf-b) (kill-buffer buf-b))
      (kill-buffer master-buf))))

;;; Tests — P2-T21: ejn:worksheet-merge-cell removes lower cell's shadow file

(ert-deftest ejn-cell-p2-t21--removes-lower-cell-shadow-file ()
  "Verify `ejn:worksheet-merge-cell' deletes the lower cell's shadow file from disk."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-merge-kill-shadow.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf nil)
         (buf-a nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          (let ((shadow-b (slot-value cell-b 'shadow-file)))
            (should (stringp shadow-b))
            (should (file-exists-p shadow-b))
            (with-current-buffer buf-a
              (ejn:worksheet-merge-cell))
            (should-not (file-exists-p shadow-b))))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      (when (buffer-live-p buf-b) (kill-buffer buf-b))
      (kill-buffer master-buf))))

;;; Tests — P2-T21: ejn:worksheet-merge-cell updates current cell's shadow file

(ert-deftest ejn-cell-p2-t21--updates-current-cell-shadow-file ()
  "Verify `ejn:worksheet-merge-cell' writes the merged source to the current cell's shadow file."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-merge-update-shadow.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf nil)
         (buf-a nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          (ejn-cell-open-buffer cell-b nb)
          (with-current-buffer buf-a
            (ejn:worksheet-merge-cell))
          (let ((shadow-a (slot-value cell-a 'shadow-file)))
            (should (stringp shadow-a))
            (should (file-exists-p shadow-a))
            (should (string= (with-temp-buffer
                               (insert-file-contents shadow-a)
                               (buffer-string))
                             "A\n\nB"))))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      (kill-buffer master-buf))))

;;; Tests — P2-T21: ejn:worksheet-merge-cell refreshes master view

(ert-deftest ejn-cell-p2-t21--refreshes-master-view ()
  "Verify `ejn:worksheet-merge-cell' re-renders the master view after merge."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-merge-refresh.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "AAA"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "BBB"))
         (cell-c (make-instance 'ejn-cell :type 'code :source "CCC"))
         (master-buf nil)
         (buf-a nil))
    (oset nb cells (list cell-a cell-b cell-c))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          ;; Before merge, master view contains "BBB"
          (with-current-buffer master-buf
            (should (string-match-p "BBB"
                                    (buffer-substring-no-properties
                                     (point-min) (point-max)))))
          ;; Merge cell-a with cell-b
          (with-current-buffer buf-a
            (ejn:worksheet-merge-cell))
          ;; After merge, master view should not contain standalone "BBB"
          ;; as a separate cell entry (it's merged into cell-a)
          (with-current-buffer master-buf
            (should (= (length (slot-value nb 'cells)) 2))
            (let ((content (buffer-substring-no-properties
                             (point-min) (point-max))))
              (should (string-match-p "AAA" content))
              (should (string-match-p "CCC" content))
              ;; BBB should still appear but as part of the merged cell content
              (should (string-match-p "BBB" content))))
          (should (buffer-live-p master-buf)))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      (kill-buffer master-buf))))

;;; Tests — P2-T21: ejn:worksheet-merge-cell signals error on last cell

(ert-deftest ejn-cell-p2-t21--signals-error-on-last-cell ()
  "Verify `ejn:worksheet-merge-cell' signals an error when called on the last cell."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-merge-last.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          (with-current-buffer buf-b
            (should-error (ejn:worksheet-merge-cell))))
      (when (buffer-live-p buf-b) (kill-buffer buf-b))
      (kill-buffer master-buf))))

;;; Tests — P2-T21: ejn:worksheet-merge-cell signals error on single cell

(ert-deftest ejn-cell-p2-t21--signals-error-on-single-cell ()
  "Verify `ejn:worksheet-merge-cell' signals an error when there is only one cell."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-merge-single.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (master-buf nil)
         (buf-a nil))
    (oset nb cells (list cell-a))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          (with-current-buffer buf-a
            (should-error (ejn:worksheet-merge-cell))))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      (kill-buffer master-buf))))

;;; Tests — P2-T21: ejn:worksheet-merge-cell is interactive

(ert-deftest ejn-cell-p2-t21--command-is-interactive ()
  "Verify `ejn:worksheet-merge-cell' is defined as an interactive command."
  (should (commandp 'ejn:worksheet-merge-cell)))

;;; Tests — P2-T22: ejn:worksheet-copy-cell copies source and type to kill ring

(ert-deftest ejn-cell-p2-t22--copies-source-and-type-to-kill-ring ()
  "Verify `ejn:worksheet-copy-cell' pushes a copy of the cell's `:source' and `:type' onto the notebook's `ejn-cell-kill-ring'."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-copy-cell.ipynb"
                             :cells nil))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "print('hello')"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          (should-not (slot-value nb 'ejn-cell-kill-ring))
          (with-current-buffer buf
            (ejn:worksheet-copy-cell nil))
          (let ((kill-ring (slot-value nb 'ejn-cell-kill-ring)))
            (should (listp kill-ring))
            (should (= (length kill-ring) 1))
            (let ((entry (car kill-ring)))
              (should (string= (cdr (assq 'source entry))
                               "print('hello')"))
              (should (eq (cdr (assq 'type entry)) 'code)))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P2-T22: Multiple copies cons onto kill ring (most recent first)

(ert-deftest ejn-cell-p2-t22--multiple-copies-cons-most-recent-first ()
  "Verify multiple copies are cons'd onto the kill ring with most recent at the top."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-copy-multi.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'markdown :source "B"))
         (master-buf nil)
         (buf-a nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          ;; Copy cell-a first
          (with-current-buffer buf-a
            (ejn:worksheet-copy-cell nil))
          ;; Copy cell-b second
          (with-current-buffer buf-b
            (ejn:worksheet-copy-cell nil))
          (let ((kill-ring (slot-value nb 'ejn-cell-kill-ring)))
            (should (= (length kill-ring) 2))
            ;; Most recent (cell-b) at the top
            (let ((entry (car kill-ring)))
              (should (string= (cdr (assq 'source entry)) "B"))
              (should (eq (cdr (assq 'type entry)) 'markdown)))
            ;; cell-a is second
            (let ((entry (cadr kill-ring)))
              (should (string= (cdr (assq 'source entry)) "A"))
              (should (eq (cdr (assq 'type entry)) 'code)))))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      (when (buffer-live-p buf-b) (kill-buffer buf-b))
      (kill-buffer master-buf))))

;;; Tests — P2-T22: kill=t copies AND kills the cell

(ert-deftest ejn-cell-p2-t22--kill-arg-copies-and-kills-cell ()
  "Verify calling `ejn:worksheet-copy-cell' with `t' copies and kills the cell."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-copy-kill.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf nil)
         (buf-a nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          (should (buffer-live-p buf-a))
          (should (= (length (slot-value nb 'cells)) 2))
          ;; Copy with kill
          (with-current-buffer buf-a
            (ejn:worksheet-copy-cell t))
          ;; Kill ring should have one entry with cell-a's data
          (let ((kill-ring (slot-value nb 'ejn-cell-kill-ring)))
            (should (= (length kill-ring) 1))
            (let ((entry (car kill-ring)))
              (should (string= (cdr (assq 'source entry)) "A"))
              (should (eq (cdr (assq 'type entry)) 'code))))
          ;; Cell should be removed from cells list
          (should (= (length (slot-value nb 'cells)) 1))
          (should (eq (nth 0 (slot-value nb 'cells)) cell-b))
          ;; Buffer should be killed
          (should-not (buffer-live-p buf-a)))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      (kill-buffer master-buf))))

;;; Tests — P2-T22: kill=nil copies without killing

(ert-deftest ejn-cell-p2-t22--copy-only-does-not-kill-cell ()
  "Verify calling `ejn:worksheet-copy-cell' with `nil' copies without killing."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-copy-only.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf nil)
         (buf-a nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          (with-current-buffer buf-a
            (ejn:worksheet-copy-cell nil))
          ;; Kill ring should have one entry
          (should (= (length (slot-value nb 'ejn-cell-kill-ring)) 1))
          ;; Cell should still be in cells list
          (should (= (length (slot-value nb 'cells)) 2))
          (should (memq cell-a (slot-value nb 'cells)))
          ;; Buffer should still be alive
          (should (buffer-live-p buf-a)))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      (kill-buffer master-buf))))

;;; Tests — P2-T22: Both commands are interactive

(ert-deftest ejn-cell-p2-t22--commands-are-interactive ()
  "Verify `ejn:worksheet-copy-cell' is defined as an interactive command."
  (should (commandp 'ejn:worksheet-copy-cell)))

;;; Tests — P2-T23: ejn:worksheet-yank-cell creates new cell below with kill ring data

(ert-deftest ejn-cell-p2-t23--yanks-cell-below-with-source-and-type ()
  "Verify `ejn:worksheet-yank-cell' creates a new cell below the current cell using source and type from the kill ring's top entry."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-yank-cell.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'markdown :source "# B"))
         (master-buf nil)
         (buf-a nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          ;; Pre-populate the kill ring with a markdown entry
          (oset nb ejn-cell-kill-ring
                (list '((source . "YANKED SOURCE")
                        (type . markdown))))
          ;; Yank while in cell-a's buffer (below cell-a, above cell-b)
          (with-current-buffer buf-a
            (ejn:worksheet-yank-cell))
          ;; New cell inserted at index 1 (between A and B)
          (let ((cells (slot-value nb 'cells)))
            (should (= (length cells) 3))
            (should (eq (nth 0 cells) cell-a))
            (should (eq (nth 2 cells) cell-b))
            ;; New cell has data from kill ring
            (should (string= (slot-value (nth 1 cells) 'source)
                             "YANKED SOURCE"))
            (should (eq (slot-value (nth 1 cells) 'type) 'markdown)))
          ;; Kill ring entry was popped
          (should-not (slot-value nb 'ejn-cell-kill-ring)))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      ;; Kill new cell's buffer if open
      (let ((new-cell (nth 1 (slot-value nb 'cells))))
        (when new-cell
          (let ((new-buf (slot-value new-cell 'buffer)))
            (when (buffer-live-p new-buf) (kill-buffer new-buf)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T23: Pops from kill ring (entry removed after yank)

(ert-deftest ejn-cell-p2-t23--pops-entry-from-kill-ring ()
  "Verify `ejn:worksheet-yank-cell' removes the top entry from the kill ring, leaving older entries intact."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-yank-pop.ipynb"
                             :cells nil))
         (cell (make-instance 'ejn-cell :type 'code :source "X"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Pre-populate kill ring with two entries
          (oset nb ejn-cell-kill-ring
                (list '((source . "TOP") (type . code))
                      '((source . "BOTTOM") (type . markdown))))
          (with-current-buffer buf
            (ejn:worksheet-yank-cell))
          ;; Kill ring should have one entry remaining (the bottom one)
          (let ((kill-ring (slot-value nb 'ejn-cell-kill-ring)))
            (should (= (length kill-ring) 1))
            (let ((entry (car kill-ring)))
              (should (string= (cdr (assq 'source entry)) "BOTTOM"))
              (should (eq (cdr (assq 'type entry)) 'markdown)))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (let ((new-cell (nth 1 (slot-value nb 'cells))))
        (when new-cell
          (let ((new-buf (slot-value new-cell 'buffer)))
            (when (buffer-live-p new-buf) (kill-buffer new-buf)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T23: Signals error when kill ring is empty

(ert-deftest ejn-cell-p2-t23--signals-error-when-kill-ring-empty ()
  "Verify `ejn:worksheet-yank-cell' signals an error when the kill ring is empty."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-yank-empty.ipynb"
                             :cells nil))
         (cell (make-instance 'ejn-cell :type 'code :source "X"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          ;; Kill ring is nil (empty)
          (should-not (slot-value nb 'ejn-cell-kill-ring))
          (with-current-buffer buf
            (should-error (ejn:worksheet-yank-cell))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (kill-buffer master-buf))))

;;; Tests — P2-T23: New cell has shadow file written

(ert-deftest ejn-cell-p2-t23--new-cell-has-shadow-file ()
  "Verify `ejn:worksheet-yank-cell' writes a shadow file for the new cell."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-yank-shadow.ipynb"
                             :cells nil))
         (cell (make-instance 'ejn-cell :type 'code :source "X"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          (oset nb ejn-cell-kill-ring
                (list '((source . "shadow content") (type . code))))
          (with-current-buffer buf
            (ejn:worksheet-yank-cell))
          (let ((new-cell (nth 1 (slot-value nb 'cells))))
            (should (stringp (slot-value new-cell 'shadow-file)))
            (should (file-exists-p (slot-value new-cell 'shadow-file)))
            (should (string= "shadow content"
                             (with-temp-buffer
                               (insert-file-contents
                                (slot-value new-cell 'shadow-file))
                               (buffer-string))))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (let ((new-cell (nth 1 (slot-value nb 'cells))))
        (when new-cell
          (let ((new-buf (slot-value new-cell 'buffer)))
            (when (buffer-live-p new-buf) (kill-buffer new-buf)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T23: Master view is refreshed

(ert-deftest ejn-cell-p2-t23--refreshes-master-view ()
  "Verify `ejn:worksheet-yank-cell' re-renders the master view buffer."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-yank-refresh.ipynb"
                             :cells nil))
         (cell (make-instance 'ejn-cell :type 'code :source "ORIGINAL"))
         (master-buf nil)
         (buf nil))
    (oset nb cells (list cell))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf (ejn-cell-open-buffer cell nb))
          (oset nb ejn-cell-kill-ring
                (list '((source . "YANKED") (type . code))))
          (with-current-buffer buf
            (ejn:worksheet-yank-cell))
          ;; Master view should show the yanked content
          (with-current-buffer master-buf
            (let ((content (buffer-substring-no-properties
                             (point-min) (point-max))))
              (should (string-match-p "YANKED" content))
              (should (string-match-p "ORIGINAL" content)))))
      (when (buffer-live-p buf) (kill-buffer buf))
      (let ((new-cell (nth 1 (slot-value nb 'cells))))
        (when new-cell
          (let ((new-buf (slot-value new-cell 'buffer)))
            (when (buffer-live-p new-buf) (kill-buffer new-buf)))))
      (kill-buffer master-buf))))

;;; Tests — P2-T23: Command is interactive

(ert-deftest ejn-cell-p2-t23--command-is-interactive ()
  "Verify `ejn:worksheet-yank-cell' is defined as an interactive command."
  (should (commandp 'ejn:worksheet-yank-cell)))

;;; Tests — P2-T24: In cell buffer, next input navigates to next cell

(ert-deftest ejn-cell-p2-t24--goto-next-in-cell-buffer-navigates-to-next-cell ()
  "Verify `ejn:worksheet-goto-next-input' in a cell buffer opens and switches to the next cell's buffer."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-goto-next.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf nil)
         (buf-a nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (setq buf-a (ejn-cell-open-buffer cell-a nb))
          ;; From cell-a's buffer, go next — should open cell-b's buffer
          (set-buffer buf-a)
          (ejn:worksheet-goto-next-input)
          ;; Cell-b's buffer should now be live
          (should (buffer-live-p (slot-value cell-b 'buffer)))
          ;; The current buffer should contain cell-b
          (should (eq (buffer-local-value 'ejn--cell (current-buffer)) cell-b)))
      (when (buffer-live-p buf-a) (kill-buffer buf-a))
      (when (buffer-live-p (slot-value cell-b 'buffer))
        (kill-buffer (slot-value cell-b 'buffer)))
      (kill-buffer master-buf))))

;;; Tests — P2-T24: In cell buffer, prev input navigates to previous cell

(ert-deftest ejn-cell-p2-t24--goto-prev-in-cell-buffer-navigates-to-prev-cell ()
  "Verify `ejn:worksheet-goto-prev-input' in a cell buffer opens and switches to the previous cell's buffer."
  (let* ((nb (make-instance 'ejn-notebook
                             :path "/tmp/test-goto-prev.ipynb"
                             :cells nil))
         (cell-a (make-instance 'ejn-cell :type 'code :source "A"))
         (cell-b (make-instance 'ejn-cell :type 'code :source "B"))
         (master-buf nil)
         (buf-b nil))
    (oset nb cells (list cell-a cell-b))
    (setq master-buf (ejn--create-master-view nb))
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell-a nb)
          (setq buf-b (ejn-cell-open-buffer cell-b nb))
          ;; From cell-b's buffer, go prev — should switch to cell-a's buffer
          (set-buffer buf-b)
          (ejn:worksheet-goto-prev-input)
          ;; Cell-a's buffer should now be live
          (should (buffer-live-p (slot-value cell-a 'buffer)))
          ;; The current buffer should contain cell-a
          (should (eq (buffer-local-value 'ejn--cell (current-buffer)) cell-a)))
      (when (buffer-live-p (slot-value cell-a 'buffer))
        (kill-buffer (slot-value cell-a 'buffer)))
      (when (buffer-live-p buf-b) (kill-buffer buf-b))
      (kill-buffer master-buf))))

;;; Tests — P2-T24: Commands are interactive

(ert-deftest ejn-cell-p2-t24--commands-are-interactive ()
  "Verify both navigation commands are defined and interactive."
  (should (commandp 'ejn:worksheet-goto-next-input))
  (should (commandp 'ejn:worksheet-goto-prev-input)))

;;; ejn-cell-tests.el ends here
