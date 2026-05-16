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

(ert-deftest ejn-execute-test/stream-callback-appends-output ()
  "Stream callback should append a stream output to the cell."
  (let ((cell (ejn-make-cell 'code "print(1)")))
    (setf (ejn-cell-outputs cell) nil)
    (let ((callbacks (ejn-execute--make-callbacks cell)))
      (funcall (plist-get callbacks :on-stream)
               (ejn-cell-id cell) "hello " "stdout"))
      (should (= 1 (length (ejn-cell-outputs cell))))
      (should (eq 'stream (ejn-output-type (car (ejn-cell-outputs cell)))))))

(ert-deftest ejn-execute-test/error-callback-appends-error-output ()
  "Error callback should append an error output to the cell."
  (let ((cell (ejn-make-cell 'code "raise")))
    (setf (ejn-cell-outputs cell) nil)
    (let ((callbacks (ejn-execute--make-callbacks cell)))
      (funcall (plist-get callbacks :on-error)
               (ejn-cell-id cell)
               "ValueError" "something went wrong"
               '("traceback line 1" "traceback line 2")))
      (should (= 1 (length (ejn-cell-outputs cell))))
      (should (eq 'error (ejn-output-type (car (ejn-cell-outputs cell)))))))

(provide 'ejn-execute-test)
;;; ejn-execute-test.el ends here
