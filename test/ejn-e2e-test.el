;;; ejn-e2e-test.el --- End-to-end integration test for EJN  -*- lexical-binding: t -*-

;; End-to-end integration test that validates the full EJN workflow:
;;   1. Load EJN package
;;   2. Open a .ipynb notebook file
;;   3. Start a Jupyter kernel
;;   4. Navigate cells in the master buffer
;;   5. Execute each cell and verify results
;;   6. Clean up (stop kernel, kill buffers)
;;
;; Run with: eask emacs --batch -Q -l test/ejn-e2e-test.el
;; Requires: jupyter with python3 kernel installed

(let* ((project-root (file-name-directory
                      (directory-file-name (file-name-directory (or load-file-name buffer-file-name)))))
       (e2e-notebook (expand-file-name "e2e/simple.ipynb" project-root)))

  (add-to-list 'load-path project-root)
  (add-to-list 'load-path (expand-file-name "lisp" project-root))
  (require 'ejn)
  (message "=== EJN loaded ===")

  (let* ((notebook (ejn-notebook-load e2e-notebook))
         (cells (slot-value notebook 'cells))
         (master-buf (ejn--create-master-view notebook)))

    (message "=== Notebook loaded: %s cells ===" (length cells))

    ;; Initialize first cell
    (when cells
      (ejn-cell-initialize (car cells) notebook))

    ;; --- Navigation tests in master buffer ---
    (with-current-buffer master-buf
      (goto-char (point-min))

      (condition-case err
          (progn
            (ejn:worksheet-goto-next-input)
            (message "=== Nav next #1: OK (pt=%d) ===" (point)))
        (error (message "=== Nav next #1: FAIL - %s ===" (cdr err))))

      (condition-case err
          (progn
            (ejn:worksheet-goto-next-input)
            (message "=== Nav next #2: OK (pt=%d) ===" (point)))
        (error (message "=== Nav next #2: FAIL - %s ===" (cdr err))))

      (condition-case err
          (progn
            (ejn:worksheet-goto-next-input)
            (message "=== Nav next #3: OK (pt=%d) ===" (point)))
        (error (message "=== Nav next #3: FAIL - %s ===" (cdr err))))

      (condition-case nil
          (ejn:worksheet-goto-next-input)
        (error (message "=== Nav past-end: OK (expect err) ===")))

      (condition-case err
          (progn
            (ejn:worksheet-goto-prev-input)
            (message "=== Nav prev: OK (pt=%d) ===" (point)))
        (error (message "=== Nav prev: FAIL - %s ===" (cdr err))))

      (goto-char (point-min))
      (forward-line 1)
      (condition-case nil
          (ejn:worksheet-goto-prev-input)
        (error (message "=== Nav prev-at-begin: OK (expect err) ==="))))

    ;; --- Initialize remaining cells ---
    (dolist (cell cells)
      (unless (slot-value cell 'initialized-p)
        (ejn-cell-initialize cell notebook)))
    (message "=== All cells initialized ===")

    ;; --- Start kernel ---
    (condition-case err
        (let ((client (ejn-kernel-start notebook "python3")))
          (message "=== Kernel started ==="))
      (error (message "=== Kernel start FAILED: %s ===" (cdr err))))

    ;; --- Execute cells ---
    (let ((idx 0))
      (dolist (cell cells)
        (message "=== Execute cell %d ===" idx)
        (condition-case err
            (progn
              (ejn--execute-cell cell)
              (sleep-for 2))
          (error (message "=== Cell %d exec FAILED: %s ===" idx (cdr err))))
        (cl-incf idx)))

    ;; --- Check results ---
    (let ((idx 0))
      (dolist (cell cells)
        (message "=== Cell %d: count=%s outputs=%s ==="
                 idx
                 (slot-value cell 'exec-count)
                 (if (slot-value cell 'outputs) "has-output" "none"))
        (cl-incf idx)))

    ;; --- Cleanup ---
    (condition-case nil
        (ejn-kernel-stop notebook)
      (error nil))
    (message "=== Cleanup done ===")))

(message "=== E2E TEST COMPLETE ===")
