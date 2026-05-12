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

(ert-deftest ejn-test-util-test/with-notebook-buffer-is-defined ()
  "ejn-test-with-notebook-buffer macro should be defined."
  (should (fboundp 'ejn-test-with-notebook-buffer)))

(ert-deftest ejn-test-util-test/wait-for-sync-is-defined ()
  "ejn-test-wait-for-sync macro should be defined."
  (should (fboundp 'ejn-test-wait-for-sync)))

(provide 'ejn-test-util-test)
;;; ejn-test-util-test.el ends here
