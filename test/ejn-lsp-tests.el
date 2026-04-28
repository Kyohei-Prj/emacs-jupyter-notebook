;;; ejn-lsp-tests.el --- ERT tests for ejn-lsp  -*- lexical-binding: t; -*-

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

;; Tests for P3-T02: ejn-lsp-sentinel-line pure function.

;;; Code:

(require 'ert)
(require 'xref)

;; Ensure lisp/ is on the load-path
(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))

;; Test stub for lsp-virtual-buffer-register (defined before ejn-lsp is loaded
;; so that declare-function in ejn-lsp.el picks it up)
(defvar ejn-lsp--test-captured-args nil
  "Test variable: args passed to stub `lsp-virtual-buffer-register'.")

(defun lsp-virtual-buffer-register (&rest args)
  "Stub for `lsp-virtual-buffer-register' that captures arguments for testing.
Used because the real function may not be available in the test environment."
  (setq ejn-lsp--test-captured-args args)
  nil)

(defvar ejn-lsp--test-unregister-called nil
  "Test variable: t when stub `lsp-virtual-buffer-unregister' is called.")

(defun lsp-virtual-buffer-unregister (&rest _args)
  "Stub for `lsp-virtual-buffer-unregister' that records the call for testing."
  (setq ejn-lsp--test-unregister-called t)
  nil)

(defvar ejn-lsp--test-kill-workspace-called nil
  "Test variable: t when stub `lsp-kill-workspace' is called.")

(defun lsp-kill-workspace (&rest _args)
  "Stub for `lsp-kill-workspace' that records the call for testing."
  (setq ejn-lsp--test-kill-workspace-called t)
  nil)

(defun lsp-completion-at-point (&optional _pos)
  "Stub for `lsp-completion-at-point'. Returns nil."
  nil)

;; Stub for lsp-find-definition (defined before ejn-lsp is loaded
;; so that declare-function in ejn-lsp.el picks it up)
(defvar ejn-lsp--test-find-def-position nil
  "Test variable: position passed to stub `lsp-find-definition'.")

(defun lsp-find-definition (_position)
  "Stub for `lsp-find-definition' that records the position for testing."
  (setq ejn-lsp--test-find-def-position _position)
  nil)

(require 'ejn)
(require 'ejn-lsp)

;;; Tests — P3-T02: ejn-lsp-sentinel-line

(ert-deftest ejn-lsp-p3-t02--returns-sentinel-for-index-zero ()
  "Verify `(ejn-lsp-sentinel-line 0)' returns \"# ejn:cell:0\\n\"."
  ;; Arrange — none needed; pure function, no state.
  ;; Act
  (let ((result (ejn-lsp-sentinel-line 0)))
    ;; Assert
    (should (equal result "# ejn:cell:0\n"))))

(ert-deftest ejn-lsp-p3-t02--returns-sentinel-for-higher-index ()
  "Verify `(ejn-lsp-sentinel-line 42)' returns \"# ejn:cell:42\\n\"."
  ;; Arrange — none needed; pure function, no state.
  ;; Act
  (let ((result (ejn-lsp-sentinel-line 42)))
    ;; Assert
    (should (equal result "# ejn:cell:42\n"))))

;;; Tests — P3-T03: ejn-lsp-cell-line-count

(ert-deftest ejn-lsp-p3-t03--empty-string-returns-zero ()
  "Empty string has zero lines."
  ;; Arrange
  (let ((source ""))
    ;; Act
    (let ((result (ejn-lsp-cell-line-count source)))
      ;; Assert
      (should (equal result 0)))))

(ert-deftest ejn-lsp-p3-t03--single-line-no-newline-returns-one ()
  "Single line without trailing newline counts as one line."
  (let ((source "hello"))
    (let ((result (ejn-lsp-cell-line-count source)))
      (should (equal result 1)))))

(ert-deftest ejn-lsp-p3-t03--single-line-with-newline-returns-one ()
  "Single line with trailing newline still counts as one line."
  (let ((source "hello\n"))
    (let ((result (ejn-lsp-cell-line-count source)))
      (should (equal result 1)))))

(ert-deftest ejn-lsp-p3-t03--multiple-lines-with-newline-returns-count ()
  "Multiple lines with trailing newline return correct count."
  (let ((source "a\nb\nc\n"))
    (let ((result (ejn-lsp-cell-line-count source)))
      (should (equal result 3)))))

(ert-deftest ejn-lsp-p3-t03--multiple-lines-no-trailing-newline-returns-count ()
  "Multiple lines without trailing newline return correct count."
  (let ((source "a\nb\nc"))
    (let ((result (ejn-lsp-cell-line-count source)))
      (should (equal result 3)))))

(ert-deftest ejn-lsp-p3-t03--just-newline-returns-one ()
  "A string containing only a newline counts as one line."
  (let ((source "\n"))
    (let ((result (ejn-lsp-cell-line-count source)))
      (should (equal result 1)))))

(ert-deftest ejn-lsp-p3-t03--multiple-newlines-returns-count ()
  "Multiple consecutive newlines each count as a line."
  (let ((source "\n\n"))
    (let ((result (ejn-lsp-cell-line-count source)))
      (should (equal result 2)))))

;;; Tests — P3-T04: ejn-lsp-composite-path

(ert-deftest ejn-lsp-p3-t04--basic-path-returns-composite-py ()
  "Notebook at `/path/to/notebook.ipynb` returns cache composite path."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook
                                 :path "/path/to/notebook.ipynb")))
    ;; Act
    (let ((result (ejn-lsp-composite-path notebook)))
      ;; Assert
      (should (equal result "/path/to/.ejn-cache/notebook/composite.py")))))

(ert-deftest ejn-lsp-p3-t04--nested-path-returns-composite-py ()
  "Notebook at `/a/b/c/my-notebook.ipynb` returns correct composite path."
  ;; Arrange
  (let ((notebook (make-instance 'ejn-notebook
                                 :path "/a/b/c/my-notebook.ipynb")))
    ;; Act
    (let ((result (ejn-lsp-composite-path notebook)))
      ;; Assert
      (should (equal result "/a/b/c/.ejn-cache/my-notebook/composite.py")))))

;;; Tests — P3-T05: ejn-lsp-generate-composite

