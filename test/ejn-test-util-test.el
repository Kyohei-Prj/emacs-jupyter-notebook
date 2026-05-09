;;; ejn-test-util-test.el --- Tests for test utilities  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-test-util)

;;; Code:

(ert-deftest ejn-test-util-test/fixture-directory-exists ()
  "Test fixture directory should exist."
  (should (f-dir? ejn-test-fixtures-directory)))

(ert-deftest ejn-test-util-test/load-sample-notebook-returns-json ()
  "Loading the sample notebook should return valid JSON."
  (let ((data (ejn-test-load-fixture "sample.ipynb")))
    (should (consp data))))

(provide 'ejn-test-util-test)
;;; ejn-test-util-test.el ends here
