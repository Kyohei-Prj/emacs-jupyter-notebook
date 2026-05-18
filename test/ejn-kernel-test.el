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
  (should (cl-generic-p #'ejn--kernel-interrupt))
  (should (cl-generic-p #'ejn--kernel-restart))
  (should (cl-generic-p #'ejn--kernel-shutdown))
  (should (cl-generic-p #'ejn-kernel-alive-p))
  (should (cl-generic-p #'ejn-kernel-complete))
  (should (cl-generic-p #'ejn-kernel-inspect))
  (should (cl-generic-p #'ejn-kernel-status)))

(ert-deftest ejn-kernel-test/status-returns-kernel-state ()
  "Ejn-kernel-status should return the kernel's current state."
  (require 'ejn-kernel)
  (let ((kernel (ejn-make-kernel "python3")))
    (should (eq 'startup (ejn-kernel-status kernel)))
    (ejn-kernel-transition kernel 'connected)
    (should (eq 'connected (ejn-kernel-status kernel)))))

(ert-deftest ejn-kernel-test/heartbeat-default-is-30s ()
  "Heartbeat interval should default to 30 seconds."
  (require 'ejn-kernel)
  (should (= 30 ejn-kernel-heartbeat-interval)))

(ert-deftest ejn-kernel-test/heartbeat-can-start-and-stop ()
  "Heartbeat timer can be started and stopped."
  (require 'ejn-kernel)
  (let ((kernel (ejn-make-kernel "python3")))
    (ejn-kernel-start-heartbeat kernel)
    (should ejn--kernel-heartbeat-timer)
    (ejn-kernel-stop-heartbeat)
    (should-not ejn--kernel-heartbeat-timer)))

(ert-deftest ejn-kernel-test/alive-p-returns-nil-without-client ()
  "Alive-p should return nil when kernel has no client."
  (require 'ejn-kernel)
  (require 'ejn-kernel-jupyter)
  (let ((kernel (ejn-make-kernel "python3")))
    (ejn-kernel-transition kernel 'connected)
    (should-not (ejn-kernel-alive-p kernel))))

(ert-deftest ejn-kernel-test/reconnect-is-generic ()
  "Ejn-kernel-reconnect should be a CLOS generic."
  (require 'ejn-kernel)
  (should (cl-generic-p #'ejn-kernel-reconnect)))

(ert-deftest ejn-kernel-test/reconnect-command-is-interactive ()
  "Ejn-kernel-reconnect-command should be an interactive command."
  (require 'ejn-kernel)
  (should (commandp #'ejn-kernel-reconnect-command)))

(ert-deftest ejn-kernel-test/reconnect-command-signals-if-not-dead ()
  "Reconnect should signal an error if kernel is not dead."
  (require 'ejn-kernel)
  (require 'ejn-mode)
  (require 'ejn-test-util)
  (let ((kernel (ejn-make-kernel "python3")))
    (ejn-kernel-transition kernel 'connected)
    (ejn-test-with-temp-buffer " *test*"
			       (ejn-mode)
			       (set (make-local-variable 'ejn--notebook) (ejn-make-notebook))
			       (set (make-local-variable 'ejn--kernel) kernel)
			       (should-error (ejn-kernel-reconnect-command)))))

(ert-deftest ejn-kernel-test/heartbeat-transitions-to-dead ()
  "Heartbeat should transition kernel to dead when no client exists."
  (require 'ejn-kernel)
  (require 'ejn-kernel-jupyter)
  (let ((kernel (ejn-make-kernel "python3"))
        (ejn-kernel-dead-hook nil))
    (ejn-kernel-transition kernel 'connected)
    (ejn-kernel--heartbeat-tick kernel)
    (should (eq 'dead (ejn-kernel-state kernel)))))

(ert-deftest ejn-kernel-test/heartbeat-runs-dead-hook ()
  "Heartbeat should run ejn-kernel-dead-hook when kernel dies."
  (require 'ejn-kernel)
  (require 'ejn-kernel-jupyter)
  (let ((kernel (ejn-make-kernel "python3"))
        (hook-ran nil)
        (ejn-kernel-dead-hook nil))
    (add-hook 'ejn-kernel-dead-hook (lambda () (setq hook-ran t)))
    (ejn-kernel-transition kernel 'connected)
    (ejn-kernel--heartbeat-tick kernel)
    (should hook-ran)))

(ert-deftest ejn-kernel-test/heartbeat-skip-non-connected-states ()
  "Heartbeat should skip state check for non-connected states."
  (require 'ejn-kernel)
  (require 'ejn-kernel-jupyter)
  (let ((kernel (ejn-make-kernel "python3")))
    (ejn-kernel-transition kernel 'busy)
    (ejn-kernel--heartbeat-tick kernel)
    (should (eq 'busy (ejn-kernel-state kernel)))))

(provide 'ejn-kernel-test)
;;; ejn-kernel-test.el ends here
