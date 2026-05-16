;;; ejn-kernel-test.el --- Tests for ejn-kernel  -*- lexical-binding: t; -*-

(require 'cl-generic)
(require 'ert)

;;; Code:

(ert-deftest ejn-kernel-test/kernel-struct-has-default-state ()
  "A new kernel should start in startup state."
  (require 'ejn-kernel)
  (let ((kernel (ejn-make-kernel "python3")))
    (should (eq 'startup (ejn-kernel-state kernel)))))

(ert-deftest ejn-kernel-test/kernel-struct-stores-kernelspec ()
  "The kernel should remember its kernelspec."
  (require 'ejn-kernel)
  (let ((kernel (ejn-make-kernel "python3")))
    (should (string= "python3" (ejn-kernel-kernelspec kernel)))))

(ert-deftest ejn-kernel-test/kernel-struct-has-nil-client ()
  "A new kernel should have no client."
  (require 'ejn-kernel)
  (let ((kernel (ejn-make-kernel "python3")))
    (should-not (ejn-kernel-client kernel))))

(ert-deftest ejn-kernel-test/generics-are-defined ()
  "All kernel generics should be defined."
  (require 'ejn-kernel)
  (should (cl-generic-p #'ejn-kernel-start))
  (should (cl-generic-p #'ejn-kernel-execute))
  (should (cl-generic-p #'ejn-kernel-interrupt))
  (should (cl-generic-p #'ejn-kernel-restart))
  (should (cl-generic-p #'ejn-kernel-shutdown))
  (should (cl-generic-p #'ejn-kernel-alive-p)))

(provide 'ejn-kernel-test)
;;; ejn-kernel-test.el ends here
