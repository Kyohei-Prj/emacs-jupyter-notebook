;;; ejn-core-test.el --- Tests for ejn-core  -*- lexical-binding: t; -*-

(require 'ert)

;;; Code:

(ert-deftest ejn-core-test/package-version-exists ()
  "Check `ejn-version' is a non-empty string."
  (require 'ejn-core)
  (should (stringp ejn-version))
  (should (string-prefix-p "" ejn-version)))

(ert-deftest ejn-core-test/source-directory-is-set ()
  "Check `ejn-source-directory' points to the Lisp directory."
  (require 'ejn-core)
  (should (string-suffix-p "lisp/" ejn-source-directory)))

(ert-deftest ejn-core-test/defgroup-exists ()
  "Check the `ejn' custom group is defined."
  (require 'ejn-core)
  (should (get 'ejn 'custom-prefix)))

(ert-deftest ejn-core-test/auto-mode-opens-ipynb-files-in-ejn-mode ()
  "Files ending in .ipynb should open in ejn-mode."
  (require 'ejn)
  (should (cl-some (lambda (entry)
                     (and (eq (cdr entry) 'ejn-mode)
                          (string-match "\\.ipynb" (car entry))))
                   auto-mode-alist)))

(provide 'ejn-core-test)
;;; ejn-core-test.el ends here
