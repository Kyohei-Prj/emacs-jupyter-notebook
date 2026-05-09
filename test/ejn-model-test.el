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
    (should (hash-table-p (ejn-notebook-dirty-cells nb)))
    (should (listp (ejn-notebook-undo-history nb)))))

(provide 'ejn-model-test)
;;; ejn-model-test.el ends here
