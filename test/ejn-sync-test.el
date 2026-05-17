;;; ejn-sync-test.el --- Tests for ejn-sync  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-sync)
(require 'ejn-render)
(require 'ejn-test-util)

;;; Code:

(ert-deftest ejn-sync-test/after-change-handler-exists ()
  "Ejn--after-change-handler should be defined."
  (should (fboundp 'ejn--after-change-handler)))

(ert-deftest ejn-sync-test/render-guard-skips-sync ()
  "Handler should return immediately when ejn--rendering-p is non-nil."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (insert "print(1)")
			     (put-text-property (point-min) (point-max) 'ejn-cell-id "cell-1")
			     (setq ejn--rendering-p t)
			     (goto-char (point-min))
			     (ejn--after-change-handler (point-min) (point-min) 0)
			     (should (null ejn--pending-sync-set))))

(ert-deftest ejn-sync-test/output-zone-changes-ignored ()
  "Handler should skip changes in output zones."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (insert "print(1)")
			     (put-text-property (point-min) (point-max) 'ejn-cell-id "cell-1")
			     (put-text-property (point-min) (point-max) 'ejn-output-zone t)
			     (goto-char (point-min))
			     (ejn--after-change-handler (point-min) (point-min) 0)
			     (should (null ejn--pending-sync-set))))

(ert-deftest ejn-sync-test/source-change-schedules-cell ()
  "Handler should add cell to pending sync for source region changes."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (insert "print(1)")
			     (put-text-property (point-min) (point-max) 'ejn-cell-id "cell-1")
			     (goto-char (point-min))
			     (ejn--after-change-handler (point-min) (point-min) 0)
			     (should (hash-table-p ejn--pending-sync-set))
			     (should (gethash "cell-1" ejn--pending-sync-set))))

(ert-deftest ejn-sync-test/debounce-variable-exists ()
  "Ejn-sync-debounce-seconds should be a number."
  (should (numberp ejn-sync-debounce-seconds)))

(ert-deftest ejn-sync-test/schedule-sync-creates-timer ()
  "Ejn--schedule-sync should create a timer."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (ejn--schedule-sync)
			     (should (timerp ejn--sync-timer))
			     (cancel-timer ejn--sync-timer)
			     (setq ejn--sync-timer nil)))

(ert-deftest ejn-sync-test/schedule-sync-cancels-previous-timer ()
  "Ejn--schedule-sync should cancel any existing timer before creating a new one."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (ejn--schedule-sync)
			     (let ((first-timer ejn--sync-timer))
			       (ejn--schedule-sync)
			       (should (not (eq first-timer ejn--sync-timer)))
			       (cancel-timer ejn--sync-timer)
			       (setq ejn--sync-timer nil))))

(ert-deftest ejn-sync-test/perform-sync-updates-model ()
  "Sync should update model source when buffer content changes."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (let ((nb (ejn-make-notebook)))
			       (ejn-notebook-insert-cell nb 'code :at 0)
			       (let* ((cell (ejn-notebook-cell-at-index nb 0))
				      (cell-id (ejn-cell-id cell)))
				 (ejn-notebook-set-cell-source nb cell-id "original\n")
				 (set (make-local-variable 'ejn--notebook) nb)
				 (set (make-local-variable 'ejn--pending-sync-set) (make-hash-table :test 'equal))
				 (puthash cell-id t ejn--pending-sync-set)
				 (insert "original\n")
				 (put-text-property (point-min) (point-max) 'ejn-cell-id cell-id)
				 (delete-region (point-min) (point-max))
				 (insert "modified\n")
				 (put-text-property (point-min) (point-max) 'ejn-cell-id cell-id)
				 (ejn--perform-sync)
				 (should (string= (ejn-cell-source (ejn-notebook-cell-by-id nb cell-id))
						  "modified\n"))))))

(ert-deftest ejn-sync-test/perform-sync-skips-unchanged ()
  "Sync should not update model when buffer content is unchanged."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (let ((nb (ejn-make-notebook)))
			       (ejn-notebook-insert-cell nb 'code :at 0)
			       (let* ((cell (ejn-notebook-cell-at-index nb 0))
				      (cell-id (ejn-cell-id cell))
				      (source "original\n"))
				 (ejn-notebook-set-cell-source nb cell-id source)
				 (set (make-local-variable 'ejn--notebook) nb)
				 (set (make-local-variable 'ejn--pending-sync-set) (make-hash-table :test 'equal))
				 (puthash cell-id t ejn--pending-sync-set)
				 (insert source)
				 (put-text-property (point-min) (point-max) 'ejn-cell-id cell-id)
				 (ejn--perform-sync)
				 (should (string= (ejn-cell-source (ejn-notebook-cell-by-id nb cell-id))
						  source))))))

(ert-deftest ejn-sync-test/perform-sync-runs-hook ()
  "Sync should run ejn-after-sync-hook when cells were updated."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (let ((nb (ejn-make-notebook))
				   (hook-called nil))
			       (ejn-notebook-insert-cell nb 'code :at 0)
			       (let* ((cell (ejn-notebook-cell-at-index nb 0))
				      (cell-id (ejn-cell-id cell))
				      (hook-fn (lambda () (setq hook-called t))))
				 (ejn-notebook-set-cell-source nb cell-id "original\n")
				 (set (make-local-variable 'ejn--notebook) nb)
				 (set (make-local-variable 'ejn--pending-sync-set) (make-hash-table :test 'equal))
				 (puthash cell-id t ejn--pending-sync-set)
				 (add-hook 'ejn-after-sync-hook hook-fn nil t)
				 (insert "original\n")
				 (put-text-property (point-min) (point-max) 'ejn-cell-id cell-id)
				 (delete-region (point-min) (point-max))
				 (insert "modified\n")
				 (put-text-property (point-min) (point-max) 'ejn-cell-id cell-id)
				 (ejn--perform-sync)
				 (should hook-called)))))

(ert-deftest ejn-sync-test/sync-mode-enables-hook ()
  "Ejn-sync-mode should add the after-change handler."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (should-not (memq #'ejn--after-change-handler after-change-functions))
			     (ejn-sync-mode)
			     (should (memq #'ejn--after-change-handler after-change-functions))))

(ert-deftest ejn-sync-test/sync-mode-disables-hook ()
  "Calling ejn-sync-mode twice should toggle off."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (ejn-sync-mode)
			     (ejn-sync-mode)
			     (should-not (memq #'ejn--after-change-handler after-change-functions))))

(ert-deftest ejn-sync-test/full-sync-flow-updates-model ()
  "Complete flow: edit buffer, after-change, wait, sync, model updated."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (let ((nb (ejn-make-notebook))
				   (cell)
				   (cell-id))
			       (ejn-notebook-insert-cell nb 'code :at 0)
			       (setq cell (ejn-notebook-cell-at-index nb 0))
			       (setq cell-id (ejn-cell-id cell))
			       (ejn-notebook-set-cell-source nb cell-id "original\n")
			       (set (make-local-variable 'ejn--notebook) nb)
			       (ejn-render-notebook nb)
			       (ejn-sync-mode)
			       (goto-char (point-min))
			       (let ((start (point)))
				 (delete-region start (+ start 8))
				 (insert "modified")
				 ;; Restore text properties for region finder
				 (put-text-property start (point) 'ejn-cell-id cell-id))
			       (ejn-test-wait-for-sync)
			       (should (string= (ejn-cell-source (ejn-notebook-cell-by-id nb cell-id))
						"modified\n")))))

(ert-deftest ejn-sync-test/multiple-edits-batched ()
  "Multiple edits to the same cell should batch into one sync."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (let ((nb (ejn-make-notebook))
				   (sync-count 0)
				   (cell)
				   (cell-id))
			       (ejn-notebook-insert-cell nb 'code :at 0)
			       (setq cell (ejn-notebook-cell-at-index nb 0))
			       (setq cell-id (ejn-cell-id cell))
			       (ejn-notebook-set-cell-source nb cell-id "a\n")
			       (set (make-local-variable 'ejn--notebook) nb)
			       (add-hook 'ejn-after-sync-hook (lambda () (cl-incf sync-count)) nil t)
			       (ejn-render-notebook nb)
			       (ejn-sync-mode)
			       (goto-char (point-min))
			       (let ((start (point)))
				 ;; Replace content, restoring properties
				 (delete-region start (1- (point-max)))
				 (insert "z")
				 (put-text-property start (point-max) 'ejn-cell-id cell-id))
			       (ejn-test-wait-for-sync)
			       (should (= sync-count 1))
			       (should (string= (ejn-cell-source (ejn-notebook-cell-by-id nb cell-id))
						"z\n")))))

(ert-deftest ejn-sync-test/unchanged-cell-skips-hook ()
  "If buffer content matches model, hook should not run."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (let ((nb (ejn-make-notebook))
				   (hook-called nil)
				   (cell)
				   (cell-id)
				   (hook-fn))
			       (ejn-notebook-insert-cell nb 'code :at 0)
			       (setq cell (ejn-notebook-cell-at-index nb 0))
			       (setq cell-id (ejn-cell-id cell))
			       (setq hook-fn (lambda () (setq hook-called t)))
			       (ejn-notebook-set-cell-source nb cell-id "stable\n")
			       (set (make-local-variable 'ejn--notebook) nb)
			       (set (make-local-variable 'ejn--pending-sync-set) (make-hash-table :test 'equal))
			       (puthash cell-id t ejn--pending-sync-set)
			       (add-hook 'ejn-after-sync-hook hook-fn nil t)
			       (insert "stable\n")
			       (put-text-property (point-min) (point-max) 'ejn-cell-id cell-id)
			       (ejn--perform-sync)
			       (should-not hook-called))))

(ert-deftest ejn-sync-test/rendering-guard-with-after-change ()
  "Changes during render should not be tracked."
  (ejn-test-with-temp-buffer " *ejn-sync-test*"
			     (let ((nb (ejn-make-notebook))
				   (cell)
				   (cell-id))
			       (ejn-notebook-insert-cell nb 'code :at 0)
			       (setq cell (ejn-notebook-cell-at-index nb 0))
			       (setq cell-id (ejn-cell-id cell))
			       (ejn-notebook-set-cell-source nb cell-id "test\n")
			       (set (make-local-variable 'ejn--notebook) nb)
			       (set (make-local-variable 'ejn--pending-sync-set) (make-hash-table :test 'equal))
			       (ejn-render-notebook nb)
			       (should (= (hash-table-count ejn--pending-sync-set) 0)))))

(provide 'ejn-sync-test)
;;; ejn-sync-test.el ends here
