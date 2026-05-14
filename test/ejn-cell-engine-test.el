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

(provide 'ejn-cell-engine-test)
;;; ejn-cell-engine-test.el ends here
