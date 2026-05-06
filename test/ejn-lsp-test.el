;;; ejn-lsp-test.el --- ERT smoke tests for ejn-lsp  -*- lexical-binding: t; -*-

(require 'ert)

(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))
(require 'ejn-core)
(require 'ejn-cell)
(require 'ejn-master)
(require 'ejn-lsp)

(ert-deftest ejn-lsp-test-p7-t1--register-virtual-buffer-integer-offset-line ()
  "B30: `ejn-lsp--register-virtual-buffer' passes integer `:offset-line'
to `lsp-virtual-buffer-register' (not a cons cell)."
  (let* ((ipynb-str "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{},\"cells\":[{\"cell_type\":\"code\",\"source\":\"x=1\",\"outputs\":[],\"execution_count\":null},{\"cell_type\":\"code\",\"source\":\"y=2\",\"outputs\":[],\"execution_count\":null}]}")
         (tmp-ipynb (make-temp-file "ejn-p7t1-" nil ".ipynb" ipynb-str))
         (lsp-args nil)
         (cell-buf (generate-new-buffer "*ejn-lsp-test-cell*")))
    (unwind-protect
        (let* ((notebook (ejn-notebook-load tmp-ipynb))
               (cell (nth 1 (slot-value notebook 'cells))))
          (with-current-buffer cell-buf
            (set (make-local-variable 'ejn--cell) cell)
            (set (make-local-variable 'ejn--notebook) notebook))
          (oset cell buffer cell-buf)
          (cl-letf (((symbol-function 'lsp-virtual-buffer-register)
                     (lambda (args)
                       (setq lsp-args args))))
            (ejn-lsp--register-virtual-buffer cell notebook)
            (should (listp lsp-args))
            (let ((offset-line (plist-get lsp-args :offset-line)))
              (should (integerp offset-line)))))
      (ignore-errors (delete-file tmp-ipynb))
      (when (buffer-live-p cell-buf)
        (kill-buffer cell-buf)))))

(ert-deftest ejn-lsp-test-p7-t1--master-view-scroll-hook-local ()
  "B31: Scroll hook added with `local' flag via `buffer-local-value' check.
Verify the hook is not added to the global `window-scroll-functions'."
  (let* ((ipynb-str "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{},\"cells\":[]}")
         (tmp-ipynb (make-temp-file "ejn-p7t1-" nil ".ipynb" ipynb-str))
         (global-hooks-before (default-value 'window-scroll-functions)))
    (unwind-protect
        (let ((notebook (ejn-notebook-load tmp-ipynb)))
          (ejn--create-master-view notebook)
          (should-not (memq #'ejn--master-scroll-hook
                            (default-value 'window-scroll-functions))))
      (ignore-errors (delete-file tmp-ipynb))
      (set-default 'window-scroll-functions global-hooks-before)
      (dolist (buf (buffer-list))
        (when (string-prefix-p "*ejn-master:" (buffer-name buf))
          (kill-buffer buf))))))

(ert-deftest ejn-lsp-test-p7-t1--cell-chunk-head-prefix-exists ()
  "B33: `ejn--cell-chunk-head-prefix' is a defconst with the correct prefix
string for polymode chunk delimiters."
  (should (boundp 'ejn--cell-chunk-head-prefix))
  (should (stringp ejn--cell-chunk-head-prefix))
  (should (string= ejn--cell-chunk-head-prefix "# %%<ejn-cell:")))

(ert-deftest ejn-lsp-test-p7-t1--poly-render-uses-constant ()
  "B33: `ejn--poly-render-cells' output begins with the chunk head prefix
constant for the first cell, confirming the constant replaces inline format."
  (let* ((ipynb-str "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{},\"cells\":[{\"cell_type\":\"code\",\"source\":\"pass\",\"outputs\":[],\"execution_count\":null}]}")
         (tmp-ipynb (make-temp-file "ejn-p7t1-" nil ".ipynb" ipynb-str))
         (notebook (ejn-notebook-load tmp-ipynb)))
    (unwind-protect
        (with-temp-buffer
          (ejn--poly-render-cells notebook)
          (should (string-prefix-p ejn--cell-chunk-head-prefix
                                   (buffer-substring-no-properties
                                    (point-min)
                                    (min (+ (point-min) (length ejn--cell-chunk-head-prefix))
                                         (point-max))))))
      (ignore-errors (delete-file tmp-ipynb)))))

(provide 'ejn-lsp-test)

;;; ejn-lsp-test.el ends here
