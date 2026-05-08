;;; ejn-log-test.el --- Tests for ejn-log  -*- lexical-binding:t -*-

;; Copyright (C) 2025 Kyohei

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
(require 'ejn-core)
(require 'ejn-log)

(ert-deftest ejn-log-test/log-message-appends-to-buffer ()
  "Log messages should appear in the *ejn-debug* buffer."
  (let ((buf (get-buffer-create "*ejn-debug*")))
    (with-current-buffer buf (erase-buffer))
    (let ((ejn-debug t))
      (ejn-log-message "test" "hello world")))
  (with-current-buffer "*ejn-debug*"
    (goto-char (point-min))
    (should (search-forward "hello world" nil t))))

(ert-deftest ejn-log-test/log-with-level-includes-tag ()
  "Log messages should include the level tag."
  (let ((buf (get-buffer-create "*ejn-debug*")))
    (with-current-buffer buf (erase-buffer))
    (let ((ejn-debug t))
      (ejn-log-message "warn" "something happened")))
  (with-current-buffer "*ejn-debug*"
    (goto-char (point-min))
    (should (search-forward "[warn]" nil t))))

(ert-deftest ejn-log-test/log-disabled-when-debug-nil ()
  "Logging should be a no-op when `ejn-debug' is nil."
  (let ((buf (get-buffer-create "*ejn-debug*")))
    (with-current-buffer buf (erase-buffer))
    (let ((ejn-debug nil))
      (ejn-log-message "info" "should not appear"))
    (with-current-buffer buf
      (should (= (buffer-size) 0)))))

(ert-deftest ejn-log-test/trace-records-function-and-args ()
  "Record function name and arguments via `ejn-log-trace'."
  (let ((buf (get-buffer-create "*ejn-debug*")))
    (with-current-buffer buf (erase-buffer))
    (let ((ejn-debug t))
      (ejn-log-trace "test-func" :arg1 42 :arg2 "foo")))
  (with-current-buffer "*ejn-debug*"
    (goto-char (point-min))
    (should (search-forward "test-func" nil t))
    (should (search-forward "42" nil t))))

(ert-deftest ejn-log-test/profile-timer-returns-positive-number ()
  "Return a positive elapsed time via `ejn-log-profile'."
  (let ((elapsed (ejn-log-profile
                  (let ((sum 0))
                    (dotimes (i 10000 sum)
                      (cl-incf sum))))))
    (should (numberp elapsed))
    (should (> elapsed 0.0))))

(provide 'ejn-log-test)
;;; ejn-log-test.el ends here
