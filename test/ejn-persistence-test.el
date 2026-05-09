;;; ejn-persistence-test.el --- Tests for ejn-persistence  -*- lexical-binding: t; -*-

(require 'ert)

;;; Code:

(ert-deftest ejn-persistence-test/ipynb-backend-registered ()
  "The .ipynb backend should be auto-registered."
  (require 'ejn-persistence)
  (should (ejn-persistence-backend-for "test.ipynb")))

(ert-deftest ejn-persistence-test/non-ipynb-returns-nil ()
  "Non-.ipynb files should return nil."
  (require 'ejn-persistence)
  (should-not (ejn-persistence-backend-for "test.py")))

(ert-deftest ejn-persistence-test/can-handle-p-works ()
  "Backend can-handle-p should return correct values."
  (require 'ejn-persistence)
  (let ((backend (ejn-persistence-backend-for "test.ipynb")))
    (should (ejn-persistence-can-handle-p backend "foo.ipynb"))
    (should-not (ejn-persistence-can-handle-p backend "foo.py"))))

(provide 'ejn-persistence-test)
;;; ejn-persistence-test.el ends here
