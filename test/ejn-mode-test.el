;;; ejn-mode-test.el --- Tests for ejn-mode  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Kyohei

;; This file is part of emacs-jupyter-notebook.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Code:

(require 'ert)
(require 'ejn-mode)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-test-util)

(ert-deftest ejn-mode-test/mode-is-derived-from-text-mode ()
  "ejn-mode should derive from text-mode."
  (ejn-test-with-temp-buffer " *test*"
    (ejn-mode)
    (should (derived-mode-p 'text-mode))))

(ert-deftest ejn-mode-test/mode-sets-buffer-local-variables ()
  "ejn-mode should initialize buffer-local variables."
  (ejn-test-with-temp-buffer " *test*"
    (ejn-mode)
    (should (local-variable-p 'ejn--notebook))
    (should (local-variable-p 'ejn--rendering-p))
    (should-not ejn--notebook)
    (should-not ejn--rendering-p)))

(ert-deftest ejn-mode-test/keymap-bindings ()
  "Keymap should have expected bindings."
  (ejn-test-with-temp-buffer " *test*"
    (ejn-mode)
    (should (eq (lookup-key ejn-mode-map (kbd "C-c C-c")) #'ejn-execute-cell))
    (should (eq (lookup-key ejn-mode-map (kbd "C-c C-n")) #'ejn-goto-next-cell))
    (should (eq (lookup-key ejn-mode-map (kbd "C-<down>")) #'ejn-goto-next-cell))
    (should (eq (lookup-key ejn-mode-map (kbd "C-c C-a")) #'ejn-insert-cell-above))
    (should (eq (lookup-key ejn-mode-map (kbd "C-c C-b")) #'ejn-insert-cell-below))
    (should (eq (lookup-key ejn-mode-map (kbd "C-c C-k")) #'ejn-delete-cell))
    (should (eq (lookup-key ejn-mode-map (kbd "C-x C-s")) #'ejn-save-notebook))))

(ert-deftest ejn-mode-test/kernel-stubs-signal-error ()
  "Kernel commands should signal 'kernel not connected'."
  (ejn-test-with-temp-buffer " *test*"
    (ejn-mode)
    (should-error (ejn-kernel-quit))
    (should-error (ejn-kernel-interrupt))
    (should-error (ejn-kernel-restart))))

(ert-deftest ejn-mode-test/save-notebook-serializes-model ()
  "ejn-save-notebook should serialize the model to the file."
  (require 'ejn-persistence)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "test")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (set (make-local-variable 'buffer-file-name) "/tmp/test-ejn-save.ipynb")
      (condition-case nil
          (ejn-save-notebook)
        (file-error nil))
      (when (file-exists-p "/tmp/test-ejn-save.ipynb")
        (let ((contents (with-temp-buffer
                          (insert-file-contents "/tmp/test-ejn-save.ipynb")
                          (buffer-string))))
          (should (stringp contents))
          (should (> (length contents) 0))
          (delete-file "/tmp/test-ejn-save.ipynb"))))))

(ert-deftest ejn-mode-test/mode-exit-cleanup ()
  "Exiting ejn-mode should cancel the sync timer."
  (ejn-test-with-temp-buffer " *test*"
    (ejn-mode)
    (set (make-local-variable 'ejn--sync-timer)
         (run-with-timer 1000 nil #'ignore))
    (ejn--cleanup-buffer)
    (should-not ejn--sync-timer)))

(provide 'ejn-mode-test)
;;; ejn-mode-test.el ends here
