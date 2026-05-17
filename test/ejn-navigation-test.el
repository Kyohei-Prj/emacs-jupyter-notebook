;;; ejn-navigation-test.el --- Tests for ejn-navigation  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-navigation)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-test-util)

;;; Code:

(ert-deftest ejn-navigation-test/cell-at-point-returns-cell ()
  "Ejn-cell-at-point should return the cell struct at point."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "print(1)")
    (ejn-test-with-temp-buffer " *test*"
			       (set (make-local-variable 'ejn--notebook) nb)
			       (ejn-render-notebook nb)
			       (goto-char (point-min))
			       (let ((cell (ejn-cell-at-point)))
				 (should (ejn-cell-p cell))
       (should (string= (ejn-cell-source cell) "print(1)"))))))

(ert-deftest ejn-navigation-test/cell-at-point-in-output-zone ()
  "Ejn-cell-at-point should find parent cell from within output zone."
  (require 'ejn-cell)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let* ((cell (ejn-notebook-cell-at-index nb 0))
           (cell-id (ejn-cell-id cell)))
      (setf (ejn-cell-source cell) "42")
      (setf (ejn-cell-outputs cell)
            (list (make-ejn-output
                   :type 'execute-result
                   :mime-data (list :data (list (cons 'text/plain (list "42"))))
                   :metadata nil
                   :request-id nil)))
      (ejn-test-with-temp-buffer " *test*"
        (set (make-local-variable 'ejn--notebook) nb)
        (ejn-render-notebook nb)
        (search-forward "42\n42" nil t)
        (forward-line)
        (let ((found-cell (ejn-cell-at-point)))
          (should (ejn-cell-p found-cell))
          (should (string= (ejn-cell-id found-cell) cell-id)))))))

(ert-deftest ejn-navigation-test/cell-region-returns-source-range ()
  "Ejn-cell-region should return the source region boundaries."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "line1\nline2")
    (ejn-test-with-temp-buffer " *test*"
			       (set (make-local-variable 'ejn--notebook) nb)
			       (ejn-render-notebook nb)
			       (goto-char (point-min))
			       (let ((region (ejn-cell-region)))
				 (should (= (car region) (point-min)))
				 (should (> (cdr region) (car region)))))))

(ert-deftest ejn-navigation-test/cell-full-region-includes-output ()
  "Ejn-cell-full-region should include the output zone."
  (require 'ejn-cell)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell (ejn-notebook-cell-at-index nb 0)))
      (setf (ejn-cell-source cell) "x")
      (setf (ejn-cell-outputs cell)
            (list (make-ejn-output
                   :type 'execute-result
                   :mime-data (list :data (list (cons 'text/plain (list "result"))))
                   :metadata nil
                   :request-id nil)))
      ) ;; end let cell
    (ejn-test-with-temp-buffer " *test*"
			       (set (make-local-variable 'ejn--notebook) nb)
			       (ejn-render-notebook nb)
			       (goto-char (point-min))
			       (let ((source-region (ejn-cell-region))
				     (full-region (ejn-cell-full-region)))
				 (should (> (cdr full-region) (cdr source-region)))))))

(ert-deftest ejn-navigation-test/goto-next-cell-moves-forward ()
  "Ejn-goto-next-cell should move to the next cell's source."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "first")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "second")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (ejn-goto-next-cell)
      (should (search-backward "second" nil t)))))

(ert-deftest ejn-navigation-test/goto-prev-cell-moves-backward ()
  "Ejn-goto-prev-cell should move to the previous cell's source."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "first")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "second")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (search-forward "second")
      (ejn-goto-prev-cell)
      (should (search-backward "first" nil t)))))

(ert-deftest ejn-navigation-test/goto-first-cell ()
  "Ejn-goto-first-cell should move to the first cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "first")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "second")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-max))
      (ejn-goto-first-cell)
      (should (= (point) (point-min))))))

(ert-deftest ejn-navigation-test/goto-last-cell ()
  "Ejn-goto-last-cell should move to the last cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "first")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "last")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (ejn-goto-last-cell)
      (should (search-backward "last" nil t)))))

(provide 'ejn-navigation-test)
;;; ejn-navigation-test.el ends here
