;;; ejn-render-test.el --- Tests for ejn-render  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-render)
(require 'ejn-test-util)

;;; Code:

(ert-deftest ejn-render-test/faces-are-defined ()
  "All execution state faces should be defined."
  (dolist (face '(ejn-cell-idle
                  ejn-cell-queued
                  ejn-cell-executing
                  ejn-cell-streaming
                  ejn-cell-completed
                  ejn-cell-error
                  ejn-cell-interrupted))
    (should (facep face))))

(ert-deftest ejn-render-test/state-to-face-mapping ()
  "Each execution state should map to the correct face."
  (should (eq 'ejn-cell-idle (ejn--execution-state-face 'idle)))
  (should (eq 'ejn-cell-queued (ejn--execution-state-face 'queued)))
  (should (eq 'ejn-cell-executing (ejn--execution-state-face 'executing)))
  (should (eq 'ejn-cell-streaming (ejn--execution-state-face 'streaming)))
  (should (eq 'ejn-cell-completed (ejn--execution-state-face 'completed)))
  (should (eq 'ejn-cell-error (ejn--execution-state-face 'error)))
  (should (eq 'ejn-cell-interrupted (ejn--execution-state-face 'interrupted)))
  (should (eq 'ejn-cell-idle (ejn--execution-state-face 'unknown-state))))

(ert-deftest ejn-render-test/render-cell-inserts-source ()
  "Rendering a cell should insert its source text."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "test-id"
               :type 'code
               :source "print('hello')"
               :outputs nil
               :execution-state 'idle)))
    (ejn-test-with-temp-buffer " *test*"
			       (ejn-render-cell cell)
			       (should (string= (buffer-substring-no-properties (point-min) (point-max))
						"print('hello')\n")))))

(ert-deftest ejn-render-test/render-cell-sets-text-properties ()
  "Rendering a cell should set ejn-cell-id and ejn-cell-type properties."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "prop-test"
               :type 'markdown
               :source "# Title"
               :outputs nil
               :execution-state 'idle)))
    (ejn-test-with-temp-buffer " *test*"
			       (ejn-render-cell cell)
			       (goto-char (point-min))
			       (should (string= "prop-test" (get-text-property (point) 'ejn-cell-id)))
			       (should (eq 'markdown (get-text-property (point) 'ejn-cell-type))))))

(ert-deftest ejn-render-test/render-cell-applies-execution-face ()
  "Rendering a cell should apply the execution state face to first character."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "face-test"
               :type 'code
               :source "x = 1"
               :outputs nil
               :execution-state 'completed)))
    (ejn-test-with-temp-buffer " *test*"
			       (ejn-render-cell cell)
			       (goto-char (point-min))
			       (should (memq 'ejn-cell-completed
					     (get-text-property (point) 'face))))))

(ert-deftest ejn-render-test/render-empty-cell ()
  "Rendering an empty cell should insert a newline with properties."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "empty-test"
               :type 'code
               :source ""
               :outputs nil
               :execution-state 'idle)))
    (ejn-test-with-temp-buffer " *test*"
			       (ejn-render-cell cell)
			       (should (= (buffer-size) 1))
			       (goto-char (point-min))
			       (should (string= "empty-test" (get-text-property (point) 'ejn-cell-id))))))

(ert-deftest ejn-render-test/render-outputs-creates-zone ()
  "Rendering outputs should create a read-only output zone."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "out-test"
               :type 'code
               :source "42"
               :outputs (list (make-ejn-output
                               :type 'execute-result
                               :mime-data (list :data (list (cons 'text/plain (list "42"))))
                               :metadata nil
                               :request-id nil))
               :execution-state 'completed)))
    (ejn-test-with-temp-buffer " *test*"
			       (ejn-render-cell cell)
			       (ejn-render-outputs cell)
			       (goto-char (point-min))
			       (search-forward "42\n" nil t)
			       (forward-char 1)
			       (should (get-text-property (point) 'ejn-output-zone))
			       (should (get-text-property (point) 'read-only)))))

(ert-deftest ejn-render-test/render-outputs-displays-text ()
  "Rendering outputs should display text/plain content."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "out-text"
               :type 'code
               :source "1+1"
               :outputs (list (make-ejn-output
                               :type 'execute-result
                               :mime-data (list :data (list (cons 'text/plain (list "2"))))
                               :metadata nil
                               :request-id nil))
               :execution-state 'completed)))
    (ejn-test-with-temp-buffer " *test*"
			       (ejn-render-cell cell)
			       (ejn-render-outputs cell)
			       (should (search-forward "2" nil t)))))

(ert-deftest ejn-render-test/render-notebook-renders-all-cells ()
  "Full render should produce content for all cells."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "print(1)")
    (ejn-notebook-insert-cell nb 'markdown :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "# Hello")
    (ejn-test-with-temp-buffer " *test*"
			       (ejn-render-notebook nb)
			       (should (search-forward "print(1)" nil t))
			       (should (search-forward "# Hello" nil t)))))

(ert-deftest ejn-render-test/render-notebook-sets-cell-properties ()
  "Full render should set ejn-cell-id on all source regions."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-notebook-set-cell-source nb cell-id "x")
      (ejn-test-with-temp-buffer " *test*"
				 (ejn-render-notebook nb)
				 (goto-char (point-min))
				 (should (string= cell-id (get-text-property (point) 'ejn-cell-id)))))))

(ert-deftest ejn-render-test/render-dirty-cells-updates-only-dirty ()
  "Incremental render should update only dirty cell regions."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "original")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "second")
    (ejn-test-with-temp-buffer " *test*"
      (ejn-render-notebook nb)
      (let ((cell-0-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
        (ejn-notebook-set-cell-source nb cell-0-id "modified")
        (ejn-notebook-mark-dirty nb cell-0-id)
        (ejn-render-dirty-cells nb)
        (goto-char (point-min))
        (should (search-forward "modified" nil t))
        (should (search-forward "second" nil t))
        (should-not (ejn-notebook-dirty nb))))))

(ert-deftest ejn-render-test/folded-output-spec-exists ()
  "The folded output invisibility spec should exist."
  (should (boundp 'ejn-folded-output)))

(ert-deftest ejn-render-test/toggle-output-sets-invisible ()
  "Toggling output should set invisible property on the output zone."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "fold-test"
               :type 'code
               :source "42"
               :outputs (list (make-ejn-output
                               :type 'execute-result
                               :mime-data (list :data (list (cons 'text/plain (list "42"))))
                               :metadata nil
                               :request-id nil))
               :execution-state 'completed)))
    (ejn-test-with-temp-buffer " *test*"
      (ejn-render-cell cell)
      (ejn-render-outputs cell)
      (ejn-toggle-output)
      (search-forward "\n42" nil t)
      (should (get-text-property (point) 'invisible)))))


(provide 'ejn-render-test)
;;; ejn-render-test.el ends here
