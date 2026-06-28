;;; ejn-test.el --- Tests for Emacs Jupyter Notebook -*- lexical-binding: t -*-

;; This file provides a minimal ERT test for smoke-testing the test harness.

(require 'ert)

(ert-deftest ejn-test-basic ()
  "Smoke test: ensure the test harness is working."
  (should t))

(provide 'ejn-test)
;;; ejn-test.el ends here
