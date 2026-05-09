;;; ejn-model-test.el --- Tests for ejn-model  -*- lexical-binding: t; -*-

(require 'ert)

;;; Code:

(ert-deftest ejn-model-test/notebook-creation ()
  "Creating a notebook should produce a valid struct."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (should (ejn-notebook-p nb))))

(ert-deftest ejn-model-test/notebook-defaults ()
  "New notebook should have correct defaults."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (should (stringp (ejn-notebook-id nb)))
    (should-not (ejn-notebook-path nb))
    (should (vectorp (ejn-notebook-cells nb)))
    (should (= (length (ejn-notebook-cells nb)) 0))
    (should-not (ejn-notebook-dirty nb))
    (should (= (ejn-notebook-nbformat nb) 4))
    (should (= (ejn-notebook-nbformat-minor nb) 5))
    (should (hash-table-p (ejn-notebook-dirty-set nb)))
    (should (listp (ejn-notebook-undo-history nb)))))

(ert-deftest ejn-model-test/dirty-tracker-mark-cell ()
  "Marking a cell dirty should add it to the dirty set."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-mark-dirty nb "cell-1")
    (should (member "cell-1" (ejn-notebook-dirty-cells nb)))))

(ert-deftest ejn-model-test/dirty-tracker-multiple-cells ()
  "Marking multiple cells dirty should track all of them."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-mark-dirty nb "cell-1")
    (ejn-notebook-mark-dirty nb "cell-2")
    (let ((dirty (ejn-notebook-dirty-cells nb)))
      (should (= (length dirty) 2))
      (should (member "cell-1" dirty))
      (should (member "cell-2" dirty)))))

(ert-deftest ejn-model-test/dirty-tracker-clean-cell ()
  "Cleaning a cell should remove it from the dirty set."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-mark-dirty nb "cell-1")
    (ejn-notebook-mark-dirty nb "cell-2")
    (ejn-notebook-clean-cell nb "cell-1")
    (let ((dirty (ejn-notebook-dirty-cells nb)))
      (should (= (length dirty) 1))
      (should (member "cell-2" dirty))
      (should-not (member "cell-1" dirty)))))

(ert-deftest ejn-model-test/dirty-tracker-clean-all ()
  "Cleaning all should clear the entire dirty set."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-mark-dirty nb "cell-1")
    (ejn-notebook-mark-dirty nb "cell-2")
    (ejn-notebook-clean-all nb)
    (should (= (length (ejn-notebook-dirty-cells nb)) 0))))

(ert-deftest ejn-model-test/dirty-tracker-idempotent-mark ()
  "Marking an already-dirty cell should not duplicate it."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-mark-dirty nb "cell-1")
    (ejn-notebook-mark-dirty nb "cell-1")
    (should (= (length (ejn-notebook-dirty-cells nb)) 1))))

(ert-deftest ejn-model-test/dirty-flag-set-on-mark ()
  "Marking a cell dirty should set the notebook dirty flag."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (should-not (ejn-notebook-dirty nb))
    (ejn-notebook-mark-dirty nb "cell-1")
    (should (ejn-notebook-dirty nb))))

(ert-deftest ejn-model-test/insert-cell-at-index ()
  "Inserting a cell at an index should place it correctly."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (should (= (length (ejn-notebook-cells nb)) 1))
    (should (eq (ejn-cell-type (ejn-notebook-cell-at-index nb 0)) 'code))))

(ert-deftest ejn-model-test/insert-cell-after-another ()
  "Inserting a cell after another should maintain order."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'markdown :at 0)
    (let ((first-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-notebook-insert-cell nb 'code :after first-id)
      (should (= (length (ejn-notebook-cells nb)) 2))
      (should (eq (ejn-cell-type (ejn-notebook-cell-at-index nb 1)) 'code)))))

(ert-deftest ejn-model-test/delete-cell-by-id ()
  "Deleting a cell should remove it from the notebook."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-notebook-delete-cell nb cell-id)
      (should (= (length (ejn-notebook-cells nb)) 0))
      (should-error (ejn-notebook-cell-by-id nb cell-id)))))

(ert-deftest ejn-model-test/set-cell-source ()
  "Setting cell source should update the source field."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-notebook-set-cell-source nb cell-id "print(42)")
      (should (string= (ejn-cell-source (ejn-notebook-cell-by-id nb cell-id))
                       "print(42)")))))

(ert-deftest ejn-model-test/cell-by-id-lookup ()
  "Looking up a cell by ID should return the correct cell."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell (ejn-notebook-cell-at-index nb 0))
          (cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (should (eq (ejn-notebook-cell-by-id nb cell-id) cell)))))

(ert-deftest ejn-model-test/cell-index-lookup ()
  "Getting cell index by ID should return the correct index."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'markdown :at 0)
    (ejn-notebook-insert-cell nb 'code :at 1)
    (let ((code-cell (ejn-notebook-cell-at-index nb 1)))
      (should (= (ejn-notebook-cell-index nb (ejn-cell-id code-cell)) 1)))))

(ert-deftest ejn-model-test/insert-marks-notebook-dirty ()
  "Inserting a cell should mark the notebook dirty."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (should (ejn-notebook-dirty nb))))

(ert-deftest ejn-model-test/delete-marks-notebook-dirty ()
  "Deleting a cell should mark the notebook dirty."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-clean-all nb)
    (ejn-notebook-delete-cell nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)))
    (should (ejn-notebook-dirty nb))))

(provide 'ejn-model-test)
;;; ejn-model-test.el ends here
