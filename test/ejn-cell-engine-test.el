;;; ejn-cell-engine-test.el --- Tests for ejn-cell-engine  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-cell-engine)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-navigation)
(require 'ejn-undo)
(require 'ejn-test-util)

(ert-deftest ejn-cell-engine-test/insert-cell-above ()
  "Inserting a cell above should place it before the current cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "original")
    (ejn-test-with-temp-buffer " *test*"
			       (set (make-local-variable 'ejn--notebook) nb)
			       (ejn-render-notebook nb)
			       (goto-char (point-min))
			       (ejn-insert-cell-above)
			       (should (= (length (ejn-notebook-cells nb)) 2))
			       (should (eq 'code (ejn-cell-type (ejn-notebook-cell-at-index nb 0)))))))

(ert-deftest ejn-cell-engine-test/insert-cell-below ()
  "Inserting a cell below should place it after the current cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "original")
    (ejn-test-with-temp-buffer " *test*"
			       (set (make-local-variable 'ejn--notebook) nb)
			       (ejn-render-notebook nb)
			       (goto-char (point-min))
			       (ejn-insert-cell-below)
			       (should (= (length (ejn-notebook-cells nb)) 2))
			       (should (eq 'code (ejn-cell-type (ejn-notebook-cell-at-index nb 1)))))))

(ert-deftest ejn-cell-engine-test/insert-cell-above-moves-point-to-new-cell ()
  "Inserting a cell above should move point to the new cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "original")
    (ejn-test-with-temp-buffer " *test*"
			       (set (make-local-variable 'ejn--notebook) nb)
			       (ejn-render-notebook nb)
			       (goto-char (point-min))
			       (ejn-insert-cell-above)
			       (let ((cell-at-point (ejn-cell-at-point)))
				 (should (ejn-cell-p cell-at-point))
				 (should (= (ejn-notebook-cell-index nb (ejn-cell-id cell-at-point)) 0))))))

(ert-deftest ejn-cell-engine-test/insert-cell-below-moves-point-to-new-cell ()
  "Inserting a cell below should move point to the new cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "original")
    (ejn-test-with-temp-buffer " *test*"
			       (set (make-local-variable 'ejn--notebook) nb)
			       (ejn-render-notebook nb)
			       (goto-char (point-min))
			       (ejn-insert-cell-below)
			       (let ((cell-at-point (ejn-cell-at-point)))
				 (should (ejn-cell-p cell-at-point))
				 (should (= (ejn-notebook-cell-index nb (ejn-cell-id cell-at-point)) 1))))))

(ert-deftest ejn-cell-engine-test/insert-cell-above-error-not-in-ejn-buffer ()
  "Inserting a cell above should error if not in an EJN buffer."
  (ejn-test-with-temp-buffer " *test*"
			     (should-error (ejn-insert-cell-above))))

(ert-deftest ejn-cell-engine-test/insert-cell-below-error-not-in-ejn-buffer ()
  "Inserting a cell below should error if not in an EJN buffer."
  (ejn-test-with-temp-buffer " *test*"
			     (should-error (ejn-insert-cell-below))))

(ert-deftest ejn-cell-engine-test/delete-cell ()
  "Deleting a cell should remove it from the model and re-render."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-test-with-temp-buffer " *test*"
			       (set (make-local-variable 'ejn--notebook) nb)
			       (ejn-render-notebook nb)
			       (goto-char (point-min))
			       (ejn-delete-cell)
			       (should (= (length (ejn-notebook-cells nb)) 1)))))

(ert-deftest ejn-cell-engine-test/delete-cell-error-not-in-ejn-buffer ()
  "Deleting a cell should error if not in an EJN buffer."
  (ejn-test-with-temp-buffer " *test*"
			     (should-error (ejn-delete-cell))))

(ert-deftest ejn-cell-engine-test/split-cell ()
  "Splitting a cell should divide the source at point into two cells."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "line1\nline2")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (search-forward "\n")
      (ejn-split-cell)
      (should (= (length (ejn-notebook-cells nb)) 2))
      (should (string= (ejn-cell-source (ejn-notebook-cell-at-index nb 0)) "line1\n")))))

(ert-deftest ejn-cell-engine-test/merge-cell ()
  "Merging cells should concatenate current and next cell source."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "first")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "second")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (ejn-merge-cell)
      (should (= (length (ejn-notebook-cells nb)) 1))
      (let ((source (ejn-cell-source (ejn-notebook-cell-at-index nb 0))))
        (should (string= source "first\nsecond\n"))))))

(ert-deftest ejn-cell-engine-test/move-cell-up ()
  "Moving a cell up should swap it with the previous cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "A")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "B")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (search-forward "B")
      (ejn-move-cell-up)
      (should (string= (ejn-cell-source (ejn-notebook-cell-at-index nb 0)) "B")))))

(ert-deftest ejn-cell-engine-test/move-cell-down ()
  "Moving a cell down should swap it with the next cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "A")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "B")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (ejn-move-cell-down)
      (should (string= (ejn-cell-source (ejn-notebook-cell-at-index nb 1)) "A")))))

(ert-deftest ejn-cell-engine-test/toggle-cell-type ()
  "Toggling cell type should cycle code -> markdown -> raw -> code."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (ejn-toggle-cell-type)
      (should (eq 'markdown (ejn-cell-type (ejn-notebook-cell-at-index nb 0))))
      (ejn-toggle-cell-type)
      (should (eq 'raw (ejn-cell-type (ejn-notebook-cell-at-index nb 0))))
      (ejn-toggle-cell-type)
      (should (eq 'code (ejn-cell-type (ejn-notebook-cell-at-index nb 0)))))))

(ert-deftest ejn-cell-engine-test/toggle-cell-type-error-not-in-ejn-buffer ()
  "Toggling cell type should error if not in an EJN buffer."
  (ejn-test-with-temp-buffer " *test*"
    (should-error (ejn-toggle-cell-type))))

(ert-deftest ejn-cell-engine-test/clear-output ()
  "Clearing output should remove outputs from the cell."
  (require 'ejn-cell)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell (ejn-notebook-cell-at-index nb 0)))
      (setf (ejn-cell-outputs cell)
            (list (make-ejn-output
                   :type 'execute-result
                   :mime-data (list :data (list (cons 'text/plain (list "42"))))
                   :metadata nil
                   :request-id nil))))
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (ejn-clear-output)
      (should-not (ejn-cell-outputs (ejn-notebook-cell-at-index nb 0))))))

(ert-deftest ejn-cell-engine-test/clear-output-error-not-in-ejn-buffer ()
  "Clearing output should error if not in an EJN buffer."
  (ejn-test-with-temp-buffer " *test*"
    (should-error (ejn-clear-output))))

(ert-deftest ejn-cell-engine-test/clear-all-outputs ()
  "Clearing all outputs should remove outputs from all cells."
  (require 'ejn-cell)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-insert-cell nb 'code :at 1)
    (setf (ejn-cell-outputs (ejn-notebook-cell-at-index nb 0))
          (list (make-ejn-output :type 'execute-result
                                 :mime-data (list :data (list (cons 'text/plain (list "1"))))
                                 :metadata nil :request-id nil)))
    (setf (ejn-cell-outputs (ejn-notebook-cell-at-index nb 1))
          (list (make-ejn-output :type 'execute-result
                                 :mime-data (list :data (list (cons 'text/plain (list "2"))))
                                 :metadata nil :request-id nil)))
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (ejn-clear-all-outputs)
      (should-not (ejn-cell-outputs (ejn-notebook-cell-at-index nb 0)))
      (should-not (ejn-cell-outputs (ejn-notebook-cell-at-index nb 1))))))

(ert-deftest ejn-cell-engine-test/clear-all-outputs-error-not-in-ejn-buffer ()
  "Clearing all outputs should error if not in an EJN buffer."
  (ejn-test-with-temp-buffer " *test*"
    (should-error (ejn-clear-all-outputs))))

(ert-deftest ejn-cell-engine-test/copy-and-yank-cell ()
  "Copying and yanking a cell should round-trip cell content."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "copied code")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (ejn-copy-cell)
      (ejn-yank-cell)
      (should (= (length (ejn-notebook-cells nb)) 2))
      (should (string= (ejn-cell-source (ejn-notebook-cell-at-index nb 1))
                        "copied code")))))

(ert-deftest ejn-cell-engine-test/yank-cell-error-no-kill-ring ()
  "Yanking a cell should error if kill ring is empty."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (should-error (ejn-yank-cell)))))

(ert-deftest ejn-cell-engine-test/yank-cell-error-not-in-ejn-buffer ()
  "Yanking a cell should error if not in an EJN buffer."
  (ejn-test-with-temp-buffer " *test*"
    (setq ejn--cell-kill-ring (list (list :id "dummy" :type 'code :source "test")))
    (should-error (ejn-yank-cell))))

(provide 'ejn-cell-engine-test)
;;; ejn-cell-engine-test.el ends here
