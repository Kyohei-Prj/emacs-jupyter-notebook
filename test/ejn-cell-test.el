;;; ejn-cell-test.el --- Tests for ejn-cell  -*- lexical-binding: t; -*-

(require 'ert)

;;; Code:

(ert-deftest ejn-cell-test/output-creation-with-valid-type ()
  "Creating an output with a valid type should succeed."
  (require 'ejn-cell)
  (let ((output (ejn-make-output 'stream)))
    (should (ejn-output-p output))
    (should (eq (ejn-output-type output) 'stream))))

(ert-deftest ejn-cell-test/output-defaults-are-nil ()
  "New outputs should have nil defaults for optional fields."
  (require 'ejn-cell)
  (let ((output (ejn-make-output 'display-data)))
    (should-not (ejn-output-mime-data output))
    (should-not (ejn-output-metadata output))
    (should-not (ejn-output-request-id output))))

(ert-deftest ejn-cell-test/output-rejects-invalid-type ()
  "Creating an output with an invalid type should signal an error."
  (require 'ejn-cell)
  (should-error (ejn-make-output 'invalid-type)))

(ert-deftest ejn-cell-test/output-accepts-all-valid-types ()
  "All valid output types should be accepted."
  (require 'ejn-cell)
  (dolist (type '(stream display-data execute-result error))
    (should (ejn-output-p (ejn-make-output type)))))

(ert-deftest ejn-cell-test/cell-creation-with-code-type ()
  "Creating a code cell should produce a valid cell struct."
  (require 'ejn-cell)
  (let ((cell (ejn-make-cell 'code)))
    (should (ejn-cell-p cell))
    (should (eq (ejn-cell-type cell) 'code))))

(ert-deftest ejn-cell-test/cell-accepts-all-types ()
  "All cell types should be accepted."
  (require 'ejn-cell)
  (dolist (type '(code markdown raw))
    (should (ejn-cell-p (ejn-make-cell type)))))

(ert-deftest ejn-cell-test/cell-rejects-invalid-type ()
  "Creating a cell with an invalid type should signal an error."
  (require 'ejn-cell)
  (should-error (ejn-make-cell 'invalid-type)))

(ert-deftest ejn-cell-test/cell-has-default-values ()
  "New cells should have correct default values."
  (require 'ejn-cell)
  (let ((cell (ejn-make-cell 'code)))
    (should (stringp (ejn-cell-id cell)))
    (should (string= "" (ejn-cell-source cell)))
    (should-not (ejn-cell-outputs cell))
    (should-not (ejn-cell-metadata cell))
    (should-not (ejn-cell-execution-count cell))
    (should (eq (ejn-cell-execution-state cell) 'idle))
    (should (= (ejn-cell-execution-version cell) 0))))

(ert-deftest ejn-cell-test/cell-ids-are-unique ()
  "Each created cell should have a unique ID."
  (require 'ejn-cell)
  (let ((cell1 (ejn-make-cell 'code))
        (cell2 (ejn-make-cell 'code)))
    (should-not (string= (ejn-cell-id cell1)
                         (ejn-cell-id cell2)))))

(provide 'ejn-cell-test)
;;; ejn-cell-test.el ends here
