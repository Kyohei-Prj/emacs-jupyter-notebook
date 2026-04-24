;;; test-helper.el --- Test helper for emacs-jupyter-notebook  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;; Commentary:
;; Provides shared test infrastructure for the emacs-jupyter-notebook suite.
;; Sets up load-path, requires all ejn modules so tests need not do it individually,
;; offers a fixture path helper and a macro to run code against a temporary copy
;; of the simple.ipynb notebook fixture.  Loads buttercup and el-mock when
;; available.

;; Code:

;; ---------------------------------------------------------------------------
;; Load-path setup
;; ---------------------------------------------------------------------------

(defvar ejn-test--project-root
  (file-name-directory (or load-file-name load-source-file-name))
  "Absolute path to the project root directory.")

(add-to-list 'load-path ejn-test--project-root)
(add-to-list 'load-path (expand-file-name "lisp" ejn-test--project-root))

;; ---------------------------------------------------------------------------
;; Module requires (order matters: ejn-util has no internal deps)
;; ---------------------------------------------------------------------------

(require 'ejn-util)
(require 'ejn-data)
(require 'ejn-io)
(require 'ejn-kernel)
(require 'ejn-buffer)
(require 'ejn-shadow)
(require 'ejn-lsp)
(require 'ejn-display)
(require 'ejn-output)
(require 'ejn-treesit)

;; ---------------------------------------------------------------------------
;; Test framework (optional — tests that need buttercup/el-mock will require
;; them explicitly, but we load them here so stub smoke tests work)
;; ---------------------------------------------------------------------------

(when (require 'buttercup nil t)
  (require 'el-mock))

;; ---------------------------------------------------------------------------
;; Fixture helpers
;; ---------------------------------------------------------------------------

(defun ejn-test--fixture-path (name)
  "Return absolute path to `fixtures/NAME' in the project root.
The fixtures directory is at the project root, one level above this helper."
  (expand-file-name (concat "../fixtures/" name) ejn-test--project-root))

(defmacro ejn-test--with-temp-notebook (&rest body)
  "Copy `fixtures/simple.ipynb' to a temp dir, run BODY with temp path, then clean up.

Within BODY the variable `temp-notebook-path' is bound to the absolute path
of the copied notebook file."
  (declare (indent 0) (debug t))
  `(let* ((tmp-dir (make-temp-file "ejn-test-" t))
         (temp-notebook-path (expand-file-name "simple.ipynb" tmp-dir)))
     (copy-file (ejn-test--fixture-path "simple.ipynb") temp-notebook-path t)
     (unwind-protect
         (progn
           ,@body)
       (when (file-exists-p tmp-dir)
         (delete-directory tmp-dir t)))))

(provide 'test-helper)

;;; test-helper.el ends here
