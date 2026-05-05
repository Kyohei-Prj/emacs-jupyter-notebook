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

;;; ejn-core-test.el ends here
