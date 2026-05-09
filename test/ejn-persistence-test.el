;;; ejn-persistence-test.el --- Tests for ejn-persistence  -*- lexical-binding: t; -*-

(require 'ert)

;;; Code:

(ert-deftest ejn-persistence-test/ipynb-backend-registered ()
  "The .ipynb backend should be auto-registered."
  (require 'ejn-persistence)
  (should (ejn-persistence-backend-for "test.ipynb")))

(ert-deftest ejn-persistence-test/non-ipynb-returns-nil ()
  "Non-.ipynb files should return nil."
  (require 'ejn-persistence)
  (should-not (ejn-persistence-backend-for "test.py")))

(ert-deftest ejn-persistence-test/can-handle-p-works ()
  "Backend can-handle-p should return correct values."
  (require 'ejn-persistence)
  (let ((backend (ejn-persistence-backend-for "test.ipynb")))
    (should (ejn-persistence-can-handle-p backend "foo.ipynb"))
    (should-not (ejn-persistence-can-handle-p backend "foo.py"))))

(ert-deftest ejn-persistence-test/parse-sample-notebook ()
  "Parsing sample.ipynb should produce a valid notebook."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "sample.ipynb"))))
    (should (ejn-notebook-p nb))
    (should (= (length (ejn-notebook-cells nb)) 3))
    (should (= (ejn-notebook-nbformat nb) 4))
    (should (= (ejn-notebook-nbformat-minor nb) 5))))

(ert-deftest ejn-persistence-test/parse-empty-notebook ()
  "Parsing an empty notebook should produce a valid empty notebook."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "empty.ipynb"))))
    (should (ejn-notebook-p nb))
    (should (= (length (ejn-notebook-cells nb)) 0))))

(ert-deftest ejn-persistence-test/parse-preserves-cell-ids ()
  "Parsing should preserve cell IDs from the notebook file."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "sample.ipynb"))))
    (let ((cell (ejn-notebook-cell-at-index nb 0)))
      (should (string= (ejn-cell-id cell) "test-cell-1")))))

(ert-deftest ejn-persistence-test/parse-preserves-cell-types ()
  "Parsing should preserve cell types."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "sample.ipynb"))))
    (should (eq (ejn-cell-type (ejn-notebook-cell-at-index nb 0)) 'code))
    (should (eq (ejn-cell-type (ejn-notebook-cell-at-index nb 1)) 'markdown))
    (should (eq (ejn-cell-type (ejn-notebook-cell-at-index nb 2)) 'code))))

(ert-deftest ejn-persistence-test/parse-normalizes-source-to-string ()
  "Parsing should normalize source arrays to strings."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "sample.ipynb"))))
    (let ((cell (ejn-notebook-cell-at-index nb 0)))
      (should (stringp (ejn-cell-source cell)))
      (should (string= (ejn-cell-source cell) "print(\"hello\")")))))

(ert-deftest ejn-persistence-test/parse-preserves-outputs ()
  "Parsing should preserve cell outputs."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "sample.ipynb"))))
    (let ((cell (ejn-notebook-cell-at-index nb 2)))
      (should (> (length (ejn-cell-outputs cell)) 0))
      (should (eq (ejn-output-type (car (ejn-cell-outputs cell)))
                  'execute-result)))))

(ert-deftest ejn-persistence-test/parse-preserves-metadata ()
  "Parsing should preserve notebook-level metadata."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "sample.ipynb"))))
    (should (assq :kernelspec (ejn-notebook-metadata nb)))))

(ert-deftest ejn-persistence-test/parse-preserves-unknown-metadata ()
  "Parsing should preserve unknown metadata keys."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "unknown-metadata.ipynb"))))
    (should (assq :custom-notebook-property (ejn-notebook-metadata nb)))))

(ert-deftest ejn-persistence-test/parse-with-outputs-fixture ()
  "Parsing with-outputs.ipynb should produce correct output types."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "with-outputs.ipynb"))))
    (should (= (length (ejn-notebook-cells nb)) 4))
    (should (eq (ejn-output-type (car (ejn-cell-outputs (ejn-notebook-cell-at-index nb 0))))
                'stream))
    (should (eq (ejn-output-type (car (ejn-cell-outputs (ejn-notebook-cell-at-index nb 1))))
                'execute-result))
    (should (eq (ejn-output-type (car (ejn-cell-outputs (ejn-notebook-cell-at-index nb 2))))
                'error))
    (should (eq (ejn-output-type (car (ejn-cell-outputs (ejn-notebook-cell-at-index nb 3))))
                'display-data))))

(ert-deftest ejn-persistence-test/parse-invalid-json-signals-error ()
  "Parsing invalid JSON should signal ejn-invalid-notebook."
  (require 'ejn-persistence)
  (with-temp-buffer
    (insert "{ invalid json }")
    (let ((tmpfile (make-temp-file "ejn-test" nil ".ipynb")))
      (write-region (point-min) (point-max) tmpfile nil 'nomessage)
      (unwind-protect
          (should-error (ejn-ipynb-parse-notebook tmpfile)
                        :type 'ejn-invalid-notebook)
        (delete-file tmpfile)))))

(ert-deftest ejn-persistence-test/serialize-produces-valid-json ()
  "Serializing a notebook should produce valid JSON."
  (require 'ejn-persistence)
  (let ((nb (ejn-make-notebook))
        (tmpfile (make-temp-file "ejn-test" nil ".ipynb")))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (unwind-protect
        (progn
          (ejn-ipynb-serialize-notebook nb tmpfile)
          (with-temp-buffer
            (insert-file-contents tmpfile)
            (let ((json-object-type 'alist)
                  (json-array-type 'list)
                  (json-key-type 'keyword))
              (should (json-read-object)))))
      (delete-file tmpfile))))

(ert-deftest ejn-persistence-test/serialize-preserved-cell-ids ()
  "Serialization should preserve cell IDs."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "sample.ipynb")))
        (tmpfile (make-temp-file "ejn-test" nil ".ipynb")))
    (unwind-protect
        (progn
          (ejn-ipynb-serialize-notebook nb tmpfile)
          (with-temp-buffer
            (insert-file-contents tmpfile)
            (let ((json-object-type 'alist)
                  (json-array-type 'list)
                  (json-key-type 'keyword))
              (let ((data (json-read-object)))
                (let ((cells (cdr (assq :cells data))))
                  (should (string= (cdr (assq :id (car cells)))
                                   "test-cell-1"))))))
      (delete-file tmpfile)))))

(ert-deftest ejn-persistence-test/serialize-outputs-source-as-string ()
  "Serialization should output source as a string."
  (require 'ejn-persistence)
  (let ((nb (ejn-make-notebook))
        (tmpfile (make-temp-file "ejn-test" nil ".ipynb")))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb
                                  (ejn-cell-id (ejn-notebook-cell-at-index nb 0))
                                  "print(1)\nprint(2)")
    (unwind-protect
        (progn
          (ejn-ipynb-serialize-notebook nb tmpfile)
          (with-temp-buffer
            (insert-file-contents tmpfile)
            (let ((json-object-type 'alist)
                  (json-array-type 'list)
                  (json-key-type 'keyword))
              (let ((data (json-read-object)))
                (let ((cell (car (cdr (assq :cells data)))))
                  (should (stringp (cdr (assq :source cell))))))))
      (delete-file tmpfile)))))

(provide 'ejn-persistence-test)
;;; ejn-persistence-test.el ends here
