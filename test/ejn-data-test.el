;;; ejn-data-test.el --- Tests for ejn-data  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;; Commentary:

;; Tests for ejn-data module covering:
;; - P2-T13: ejn-cell, ejn-output, ejn-notebook construction and slot access
;; - P2-T17: cell manipulation helpers (insert, delete, move, update-source)

;; Code:

(require 'test-helper)
(require 'ejn-data)

(ert-deftest ejn-data-test-smoke-cell ()
  "Smoke test: ejn-cell struct is importable and constructible."
  (let ((cell (ejn-make-cell :id "a1b2c3d4-e5f6-7890-abcd-ef1234567890")))
    (should (ejn-cell-p cell))
    (should (string= (ejn-cell-id cell) "a1b2c3d4-e5f6-7890-abcd-ef1234567890"))
    (should (eq (ejn-cell-type cell) 'code))
    (should (string= (ejn-cell-language cell) "python"))
    (should (string= (ejn-cell-source cell) ""))
    (should (eq (ejn-cell-outputs cell) nil))
    (should (eq (ejn-cell-execution-count cell) nil))
    (should (hash-table-p (ejn-cell-metadata cell)))
    (should (eq (hash-table-test (ejn-cell-metadata cell)) 'equal))))

(ert-deftest ejn-data-test-smoke-output ()
  "Smoke test: ejn-output struct is importable and constructible."
  (let ((output (ejn-make-output :output-type 'error
                                 :ename "NameError"
                                 :evalue "name not defined"
                                 :traceback "(traceback line)\n")))
    (should (ejn-output-p output))
    (should (eq (ejn-output-output-type output) 'error))
    (should (string= (ejn-output-ename output) "NameError"))
    (should (string= (ejn-output-evalue output) "name not defined"))
    (should (string= (ejn-output-traceback output) "(traceback line)\n"))
    (should (hash-table-p (ejn-output-data output)))
    (should (hash-table-p (ejn-output-metadata output)))))

(ert-deftest ejn-data-test-smoke-notebook ()
  "Smoke test: ejn-notebook struct is importable and constructible."
  (let ((nb (ejn-make-notebook :path "/tmp/test.ipynb"
                               :kernel-name "python3"
                               :language "python")))
    (should (ejn-notebook-p nb))
    (should (string= (ejn-notebook-path nb) "/tmp/test.ipynb"))
    (should (= (ejn-notebook-nbformat nb) 4))
    (should (= (ejn-notebook-nbformat-minor nb) 5))
    (should (string= (ejn-notebook-kernel-name nb) "python3"))
    (should (string= (ejn-notebook-language nb) "python"))
    (should (eq (ejn-notebook-cells nb) nil))
    (should (eq (ejn-notebook-dirty-p nb) nil))
    (should (hash-table-p (ejn-notebook-metadata nb)))))

(ert-deftest ejn-data-test-smoke-cell-by-id ()
  "Smoke test: ejn-notebook-cell-by-id returns correct cell or nil."
  (let* ((cell1 (ejn-make-cell :id "id-1"))
         (cell2 (ejn-make-cell :id "id-2"))
         (nb (ejn-make-notebook :cells (list cell1 cell2))))
    (should (eq (ejn-notebook-cell-by-id nb "id-1") cell1))
    (should (eq (ejn-notebook-cell-by-id nb "id-2") cell2))
    (should-not (ejn-notebook-cell-by-id nb "nonexistent"))))

;;;; P2-T13: Notebook construction with all slots explicitly set

(ert-deftest ejn-data-test-notebook-construction-all-slots ()
  "P2-T13: ejn-make-notebook with all slots explicitly set.

Construct a notebook with every slot set to a non-default value,
then verify each slot accessor returns the expected value."
  (let* ((cell (ejn-make-cell :id "c1"))
         (meta (make-hash-table :test 'equal))
         (nb (ejn-make-notebook :path "/tmp/test.ipynb"
                                :nbformat 4
                                :nbformat-minor 5
                                :metadata meta
                                :kernel-name "python3"
                                :language "python"
                                :cells (list cell)
                                :dirty-p t)))
    (should (ejn-notebook-p nb))
    (should (string= (ejn-notebook-path nb) "/tmp/test.ipynb"))
    (should (= (ejn-notebook-nbformat nb) 4))
    (should (= (ejn-notebook-nbformat-minor nb) 5))
    (should (eq (eq (ejn-notebook-metadata nb) meta) t))
    (should (string= (ejn-notebook-kernel-name nb) "python3"))
    (should (string= (ejn-notebook-language nb) "python"))
    (should (= (length (ejn-notebook-cells nb)) 1))
    (should (eq (eq (cl-first (ejn-notebook-cells nb)) cell) t))
    (should (eq (ejn-notebook-dirty-p nb) t))))

(ert-deftest ejn-data-test-notebook-empty-cells ()
  "P2-T13: ejn-make-notebook with empty cells list.

Verify that a notebook with no cells has an empty cells list
and the default value for dirty-p."
  (let ((nb (ejn-make-notebook :cells nil)))
    (should (ejn-notebook-p nb))
    (should (eq (ejn-notebook-cells nb) nil))
    (should (eq (ejn-notebook-dirty-p nb) nil))))

;;;; P2-T17: Cell manipulation tests

(defun ejn-data-test--make-sample-notebook ()
  "Create a sample notebook with 3 cells for P2-T17 tests."
  (let* ((c1 (ejn-make-cell :id "a" :source "cell-a"))
         (c2 (ejn-make-cell :id "b" :source "cell-b"))
         (c3 (ejn-make-cell :id "c" :source "cell-c")))
    (ejn-make-notebook :path "/tmp/test.ipynb"
                       :kernel-name "python3"
                       :language "python"
                       :cells (list c1 c2 c3))))

(ert-deftest ejn-data-test-insert-at-zero ()
  "P2-T17: ejn-notebook-insert-cell at index 0 prepends the cell."
  (let* ((nb (ejn-data-test--make-sample-notebook))
         (new-cell (ejn-make-cell :id "x" :source "inserted"))
         (result (ejn-notebook-insert-cell nb new-cell 0)))
    (should (eq (ejn-notebook-cell-by-id result "x") (cl-first (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-cell-by-id result "a") (cl-second (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-dirty-p result) t))))

(ert-deftest ejn-data-test-insert-at-end ()
  "P2-T17: ejn-notebook-insert-cell at index >= length appends the cell."
  (let* ((nb (ejn-data-test--make-sample-notebook))
         (new-cell (ejn-make-cell :id "x" :source "inserted"))
         (result (ejn-notebook-insert-cell nb new-cell 10)))
    (should (= (length (ejn-notebook-cells result)) 4))
    (should (eq (ejn-notebook-cell-by-id result "a")
                (cl-first (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-cell-by-id result "c")
                (cl-third (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-cell-by-id result "x")
                (cl-fourth (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-dirty-p result) t))))

(ert-deftest ejn-data-test-delete-existing-cell ()
  "P2-T17: ejn-notebook-delete-cell removes the cell by UUID."
  (let* ((nb (ejn-data-test--make-sample-notebook))
         (result (ejn-notebook-delete-cell nb "b")))
    (should (eq (length (ejn-notebook-cells result)) 2))
    (should (eq (ejn-notebook-cell-by-id result "a")
                (cl-first (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-cell-by-id result "c")
                (cl-second (ejn-notebook-cells result))))
    (should-not (ejn-notebook-cell-by-id result "b"))
    (should (eq (ejn-notebook-dirty-p result) t))))

(ert-deftest ejn-data-test-delete-non-existing-cell ()
  "P2-T17: ejn-notebook-delete-cell with non-existing UUID is a no-op."
  (let* ((nb (ejn-data-test--make-sample-notebook))
         (result (ejn-notebook-delete-cell nb "nonexistent")))
    (should (= (length (ejn-notebook-cells result)) 3))
    (should (eq (ejn-notebook-dirty-p result) t))))

(ert-deftest ejn-data-test-move-cell-up ()
  "P2-T17: ejn-notebook-move-cell direction 'up moves a cell upward."
  (let* ((nb (ejn-data-test--make-sample-notebook))
         (result (ejn-notebook-move-cell nb "b" 'up)))
    (should (eq (ejn-notebook-cell-by-id result "b")
                (cl-first (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-cell-by-id result "a")
                (cl-second (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-dirty-p result) t))))

(ert-deftest ejn-data-test-move-cell-down ()
  "P2-T17: ejn-notebook-move-cell direction 'down moves a cell downward."
  (let* ((nb (ejn-data-test--make-sample-notebook))
         (result (ejn-notebook-move-cell nb "b" 'down)))
    (should (eq (ejn-notebook-cell-by-id result "a")
                (cl-first (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-cell-by-id result "c")
                (cl-second (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-cell-by-id result "b")
                (cl-third (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-dirty-p result) t))))

(ert-deftest ejn-data-test-move-first-cell-up ()
  "P2-T17: ejn-notebook-move-cell 'up on first cell is a no-op."
  (let* ((nb (ejn-data-test--make-sample-notebook))
         (result (ejn-notebook-move-cell nb "a" 'up)))
    (should (eq (ejn-notebook-cell-by-id result "a")
                (cl-first (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-cell-by-id result "b")
                (cl-second (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-dirty-p result) t))))

(ert-deftest ejn-data-test-move-last-cell-down ()
  "P2-T17: ejn-notebook-move-cell 'down on last cell is a no-op."
  (let* ((nb (ejn-data-test--make-sample-notebook))
         (result (ejn-notebook-move-cell nb "c" 'down)))
    (should (eq (ejn-notebook-cell-by-id result "a")
                (cl-first (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-cell-by-id result "c")
                (cl-third (ejn-notebook-cells result))))
    (should (eq (ejn-notebook-dirty-p result) t))))

(ert-deftest ejn-data-test-update-cell-source ()
  "P2-T17: ejn-notebook-update-cell-source replaces cell source and sets dirty."
  (let* ((nb (ejn-data-test--make-sample-notebook))
         (result (ejn-notebook-update-cell-source nb "a" "new-source")))
    (should (string= (ejn-cell-source (ejn-notebook-cell-by-id result "a"))
                     "new-source"))
    (should (string= (ejn-cell-source (ejn-notebook-cell-by-id result "b"))
                     "cell-b"))
    (should (eq (ejn-notebook-dirty-p result) t))))

(ert-deftest ejn-data-test-update-non-existing-cell-source ()
  "P2-T17: ejn-notebook-update-cell-source with non-existing UUID is a no-op."
  (let* ((nb (ejn-data-test--make-sample-notebook))
         (result (ejn-notebook-update-cell-source nb "nonexistent" "new-source")))
    (should (string= (ejn-cell-source (ejn-notebook-cell-by-id result "a"))
                     "cell-a"))
    (should (eq (ejn-notebook-dirty-p result) t))))

(provide 'ejn-data-test)
;;; ejn-data-test.el ends here
