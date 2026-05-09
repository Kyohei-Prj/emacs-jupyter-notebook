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

(provide 'ejn-model-test)
;;; ejn-model-test.el ends here
