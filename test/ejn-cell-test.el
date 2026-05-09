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

(provide 'ejn-cell-test)
;;; ejn-cell-test.el ends here
