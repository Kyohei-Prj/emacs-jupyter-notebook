;; test-runner.el --- Run all ejn tests
;; SPDX-License-Identifier: GPL-3.0-or-later

;; Code:

(let ((load-prefer-newer t)
      (root (file-name-directory (or load-file-name (error "No load-file-name")))))
  (add-to-list 'load-path root)
  (add-to-list 'load-path (expand-file-name "lisp" root)))

(require 'test-helper)

(dolist (f (directory-files "test" t "^ejn-.*-test\\.el$"))
  (load-file f))

(ert-run-tests-batch-and-exit)

;;; test-runner.el ends here
