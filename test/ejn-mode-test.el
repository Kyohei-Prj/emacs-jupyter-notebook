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

(provide 'ejn-mode-test)
;;; ejn-mode-test.el ends here