(ert-deftest ejn-lsp-p3-t05--single-code-cell-writes-composite ()
  "Single code cell produces composite.py with sentinel and source."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "print('hello')"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    ;; Act & Assert
    (unwind-protect
        (let ((result (ejn-lsp-generate-composite notebook)))
          (should (file-exists-p result))
          (should (string= result (ejn-lsp-composite-path notebook)))
          (with-temp-buffer
            (insert-file-contents result)
            (should (string= (buffer-string)
                             "# ejn:cell:0\nprint('hello')\n"))))
      ;; Cleanup
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t05--multiple-code-cells-concatenated-in-order ()
  "Multiple code cells appear in composite in notebook order with sentinel lines."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "x = 1"))
         (cell-b (make-instance 'ejn-cell
                                :type 'code
                                :source "y = 2"))
         (cell-c (make-instance 'ejn-cell
                                :type 'code
                                :source "z = x + y"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell-a cell-b cell-c))))
    (unwind-protect
        (let ((result (ejn-lsp-generate-composite notebook)))
          (with-temp-buffer
            (insert-file-contents result)
            (should (string= (buffer-string)
                             "# ejn:cell:0\nx = 1\n# ejn:cell:1\ny = 2\n# ejn:cell:2\nz = x + y\n"))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t05--skips-non-code-cells ()
  "Only code cells appear in composite; markdown and raw cells are skipped."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell-code1 (make-instance 'ejn-cell
                                    :type 'code
                                    :source "a = 1"))
         (cell-md (make-instance 'ejn-cell
                                 :type 'markdown
                                 :source "# This is markdown"))
         (cell-raw (make-instance 'ejn-cell
                                  :type 'raw
                                  :source "raw content"))
         (cell-code2 (make-instance 'ejn-cell
                                    :type 'code
                                    :source "b = 2"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell-code1 cell-md cell-raw cell-code2))))
    (unwind-protect
        (let ((result (ejn-lsp-generate-composite notebook)))
          (with-temp-buffer
            (insert-file-contents result)
            (should (string= (buffer-string)
                             "# ejn:cell:0\na = 1\n# ejn:cell:1\nb = 2\n"))
            (should-not (string= (buffer-string)
                                 "# This is markdown"))
            (should-not (string= (buffer-string)
                                 "raw content"))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t05--sentinel-index-counts-code-cells-only ()
  "Sentinel indices use 0-based index among code cells, not total cells."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell-md1 (make-instance 'ejn-cell
                                  :type 'markdown
                                  :source "# header"))
         (cell-code1 (make-instance 'ejn-cell
                                    :type 'code
                                    :source "import os"))
         (cell-md2 (make-instance 'ejn-cell
                                  :type 'markdown
                                  :source "## section"))
         (cell-code2 (make-instance 'ejn-cell
                                    :type 'code
                                    :source "import sys"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell-md1 cell-code1 cell-md2 cell-code2))))
    (unwind-protect
        (let ((result (ejn-lsp-generate-composite notebook)))
          (with-temp-buffer
            (insert-file-contents result)
            ;; Code cell 1 gets sentinel index 0, code cell 2 gets sentinel index 1
            (should (string= (buffer-string)
                             "# ejn:cell:0\nimport os\n# ejn:cell:1\nimport sys\n"))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t05--atomic-write-via-tmp-and-rename ()
  "Composite file is written atomically using .tmp + rename-file."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (composite-path (ejn-lsp-composite-path notebook))
         (tmp-path (concat composite-path ".tmp")))
    (unwind-protect
        (progn
          (ejn-lsp-generate-composite notebook)
          ;; After generation, the .tmp file should NOT exist
          (should-not (file-exists-p tmp-path))
          ;; The composite file SHOULD exist
          (should (file-exists-p composite-path)))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t05--returns-absolute-path-to-composite-py ()
  "Function returns the absolute path to the generated composite.py."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    (unwind-protect
        (let ((result (ejn-lsp-generate-composite notebook)))
          ;; Assert: result is an absolute path
          (should (file-name-absolute-p result))
          ;; Assert: result ends with composite.py
          (should (string-suffix-p "composite.py" result))
          ;; Assert: result matches ejn-lsp-composite-path
          (should (string= result (ejn-lsp-composite-path notebook))))
      (delete-directory tmp-dir 'recursive))))

;;; Tests — P3-T06: ejn-lsp--debounced-composite-regen

(ert-deftest ejn-lsp-p3-t06--schedules-timer-on-first-call ()
  "First call to `ejn-lsp--debounced-composite-regen' schedules a timer."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells '())))
    (with-temp-buffer
      (set (make-local-variable 'ejn--notebook) notebook)
      (ejn-lsp--debounced-composite-regen 0 0 0)
      (should (timerp ejn-lsp--composite-regen-timer))
      (cancel-timer ejn-lsp--composite-regen-timer))
    (delete-directory tmp-dir 'recursive)))

(ert-deftest ejn-lsp-p3-t06--cancels-previous-timer-on-repeated-calls ()
  "Repeated calls cancel the previous timer and schedule a new one."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells '()))
         (first-timer nil))
    (with-temp-buffer
      (set (make-local-variable 'ejn--notebook) notebook)
      (ejn-lsp--debounced-composite-regen 0 0 0)
      (setq first-timer ejn-lsp--composite-regen-timer)
      (should (timerp first-timer))
      (ejn-lsp--debounced-composite-regen 0 0 0)
      (should-not (eq first-timer ejn-lsp--composite-regen-timer))
      (should (timerp ejn-lsp--composite-regen-timer))
      (cancel-timer ejn-lsp--composite-regen-timer))
    (delete-directory tmp-dir 'recursive)))

(ert-deftest ejn-lsp-p3-t06--timer-fires-and-generates-composite ()
  "When the scheduled timer fires, it calls `ejn-lsp-generate-composite'."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (composite-path (ejn-lsp-composite-path notebook)))
    (with-temp-buffer
      (set (make-local-variable 'ejn--notebook) notebook)
      (ejn-lsp--debounced-composite-regen 0 0 0)
      ;; Wait for the 0.3s timer to fire
      (sit-for 1)
      (should (file-exists-p composite-path))
      (when (timerp ejn-lsp--composite-regen-timer)
        (cancel-timer ejn-lsp--composite-regen-timer)))
    (delete-directory tmp-dir 'recursive)))

(ert-deftest ejn-lsp-p3-t06--timer-stored-in-buffer-local-variable ()
  "The timer ID is stored in `ejn-lsp--composite-regen-timer' variable."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells '())))
    (with-temp-buffer
      (set (make-local-variable 'ejn--notebook) notebook)
      (should-not (and (boundp 'ejn-lsp--composite-regen-timer)
                       (timerp ejn-lsp--composite-regen-timer)))
      (ejn-lsp--debounced-composite-regen 0 0 0)
      (should (boundp 'ejn-lsp--composite-regen-timer))
      (should (timerp ejn-lsp--composite-regen-timer))
      (when (timerp ejn-lsp--composite-regen-timer)
        (cancel-timer ejn-lsp--composite-regen-timer)))
    (delete-directory tmp-dir 'recursive)))

;;; Tests — P3-T07: ejn-lsp--debounced-composite-regen in after-change hook

(ert-deftest ejn-lsp-p3-t07--debounced-regen-in-after-change-hook ()
  "Smoke: `ejn-lsp--debounced-composite-regen' is in `after-change-functions' when a cell buffer is opened."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell notebook)
          (with-current-buffer (slot-value cell 'buffer)
            (should (memq #'ejn-lsp--debounced-composite-regen
                          after-change-functions))))
      (when (slot-value cell 'buffer)
        (kill-buffer (slot-value cell 'buffer)))
      (delete-directory tmp-dir 'recursive))))

;;; Tests — P3-T08: ejn-lsp-pos-to-composite

(ert-deftest ejn-lsp-p3-t08--non-code-cell-returns-nil ()
  "Non-code cells (markdown, raw) return nil since they don't appear in composite."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell-md (make-instance 'ejn-cell
                                 :type 'markdown
                                 :source "# Header"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell-md))))
    ;; Act
    (let ((result (ejn-lsp-pos-to-composite cell-md notebook 0 0)))
      ;; Assert
      (should-not result)))
  ;; Also test raw cell
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell-raw (make-instance 'ejn-cell
                                  :type 'raw
                                  :source "raw content"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell-raw))))
    (let ((result (ejn-lsp-pos-to-composite cell-raw notebook 0 0)))
      (should-not result))
    (delete-directory tmp-dir 'recursive)))

(ert-deftest ejn-lsp-p3-t08--single-code-cell-origin-to-composite-one ()
  "Single code cell at buffer position (0, 0) maps to composite (1, 0).
Line 0 in composite is the sentinel; source starts at line 1."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "print('hello')"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    ;; Act
    (let ((result (ejn-lsp-pos-to-composite cell notebook 0 0)))
      ;; Assert
      (should (equal result (cons 1 0))))
    (delete-directory tmp-dir 'recursive)))

(ert-deftest ejn-lsp-p3-t08--column-offset-is-preserved ()
  "Column offset in the cell buffer maps directly to the composite column."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    ;; Act
    (let ((result (ejn-lsp-pos-to-composite cell notebook 0 5)))
      ;; Assert — line offset by sentinel (1), column preserved (5)
      (should (equal result (cons 1 5))))
    (delete-directory tmp-dir 'recursive)))

(ert-deftest ejn-lsp-p3-t08--two-code-cells-second-cell-origin ()
  "Second code cell at (0, 0) maps after first cell's content + sentinel."
  ;; Arrange: cell-0 has source "x = 1" (1 line, no trailing newline)
  ;; composite: line 0 = sentinel, line 1 = "x = 1"
  ;; cell-1: line 2 = sentinel, line 3 = source start
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell-0 (make-instance 'ejn-cell
                                :type 'code
                                :source "x = 1"))
         (cell-1 (make-instance 'ejn-cell
                                :type 'code
                                :source "y = 2"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell-0 cell-1))))
    ;; Act
    (let ((result (ejn-lsp-pos-to-composite cell-1 notebook 0 0)))
      ;; Assert: composite line = 1 (sentinel) + 1 (cell-0 source) + 1 (cell-1 sentinel) + 0 = 3
      (should (equal result (cons 3 0))))
    (delete-directory tmp-dir 'recursive)))

(ert-deftest ejn-lsp-p3-t08--last-line-without-trailing-newline ()
  "Multi-line source without trailing newline: last line maps correctly."
  ;; Arrange: source "a\nb\nc" has 3 lines (no trailing newline)
  ;; composite: line 0 = sentinel, line 1 = "a", line 2 = "b", line 3 = "c"
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "a\nb\nc"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    ;; Act — last line of the cell (buffer-line 2)
    (let ((result (ejn-lsp-pos-to-composite cell notebook 2 0)))
      ;; Assert: 1 (sentinel) + 2 (buffer-line) = 3
      (should (equal result (cons 3 0))))
    (delete-directory tmp-dir 'recursive)))

;;; Tests — P3-T09: ejn-lsp-pos-from-composite

(ert-deftest ejn-lsp-p3-t09--sentinel-line-returns-nil ()
  "Sentinel line (line 0) in composite returns nil."
  ;; Arrange: notebook with one code cell whose source has no trailing newline
  ;; composite: line 0 = sentinel, line 1 = source
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
	 (nb-path (expand-file-name "test.ipynb" tmp-dir))
	 (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
	 (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    (unwind-protect
        (let ((result (ejn-lsp-pos-from-composite notebook 0)))
          ;; Assert — line 0 is the sentinel "# ejn:cell:0"
          (should-not result))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t09--first-content-line-returns-cell-and-zero ()
  "First content line of first code cell returns (cell . 0)."
  ;; Arrange: notebook with one code cell; source has no trailing newline
  ;; composite: line 0 = sentinel, line 1 = source
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    (unwind-protect
        (let ((result (ejn-lsp-pos-from-composite notebook 1)))
          ;; Assert — composite line 1 maps to cell's line 0
          (should (equal (car result) cell))
          (should (equal (cdr result) 0)))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t09--separator-line-returns-nil ()
  "Separator line between cells (from trailing newline) returns nil."
  ;; Arrange: first cell source ends with \n, creating a separator line
  ;; composite: line 0 = sentinel, line 1 = "a", line 2 = "b",
  ;;            line 3 = separator (empty), line 4 = sentinel for cell 1
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell-0 (make-instance 'ejn-cell
                                :type 'code
                                :source "a\nb\n"))
         (cell-1 (make-instance 'ejn-cell
                                :type 'code
                                :source "c"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell-0 cell-1))))
    (unwind-protect
        (let ((result (ejn-lsp-pos-from-composite notebook 3)))
          ;; Assert — line 3 is the separator line → nil
          (should-not result))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t09--second-cell-line-returns-correct-offset ()
  "Line in second code cell returns correct (cell . cell-line)."
  ;; Arrange: cell-0 source "x = 1" (1 line, no trailing newline)
  ;;          cell-1 source "a\nb\nc" (3 lines, no trailing newline)
  ;; composite: line 0 = sentinel0, line 1 = cell-0 source
  ;;            line 2 = sentinel1, line 3 = "a", line 4 = "b", line 5 = "c"
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell-0 (make-instance 'ejn-cell
                                :type 'code
                                :source "x = 1"))
         (cell-1 (make-instance 'ejn-cell
                                :type 'code
                                :source "a\nb\nc"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell-0 cell-1))))
    (unwind-protect
        (progn
          ;; Assert — composite line 4 (cell-line 1 of cell-1)
          (let ((result (ejn-lsp-pos-from-composite notebook 4)))
            (should (equal (car result) cell-1))
            (should (equal (cdr result) 1)))
          ;; Assert — composite line 3 (cell-line 0 of cell-1)
          (let ((result (ejn-lsp-pos-from-composite notebook 3)))
            (should (equal (car result) cell-1))
            (should (equal (cdr result) 0)))
          ;; Assert — composite line 5 (cell-line 2 of cell-1)
          (let ((result (ejn-lsp-pos-from-composite notebook 5)))
            (should (equal (car result) cell-1))
            (should (equal (cdr result) 2))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t09--beyond-last-cell-returns-nil ()
  "Composite line beyond the last cell returns nil."
  ;; Arrange: one code cell with source "x = 1"
  ;; composite: line 0 = sentinel, line 1 = source. Total: 2 lines.
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    (unwind-protect
        (let ((result (ejn-lsp-pos-from-composite notebook 99)))
          ;; Assert — line 99 is beyond the file → nil
          (should-not result))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t09--mixed-cell-types-skips-non-code ()
  "With markdown between code cells, only code cells are in composite."
  ;; Arrange: [code, markdown, code]
  ;; composite contains only the two code cells
  ;; cell-0 source "x = 1": line 0 = sentinel, line 1 = source
  ;; cell-2 source "y = 2": line 2 = sentinel, line 3 = source
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell-code0 (make-instance 'ejn-cell
                                    :type 'code
                                    :source "x = 1"))
         (cell-md (make-instance 'ejn-cell
                                 :type 'markdown
                                 :source "# Header"))
         (cell-code1 (make-instance 'ejn-cell
                                    :type 'code
                                    :source "y = 2"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell-code0 cell-md cell-code1))))
    (unwind-protect
        (progn
          ;; Composite line 0 → sentinel → nil
          (should-not (ejn-lsp-pos-from-composite notebook 0))
          ;; Composite line 1 → cell-code0, line 0
          (let ((result (ejn-lsp-pos-from-composite notebook 1)))
            (should (equal (car result) cell-code0))
            (should (equal (cdr result) 0)))
          ;; Composite line 2 → sentinel → nil
          (should-not (ejn-lsp-pos-from-composite notebook 2))
          ;; Composite line 3 → cell-code1, line 0
          (let ((result (ejn-lsp-pos-from-composite notebook 3)))
            (should (equal (car result) cell-code1))
            (should (equal (cdr result) 0))))
      (delete-directory tmp-dir 'recursive))))

;;; Tests — P3-T10: ejn-lsp-cell-code-index

(ert-deftest ejn-lsp-p3-t10--first-code-cell-returns-zero ()
  "First code cell in notebook returns code index 0."
  ;; Arrange
  (let* ((cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :cells (list cell))))
    ;; Act
    (let ((result (ejn-lsp-cell-code-index cell notebook)))
      ;; Assert
      (should (equal result 0)))))

(ert-deftest ejn-lsp-p3-t10--second-code-cell-returns-one ()
  "Second code cell in notebook returns code index 1."
  ;; Arrange
  (let* ((cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "x = 1"))
         (cell-b (make-instance 'ejn-cell
                                :type 'code
                                :source "y = 2"))
         (notebook (make-instance 'ejn-notebook
                                  :cells (list cell-a cell-b))))
    ;; Act
    (let ((result (ejn-lsp-cell-code-index cell-b notebook)))
      ;; Assert
      (should (equal result 1)))))

(ert-deftest ejn-lsp-p3-t10--markdown-cell-returns-minus-one ()
  "Markdown cell returns -1 since it's not a code cell."
  ;; Arrange
  (let* ((cell (make-instance 'ejn-cell
                              :type 'markdown
                              :source "# Header"))
         (notebook (make-instance 'ejn-notebook
                                  :cells (list cell))))
    ;; Act
    (let ((result (ejn-lsp-cell-code-index cell notebook)))
      ;; Assert
      (should (equal result -1)))))

(ert-deftest ejn-lsp-p3-t10--raw-cell-returns-minus-one ()
  "Raw cell returns -1 since it's not a code cell."
  ;; Arrange
  (let* ((cell (make-instance 'ejn-cell
                              :type 'raw
                              :source "raw content"))
         (notebook (make-instance 'ejn-notebook
                                  :cells (list cell))))
    ;; Act
    (let ((result (ejn-lsp-cell-code-index cell notebook)))
      ;; Assert
      (should (equal result -1)))))

(ert-deftest ejn-lsp-p3-t10--code-after-markdown-returns-code-index ()
  "Code cell after markdown returns its code-only index (not total position).
Notebook: [markdown, code, code]. Second cell (first code) → 0, third cell (second code) → 1."
  ;; Arrange
  (let* ((cell-md (make-instance 'ejn-cell
                                 :type 'markdown
                                 :source "# Header"))
         (cell-code0 (make-instance 'ejn-cell
                                    :type 'code
                                    :source "a = 1"))
         (cell-code1 (make-instance 'ejn-cell
                                    :type 'code
                                    :source "b = 2"))
         (notebook (make-instance 'ejn-notebook
                                  :cells (list cell-md cell-code0 cell-code1))))
    ;; Act & Assert
    ;; First code cell (at total position 1) has code-index 0
    (should (equal (ejn-lsp-cell-code-index cell-code0 notebook) 0))
    ;; Second code cell (at total position 2) has code-index 1
    (should (equal (ejn-lsp-cell-code-index cell-code1 notebook) 1))
    ;; Markdown cell returns -1
    (should (equal (ejn-lsp-cell-code-index cell-md notebook) -1))))

(ert-deftest ejn-lsp-p3-t10--only-code-cells-same-as-total-index ()
  "When all cells are code, code-index equals total position."
  ;; Arrange
  (let* ((cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "a = 1"))
         (cell-b (make-instance 'ejn-cell
                                :type 'code
                                :source "b = 2"))
         (cell-c (make-instance 'ejn-cell
                                :type 'code
                                :source "c = 3"))
         (notebook (make-instance 'ejn-notebook
                                  :cells (list cell-a cell-b cell-c))))
    ;; Act & Assert
    (should (equal (ejn-lsp-cell-code-index cell-a notebook) 0))
    (should (equal (ejn-lsp-cell-code-index cell-b notebook) 1))
    (should (equal (ejn-lsp-cell-code-index cell-c notebook) 2))))

;;; Tests — P3-T11: ejn-lsp--register-virtual-buffer

(ert-deftest ejn-lsp-p3-t11--calls-lsp-virtual-buffer-register-with-correct-args ()
  "Verify `ejn-lsp--register-virtual-buffer' calls `lsp-virtual-buffer-register'
with :real-buffer, :virtual-file (composite path), and :offset-line."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "print('hello')"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (expected-composite-path (ejn-lsp-composite-path notebook))
         (expected-offset (ejn-lsp-pos-to-composite cell notebook 0 0)))
    (unwind-protect
        (progn
          ;; Reset captured args
          (setq ejn-lsp--test-captured-args nil)
          ;; Open the cell buffer so :real-buffer has a value
          (ejn-cell-open-buffer cell notebook)
          (let ((real-buf (slot-value cell 'buffer)))
            ;; Act
            (ejn-lsp--register-virtual-buffer cell notebook)
            ;; Assert — captured args is a plist:
            ;;   (:real-buffer BUF :virtual-file PATH :offset-line OFFSET)
            (let ((captured ejn-lsp--test-captured-args))
              (should captured)
              (should (eq (car captured) ':real-buffer))
              (should (eq (cadr captured) real-buf))
              (should (eq (nth 2 captured) ':virtual-file))
              (should (string= (nth 3 captured) expected-composite-path))
              (should (eq (nth 4 captured) ':offset-line))
              (should (equal (nth 5 captured) expected-offset))))
          ;; Cleanup buffer
          (when (slot-value cell 'buffer)
            (kill-buffer (slot-value cell 'buffer))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t11--sets-cell-lsp-attached-p-to-t ()
  "Verify `ejn-lsp--register-virtual-buffer' sets `ejn--cell-lsp-attached-p' to t."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
     (unwind-protect
         (progn
           (ejn-cell-open-buffer cell notebook)
           ;; P3-T17 wiring sets the flag during open; reset it so we can
           ;; verify --register-virtual-buffer sets it from nil → t.
           (with-current-buffer (slot-value cell 'buffer)
             (set (make-local-variable 'ejn--cell-lsp-attached-p) nil))
           ;; Before registration, flag should be nil
           (with-current-buffer (slot-value cell 'buffer)
             (should-not (bound-and-true-p ejn--cell-lsp-attached-p)))
           ;; Act
           (ejn-lsp--register-virtual-buffer cell notebook)
           ;; Assert — flag is set to t
           (with-current-buffer (slot-value cell 'buffer)
             (should ejn--cell-lsp-attached-p))
           ;; Cleanup
           (kill-buffer (slot-value cell 'buffer)))
       (delete-directory tmp-dir 'recursive))))

;;; Tests — P3-T12: ejn-lsp--register-fallback

(ert-deftest ejn-lsp-p3-t12--calls-generate-composite ()
  "Fallback registration calls `ejn-lsp-generate-composite' for the notebook."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (generate-called nil))
    (unwind-protect
        (progn
          (cl-letf (((symbol-function 'lsp)
                     (lambda (&rest _args) nil))
                    ((symbol-function 'ejn-lsp-generate-composite)
                     (lambda (notebook)
                       (setq generate-called t)
                       (ejn-lsp-composite-path notebook))))
            (with-temp-buffer
              (ejn-lsp--register-fallback cell notebook)))
          (should generate-called))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t12--calls-lsp-on-composite-path ()
  "Fallback registration calls `lsp' on the composite file path."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (lsp-called-paths '()))
    (unwind-protect
        (progn
          (cl-letf (((symbol-function 'lsp)
                     (lambda (path)
                       (push path lsp-called-paths))))
            (with-temp-buffer
              (ejn-lsp--register-fallback cell notebook)))
          (should (equal (car lsp-called-paths)
                         (ejn-lsp-composite-path notebook))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t12--shows-warning-message ()
  "Fallback registration displays a warning message about limited position translation."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (messages-captured '()))
    (unwind-protect
        (progn
          (cl-letf (((symbol-function 'lsp)
                     (lambda (&rest _args) nil))
                    ((symbol-function 'message)
                     (lambda (&rest args)
                       (push (apply #'format args) messages-captured)
                       nil)))
            (with-temp-buffer
              (ejn-lsp--register-fallback cell notebook)))
          (should (cl-loop for msg in messages-captured
                           thereis (and (stringp msg)
                                        (string-match "limit" msg)))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t12--sets-cell-lsp-attached-p ()
  "Fallback registration sets `ejn--cell-lsp-attached-p' to `t'."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell notebook)
          (cl-letf (((symbol-function 'lsp)
                     (lambda (&rest _args) nil)))
            (ejn-lsp--register-fallback cell notebook))
          (with-current-buffer (slot-value cell 'buffer)
            (should (equal (bound-and-true-p ejn--cell-lsp-attached-p) t)))
          (kill-buffer (slot-value cell 'buffer)))
      (delete-directory tmp-dir 'recursive))))


;;; Tests — P3-T13: ejn-lsp-register-cell

(ert-deftest ejn-lsp-p3-t13--idempotent-when-already-attached ()
  "When `ejn--cell-lsp-attached-p' is already t, do not call registration."
  ;; Arrange: create cell with buffer, set flag, reset captured args
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
     (unwind-protect
         (progn
           (ejn-cell-open-buffer cell notebook)
           ;; P3-T17 wiring calls register-cell during open, which sets
           ;; ejn-lsp--test-captured-args. Clear it so we can detect NEW calls.
           (setq ejn-lsp--test-captured-args nil)
           ;; Ensure flag is t (P3-T17 may have set it, but be explicit).
           (with-current-buffer (slot-value cell 'buffer)
             (set (make-local-variable 'ejn--cell-lsp-attached-p) t))
           ;; Act
           (ejn-lsp-register-cell cell notebook)
           ;; Assert: lsp-virtual-buffer-register should NOT have been called
           ;; again (idempotent)
           (should-not ejn-lsp--test-captured-args)
           (kill-buffer (slot-value cell 'buffer)))
       (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t13--dispatches-to-virtual-buffer-when-available ()
  "When `ejn--cell-lsp-attached-p' is nil, dispatch to `ejn-lsp--register-virtual-buffer'."
  ;; Arrange: create cell with buffer, flag NOT set, reset captured args
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (ejn-lsp--test-captured-args nil))
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell notebook)
          ;; Act
          (ejn-lsp-register-cell cell notebook)
          ;; Assert: lsp-virtual-buffer-register should have been called
          (should ejn-lsp--test-captured-args)
          (kill-buffer (slot-value cell 'buffer)))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t13--dispatches-to-fallback-when-virtual-buffer-fails ()
  "When `ejn-lsp--register-virtual-buffer' errors, dispatch to `ejn-lsp--register-fallback'."
  ;; Arrange: create cell, shadow virtual-buffer to signal error, track fallback calls
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (fallback-called nil))
     (unwind-protect
         (progn
           (ejn-cell-open-buffer cell notebook)
           ;; P3-T17 wiring sets the flag during open; reset to nil so that
           ;; ejn-lsp-register-cell will attempt registration (and hit our shadow).
           (with-current-buffer (slot-value cell 'buffer)
             (set (make-local-variable 'ejn--cell-lsp-attached-p) nil))
           (cl-letf (((symbol-function 'ejn-lsp--register-virtual-buffer)
                      (lambda (&rest _)
                        (signal 'error '("virtual-buffer-failed"))))
                     ((symbol-function 'ejn-lsp--register-fallback)
                      (lambda (c n)
                        (setq fallback-called t))))
             ;; Act
             (ejn-lsp-register-cell cell notebook))
           ;; Assert: fallback should have been called
           (should fallback-called)
           (kill-buffer (slot-value cell 'buffer)))
       (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t13--no-op-when-cell-has-no-buffer ()
  "When the cell has no buffer, do nothing."
  ;; Arrange: cell with no buffer, reset captured args
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (ejn-lsp--test-captured-args nil))
    ;; Act — cell has no buffer slot set
    (ejn-lsp-register-cell cell notebook)
    ;; Assert: nothing should have been called
    (should-not ejn-lsp--test-captured-args)
    ;; Cleanup
    (delete-directory tmp-dir 'recursive)))

;;; Tests — P3-T14: ejn-lsp-unregister-cell

(ert-deftest ejn-lsp-p3-t14--unregister-clears-attached-flag ()
  "Smoke: `ejn-lsp-unregister-cell' clears `ejn--cell-lsp-attached-p' in the cell's buffer."
  ;; Arrange: create cell with buffer, set attached flag, reset stub vars
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (ejn-lsp--test-unregister-called nil)
         (ejn-lsp--test-kill-workspace-called nil))
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell notebook)
          (with-current-buffer (slot-value cell 'buffer)
            (set (make-local-variable 'ejn--cell-lsp-attached-p) t))
          ;; Act
          (ejn-lsp-unregister-cell cell)
          ;; Assert: flag should be cleared
          (with-current-buffer (slot-value cell 'buffer)
            (should-not ejn--cell-lsp-attached-p))
          (kill-buffer (slot-value cell 'buffer)))
      (delete-directory tmp-dir 'recursive))))

;;; Tests — P3-T15: ejn-lsp-setup-cell-buffer

(ert-deftest ejn-lsp-p3-t15--sets-default-directory-to-notebook-dir ()
  "Verify `default-directory' in the cell buffer equals notebook's parent directory."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell notebook)
          ;; Act
          (ejn-lsp-setup-cell-buffer cell notebook)
          ;; Assert
          (with-current-buffer (slot-value cell 'buffer)
            (should (string= default-directory
                             (file-name-directory nb-path))))
          (kill-buffer (slot-value cell 'buffer)))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t15--generates-composite-when-not-existent ()
  "Verify composite file is generated if it doesn't exist before setup."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (composite-path (ejn-lsp-composite-path notebook))
         (register-cell-called nil))
     (unwind-protect
         (progn
           ;; Shadow setup-cell-buffer during open to prevent P3-T17 wiring
           ;; from generating composite and setting the flag.
           (cl-letf (((symbol-function 'ejn-lsp-setup-cell-buffer)
                      (lambda (&rest _) nil)))
             (ejn-cell-open-buffer cell notebook))
           ;; Composite should not exist yet
           (should-not (file-exists-p composite-path))
           ;; Shadow register-cell to prevent it from running
           (cl-letf (((symbol-function 'ejn-lsp-register-cell)
                      (lambda (_c _n)
                        (setq register-cell-called t))))
             ;; Act
             (ejn-lsp-setup-cell-buffer cell notebook))
           ;; Assert
           (should (file-exists-p composite-path))
           (should register-cell-called)
           (kill-buffer (slot-value cell 'buffer)))
       (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t15--skips-composite-when-already-exists ()
  "Verify `ejn-lsp-generate-composite' is NOT called when composite already exists."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (composite-path (ejn-lsp-composite-path notebook))
         (generate-called nil)
         (register-cell-called nil))
     (unwind-protect
         (progn
           ;; Pre-create the composite file
           (make-directory (file-name-directory composite-path) t)
           (with-temp-file composite-path
             (insert "# pre-existing"))
           ;; Shadow setup-cell-buffer during open to prevent P3-T17 wiring
           ;; from setting the flag, so setup-cell-buffer actually runs below.
           (cl-letf (((symbol-function 'ejn-lsp-setup-cell-buffer)
                      (lambda (&rest _) nil)))
             (ejn-cell-open-buffer cell notebook))
           ;; Shadow both functions to track calls
           (cl-letf (((symbol-function 'ejn-lsp-generate-composite)
                      (lambda (_n)
                        (setq generate-called t)
                        composite-path))
                     ((symbol-function 'ejn-lsp-register-cell)
                      (lambda (_c _n)
                        (setq register-cell-called t))))
             ;; Act
             (ejn-lsp-setup-cell-buffer cell notebook))
           ;; Assert: generate was NOT called, but register was
           (should-not generate-called)
           (should register-cell-called)
           (kill-buffer (slot-value cell 'buffer)))
       (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t15--calls-register-cell ()
  "Verify `ejn-lsp-register-cell' is called with the correct cell and notebook."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (captured-args nil))
     (unwind-protect
         (progn
           ;; Shadow setup-cell-buffer during open to prevent P3-T17 wiring
           ;; from setting the flag, so setup-cell-buffer actually runs.
           (cl-letf (((symbol-function 'ejn-lsp-setup-cell-buffer)
                      (lambda (&rest _) nil)))
             (ejn-cell-open-buffer cell notebook))
           (cl-letf (((symbol-function 'ejn-lsp-register-cell)
                      (lambda (c n)
                        (setq captured-args (list c n)))))
             ;; Act
             (ejn-lsp-setup-cell-buffer cell notebook))
           ;; Assert
           (should (equal (car captured-args) cell))
           (should (equal (cadr captured-args) notebook))
           (kill-buffer (slot-value cell 'buffer)))
       (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t15--idempotent-when-already-attached ()
  "When `ejn--cell-lsp-attached-p' is already t, setup does nothing."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (register-cell-called nil)
         (generate-called nil))
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell notebook)
          ;; Manually set the attached flag to t
          (with-current-buffer (slot-value cell 'buffer)
            (set (make-local-variable 'ejn--cell-lsp-attached-p) t))
          ;; Shadow both functions to verify they're NOT called
          (cl-letf (((symbol-function 'ejn-lsp-generate-composite)
                     (lambda (_n)
                       (setq generate-called t)))
                    ((symbol-function 'ejn-lsp-register-cell)
                     (lambda (_c _n)
                       (setq register-cell-called t))))
            ;; Act
            (ejn-lsp-setup-cell-buffer cell notebook))
          ;; Assert: neither function should have been called
          (should-not generate-called)
          (should-not register-cell-called)
          (kill-buffer (slot-value cell 'buffer)))
      (delete-directory tmp-dir 'recursive))))

;;; Tests — P3-T16: ejn-kernel-complete

(ert-deftest ejn-lsp-p3-t16--signals-user-error ()
  "Verify `ejn-kernel-complete' signals `user-error' with the expected message."
  (should-error (ejn-kernel-complete #'ignore)
                :type 'user-error)
  ;; Verify the error message content
  (condition-case err
      (ejn-kernel-complete #'ignore)
    (user-error
     (should (string= (car (cdr err))
                      "Kernel completion requires Phase 4")))))

;;; Tests — P3-T17: ejn-lsp-setup-cell-buffer call in ejn-cell-open-buffer

(ert-deftest ejn-lsp-p3-t17--open-buffer-calls-setup-cell-buffer ()
  "Smoke: `ejn-cell-open-buffer' calls `ejn-lsp-setup-cell-buffer' when a notebook is provided."
  ;; Arrange: create a fresh cell (no buffer slot set)
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (captured-cell nil)
         (captured-notebook nil))
    (unwind-protect
        (progn
          ;; Shadow ejn-lsp-setup-cell-buffer and call ejn-cell-open-buffer
          ;; inside the shadow so the internal call hits our stub.
          (cl-letf (((symbol-function 'ejn-lsp-setup-cell-buffer)
                     (lambda (c n)
                       (setq captured-cell c
                             captured-notebook n))))
            (ejn-cell-open-buffer cell notebook))
          ;; Assert: the stub was called with the expected cell and notebook
          (should (eq captured-cell cell))
          (should (eq captured-notebook notebook))
          (kill-buffer (slot-value cell 'buffer)))
      (delete-directory tmp-dir 'recursive))))

;;; Tests — P3-T18: lsp-completion-at-point in completion-at-point-functions

(ert-deftest ejn-lsp-p3-t18--adds-lsp-completion-to-cell-buffer ()
  "Smoke: `ejn-lsp-setup-cell-buffer' adds `lsp-completion-at-point'
to buffer-local `completion-at-point-functions'."
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell))))
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell notebook)
          ;; Act
          (ejn-lsp-setup-cell-buffer cell notebook)
          ;; Assert: lsp-completion-at-point is in completion-at-point-functions
          (with-current-buffer (slot-value cell 'buffer)
            (should (memq #'lsp-completion-at-point
                          completion-at-point-functions)))
          (kill-buffer (slot-value cell 'buffer)))
      (delete-directory tmp-dir 'recursive))))

;;; Tests — P3-T19: ejn:pytools-jump-to-source

(ert-deftest ejn-lsp-p3-t19--signals-user-error-when-xref-nil ()
  "When `lsp-find-definition' returns nil, signal `user-error'."
  ;; Arrange: set up a cell buffer with ejn--cell and ejn--notebook bound
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (ejn-lsp--test-find-def-position nil)
         ;; lsp-find-definition returns nil (no definition found)
         (lsp-def-result nil))
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell notebook)
          (with-current-buffer (slot-value cell 'buffer)
            (cl-letf (((symbol-function 'lsp-find-definition)
                       (lambda (_pos) lsp-def-result)))
              ;; Act & Assert: should signal user-error
              (should-error (call-interactively #'ejn:pytools-jump-to-source)
                            :type 'user-error)))
          (kill-buffer (slot-value cell 'buffer)))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t19--calls-lsp-find-definition-with-composite-position ()
  "Calls `lsp-find-definition' with the composite position translated from point."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (captured-position nil)
         (expected-composite (ejn-lsp-pos-to-composite cell notebook 0 0)))
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell notebook)
          ;; Reset stub state
          (setq ejn-lsp--test-find-def-position nil)
          (with-current-buffer (slot-value cell 'buffer)
            (goto-char (point-min))
            ;; Shadow lsp-find-definition to capture its argument
            (cl-letf (((symbol-function 'lsp-find-definition)
                       (lambda (pos)
                         (setq captured-position pos)
                         nil)))
              ;; Act: call the command; it will error because xref is nil,
              ;; but we only care that lsp-find-definition was called with
              ;; the correct composite position
              (condition-case-unless-debug _err
                  (call-interactively #'ejn:pytools-jump-to-source)
                (user-error nil))))
          ;; Assert
          (should (equal captured-position expected-composite)))
        (when (slot-value cell 'buffer)
          (kill-buffer (slot-value cell 'buffer)))
        (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-lsp-p3-t19--switches-to-target-cell-buffer ()
  "When xref is found, switch to the target cell's buffer at the resolved line."
  ;; Arrange: two code cells; jump from cell-0 to cell-1
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell-0 (make-instance 'ejn-cell
                                :type 'code
                                :source "import os"))
         (cell-1 (make-instance 'ejn-cell
                                :type 'code
                                :source "os.path.join"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell-0 cell-1)))
         (xref-result nil))
    (unwind-protect
        (progn
          ;; Open both cell buffers
          (ejn-cell-open-buffer cell-0 notebook)
          (ejn-cell-open-buffer cell-1 notebook)
          ;; Set up xref result (dummy; translate-xref-to-cell will return cell-1 info)
          (setq xref-result '(dummy-xref))
          (with-current-buffer (slot-value cell-0 'buffer)
            (goto-char (point-min))
            (cl-letf (((symbol-function 'lsp-find-definition)
                       (lambda (_pos) xref-result))
                      ((symbol-function 'ejn-lsp--translate-xref-to-cell)
                       (lambda (_xref _nb)
                         (cons (slot-value cell-1 'buffer) 0))))
              ;; Act
              (call-interactively #'ejn:pytools-jump-to-source)))
          ;; Assert: we should now be in cell-1's buffer
          (should (eq (window-buffer (selected-window))
                      (slot-value cell-1 'buffer)))
          (kill-buffer (slot-value cell-0 'buffer))
          (kill-buffer (slot-value cell-1 'buffer)))
      (delete-directory tmp-dir 'recursive))))

;;; Tests — P3-T20: ejn-lsp--translate-xref-to-cell

(ert-deftest ejn-lsp-p3-t20--returns-nil-for-non-composite-file ()
  "Returns nil when xref points to a file other than the composite."
  ;; Arrange: create an xref pointing to a non-composite file
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (xref (xref-make "dummy"
                          (xref-make-file-location "/some/other/file.py" 5 0))))
    ;; Act
    (let ((result (ejn-lsp--translate-xref-to-cell xref notebook)))
      ;; Assert
      (should-not result))
    (delete-directory tmp-dir 'recursive)))

(ert-deftest ejn-lsp-p3-t20--returns-nil-when-composite-line-is-sentinel ()
  "Returns nil when the composite line maps to a sentinel/separator."
  ;; Arrange: notebook with one code cell; composite line 0 is the sentinel
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (composite-path (ejn-lsp-composite-path notebook))
         ;; Line 1 (1-based) = line 0 (0-based) = sentinel line → nil
         (xref (xref-make "dummy"
                          (xref-make-file-location composite-path 1 0))))
    ;; Act
    (let ((result (ejn-lsp--translate-xref-to-cell xref notebook)))
      ;; Assert: sentinel line → nil
      (should-not result))
    (delete-directory tmp-dir 'recursive)))

(ert-deftest ejn-lsp-p3-t20--returns-cell-buffer-and-line-for-valid-composite-xref ()
  "Returns (buffer . line) when xref maps to a valid cell line in composite."
  ;; Arrange: notebook with two code cells; xref points to cell-1's line in composite
  ;; composite layout:
  ;;   line 0 (0-based) = sentinel for cell-0
  ;;   line 1 = "import os"  (cell-0 source, cell-line 0)
  ;;   line 2 = sentinel for cell-1
  ;;   line 3 = "os.path.join"  (cell-1 source, cell-line 0)
  ;; xref line 4 (1-based) = line 3 (0-based) → cell-1, cell-line 0
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell-0 (make-instance 'ejn-cell
                                :type 'code
                                :source "import os"))
         (cell-1 (make-instance 'ejn-cell
                                :type 'code
                                :source "os.path.join"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell-0 cell-1)))
         (composite-path (ejn-lsp-composite-path notebook))
         (xref (xref-make "dummy"
                          (xref-make-file-location composite-path 4 0))))
    ;; Open both cell buffers
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell-0 notebook)
          (ejn-cell-open-buffer cell-1 notebook)
          ;; Act
          (let ((result (ejn-lsp--translate-xref-to-cell xref notebook)))
            ;; Assert
            (should result)
            (should (eq (car result) (slot-value cell-1 'buffer)))
            (should (equal (cdr result) 0)))
          (kill-buffer (slot-value cell-0 'buffer))
          (kill-buffer (slot-value cell-1 'buffer)))
      (delete-directory tmp-dir 'recursive))))

;;; Tests — P3-T21: ejn:pytools-jump-back

(ert-deftest ejn-lsp-p3-t21--smoke-jump-back-is-defined-and-interactive ()
  "Smoke: `ejn:pytools-jump-back' is defined and interactive."
  (should (fboundp #'ejn:pytools-jump-back))
  (should (commandp #'ejn:pytools-jump-back)))

;;; Tests — P3-T22: M-. keybinding in ejn-mode-map

(ert-deftest ejn-lsp-p3-t22--m-dot-bound-to-jump-to-source-in-ejn-mode-map ()
  "Smoke: `M-.' is bound to `ejn:pytools-jump-to-source' in `ejn-mode-map'."
  (should (eq (lookup-key ejn-mode-map (kbd "M-."))
              #'ejn:pytools-jump-to-source)))

;;; Tests — P3-T23: M-, keybinding in ejn-mode-map

(ert-deftest ejn-lsp-p3-t23--smoke-m-comma-binds-jump-back ()
  "Smoke: `M-,' is bound to `ejn:pytools-jump-back' in `ejn-mode-map'."
  (should (eq (lookup-key ejn-mode-map (kbd "M-,"))
              #'ejn:pytools-jump-back)))

;;; Tests — P3-T24: ejn--cell-kill-buffer-hook calls ejn-lsp-unregister-cell

(ert-deftest ejn-lsp-p3-t24--kill-hook-calls-unregister-cell ()
  "Smoke: killing a cell buffer triggers `ejn-lsp-unregister-cell' via
`ejn--cell-kill-buffer-hook'."
  ;; Arrange
  (let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (nb-path (expand-file-name "test.ipynb" tmp-dir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"))
         (notebook (make-instance 'ejn-notebook
                                  :path nb-path
                                  :cells (list cell)))
         (unregister-captured-cell nil))
    (unwind-protect
        (progn
          (ejn-cell-open-buffer cell notebook)
          (let ((buf (slot-value cell 'buffer)))
            ;; Shadow ejn-lsp-unregister-cell to capture the cell arg
            (cl-letf (((symbol-function 'ejn-lsp-unregister-cell)
                       (lambda (c)
                         (setq unregister-captured-cell c))))
              ;; Act: kill the buffer, which runs ejn--cell-kill-buffer-hook
              (kill-buffer buf)))
          ;; Assert: ejn-lsp-unregister-cell was called with our cell
          (should (eq unregister-captured-cell cell)))
      (delete-directory tmp-dir 'recursive))))

;;; ejn-lsp-tests.el ends here
