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

(provide 'ejn-execute-test)
;;; ejn-execute-test.el ends here
