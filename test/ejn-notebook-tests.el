;;; ejn-notebook-tests.el --- ERT tests for ejn-notebook  -*- lexical-binding: t; -*-

;; Copyright (C) 2025  EJN Contributors

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Tests for ejn-notebook: save (P2-T25), rename (P2-T26),
;; and save round-trip (P2-T38).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'eieio)
(require 'json)

(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))

(require 'ejn-core)
(require 'ejn-notebook)
(require 'ejn)

(ert-deftest ejn-notebook-p2-t26--rename-renames-ipynb-on-disk ()
  "Verify ejn-notebook-rename renames the .ipynb file on disk."
  (let* ((tmp-dir (expand-file-name "ejn-test" temporary-file-directory))
         (old-path (expand-file-name "oldname.ipynb" tmp-dir))
         (new-path (expand-file-name "newname.ipynb" tmp-dir)))
    (make-directory tmp-dir t)
    (unwind-protect
        (progn
          (with-temp-file old-path
            (insert "{}"))
          (let* ((cell0 (make-instance 'ejn-cell
                                       :type 'code
                                       :source "pass"))
                 (nb (make-instance 'ejn-notebook
                                    :path old-path
                                    :cells (list cell0))))
            (ejn-notebook-rename nb new-path)
            (should-not (file-exists-p old-path))
            (should (file-exists-p new-path))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-notebook-p2-t26--rename-updates-path-slot ()
  "Verify ejn-notebook-rename updates the notebook path slot."
  (let* ((tmp-dir (expand-file-name "ejn-test" temporary-file-directory))
         (old-path (expand-file-name "oldname.ipynb" tmp-dir))
         (new-path (expand-file-name "newname.ipynb" tmp-dir)))
    (make-directory tmp-dir t)
    (unwind-protect
        (progn
          (with-temp-file old-path
            (insert "{}"))
          (let* ((cell0 (make-instance 'ejn-cell
                                       :type 'code
                                       :source "pass"))
                 (nb (make-instance 'ejn-notebook
                                    :path old-path
                                    :cells (list cell0))))
            (ejn-notebook-rename nb new-path)
            (should (string= new-path (slot-value nb 'path)))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-notebook-p2-t26--rename-renames-cache-directory ()
  "Verify cache dir is renamed from old-stem to new-stem."
  (let* ((tmp-dir (expand-file-name "ejn-test" temporary-file-directory))
         (old-path (expand-file-name "oldname.ipynb" tmp-dir))
         (new-path (expand-file-name "newname.ipynb" tmp-dir)))
    (make-directory tmp-dir t)
    (unwind-protect
        (progn
          (with-temp-file old-path
            (insert "{}"))
          (let* ((cell0 (make-instance 'ejn-cell
                                       :type 'code
                                       :source "pass"))
                 (nb (make-instance 'ejn-notebook
                                    :path old-path
                                    :cells (list cell0))))
            (ejn-shadow-write-cell cell0 nb)
            (let ((old-cache (expand-file-name ".ejn-cache/oldname" tmp-dir))
                  (new-cache (expand-file-name ".ejn-cache/newname" tmp-dir)))
              (should (file-directory-p old-cache))
              (ejn-notebook-rename nb new-path)
              (should-not (file-directory-p old-cache))
              (should (file-directory-p new-cache)))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-notebook-p2-t26--rename-returns-t-on-success ()
  "Verify ejn-notebook-rename returns t on success."
  (let* ((tmp-dir (expand-file-name "ejn-test" temporary-file-directory))
         (old-path (expand-file-name "oldname.ipynb" tmp-dir))
         (new-path (expand-file-name "newname.ipynb" tmp-dir)))
    (make-directory tmp-dir t)
    (unwind-protect
        (progn
          (with-temp-file old-path
            (insert "{}"))
          (let* ((cell0 (make-instance 'ejn-cell
                                       :type 'code
                                       :source "pass"))
                 (nb (make-instance 'ejn-notebook
                                    :path old-path
                                    :cells (list cell0)))
                 (result (ejn-notebook-rename nb new-path)))
            (should (eq result t))))
      (delete-directory tmp-dir 'recursive))))

(ert-deftest ejn-notebook-p2-t26--rename-command-is-interactive ()
  "Verify ejn:notebook-rename-command is an interactive command."
  (should (commandp #'ejn:notebook-rename-command)))

;;; Tests — P2-T38: Save round-trip

(ert-deftest ejn-notebook-p2-t38--round-trip-preserves-cell-count-types-sources ()
  "Verify save then re-open preserves cell count, types, and sources.

Create a notebook with 3 cells of different types, save to disk,
re-open, and verify all properties match."
  (let* ((tmpdir (make-temp-file "ejn-test-roundtrip-" t))
         (nbpath (expand-file-name "roundtrip.ipynb" tmpdir))
         (cell-code (make-instance 'ejn-cell
                                   :type 'code
                                   :source "print('hello')"))
         (cell-md (make-instance 'ejn-cell
                                 :type 'markdown
                                 :source "# Title\nSome text."))
         (cell-raw (make-instance 'ejn-cell
                                  :type 'raw
                                  :source "raw content here"))
         (cells (list cell-code cell-md cell-raw))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells cells))
         (buf (generate-new-buffer "*ejn-roundtrip-test*")))
    (unwind-protect
        (progn
          ;; Arrange: associate notebook with buffer
          (with-current-buffer buf
            (set (make-local-variable 'ejn--notebook) nb))
          ;; Act: save via the command
          (with-current-buffer buf
            (ejn:notebook-save-notebook-command))
          ;; Assert: re-open and verify
          (let ((nb2 (ejn-notebook-load nbpath)))
            (should (= (length (slot-value nb2 'cells)) 3))
            (should (equal (slot-value (nth 0 (slot-value nb2 'cells)) 'type)
                           'code))
            (should (equal (slot-value (nth 0 (slot-value nb2 'cells)) 'source)
                           "print('hello')"))
            (should (equal (slot-value (nth 1 (slot-value nb2 'cells)) 'type)
                           'markdown))
            (should (equal (slot-value (nth 1 (slot-value nb2 'cells)) 'source)
                           "# Title\nSome text."))
            (should (equal (slot-value (nth 2 (slot-value nb2 'cells)) 'type)
                           'raw))
            (should (equal (slot-value (nth 2 (slot-value nb2 'cells)) 'source)
                           "raw content here"))))
      (kill-buffer buf)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-notebook-p2-t38--buffer-modifications-captured-in-save ()
  "Verify modifications to cell buffers are captured in the saved .ipynb.

Set up a notebook with a cell, create its buffer with different content,
mark the cell dirty, save, then re-open and verify the new source."
  (let* ((tmpdir (make-temp-file "ejn-test-roundtrip-" t))
         (nbpath (expand-file-name "modified.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "original source"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell)))
         (buf (generate-new-buffer "*ejn-mod-test*"))
         (cell-buf (generate-new-buffer "*ejn-cell-mod*")))
    (unwind-protect
        (progn
          ;; Arrange: set up cell buffer with modified content
          (with-current-buffer cell-buf
            (erase-buffer)
            (insert "modified source in buffer"))
          (oset cell buffer cell-buf)
          (oset cell dirty t)
          ;; Associate notebook with the test buffer
          (with-current-buffer buf
            (set (make-local-variable 'ejn--notebook) nb))
          ;; Act: save via the command (should flush dirty buffers)
          (with-current-buffer buf
            (ejn:notebook-save-notebook-command))
          ;; Assert: re-open and verify modified source is saved
          (let ((nb2 (ejn-notebook-load nbpath)))
            (should (= (length (slot-value nb2 'cells)) 1))
            (should (equal (slot-value (nth 0 (slot-value nb2 'cells)) 'source)
                           "modified source in buffer"))))
      (kill-buffer buf)
      (kill-buffer cell-buf)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-notebook-p2-t38--dirty-flags-cleared-after-save ()
  "Verify all dirty flags are cleared after save completes.

Set up a notebook with dirty cells that have live buffers, save, then
check that every cell's :dirty slot is nil."
  (let* ((tmpdir (make-temp-file "ejn-test-roundtrip-" t))
         (nbpath (expand-file-name "dirty-clear.ipynb" tmpdir))
         (cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "source a"))
         (cell-b (make-instance 'ejn-cell
                                :type 'code
                                :source "source b"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell-a cell-b)))
         (buf (generate-new-buffer "*ejn-dirty-test*"))
         (buf-a (generate-new-buffer "*ejn-cell-a-dirty*"))
         (buf-b (generate-new-buffer "*ejn-cell-b-dirty*")))
    (unwind-protect
        (progn
          ;; Arrange: mark both cells dirty with live buffers
          (oset cell-a buffer buf-a)
          (oset cell-a dirty t)
          (oset cell-b buffer buf-b)
          (oset cell-b dirty t)
          (with-current-buffer buf
            (set (make-local-variable 'ejn--notebook) nb))
          ;; Act: save via the command
          (with-current-buffer buf
            (ejn:notebook-save-notebook-command))
          ;; Assert: all dirty flags cleared
          (should-not (ejn-cell-dirty-p cell-a))
          (should-not (ejn-cell-dirty-p cell-b)))
      (kill-buffer buf)
      (kill-buffer buf-a)
      (kill-buffer buf-b)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-notebook-p2-t38--saved-file-is-valid-nbformat-json ()
  "Verify the saved file is valid nbformat 4.x JSON.

Save a notebook and check the file content: valid JSON parseable by
json-parse-buffer, contains nbformat key with value 4, and contains
a cells array."
  (let* ((tmpdir (make-temp-file "ejn-test-roundtrip-" t))
         (nbpath (expand-file-name "nbformat-check.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "pass"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell)))
         (buf (generate-new-buffer "*ejn-nbformat-test*")))
    (unwind-protect
        (progn
          ;; Arrange: associate notebook with buffer
          (with-current-buffer buf
            (set (make-local-variable 'ejn--notebook) nb))
          ;; Act: save via the command
          (with-current-buffer buf
            (ejn:notebook-save-notebook-command))
          ;; Assert: file contains valid nbformat 4.x JSON
          (let ((json-data
                 (with-temp-buffer
                   (insert-file-contents nbpath)
                   (json-parse-buffer :object-type 'hash-table))))
            (should (gethash "nbformat" json-data))
            (should (= (gethash "nbformat" json-data) 4))
            (should (gethash "cells" json-data))
            (should (= (length (gethash "cells" json-data)) 1))))
      (kill-buffer buf)
      (delete-directory tmpdir 'recursive))))

;;; Tests — P3-T4: Outputs survive save/load round-trip

(ert-deftest ejn-notebook-p3-t4--outputs-survive-save-load-roundtrip ()
  "Verify non-empty cell outputs survive JSON serialization round-trip.

Create a notebook with code cells that have outputs (hash-tables
simulating real Jupyter output structures), save to .ipynb, reload
via ejn-notebook-load, and assert that outputs match the originals."
  (let* ((tmpdir (make-temp-file "ejn-test-outputs-" t))
         (nbpath (expand-file-name "outputs-roundtrip.ipynb" tmpdir))
         ;; Simulate a real Jupyter display_data output
         (output-1
          (let ((ht (make-hash-table :test 'equal)))
            (puthash "output_type" "display_data" ht)
            (puthash "text/plain" "array([1, 2, 3])" ht)
            ht))
         ;; Simulate a stream output
         (output-2
          (let ((ht (make-hash-table :test 'equal)))
            (puthash "output_type" "stream" ht)
            (puthash "name" "stdout" ht)
            (puthash "text" "hello world\n" ht)
            ht))
         (cell-with-outputs
          (make-instance 'ejn-cell
                         :type 'code
                         :source "print('hello')"
                         :outputs (list output-1 output-2)))
         (cell-no-outputs
          (make-instance 'ejn-cell
                         :type 'code
                         :source "pass"
                         :outputs nil))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell-with-outputs cell-no-outputs)))
         (buf (generate-new-buffer "*ejn-outputs-test*")))
    (unwind-protect
        (progn
          ;; Arrange: associate notebook with buffer
          (with-current-buffer buf
            (set (make-local-variable 'ejn--notebook) nb))
          ;; Act: save then reload
          (with-current-buffer buf
            (ejn:notebook-save-notebook-command))
          (let* ((nb2 (ejn-notebook-load nbpath))
                 (cells2 (slot-value nb2 'cells))
                 (reloaded-cell (nth 0 cells2))
                 (reloaded-outputs (slot-value reloaded-cell 'outputs))
                 (empty-cell (nth 1 cells2)))
            ;; Assert: outputs list is non-nil and has correct length
            (should (listp reloaded-outputs))
            (should (= (length reloaded-outputs) 2))
            ;; Assert: first output preserves output_type
            (let ((out-1 (nth 0 reloaded-outputs)))
              (should (equal (gethash "output_type" out-1) "display_data"))
              (should (equal (gethash "text/plain" out-1) "array([1, 2, 3])")))
            ;; Assert: second output preserves stream fields
            (let ((out-2 (nth 1 reloaded-outputs)))
              (should (equal (gethash "output_type" out-2) "stream"))
              (should (equal (gethash "name" out-2) "stdout"))
              (should (equal (gethash "text" out-2) "hello world\n")))
            ;; Assert: second cell has nil outputs
            (should-not (slot-value empty-cell 'outputs))))
      (kill-buffer buf)
      (delete-directory tmpdir 'recursive))))

(ert-deftest ejn-notebook-p2-t39--file-open-alias-is-fbound-and-equivalent-to-ejn-open-file ()
  "Smoke: verify ejn:file-open is fboundp and is an alias for ejn-open-file."
  (should (fboundp #'ejn:file-open))
  (should (eq (indirect-function (symbol-function 'ejn:file-open))
              (indirect-function (symbol-function 'ejn-open-file)))))

;;; ejn-notebook-tests.el ends here
