;;; ejn-cell-test.el --- ERT tests for ejn-cell structural commands  -*- lexical-binding: t; -*-

(require 'ert)

(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))
(require 'ejn-core)
(require 'ejn-cell)
(require 'ejn-master)
(require 'ejn)

;;; Helper: create a temp .ipynb and load a notebook with cells

(defun ejn-cell-test--make-notebook (&optional num-cells)
  "Return a temp-file path and an ejn-notebook with NUM-CELLS code cells."
  (or num-cells (setq num-cells 2))
  (let* ((json-str (format "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{},\"cells\":[%s]}"
                           (mapconcat (lambda (i)
                                        (format "{\"cell_type\":\"code\",\"source\":\"cell%d\"}" i))
                                      (number-sequence 0 (1- num-cells))
                                      ",")))
         (tmp (make-temp-file "ejn-cell-test-" nil ".ipynb" json-str))
         (notebook (ejn-notebook-load tmp)))
    (list tmp notebook)))

(defun ejn-cell-test--cleanup (tmp-path)
  "Delete TMP-PATH and kill all EJN-related buffers."
  (ignore-errors (delete-file tmp-path))
  (dolist (buf (buffer-list))
    (when (string-prefix-p "*ejn-" (buffer-name buf))
      (kill-buffer buf))))


;;; ===== ejn:worksheet-insert-cell-above =====

(ert-deftest ejn-cell-test-p2-t1--insert-above-guard-no-notebook ()
  "insert-above signals user-error when no notebook is associated."
  (with-temp-buffer
    (should-error
     (ejn:worksheet-insert-cell-above)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--insert-above-guard-no-cell ()
  "insert-above signals user-error when no cell at point."
  (with-temp-buffer
    (set (make-local-variable 'ejn--notebook) (make-instance 'ejn-notebook))
    (should-error
     (ejn:worksheet-insert-cell-above)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--insert-above-switches-to-buffer ()
  "insert-above calls switch-to-buffer on the new cell's buffer."
  (let* ((result (ejn-cell-test--make-notebook 2))
         (tmp-path (car result))
         (notebook (cadr result))
         (cells (slot-value notebook 'cells))
         (cell (nth 0 cells)))
    (unwind-protect
        (with-temp-buffer
          (set (make-local-variable 'ejn--notebook) notebook)
          (set (make-local-variable 'ejn--cell) cell)
          (let ((switched-to-buf nil)
                (opened-buf nil))
            (cl-letf (((symbol-function 'switch-to-buffer)
                       (lambda (buf) (setq switched-to-buf buf)))
                      ((symbol-function 'ejn-cell-open-buffer)
                       (lambda (c &optional _) (setq opened-buf (current-buffer)) opened-buf))
                      ((symbol-function 'ejn-shadow-write-cell)
                       (lambda (_c _n) nil))
                      ((symbol-function 'ejn--reindex-shadow-files)
                       (lambda (_n) nil)))
              (ejn:worksheet-insert-cell-above)
              (should switched-to-buf)
              (should (eq switched-to-buf opened-buf))))
	  (ejn-cell-test--cleanup tmp-path)))))


;;; ===== ejn:worksheet-insert-cell-below =====

(ert-deftest ejn-cell-test-p2-t1--insert-below-guard-no-notebook ()
  "insert-below signals user-error when no notebook is associated."
  (with-temp-buffer
    (should-error
     (ejn:worksheet-insert-cell-below)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--insert-below-guard-no-cell ()
  "insert-below signals user-error when no cell at point."
  (with-temp-buffer
    (set (make-local-variable 'ejn--notebook) (make-instance 'ejn-notebook))
    (should-error
     (ejn:worksheet-insert-cell-below)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--insert-below-switches-to-buffer ()
  "insert-below calls switch-to-buffer on the new cell's buffer."
  (let* ((result (ejn-cell-test--make-notebook 2))
         (tmp-path (car result))
         (notebook (cadr result))
         (cells (slot-value notebook 'cells))
         (cell (nth 0 cells)))
    (unwind-protect
        (with-temp-buffer
          (set (make-local-variable 'ejn--notebook) notebook)
          (set (make-local-variable 'ejn--cell) cell)
          (let ((switched-to-buf nil)
                (opened-buf nil))
            (cl-letf (((symbol-function 'switch-to-buffer)
                       (lambda (buf) (setq switched-to-buf buf)))
                      ((symbol-function 'ejn-cell-open-buffer)
                       (lambda (c &optional _) (setq opened-buf (current-buffer)) opened-buf))
                      ((symbol-function 'ejn-shadow-write-cell)
                       (lambda (_c _n) nil))
                      ((symbol-function 'ejn--reindex-shadow-files)
                       (lambda (_n) nil)))
              (ejn:worksheet-insert-cell-below)
              (should switched-to-buf)
              (should (eq switched-to-buf opened-buf))))
	  (ejn-cell-test--cleanup tmp-path)))))


;;; ===== ejn:worksheet-move-cell-up =====

(ert-deftest ejn-cell-test-p2-t1--move-up-guard-no-notebook ()
  "move-up signals user-error when no notebook is associated."
  (with-temp-buffer
    (should-error
     (ejn:worksheet-move-cell-up)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--move-up-guard-no-cell ()
  "move-up signals user-error when no cell at point."
  (with-temp-buffer
    (set (make-local-variable 'ejn--notebook) (make-instance 'ejn-notebook))
    (should-error
     (ejn:worksheet-move-cell-up)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--move-up-calls-poly-refresh ()
  "move-up calls ejn--poly-refresh-cells, not ejn--refresh-master-cells."
  (let* ((result (ejn-cell-test--make-notebook 3))
         (tmp-path (car result))
         (notebook (cadr result))
         (cells (slot-value notebook 'cells))
         (cell (nth 1 cells)))
    (oset notebook master-buffer (get-buffer-create "*ejn-master:test*"))
    (unwind-protect
        (with-temp-buffer
          (set (make-local-variable 'ejn--notebook) notebook)
          (set (make-local-variable 'ejn--cell) cell)
          (let ((poly-refresh-called nil))
            (cl-letf (((symbol-function 'ejn--poly-refresh-cells)
                       (lambda () (setq poly-refresh-called t)))
                      ((symbol-function 'ejn--refresh-master-cells)
                       (lambda () (ert-fail "ejn--refresh-master-cells should NOT be called")))
                      ((symbol-function 'ejn-shadow-write-cell)
                       (lambda (_c _n) nil))
                      ((symbol-function 'delete-file)
                       (lambda (&rest _) nil)))
              (ejn:worksheet-move-cell-up)
              (should poly-refresh-called)))
	  (ejn-cell-test--cleanup tmp-path)))))


;;; ===== ejn:worksheet-move-cell-down =====

(ert-deftest ejn-cell-test-p2-t1--move-down-guard-no-notebook ()
  "move-down signals user-error when no notebook is associated."
  (with-temp-buffer
    (should-error
     (ejn:worksheet-move-cell-down)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--move-down-guard-no-cell ()
  "move-down signals user-error when no cell at point."
  (with-temp-buffer
    (set (make-local-variable 'ejn--notebook) (make-instance 'ejn-notebook))
    (should-error
     (ejn:worksheet-move-cell-down)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--move-down-calls-poly-refresh ()
  "move-down calls ejn--poly-refresh-cells, not ejn--refresh-master-cells."
  (let* ((result (ejn-cell-test--make-notebook 3))
         (tmp-path (car result))
         (notebook (cadr result))
         (cells (slot-value notebook 'cells))
         (cell (nth 0 cells)))
    (oset notebook master-buffer (get-buffer-create "*ejn-master:test*"))
    (unwind-protect
        (with-temp-buffer
          (set (make-local-variable 'ejn--notebook) notebook)
          (set (make-local-variable 'ejn--cell) cell)
          (let ((poly-refresh-called nil))
            (cl-letf (((symbol-function 'ejn--poly-refresh-cells)
                       (lambda () (setq poly-refresh-called t)))
                      ((symbol-function 'ejn--refresh-master-cells)
                       (lambda () (ert-fail "ejn--refresh-master-cells should NOT be called")))
                      ((symbol-function 'ejn-shadow-write-cell)
                       (lambda (_c _n) nil))
                      ((symbol-function 'delete-file)
                       (lambda (&rest _) nil)))
              (ejn:worksheet-move-cell-down)
              (should poly-refresh-called)))
	  (ejn-cell-test--cleanup tmp-path)))))


;;; ===== ejn:worksheet-kill-cell =====

(ert-deftest ejn-cell-test-p2-t1--kill-cell-guard-no-notebook ()
  "kill-cell signals user-error when no notebook is associated."
  (with-temp-buffer
    (should-error
     (ejn:worksheet-kill-cell)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--kill-cell-calls-poly-refresh ()
  "kill-cell calls ejn--poly-refresh-cells, not ejn--refresh-master-cells."
  (let* ((result (ejn-cell-test--make-notebook 2))
         (tmp-path (car result))
         (notebook (cadr result))
         (cells (slot-value notebook 'cells))
         (cell (nth 0 cells)))
    (oset notebook master-buffer (get-buffer-create "*ejn-master:test*"))
    (unwind-protect
        (with-temp-buffer
          (set (make-local-variable 'ejn--notebook) notebook)
          (set (make-local-variable 'ejn--cell) cell)
          (let ((poly-refresh-called nil))
            (cl-letf (((symbol-function 'ejn--poly-refresh-cells)
                       (lambda () (setq poly-refresh-called t)))
                      ((symbol-function 'ejn--refresh-master-cells)
                       (lambda () (ert-fail "ejn--refresh-master-cells should NOT be called")))
                      ((symbol-function 'ejn--reindex-shadow-files)
                       (lambda (_n) nil))
                      ((symbol-function 'delete-file)
                       (lambda (&rest _) nil))
                      ((symbol-function 'y-or-n-p)
                       (lambda (&rest _) t)))
              (ejn:worksheet-kill-cell)
              (should poly-refresh-called)))
	  (ejn-cell-test--cleanup tmp-path)))))


;;; ===== ejn:worksheet-split-cell-at-point =====

(ert-deftest ejn-cell-test-p2-t1--split-cell-guard-no-notebook ()
  "split-cell signals user-error when no notebook is associated."
  (with-temp-buffer
    (should-error
     (ejn:worksheet-split-cell-at-point)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--split-cell-guard-no-cell ()
  "split-cell signals user-error when no cell at point."
  (with-temp-buffer
    (set (make-local-variable 'ejn--notebook) (make-instance 'ejn-notebook))
    (should-error
     (ejn:worksheet-split-cell-at-point)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--split-cell-switches-to-buffer ()
  "split-cell calls switch-to-buffer on the new cell's buffer."
  (let* ((result (ejn-cell-test--make-notebook 2))
         (tmp-path (car result))
         (notebook (cadr result))
         (cells (slot-value notebook 'cells))
         (cell (nth 0 cells)))
    (unwind-protect
        (with-temp-buffer
          (insert "first line\nsecond line\n")
          (set (make-local-variable 'ejn--notebook) notebook)
          (set (make-local-variable 'ejn--cell) cell)
          (goto-char 12)  ; at beginning of second line
          (let ((switched-to-buf nil))
            (cl-letf (((symbol-function 'switch-to-buffer)
                       (lambda (buf) (setq switched-to-buf buf)))
                      ((symbol-function 'ejn-cell-open-buffer)
                       (lambda (c &optional _) (current-buffer)))
                      ((symbol-function 'ejn-shadow-write-cell)
                       (lambda (_c _n) nil))
                      ((symbol-function 'ejn--reindex-shadow-files)
                       (lambda (_n) nil))
                      ((symbol-function 'ejn-cell-refresh-buffer)
                       (lambda (_c) nil)))
              (ejn:worksheet-split-cell-at-point)
              (should switched-to-buf)))
	  (ejn-cell-test--cleanup tmp-path)))))


;;; ===== ejn:worksheet-merge-cell =====

(ert-deftest ejn-cell-test-p2-t1--merge-cell-guard-no-notebook ()
  "merge-cell signals user-error when no notebook is associated."
  (with-temp-buffer
    (should-error
     (ejn:worksheet-merge-cell)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--merge-cell-guard-no-cell ()
  "merge-cell signals user-error when no cell at point."
  (with-temp-buffer
    (set (make-local-variable 'ejn--notebook) (make-instance 'ejn-notebook))
    (should-error
     (ejn:worksheet-merge-cell)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--merge-cell-syncs-both-cells ()
  "merge-cell calls ejn-shadow-sync-cell on both cells before reading :source."
  (let* ((result (ejn-cell-test--make-notebook 3))
         (tmp-path (car result))
         (notebook (cadr result))
         (cells (slot-value notebook 'cells))
         (current-cell (nth 0 cells))
         (lower-cell (nth 1 cells)))
    (oset notebook master-buffer (get-buffer-create "*ejn-master:test*"))
    (unwind-protect
        (with-temp-buffer
          (set (make-local-variable 'ejn--notebook) notebook)
          (set (make-local-variable 'ejn--cell) current-cell)
          (let ((synced-cells '()))
            (cl-letf (((symbol-function 'ejn-shadow-sync-cell)
                       (lambda (c) (push c synced-cells)))
                      ((symbol-function 'ejn--poly-refresh-cells)
                       (lambda () nil))
                      ((symbol-function 'ejn--refresh-master-cells)
                       (lambda () (ert-fail "ejn--refresh-master-cells should NOT be called")))
                      ((symbol-function 'ejn--reindex-shadow-files)
                       (lambda (_n) nil))
                      ((symbol-function 'delete-file)
                       (lambda (&rest _) nil))
                      ((symbol-function 'buffer-live-p)
                       (lambda (&rest _) t)))
              (ejn:worksheet-merge-cell)
              (should (= (length synced-cells) 2))
              (should (memq current-cell synced-cells))
              (should (memq lower-cell synced-cells))))
	  (ejn-cell-test--cleanup tmp-path)))))


;;; ===== ejn:worksheet-yank-cell =====

(ert-deftest ejn-cell-test-p2-t1--yank-cell-guard-no-notebook ()
  "yank-cell signals user-error when no notebook is associated."
  (with-temp-buffer
    (should-error
     (ejn:worksheet-yank-cell)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--yank-cell-guard-no-cell ()
  "yank-cell signals user-error when no cell at point."
  (with-temp-buffer
    (set (make-local-variable 'ejn--notebook) (make-instance 'ejn-notebook))
    (should-error
     (ejn:worksheet-yank-cell)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--yank-cell-switches-to-buffer ()
  "yank-cell calls switch-to-buffer on the yanked cell's buffer."
  (let* ((result (ejn-cell-test--make-notebook 2))
         (tmp-path (car result))
         (notebook (cadr result))
         (cells (slot-value notebook 'cells))
         (cell (nth 0 cells)))
    ;; Prime the kill ring
    (oset notebook ejn-cell-kill-ring
          `(((source . "yanked source")
             (type . code))))
    (unwind-protect
        (with-temp-buffer
          (set (make-local-variable 'ejn--notebook) notebook)
          (set (make-local-variable 'ejn--cell) cell)
          (let ((switched-to-buf nil))
            (cl-letf (((symbol-function 'switch-to-buffer)
                       (lambda (buf) (setq switched-to-buf buf)))
                      ((symbol-function 'ejn-cell-open-buffer)
                       (lambda (c &optional _) (current-buffer)))
                      ((symbol-function 'ejn-shadow-write-cell)
                       (lambda (_c _n) nil))
                      ((symbol-function 'ejn--reindex-shadow-files)
                       (lambda (_n) nil)))
              (ejn:worksheet-yank-cell)
              (should switched-to-buf)))
	  (ejn-cell-test--cleanup tmp-path)))))


;;; ===== ejn:worksheet-copy-cell =====

(ert-deftest ejn-cell-test-p2-t1--copy-cell-guard-no-notebook ()
  "copy-cell signals user-error when no notebook is associated."
  (with-temp-buffer
    (should-error
     (ejn:worksheet-copy-cell)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--copy-cell-guard-no-cell ()
  "copy-cell signals user-error when no cell at point."
  (with-temp-buffer
    (set (make-local-variable 'ejn--notebook) (make-instance 'ejn-notebook))
    (should-error
     (ejn:worksheet-copy-cell)
     :type 'user-error)))

(ert-deftest ejn-cell-test-p2-t1--copy-cell-syncs-before-copy ()
  "copy-cell calls ejn-shadow-sync-cell before reading :source."
  (let* ((result (ejn-cell-test--make-notebook 2))
         (tmp-path (car result))
         (notebook (cadr result))
         (cells (slot-value notebook 'cells))
         (cell (nth 0 cells)))
    (unwind-protect
        (with-temp-buffer
          (set (make-local-variable 'ejn--notebook) notebook)
          (set (make-local-variable 'ejn--cell) cell)
          (let ((synced-cells '()))
            (cl-letf (((symbol-function 'ejn-shadow-sync-cell)
                       (lambda (c) (push c synced-cells)))
                      ((symbol-function 'ejn:worksheet-kill-cell)
                       (lambda () nil)))
              (ejn:worksheet-copy-cell)
              (should (= (length synced-cells) 1))
              (should (eq (car synced-cells) cell))))
	  (ejn-cell-test--cleanup tmp-path)))))


;;; ===== ejn--make-cell calls poly-refresh =====

(ert-deftest ejn-cell-test-p2-t1--make-cell-calls-poly-refresh ()
  "ejn--make-cell calls ejn--poly-refresh-cells, not ejn--refresh-master-cells."
  (let* ((result (ejn-cell-test--make-notebook 2))
         (tmp-path (car result))
         (notebook (cadr result)))
    ;; Create a fake master buffer so buffer-live-p returns t
    (let ((master-buf (get-buffer-create "*ejn-master:fake*")))
      (oset notebook master-buffer master-buf)
      (unwind-protect
          (let ((poly-refresh-called nil))
            (cl-letf (((symbol-function 'ejn--poly-refresh-cells)
                       (lambda () (setq poly-refresh-called t)))
                      ((symbol-function 'ejn--refresh-master-cells)
                       (lambda () (ert-fail "ejn--refresh-master-cells should NOT be called")))
                      ((symbol-function 'ejn-shadow-write-cell)
                       (lambda (_c _n) nil))
                      ((symbol-function 'ejn--reindex-shadow-files)
                       (lambda (_n) nil)))
              (ejn--make-cell notebook 0 'code)
              (should poly-refresh-called))
            (kill-buffer master-buf)
            (ejn-cell-test--cleanup tmp-path))))))


;;; ===== ejn:worksheet-goto-next-input (master-view) =====

(ert-deftest ejn-cell-test-p3-t1--goto-next-master-uses-re-search-forward ()
  "goto-next in master-view uses re-search-forward for chunk header regex."
  (with-temp-buffer
    (insert "# %%<ejn-cell:0:>\ncell 0\n\n# %%<ejn-cell:1:>\ncell 1\n\n# %%<ejn-cell:2:>\ncell 2\n")
    (goto-char (point-min))
    (kill-local-variable 'ejn--cell)
    ;; Save original functions, then wrap to track calls
    (let ((re-search-forward-called nil)
          (next-button-called nil)
          (orig-re-search-forward (symbol-function 're-search-forward)))
      (cl-letf (((symbol-function 're-search-forward)
                 (lambda (regexp &optional limit repeat)
                   (setq re-search-forward-called t)
                   (funcall orig-re-search-forward regexp limit repeat)))
                ((symbol-function 'next-button)
                 (lambda (&optional _)
                   (setq next-button-called t)
                   (error "next-button should not be called"))))
        (ejn:worksheet-goto-next-input)
        (should re-search-forward-called)
        (should-not next-button-called)
        (should (looking-at "^# %%<ejn-cell:1:"))))))

(ert-deftest ejn-cell-test-p3-t1--goto-next-master-error-no-more-cells ()
  "goto-next in master-view signals user-error when no more cells below."
  (with-temp-buffer
    (insert "# %%<ejn-cell:0:>\ncell 0\n")
    (goto-char (point-max))
    (kill-local-variable 'ejn--cell)
    (should-error
     (ejn:worksheet-goto-next-input)
     :type 'user-error)))


;;; ===== ejn:worksheet-goto-prev-input (master-view) =====

(ert-deftest ejn-cell-test-p3-t1--goto-prev-master-uses-re-search-backward ()
  "goto-prev in master-view uses re-search-backward for chunk header regex."
  (with-temp-buffer
    (insert "# %%<ejn-cell:0:>\ncell 0\n\n# %%<ejn-cell:1:>\ncell 1\n\n# %%<ejn-cell:2:>\ncell 2\n")
    (goto-char (point-max))
    (kill-local-variable 'ejn--cell)
    (let ((re-search-backward-called nil)
          (previous-button-called nil)
          (orig-re-search-backward (symbol-function 're-search-backward)))
      (cl-letf (((symbol-function 're-search-backward)
                 (lambda (regexp &optional limit repeat)
                   (setq re-search-backward-called t)
                   (funcall orig-re-search-backward regexp limit repeat)))
                ((symbol-function 'previous-button)
                 (lambda (&optional _)
                   (setq previous-button-called t)
                   (error "previous-button should not be called"))))
        (ejn:worksheet-goto-prev-input)
        (should re-search-backward-called)
        (should-not previous-button-called)
        (should (looking-at "^# %%<ejn-cell:2:"))))))

(ert-deftest ejn-cell-test-p3-t1--goto-prev-master-error-no-more-cells ()
  "goto-prev in master-view signals user-error when no more cells above."
  (with-temp-buffer
    (insert "# %%<ejn-cell:0:>\ncell 0\n")
    (goto-char (point-min))
    (kill-local-variable 'ejn--cell)
    (should-error
     (ejn:worksheet-goto-prev-input)
     :type 'user-error)))

;;; ejn-cell-test.el ends here
