;;; ejn-execute-test.el --- Tests for ejn-execute  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-execute)

(ert-deftest ejn-execute-test/queue-is-empty-initially ()
  "The execution queue should be empty initially."
  (should (null ejn--execution-queue)))

(ert-deftest ejn-execute-test/enqueue-adds-request ()
  "Enqueueing should add a request to the queue."
  (ejn-execute--enqueue (list :cell-id "cell-1"
                              :source "print(1)"
                              :request-id "req-1"
                              :execution-version 1))
  (should (= 1 (length ejn--execution-queue)))
  (ejn-execute--dequeue)
  (setq ejn--execution-queue nil))

(ert-deftest ejn-execute-test/dequeue-returns-fifo ()
  "Dequeuing should return requests in FIFO order."
  (ejn-execute--enqueue (list :cell-id "cell-1" :source "a" :request-id "req-1" :execution-version 1))
  (ejn-execute--enqueue (list :cell-id "cell-2" :source "b" :request-id "req-2" :execution-version 1))
  (let ((first (ejn-execute--dequeue))
        (second (ejn-execute--dequeue)))
    (should (string= "req-1" (plist-get first :request-id)))
    (should (string= "req-2" (plist-get second :request-id)))))

(ert-deftest ejn-execute-test/cell-state-transition-queued ()
  "Transitioning a cell to queued should update execution-state."
  (let ((cell (ejn-make-cell 'code "print(1)")))
    (ejn-execute--set-cell-state cell 'queued)
    (should (eq 'queued (ejn-cell-execution-state cell)))))

(ert-deftest ejn-execute-test/cell-state-transition-executing ()
  "Transitioning a cell to executing should update execution-state."
  (let ((cell (ejn-make-cell 'code "print(1)")))
    (ejn-execute--set-cell-state cell 'executing)
    (should (eq 'executing (ejn-cell-execution-state cell)))))

(ert-deftest ejn-execute-test/cell-state-transition-completed ()
  "Transitioning a cell to completed should update execution-state."
  (let ((cell (ejn-make-cell 'code "print(1)")))
    (ejn-execute--set-cell-state cell 'completed)
    (should (eq 'completed (ejn-cell-execution-state cell)))))

(ert-deftest ejn-execute-test/cell-state-transition-error ()
  "Transitioning a cell to error should update execution-state."
  (let ((cell (ejn-make-cell 'code "raise")))
    (ejn-execute--set-cell-state cell 'error)
    (should (eq 'error (ejn-cell-execution-state cell)))))

(provide 'ejn-execute-test)
;;; ejn-execute-test.el ends here
