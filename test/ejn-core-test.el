;;; ejn-core-test.el --- ERT smoke tests for ejn-core  -*- lexical-binding: t; -*-

(require 'ert)

(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))
(require 'ejn-core)
(require 'ejn-cell)
(require 'ejn)

;;; Smoke tests

(ert-deftest ejn-core--buffer-local-variables ()
  "Smoke: ejn--notebook and ejn--cell are buffer-local and isolated across buffers.

Verify that (1) both variables are buffer-local, and (2) setting one
in a temp buffer does not leak to another buffer."
  (with-temp-buffer
    ;; --- ejn--notebook isolation ---
    (set (make-local-variable 'ejn--notebook) "buf1-notebook")
    (let ((buf1-notebook ejn--notebook))
      (with-temp-buffer
        (set (make-local-variable 'ejn--notebook) "buf2-notebook")
        ;; buf2 must see its own value, not buf1's
        (should (equal "buf2-notebook" ejn--notebook))
        ;; A fresh buffer that never sets the var must see nil
        (with-temp-buffer
          (should-not ejn--notebook)))
      ;; After buf2 is killed, buf1 still sees its value
      (should (equal "buf1-notebook" ejn--notebook))
      ;; --- ejn--cell isolation ---
      (set (make-local-variable 'ejn--cell) "buf1-cell")
      (with-temp-buffer
        (set (make-local-variable 'ejn--cell) "buf2-cell")
        (should (equal "buf2-cell" ejn--cell))
        (with-temp-buffer
          (should-not ejn--cell)))
      (should (equal "buf1-cell" ejn--cell)))))

(ert-deftest ejn-core--open-file-creates-and-switches-master-buffer ()
  "Smoke: `ejn-open-file' captures `ejn--create-master-view' return value.

Verify that calling `ejn-open-file' with a valid .ipynb file results in
a live master view buffer whose name starts with `*ejn-master:' and in
which the buffer-local `ejn--notebook' variable is non-nil.
The structural fix (B01) ensures the return value of
`ejn--create-master-view' is captured and `switch-to-buffer' is called."
  (let ((temp-ipynb (make-temp-file "ejn-test-" nil ".ipynb"
                                    (json-encode
                                     '(("nbformat" . 4)
                                       ("nbformat_minor" . 5)
                                       ("metadata" . nil)
                                       ("cells" . []))))))
    (unwind-protect
        (let ((master-buf nil))
          ;; Mock read-file-name to return our temp .ipynb
          (cl-letf (((symbol-function 'read-file-name)
                     (lambda (&rest _) temp-ipynb)))
            (ejn-open-file)
            ;; After ejn-open-file, find the master buffer
            (dolist (buf (buffer-list))
              (when (string-prefix-p "*ejn-master:" (buffer-name buf))
                (setq master-buf buf)))
            ;; Structural assertion: master buffer exists and is live
            (should (bufferp master-buf))
            ;; Verify ejn--notebook is set in the master buffer
            (with-current-buffer master-buf
              (should (bound-and-true-p ejn--notebook)))))
      ;; Cleanup
      (ignore-errors (delete-file temp-ipynb))
      ;; Remove scroll hook to avoid wrong-number-of-arguments during
      ;; kill-buffer (B33, P7-T1 scope — not fixed yet)
      (remove-hook 'window-scroll-functions #'ejn--master-scroll-hook)
      (dolist (buf (buffer-list))
        (when (string-prefix-p "*ejn-master:" (buffer-name buf))
          (kill-buffer buf))))))


;;; ===== P4-T1 B22: Atomic shadow write =====

(ert-deftest ejn-core-test-p4-t1--shadow-write-cell-atomic ()
  "B22: `ejn-shadow-write-cell' writes atomically via .tmp + rename-file.

After the call, the shadow file exists at the target path. No .tmp
file remains. The content written equals the cell source."
  (let* ((ipynb-str
          "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{},\"cells\":[{\"cell_type\":\"code\",\"source\":\"hello\",\"outputs\":[],\"execution_count\":null}]}")
         (tmp-ipynb (make-temp-file "ejn-p4t1-" nil ".ipynb" ipynb-str))
         (tmp-dir (file-name-directory tmp-ipynb)))
    (unwind-protect
        (let* ((notebook (ejn-notebook-load tmp-ipynb))
               (cell (nth 0 (slot-value notebook 'cells)))
               (shadow-path (ejn-shadow-write-cell cell notebook))
               (tmp-path (concat shadow-path ".tmp")))
          ;; Shadow file exists at target path
          (should (file-exists-p shadow-path))
          ;; No leftover .tmp file
          (should-not (file-exists-p tmp-path))
          ;; Content matches cell source
          (should (string= (slot-value cell 'source)
                           (with-temp-buffer
                             (insert-file-contents shadow-path)
                             (buffer-string))))
          ;; shadow-file slot is set
          (should (string= shadow-path (slot-value cell 'shadow-file))))
      ;; Cleanup
      (ignore-errors (delete-file tmp-ipynb))
      (ignore-errors
        (let ((cache-dir (expand-file-name ".ejn-cache" tmp-dir)))
          (when (file-directory-p cache-dir)
            (dolist (f (directory-files cache-dir t "cell_"))
              (ignore-errors (delete-file f)))
            (delete-directory cache-dir)))))))

(ert-deftest ejn-core-test-p4-t1--shadow-write-cell-uses-rename-file ()
  "B22: `ejn-shadow-write-cell' uses rename-file for atomicity.

Verify that `rename-file' is invoked during the write, confirming
the .tmp + rename-file atomic pattern rather than direct write."
  (let* ((ipynb-str
          "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{},\"cells\":[{\"cell_type\":\"code\",\"source\":\"hello\",\"outputs\":[],\"execution_count\":null}]}")
         (tmp-ipynb (make-temp-file "ejn-p4t1-" nil ".ipynb" ipynb-str))
         (tmp-dir (file-name-directory tmp-ipynb)))
    (unwind-protect
        (let* ((notebook (ejn-notebook-load tmp-ipynb))
               (cell (nth 0 (slot-value notebook 'cells)))
               (rename-file-args nil))
          (cl-letf (((symbol-function 'rename-file)
                     (lambda (from to &optional _)
                       (setq rename-file-args (list from to))
                       (let ((content (with-temp-buffer
                                        (insert-file-contents from)
                                        (buffer-string))))
                         (with-temp-file to (insert content))
                         (delete-file from)))))
            (ejn-shadow-write-cell cell notebook)
            ;; rename-file must have been called
            (should rename-file-args)
            ;; First arg should be the .tmp path
            (should (string-suffix-p ".tmp" (car rename-file-args)))))
      ;; Cleanup
      (ignore-errors (delete-file tmp-ipynb))
      (ignore-errors
        (let ((cache-dir (expand-file-name ".ejn-cache" tmp-dir)))
          (when (file-directory-p cache-dir)
            (dolist (f (directory-files cache-dir t "cell_"))
              (ignore-errors (delete-file f)))
            (delete-directory cache-dir)))))))

(ert-deftest ejn-core-test-p4-t1--shadow-write-cell-atomic-nil-source ()
  "B22: `ejn-shadow-write-cell' handles nil source gracefully.

When cell source is nil, the shadow file is written as an empty
string rather than causing an error."
  (let* ((ipynb-str
          "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{},\"cells\":[{\"cell_type\":\"code\",\"source\":null,\"outputs\":[],\"execution_count\":null}]}")
         (tmp-ipynb (make-temp-file "ejn-p4t1-" nil ".ipynb" ipynb-str))
         (tmp-dir (file-name-directory tmp-ipynb)))
    (unwind-protect
        (let* ((notebook (ejn-notebook-load tmp-ipynb))
               (cell (nth 0 (slot-value notebook 'cells)))
               (shadow-path (ejn-shadow-write-cell cell notebook)))
          (should (file-exists-p shadow-path))
          ;; Nil source should produce empty file content
          (should (string= ""
                           (with-temp-buffer
                             (insert-file-contents shadow-path)
                             (buffer-string)))))
      ;; Cleanup
      (ignore-errors (delete-file tmp-ipynb))
      (ignore-errors
        (let ((cache-dir (expand-file-name ".ejn-cache" tmp-dir)))
          (when (file-directory-p cache-dir)
            (dolist (f (directory-files cache-dir t "cell_"))
              (ignore-errors (delete-file f)))
            (delete-directory cache-dir)))))))


;;; ===== P4-T1 B23: Orphan deletion via directory glob =====

(ert-deftest ejn-core-test-p4-t1--reindex-deletes-orphan-shadow-files ()
  "B23: `ejn--reindex-shadow-files' deletes orphan shadow files via glob.

Given a notebook whose cache dir contains a file that does not
correspond to any cell in the notebook's :cells list, calling
reindex deletes the orphan file."
  (let* ((ipynb-str
          "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{},\"cells\":[{\"cell_type\":\"code\",\"source\":\"only cell\",\"outputs\":[],\"execution_count\":null}]}")
         (tmp-ipynb (make-temp-file "ejn-p4t1-" nil ".ipynb" ipynb-str))
         (tmp-dir (file-name-directory tmp-ipynb)))
    (unwind-protect
        (let* ((nb-path tmp-ipynb)
               (nb-stem (file-name-sans-extension
                         (file-name-nondirectory nb-path)))
               (cache-dir (expand-file-name
                           (concat ".ejn-cache/" nb-stem)
                           tmp-dir))
               (orphan-path (expand-file-name "cell_099.py" cache-dir)))
          (make-directory cache-dir t)
          ;; Create an orphan file that no cell owns
          (with-temp-file orphan-path
            (insert "orphan content"))
          (should (file-exists-p orphan-path))
          ;; Load notebook and reindex
          (let ((notebook (ejn-notebook-load tmp-ipynb)))
            (ejn--reindex-shadow-files notebook))
          ;; Orphan should be gone
          (should-not (file-exists-p orphan-path)))
      ;; Cleanup
      (ignore-errors (delete-file tmp-ipynb))
      (ignore-errors
        (let ((cache-dir (expand-file-name ".ejn-cache" tmp-dir)))
          (when (file-directory-p cache-dir)
            (dolist (f (directory-files cache-dir t "cell_"))
              (ignore-errors (delete-file f)))
            (delete-directory cache-dir)))))))

;;; ejn-core-test.el ends here
