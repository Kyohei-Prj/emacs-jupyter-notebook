;;; ejn-kernel-jupyter-test.el --- Integration tests for Jupyter adapter  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-kernel-jupyter)

(ert-deftest ejn-kernel-jupyter-test/start-creates-client ()
  "ejn-kernel-start should create a jupyter client."
  (skip-unless (require 'jupyter nil t))
  (let ((kernel (ejn-make-kernel "python3")))
    (condition-case err
        (ejn-kernel-start kernel "python3")
      (error nil))
    (should-not (eq 'startup (ejn-kernel-state kernel)))))

(ert-deftest ejn-kernel-jupyter-test/execute-sends-request ()
  "ejn-kernel-execute should send code to the kernel."
  (skip-unless (require 'jupyter nil t))
  (let* ((kernel (ejn-make-kernel "python3"))
         (callbacks (list :on-stream (lambda (&rest _) nil)
                          :on-result (lambda (&rest _) nil)
                          :on-display (lambda (&rest _) nil)
                          :on-error (lambda (&rest _) nil)
                          :on-complete (lambda (&rest _) nil)))
         (request-id "test-request-123"))
    (condition-case err
        (progn
          (ejn-kernel-start kernel "python3")
          (ejn-kernel-execute kernel "print(1)" request-id callbacks))
      (error nil))
    (should (gethash request-id ejn--request-registry))))

(ert-deftest ejn-kernel-jupyter-test/interrupt-calls-jupyter ()
  "ejn-kernel-interrupt should call jupyter-interrupt-kernel."
  (skip-unless (require 'jupyter nil t))
  (let ((kernel (ejn-make-kernel "python3")))
    (condition-case err
        (progn
          (ejn-kernel-start kernel "python3")
          (ejn-kernel-interrupt kernel))
      (error nil))
    (should (memq (ejn-kernel-state kernel) '(interrupted connected dead)))))

(ert-deftest ejn-kernel-jupyter-test/restart-calls-jupyter ()
  "ejn-kernel-restart should call jupyter-restart-kernel."
  (skip-unless (require 'jupyter nil t))
  (let ((kernel (ejn-make-kernel "python3")))
    (condition-case err
        (progn
          (ejn-kernel-start kernel "python3")
          (ejn-kernel-restart kernel))
      (error nil))))

(ert-deftest ejn-kernel-jupyter-test/shutdown-calls-jupyter ()
  "ejn-kernel-shutdown should call jupyter-shutdown-kernel."
  (skip-unless (require 'jupyter nil t))
  (let ((kernel (ejn-make-kernel "python3")))
    (condition-case err
        (progn
          (ejn-kernel-start kernel "python3")
          (ejn-kernel-shutdown kernel))
      (error nil))
    (should (eq 'dead (ejn-kernel-state kernel)))))

(provide 'ejn-kernel-jupyter-test)
;;; ejn-kernel-jupyter-test.el ends here
