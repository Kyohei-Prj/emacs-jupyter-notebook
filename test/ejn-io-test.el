;;; ejn-io-test.el --- Tests for ejn-io  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;; Commentary:

;; Tests for ejn-io module covering:
;; - P2-T14: ejn-io-read against all three fixtures (simple, mixed-lang, with-outputs)
;; - P2-T15: Round-trip read → write → read invariant
;; - P2-T16: Error handling (bad nbformat, missing file, invalid JSON, missing cell id)

;; Code:

(require 'test-helper)
(require 'ejn-io)

;;;; P2-T14: ejn-io-read tests against all three fixtures

(ert-deftest ejn-io-test-read-simple ()
  "Read simple.ipynb — verify cell count, UUIDs, source text, kernel info.

P2-T14: ejn-io-read against simple.ipynb fixture."
  (let ((nb (ejn-io-read (ejn-test--fixture-path "simple.ipynb"))))
    ;; Notebook struct and nbformat
    (should (ejn-notebook-p nb))
    (should (= (ejn-notebook-nbformat nb) 4))
    (should (= (ejn-notebook-nbformat-minor nb) 5))
    ;; Cell count
    (should (= (length (ejn-notebook-cells nb)) 2))
    ;; Kernel info
    (should (string= (ejn-notebook-kernel-name nb) "python3"))
    (should (string= (ejn-notebook-language nb) "python"))
    ;; First cell
    (should (string= (ejn-cell-id (cl-first (ejn-notebook-cells nb)))
                     "a1b2c3d4-e5f6-7890-abcd-ef1234567890"))
    (should (string= (ejn-cell-source (cl-first (ejn-notebook-cells nb)))
                     "print(\"Hello from cell 1\")"))
    ;; Second cell
    (should (string= (ejn-cell-id (cl-second (ejn-notebook-cells nb)))
                     "b2c3d4e5-f6a7-8901-bcde-f12345678901"))
    (should (string= (ejn-cell-source (cl-second (ejn-notebook-cells nb)))
                     "print(\"Hello from cell 2\")"))))

(ert-deftest ejn-io-test-read-mixed-lang ()
  "Read mixed-lang.ipynb — verify markdown and code cells.

P2-T14: ejn-io-read against mixed-lang.ipynb fixture."
  (let ((nb (ejn-io-read (ejn-test--fixture-path "mixed-lang.ipynb"))))
    (should (= (length (ejn-notebook-cells nb)) 3))
    ;; First cell is markdown
    (should (eq (ejn-cell-type (cl-first (ejn-notebook-cells nb))) 'markdown))
    (should (string= (ejn-cell-language (cl-first (ejn-notebook-cells nb))) "markdown"))
    (should (string= (ejn-cell-source (cl-first (ejn-notebook-cells nb)))
                     "# This is a Markdown cell\n\n\n\nThis notebook has mixed languages."))
    ;; Second cell is code
    (should (eq (ejn-cell-type (cl-second (ejn-notebook-cells nb))) 'code))
    ;; Third cell is code
    (should (eq (ejn-cell-type (cl-third (ejn-notebook-cells nb))) 'code))))

(ert-deftest ejn-io-test-read-with-outputs ()
  "Read with-outputs.ipynb — verify outputs are parsed correctly.

P2-T14: ejn-io-read against with-outputs.ipynb fixture."
  (let ((nb (ejn-io-read (ejn-test--fixture-path "with-outputs.ipynb"))))
    (should (= (length (ejn-notebook-cells nb)) 2))
    (let ((cell (cl-first (ejn-notebook-cells nb))))
      ;; Execution count
      (should (= (ejn-cell-execution-count cell) 1))
      ;; One output
      (should (= (length (ejn-cell-outputs cell)) 1))
      (let ((output (cl-first (ejn-cell-outputs cell))))
        (should (eq (ejn-output-output-type output) 'execute_result))
        (should (string= (ejn-cell-source cell) "print('hello')"))))))

;;;; P2-T15: Round-trip test

(ert-deftest ejn-io-test-round-trip ()
  "Read fixture, write to temp, re-read, compare cell UUIDs and source text.

P2-T15: Round-trip invariant for ejn-io-read and ejn-io-write."
  (ejn-test--with-temp-notebook
   (let* ((original (ejn-io-read (ejn-test--fixture-path "simple.ipynb")))
          (write-result (ejn-io-write original temp-notebook-path)))
     ;; After write, dirty-p should be nil
     (should-not (ejn-notebook-dirty-p write-result))
     ;; Re-read the written file
     (let* ((re-read (ejn-io-read temp-notebook-path))
            (orig-cells (ejn-notebook-cells original))
            (re-read-cells (ejn-notebook-cells re-read)))
       (should (= (length orig-cells) (length re-read-cells)))
       (cl-loop for i from 0 below (length orig-cells)
                do (should (string= (ejn-cell-id (nth i orig-cells))
                                    (ejn-cell-id (nth i re-read-cells))))
                   (should (string= (ejn-cell-source (nth i orig-cells))
                                    (ejn-cell-source (nth i re-read-cells)))))))))

;;;; P2-T16: Error tests

(ert-deftest ejn-io-test-read-bad-nbformat ()
  "ejn-io-read errors on nbformat != 4.

P2-T16: Error handling — unsupported nbformat."
  (let ((tmp-file (make-temp-file "ejn-test-nbformat-" nil ".ipynb")))
    (unwind-protect
        (progn
          (with-temp-file tmp-file
            (insert "{\"nbformat\": 3, \"nbformat_minor\": 0, \"cells\": [], \"metadata\": {}}"))
          (should-error (ejn-io-read tmp-file) :type 'error))
      (when (file-exists-p tmp-file)
        (delete-file tmp-file)))))

(ert-deftest ejn-io-test-read-missing-file ()
  "ejn-io-read errors on missing file.

P2-T16: Error handling — file not found."
  (should-error (ejn-io-read "/nonexistent/path/notebook.ipynb")
                :type 'error))

(ert-deftest ejn-io-test-read-invalid-json ()
  "ejn-io-read errors on invalid JSON content.

P2-T16: Error handling — invalid JSON."
  (let ((tmp-file (make-temp-file "ejn-test-json-" nil ".ipynb")))
    (unwind-protect
        (progn
          (with-temp-file tmp-file
            (insert "this is not json {"))
          (should-error (ejn-io-read tmp-file) :type 'error))
      (delete-file tmp-file))))

(ert-deftest ejn-io-test-read-missing-cell-id ()
  "ejn-io--parse-cell errors when cell has no 'id' field.

P2-T16: Error handling — missing cell id."
  (should-error (ejn-io--parse-cell (make-hash-table))
                :type 'error))

(provide 'ejn-io-test)
;;; ejn-io-test.el ends here
