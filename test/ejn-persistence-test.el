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

(ert-deftest ejn-persistence-test/serialize-outputs-source-as-array ()
  "Serialization should output source as an array of strings."
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
                  (let ((source (cdr (assq :source cell))))
                  (should (listp source))
                  (should (= (length source) 2))
                  (should (string= (nth 0 source) "print(1)"))
                  (should (string= (nth 1 source) "print(2)")))))))
	  (delete-file tmpfile)))))

(ert-deftest ejn-persistence-test/roundtrip-sample-notebook ()
  "Loading and saving a notebook should preserve all data."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((original (ejn-ipynb-parse-notebook
                   (f-join ejn-test-fixtures-directory "sample.ipynb")))
        (tmpfile (make-temp-file "ejn-test" nil ".ipynb")))
    (unwind-protect
        (progn
          (ejn-ipynb-serialize-notebook original tmpfile)
          (let ((reloaded (ejn-ipynb-parse-notebook tmpfile)))
            (should (= (length (ejn-notebook-cells original))
                       (length (ejn-notebook-cells reloaded))))
            (dotimes (i (length (ejn-notebook-cells original)))
              (let ((orig-cell (ejn-notebook-cell-at-index original i))
                    (reload-cell (ejn-notebook-cell-at-index reloaded i)))
                (should (string= (ejn-cell-id orig-cell)
                                 (ejn-cell-id reload-cell)))
                (should (eq (ejn-cell-type orig-cell)
                            (ejn-cell-type reload-cell)))
                (should (string= (ejn-cell-source orig-cell)
                                 (ejn-cell-source reload-cell))))))
	  (delete-file tmpfile)))))

(ert-deftest ejn-persistence-test/roundtrip-with-modification ()
  "Saving a modified notebook and reloading should preserve changes."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "sample.ipynb")))
        (tmpfile (make-temp-file "ejn-test" nil ".ipynb")))
    (unwind-protect
        (progn
          (ejn-notebook-insert-cell nb 'markdown :at 0)
          (ejn-ipynb-serialize-notebook nb tmpfile)
          (let ((reloaded (ejn-ipynb-parse-notebook tmpfile)))
            (should (= (length (ejn-notebook-cells reloaded)) 4))
            (should (eq (ejn-cell-type (ejn-notebook-cell-at-index reloaded 0))
                        'markdown)))
	  (delete-file tmpfile)))))

(ert-deftest ejn-persistence-test/model-from-file-dispatches ()
  "`ejn-model-from-file' should dispatch to the correct backend."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-model-from-file
             (f-join ejn-test-fixtures-directory "sample.ipynb"))))
    (should (ejn-notebook-p nb))
    (should (> (length (ejn-notebook-cells nb)) 0))))

(ert-deftest ejn-persistence-test/model-to-file-dispatches ()
  "`ejn-model-to-file' should dispatch to the correct backend."
  (require 'ejn-persistence)
  (let ((nb (ejn-make-notebook))
        (tmpfile (make-temp-file "ejn-test" nil ".ipynb")))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (unwind-protect
        (progn
          (ejn-model-to-file nb tmpfile)
          (should (file-exists-p tmpfile)))
      (delete-file tmpfile))))

(ert-deftest ejn-persistence-test/unsupported-format-signals-error ()
  "Notebooks with unsupported nbformat should signal ejn-unsupported-format."
  (require 'ejn-persistence)
  (with-temp-buffer
    (insert (json-encode '(:nbformat 5 :nbformat_minor 0 :cells [] :metadata nil)))
    (let ((tmpfile (make-temp-file "ejn-test" nil ".ipynb")))
      (write-region (point-min) (point-max) tmpfile nil 'nomessage)
      (unwind-protect
          (should-error (ejn-ipynb-parse-notebook tmpfile)
                        :type 'ejn-unsupported-format)
        (delete-file tmpfile)))))

(ert-deftest ejn-persistence-test/serialize-error-output-fields ()
  "Error outputs should serialize ename, evalue, traceback (not data)."
  (require 'ejn-persistence)
  (let ((output (make-ejn-output
                 :type 'error
                 :mime-data (list :ename "ValueError"
                                  :evalue "something went wrong"
                                  :traceback '["trace1" "trace2"])
                 :metadata nil
                 :request-id nil)))
    (let ((result (ejn-ipynb-serialize-output output)))
      (should (string= (plist-get result :output_type) "error"))
      (should (string= (plist-get result :ename) "ValueError"))
      (should (string= (plist-get result :evalue) "something went wrong"))
      (should (equal (plist-get result :traceback)
                     '["trace1" "trace2"]))
      (should-not (plist-get result :data)))))

(ert-deftest ejn-persistence-test/serialize-stream-output-fields ()
  "Stream outputs should serialize name and text (not data)."
  (require 'ejn-persistence)
  (let ((output (make-ejn-output
                 :type 'stream
                 :mime-data (list :name "stdout"
                                  :text "hello\n")
                 :metadata nil
                 :request-id nil)))
    (let ((result (ejn-ipynb-serialize-output output)))
      (should (string= (plist-get result :output_type) "stream"))
      (should (string= (plist-get result :name) "stdout"))
      (should (string= (plist-get result :text) "hello\n"))
      (should-not (plist-get result :data)))))

(ert-deftest ejn-persistence-test/serialize-display-data-uses-data ()
  "Display-data outputs should continue to use :data."
  (require 'ejn-persistence)
  (let ((output (make-ejn-output
                 :type 'display-data
                 :mime-data (list :text/plain "42" :text/html "<b>42</b>")
                 :metadata (list :custom "value")
                 :request-id nil)))
    (let ((result (ejn-ipynb-serialize-output output)))
      (should (string= (plist-get result :output_type) "display_data"))
      (should (plist-get result :data))
      (should (equal (plist-get result :data)
                     (list :text/plain "42" :text/html "<b>42</b>"))))))

(ert-deftest ejn-persistence-test/error-output-roundtrip ()
  "Error outputs should round-trip preserving ename, evalue, traceback."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "with-outputs.ipynb")))
        (tmpfile (make-temp-file "ejn-test" nil ".ipynb")))
    (unwind-protect
        (progn
          (ejn-ipynb-serialize-notebook nb tmpfile)
          (let ((reloaded (ejn-ipynb-parse-notebook tmpfile)))
            (let ((error-cell (ejn-notebook-cell-at-index reloaded 2)))
              (let ((error-output (car (ejn-cell-outputs error-cell))))
                (let ((mime-data (ejn-output-mime-data error-output)))
                  (should (eq (ejn-output-type error-output) 'error))
                  (should (string= (plist-get mime-data :ename) "ValueError"))
                  (should (string= (plist-get mime-data :evalue)
                                   "something went wrong")))))))
      (delete-file tmpfile))))

(ert-deftest ejn-persistence-test/stream-output-roundtrip ()
  "Stream outputs should round-trip preserving name and text."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "with-outputs.ipynb")))
        (tmpfile (make-temp-file "ejn-test" nil ".ipynb")))
    (unwind-protect
        (progn
          (ejn-ipynb-serialize-notebook nb tmpfile)
          (let ((reloaded (ejn-ipynb-parse-notebook tmpfile)))
            (let ((stream-cell (ejn-notebook-cell-at-index reloaded 0)))
              (let ((stream-output (car (ejn-cell-outputs stream-cell))))
                (let ((mime-data (ejn-output-mime-data stream-output)))
                  (should (eq (ejn-output-type stream-output) 'stream))
                  (should (string= (plist-get mime-data :name) "stdout")))))))
      (delete-file tmpfile))))

(ert-deftest ejn-persistence-test/execute-result-output-roundtrip ()
  "Execute_result outputs should round-trip preserving mime-data."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook
             (f-join ejn-test-fixtures-directory "with-outputs.ipynb")))
        (tmpfile (make-temp-file "ejn-test" nil ".ipynb")))
    (unwind-protect
        (progn
          (ejn-ipynb-serialize-notebook nb tmpfile)
          (let ((reloaded (ejn-ipynb-parse-notebook tmpfile)))
            (let ((cell (ejn-notebook-cell-at-index reloaded 1)))
              (let ((output (car (ejn-cell-outputs cell))))
                (should (eq (ejn-output-type output) 'execute-result))
                (let ((mime-data (ejn-output-mime-data output)))
                  (let ((inner (plist-get mime-data :data)))
                    (should inner)
                    (should (equal (alist-get 'text/plain inner) '("42")))
                    (should (equal (alist-get 'text/html inner) '("<b>42</b>")))))))))
      (delete-file tmpfile))))

(ert-deftest ejn-persistence-test/roundtrip-preserves-blank-lines-in-source ()
  "Multi-line source with blank lines must survive parse → serialize → parse."
  (require 'ejn-persistence)
  (require 'ejn-test-util)
  (let ((nb (ejn-ipynb-parse-notebook (f-join ejn-test-fixtures-directory "sample.ipynb")))
        (temp-path (make-temp-file "ejn-test" nil ".ipynb")))
    (unwind-protect
        (progn
          (let ((cell (ejn-notebook-cell-at-index nb 0)))
            (ejn-notebook-set-cell-source nb (ejn-cell-id cell) "line1\n\nline3\n\n\nline6")
            (let ((serialized (ejn-ipynb-serialize-cell cell)))
              (should (equal (plist-get serialized :source)
                             '["line1" "" "line3" "" "" "line6"]))))
          (ejn-ipynb-serialize-notebook nb temp-path)
          (let ((nb2 (ejn-ipynb-parse-notebook temp-path)))
            (let ((cell2 (ejn-notebook-cell-at-index nb2 0)))
              (should (string= (ejn-cell-source cell2) "line1\n\nline3\n\n\nline6")))))
      (delete-file temp-path))))

(provide 'ejn-persistence-test)
;;; ejn-persistence-test.el ends here
