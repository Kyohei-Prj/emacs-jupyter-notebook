;;; ejn-core-tests.el --- ERT tests for ejn-core (P2-T1)  -*- lexical-binding: t; -*-

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

;; Tests for P2-T1: EIEIO data model classes.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'eieio)

;; Ensure lisp/ is on the load-path
(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))

(require 'ejn-core)

;;; Tests — P2-T1: EIEIO classes exist and are valid

(ert-deftest ejn-core-p2-t1--ejn-notebook-is-class ()
  "Verify `ejn-notebook' is a defined EIEIO class."
  (should (fboundp 'ejn-notebook)))

(ert-deftest ejn-core-p2-t1--ejn-cell-is-class ()
  "Verify `ejn-cell' is a defined EIEIO class."
  (should (fboundp 'ejn-cell)))

;;; Tests — P2-T1: ejn-notebook slots

(ert-deftest ejn-core-p2-t1--ejn-notebook-has-slot-path ()
  "Verify `ejn-notebook' has a `path' slot of type string."
  (let ((nb (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (should (eieio-object-p nb))
    (should (equal (slot-value nb 'path) "/tmp/test.ipynb"))))

(ert-deftest ejn-core-p2-t1--ejn-notebook-has-slot-metadata-default-nil ()
  "Verify `ejn-notebook' has a `metadata' slot defaulting to nil."
  (let ((nb (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (should-not (slot-value nb 'metadata))))

(ert-deftest ejn-core-p2-t1--ejn-notebook-has-slot-cells-default-nil ()
  "Verify `ejn-notebook' has a `cells' slot defaulting to nil."
  (let ((nb (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (should-not (slot-value nb 'cells))))

(ert-deftest ejn-core-p2-t1--ejn-notebook-has-slot-kernel-id-default-nil ()
  "Verify `ejn-notebook' has a `kernel-id' slot defaulting to nil."
  (let ((nb (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (should-not (slot-value nb 'kernel-id))))

(ert-deftest ejn-core-p2-t1--ejn-notebook-has-slot-kill-ring-default-nil ()
  "Verify `ejn-notebook' has an `ejn-cell-kill-ring' slot defaulting to nil."
  (let ((nb (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (should-not (slot-value nb 'ejn-cell-kill-ring))))

(ert-deftest ejn-core-p2-t1--ejn-notebook-has-slot-master-buffer-default-nil ()
  "Verify `ejn-notebook' has a `master-buffer' slot defaulting to nil."
  (let ((nb (make-instance 'ejn-notebook :path "/tmp/test.ipynb")))
    (should-not (slot-value nb 'master-buffer))))

;;; Tests — P2-T1: ejn-cell slots

(ert-deftest ejn-core-p2-t1--ejn-cell-has-slot-type ()
  "Verify `ejn-cell' has a `type' slot accepting a symbol."
  (let ((cell (make-instance 'ejn-cell :type 'code :source "")))
    (should (eieio-object-p cell))
    (should (equal (slot-value cell 'type) 'code))))

(ert-deftest ejn-core-p2-t1--ejn-cell-has-slot-source ()
  "Verify `ejn-cell' has a `source' slot accepting a string."
  (let ((cell (make-instance 'ejn-cell :type 'code :source "print(1)")))
    (should (equal (slot-value cell 'source) "print(1)"))))

(ert-deftest ejn-core-p2-t1--ejn-cell-has-slot-outputs-default-nil ()
  "Verify `ejn-cell' has an `outputs' slot defaulting to nil."
  (let ((cell (make-instance 'ejn-cell :type 'code :source "")))
    (should-not (slot-value cell 'outputs))))

(ert-deftest ejn-core-p2-t1--ejn-cell-has-slot-buffer-default-nil ()
  "Verify `ejn-cell' has a `buffer' slot defaulting to nil."
  (let ((cell (make-instance 'ejn-cell :type 'code :source "")))
    (should-not (slot-value cell 'buffer))))

(ert-deftest ejn-core-p2-t1--ejn-cell-has-slot-shadow-file-default-nil ()
  "Verify `ejn-cell' has a `shadow-file' slot defaulting to nil."
  (let ((cell (make-instance 'ejn-cell :type 'code :source "")))
    (should-not (slot-value cell 'shadow-file))))

(ert-deftest ejn-core-p2-t1--ejn-cell-has-slot-exec-count-default-nil ()
  "Verify `ejn-cell' has an `exec-count' slot defaulting to nil."
  (let ((cell (make-instance 'ejn-cell :type 'code :source "")))
    (should-not (slot-value cell 'exec-count))))

(ert-deftest ejn-core-p2-t1--ejn-cell-has-slot-dirty-default-nil ()
  "Verify `ejn-cell' has a `dirty' slot defaulting to nil."
  (let ((cell (make-instance 'ejn-cell :type 'code :source "")))
    (should-not (slot-value cell 'dirty))))

;;; Tests — P2-T1: Instantiation with valid initargs

(ert-deftest ejn-core-p2-t1--ejn-notebook-instantiate-with-path ()
  "Verify `ejn-notebook' can be instantiated with a :path initarg."
  (let ((nb (make-instance 'ejn-notebook
                           :path "/absolute/path/to/test.ipynb")))
    (should (equal (slot-value nb 'path)
                   "/absolute/path/to/test.ipynb"))
    (should (stringp (slot-value nb 'path)))))

(ert-deftest ejn-core-p2-t1--ejn-cell-instantiate-with-type-and-source ()
  "Verify `ejn-cell' can be instantiated with :type and :source initargs."
  (let ((cell (make-instance 'ejn-cell
                             :type 'markdown
                             :source "# Heading")))
    (should (equal (slot-value cell 'type) 'markdown))
    (should (equal (slot-value cell 'source) "# Heading"))))

;;; Tests — P2-T1: ejn-cell ID generation via cl-gensym

(ert-deftest ejn-core-p2-t1--ejn-cell-id-is-generated ()
  "Verify `ejn-cell' generates a non-nil `id' slot automatically."
  (let ((cell (make-instance 'ejn-cell :type 'code :source "")))
    (should (slot-value cell 'id))
    (should-not (string= "" (slot-value cell 'id)))))

(ert-deftest ejn-core-p2-t1--ejn-cell-id-is-unique-per-instance ()
  "Verify each `ejn-cell' gets a unique `id'."
  (let ((cell-a (make-instance 'ejn-cell :type 'code :source ""))
        (cell-b (make-instance 'ejn-cell :type 'code :source "")))
    (should-not (string= (slot-value cell-a 'id)
                         (slot-value cell-b 'id)))))

;;; Tests — P2-T2: ejn-notebook-load signals file-error for missing file

(ert-deftest ejn-core-p2-t2--load-signals-file-error-for-missing-file ()
  "Verify `ejn-notebook-load' signals `file-error' when file doesn't exist."
  (should-error
   (ejn-notebook-load "/nonexistent/path/to/notebook.ipynb")
   :type 'file-error))

;;; Tests — P2-T2: ejn-notebook-load signals json-error for invalid JSON

(ert-deftest ejn-core-p2-t2--load-signals-json-error-for-invalid-json ()
  "Verify `ejn-notebook-load' signals `json-error' for invalid JSON content."
  (let ((tmpfile (make-temp-file "ejn-test-" nil ".ipynb" "not valid json {{{")))
    (unwind-protect
        (should-error
         (ejn-notebook-load tmpfile)
         :type 'json-error)
      (delete-file tmpfile))))

;;; Tests — P2-T2: ejn-notebook-load signals json-error for unrecognized nbformat

(ert-deftest ejn-core-p2-t2--load-signals-json-error-for-unknown-nbformat ()
  "Verify `ejn-notebook-load' signals `json-error' for unrecognized nbformat."
  (let ((tmpfile (make-temp-file "ejn-test-" nil ".ipynb"
                                 "{\"nbformat\": 99, \"nbformat_minor\": 0}")))
    (unwind-protect
        (should-error
         (ejn-notebook-load tmpfile)
         :type 'json-error)
      (delete-file tmpfile))))

(ert-deftest ejn-core-p2-t2--load-signals-json-error-for-missing-nbformat ()
  "Verify `ejn-notebook-load' signals `json-error' when nbformat key is absent."
  (let ((tmpfile (make-temp-file "ejn-test-" nil ".ipynb" "{}")))
    (unwind-protect
        (should-error
         (ejn-notebook-load tmpfile)
         :type 'json-error)
      (delete-file tmpfile))))

;;; Tests — P2-T2: ejn-notebook-load sets :path slot

(ert-deftest ejn-core-p2-t2--load-sets-path-slot ()
  "Verify `ejn-notebook-load' sets the notebook's :path slot."
  (let ((tmpfile (make-temp-file "ejn-test-" nil ".ipynb"
                                 "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")))
    (unwind-protect
        (let ((nb (ejn-notebook-load tmpfile)))
          (should (equal (slot-value nb 'path) tmpfile)))
      (delete-file tmpfile))))

;;; Tests — P2-T2: ejn-notebook-load returns ejn-notebook for valid nbformat 4.x

(ert-deftest ejn-core-p2-t2--load-returns-ejn-notebook-for-nbformat-4 ()
  "Verify `ejn-notebook-load' returns an `ejn-notebook' for valid nbformat 4.x."
  (let ((tmpfile (make-temp-file "ejn-test-" nil ".ipynb"
                                 "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")))
    (unwind-protect
        (let ((nb (ejn-notebook-load tmpfile)))
          (should (eieio-object-p nb))
          (should (eql (class-of nb) 'ejn-notebook)))
      (delete-file tmpfile))))

;;; Tests — P2-T2: ejn-notebook-load populates :cells list

(ert-deftest ejn-core-p2-t2--load-populates-cells-list ()
  "Verify `ejn-notebook-load' parses cells into `ejn-cell' objects."
  (let ((tmpfile (make-temp-file "ejn-test-" nil ".ipynb"
                                  "{\"nbformat\": 4, \"cells\": [{\"cell_type\": \"code\", \"source\": \"print(1)\"}], \"metadata\": {}}")))
    (unwind-protect
        (let ((nb (ejn-notebook-load tmpfile)))
          (should (= (length (slot-value nb 'cells)) 1))
          (let ((cell (car (slot-value nb 'cells))))
            (should (eieio-object-p cell))
            (should (eql (class-of cell) 'ejn-cell))
            (should (equal (slot-value cell 'type) 'code))
            (should (equal (slot-value cell 'source) "print(1)"))))
      (delete-file tmpfile))))

;;; Tests — P2-T2: ejn-notebook-load handles multiple cell types

(ert-deftest ejn-core-p2-t2--load-handles-multiple-cell-types ()
  "Verify `ejn-notebook-load' parses multiple cell types correctly."
  (let ((tmpfile (make-temp-file "ejn-test-" nil ".ipynb"
                                  "{\"nbformat\": 4, \"cells\": [{\"cell_type\": \"code\", \"source\": \"x = 1\", \"execution_count\": 1}, {\"cell_type\": \"markdown\", \"source\": \"# Title\"}, {\"cell_type\": \"raw\", \"source\": \"raw content\"}], \"metadata\": {}}")))
    (unwind-protect
        (let ((nb (ejn-notebook-load tmpfile)))
          (should (= (length (slot-value nb 'cells)) 3))
          (let ((cells (slot-value nb 'cells)))
            (should (equal (slot-value (nth 0 cells) 'type) 'code))
            (should (equal (slot-value (nth 0 cells) 'exec-count) 1))
            (should (equal (slot-value (nth 1 cells) 'type) 'markdown))
            (should (equal (slot-value (nth 2 cells) 'type) 'raw))))
      (delete-file tmpfile))))

;;; Tests — P2-T3: ejn--parse-cell-data

(ert-deftest ejn-core-p2-t3--parse-cell-data-extracts-fields ()
  "Verify `ejn--parse-cell-data' extracts cell_type, source, outputs, execution_count from JSON."
  (let* ((cell-json (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "code" cell-json))
         (_ (puthash "source" "print(1)" cell-json))
         (_ (puthash "outputs" '(("output1" . "value1")) cell-json))
         (_ (puthash "execution_count" 5 cell-json))
         (cell (ejn--parse-cell-data cell-json)))
    (should (equal (slot-value cell 'type) 'code))
    (should (equal (slot-value cell 'source) "print(1)"))
    (should (equal (slot-value cell 'outputs) '(("output1" . "value1"))))
    (should (equal (slot-value cell 'exec-count) 5))))

(ert-deftest ejn-core-p2-t3--parse-cell-data-joins-source-list ()
  "Verify `ejn--parse-cell-data' joins source when it is a list of strings."
  (let* ((cell-json (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "code" cell-json))
         (_ (puthash "source" '("line1\n" "line2\n" "line3") cell-json))
         (_ (puthash "outputs" nil cell-json))
         (_ (puthash "execution_count" nil cell-json))
         (cell (ejn--parse-cell-data cell-json)))
    (should (equal (slot-value cell 'source) "line1\nline2\nline3"))))

(ert-deftest ejn-core-p2-t3--parse-cell-data-handles-plain-string-source ()
  "Verify `ejn--parse-cell-data' handles source as a plain string."
  (let* ((cell-json (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "markdown" cell-json))
         (_ (puthash "source" "# Heading\nThis is markdown." cell-json))
         (_ (puthash "outputs" nil cell-json))
         (_ (puthash "execution_count" nil cell-json))
         (cell (ejn--parse-cell-data cell-json)))
    (should (equal (slot-value cell 'source) "# Heading\nThis is markdown."))))

(ert-deftest ejn-core-p2-t3--parse-cell-data-creates-ejn-cell-instance ()
  "Verify `ejn--parse-cell-data' creates an `ejn-cell' instance with the correct type symbol."
  (let* ((cell-json (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "raw" cell-json))
         (_ (puthash "source" "raw content" cell-json))
         (_ (puthash "outputs" nil cell-json))
         (_ (puthash "execution_count" nil cell-json))
         (cell (ejn--parse-cell-data cell-json)))
    (should (eieio-object-p cell))
    (should (eql (class-of cell) 'ejn-cell))
    (should (equal (slot-value cell 'type) 'raw))))

;;; Tests — P2-T3: ejn--parse-cells-nbformat4

(ert-deftest ejn-core-p2-t3--parse-cells-nbformat4-parses-cells-array ()
  "Verify `ejn--parse-cells-nbformat4' reads the `cells' array from notebook JSON."
  (let* ((cell-json (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "code" cell-json))
         (_ (puthash "source" "x = 1" cell-json))
         (_ (puthash "outputs" nil cell-json))
         (_ (puthash "execution_count" nil cell-json))
         (notebook-json (make-hash-table :test 'equal))
         (_ (puthash "cells" (vector cell-json) notebook-json))
         (cells (ejn--parse-cells-nbformat4 notebook-json)))
    (should (= (length cells) 1))
    (should (equal (slot-value (car cells) 'type) 'code))
    (should (equal (slot-value (car cells) 'source) "x = 1"))))

(ert-deftest ejn-core-p2-t3--parse-cells-nbformat4-maps-each-cell-via-parse-cell-data ()
  "Verify `ejn--parse-cells-nbformat4' maps each JSON cell to `ejn-cell' via `ejn--parse-cell-data'."
  (let* ((cell-json-a (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "code" cell-json-a))
         (_ (puthash "source" "a" cell-json-a))
         (_ (puthash "outputs" nil cell-json-a))
         (_ (puthash "execution_count" 1 cell-json-a))
         (cell-json-b (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "markdown" cell-json-b))
         (_ (puthash "source" "b" cell-json-b))
         (_ (puthash "outputs" nil cell-json-b))
         (_ (puthash "execution_count" nil cell-json-b))
         (notebook-json (make-hash-table :test 'equal))
         (_ (puthash "cells" (vector cell-json-a cell-json-b) notebook-json))
         (cells (ejn--parse-cells-nbformat4 notebook-json)))
    (should (= (length cells) 2))
    (cl-loop for cell in cells
             always (eql (class-of cell) 'ejn-cell))))

(ert-deftest ejn-core-p2-t3--parse-cells-nbformat4-returns-correct-order ()
  "Verify `ejn--parse-cells-nbformat4' returns `ejn-cell' objects in the same order as the JSON array."
  (let* ((cell-jsons (cl-loop for i from 1 to 3
                               collect
                               (let ((j (make-hash-table :test 'equal)))
                                 (puthash "cell_type" "code" j)
                                 (puthash "source" (number-to-string i) j)
                                 (puthash "outputs" nil j)
                                 (puthash "execution_count" nil j)
                                 j)))
         (notebook-json (make-hash-table :test 'equal))
         (_ (puthash "cells" (vconcat cell-jsons) notebook-json))
         (cells (ejn--parse-cells-nbformat4 notebook-json)))
    (should (= (length cells) 3))
    (should (equal (slot-value (nth 0 cells) 'source) "1"))
    (should (equal (slot-value (nth 1 cells) 'source) "2"))
    (should (equal (slot-value (nth 2 cells) 'source) "3"))))

(ert-deftest ejn-core-p2-t3--parse-cells-nbformat4-handles-empty-cells ()
  "Verify `ejn--parse-cells-nbformat4' returns an empty list for an empty `cells' array."
  (let* ((notebook-json (make-hash-table :test 'equal))
         (_ (puthash "cells" (vector) notebook-json))
         (cells (ejn--parse-cells-nbformat4 notebook-json)))
    (should (equal cells '())))
  ;; Also test when cells key is absent
  (let* ((notebook-json (make-hash-table :test 'equal))
         (_ (puthash "metadata" (make-hash-table :test 'equal) notebook-json))
         (cells (ejn--parse-cells-nbformat4 notebook-json)))
    (should (equal cells '()))))

(ert-deftest ejn-core-p2-t3--parse-cells-nbformat4-handles-source-as-list ()
  "Verify `ejn--parse-cells-nbformat4' handles cells with source as a list of strings."
  (let* ((cell-json (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "code" cell-json))
         (_ (puthash "source" '("import os\n" "import sys\n") cell-json))
         (_ (puthash "outputs" nil cell-json))
         (_ (puthash "execution_count" 2 cell-json))
         (notebook-json (make-hash-table :test 'equal))
         (_ (puthash "cells" (vector cell-json) notebook-json))
         (cells (ejn--parse-cells-nbformat4 notebook-json))
         (cell (car cells)))
    (should (equal (slot-value cell 'source) "import os\nimport sys\n"))
    (should (equal (slot-value cell 'exec-count) 2))))

(ert-deftest ejn-core-p2-t3--parse-cells-nbformat4-handles-source-as-string ()
  "Verify `ejn--parse-cells-nbformat4' handles cells with source as a plain string."
  (let* ((cell-json (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "markdown" cell-json))
         (_ (puthash "source" "# Title" cell-json))
         (_ (puthash "outputs" nil cell-json))
         (_ (puthash "execution_count" nil cell-json))
         (notebook-json (make-hash-table :test 'equal))
         (_ (puthash "cells" (vector cell-json) notebook-json))
         (cells (ejn--parse-cells-nbformat4 notebook-json))
         (cell (car cells)))
    (should (equal (slot-value cell 'source) "# Title"))
    (should (equal (slot-value cell 'type) 'markdown))))

;;; Tests — P2-T4: ejn--parse-cells-nbformat3

(ert-deftest ejn-core-p2-t4--parse-cells-nbformat3-parses-worksheet-cells ()
  "Verify `ejn--parse-cells-nbformat3' reads cells from `notebook[\"worksheets\"][0][\"cells\"]`."
  (let* ((cell-json (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "code" cell-json))
         (_ (puthash "source" "x = 1" cell-json))
         (_ (puthash "outputs" nil cell-json))
         (_ (puthash "execution_count" nil cell-json))
         (worksheet (make-hash-table :test 'equal))
         (_ (puthash "cells" (vector cell-json) worksheet))
         (notebook-json (make-hash-table :test 'equal))
         (_ (puthash "worksheets" (vector worksheet) notebook-json))
         (cells (ejn--parse-cells-nbformat3 notebook-json)))
    (should (= (length cells) 1))
    (should (equal (slot-value (car cells) 'type) 'code))
    (should (equal (slot-value (car cells) 'source) "x = 1"))))

(ert-deftest ejn-core-p2-t4--parse-cells-nbformat3-returns-correct-order ()
  "Verify `ejn--parse-cells-nbformat3' returns `ejn-cell' objects in correct order."
  (let* ((cell-jsons (cl-loop for i from 1 to 3
                               collect
                               (let ((j (make-hash-table :test 'equal)))
                                 (puthash "cell_type" "code" j)
                                 (puthash "source" (number-to-string i) j)
                                 (puthash "outputs" nil j)
                                 (puthash "execution_count" nil j)
                                 j)))
         (worksheet (make-hash-table :test 'equal))
         (_ (puthash "cells" (vconcat cell-jsons) worksheet))
         (notebook-json (make-hash-table :test 'equal))
         (_ (puthash "worksheets" (vector worksheet) notebook-json))
         (cells (ejn--parse-cells-nbformat3 notebook-json)))
    (should (= (length cells) 3))
    (should (equal (slot-value (nth 0 cells) 'source) "1"))
    (should (equal (slot-value (nth 1 cells) 'source) "2"))
    (should (equal (slot-value (nth 2 cells) 'source) "3"))))

(ert-deftest ejn-core-p2-t4--parse-cells-nbformat3-handles-empty-worksheets ()
  "Verify `ejn--parse-cells-nbformat3' returns empty list for empty worksheets."
  ;; Empty worksheets array
  (let* ((notebook-json (make-hash-table :test 'equal))
         (_ (puthash "worksheets" (vector) notebook-json))
         (cells (ejn--parse-cells-nbformat3 notebook-json)))
    (should (equal cells '())))
  ;; Worksheet with empty cells
  (let* ((worksheet (make-hash-table :test 'equal))
         (_ (puthash "cells" (vector) worksheet))
         (notebook-json (make-hash-table :test 'equal))
         (_ (puthash "worksheets" (vector worksheet) notebook-json))
         (cells (ejn--parse-cells-nbformat3 notebook-json)))
    (should (equal cells '()))))

(ert-deftest ejn-core-p2-t4--parse-cells-nbformat3-handles-multiple-cell-types ()
  "Verify `ejn--parse-cells-nbformat3' handles multiple cells with different types."
  (let* ((cell-code (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "code" cell-code))
         (_ (puthash "source" "print(1)" cell-code))
         (_ (puthash "outputs" nil cell-code))
         (_ (puthash "execution_count" 1 cell-code))
         (cell-md (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "markdown" cell-md))
         (_ (puthash "source" "# Title" cell-md))
         (_ (puthash "outputs" nil cell-md))
         (_ (puthash "execution_count" nil cell-md))
         (cell-raw (make-hash-table :test 'equal))
         (_ (puthash "cell_type" "raw" cell-raw))
         (_ (puthash "source" "raw data" cell-raw))
         (_ (puthash "outputs" nil cell-raw))
         (_ (puthash "execution_count" nil cell-raw))
         (worksheet (make-hash-table :test 'equal))
         (_ (puthash "cells" (vector cell-code cell-md cell-raw) worksheet))
         (notebook-json (make-hash-table :test 'equal))
         (_ (puthash "worksheets" (vector worksheet) notebook-json))
         (cells (ejn--parse-cells-nbformat3 notebook-json)))
    (should (= (length cells) 3))
    (should (equal (slot-value (nth 0 cells) 'type) 'code))
    (should (equal (slot-value (nth 1 cells) 'type) 'markdown))
    (should (equal (slot-value (nth 2 cells) 'type) 'raw))))

(ert-deftest ejn-core-p2-t4--load-nbformat3-returns-notebook ()
  "Verify `ejn-notebook-load' successfully loads an nbformat 3 notebook."
  (let ((tmpfile (make-temp-file "ejn-test-nb3-" nil ".ipynb"
                                  "{\"nbformat\": 3, \"worksheets\": [{\"cells\": [{\"cell_type\": \"code\", \"source\": \"print(1)\", \"outputs\": [], \"execution_count\": 1}, {\"cell_type\": \"markdown\", \"source\": \"# Heading\", \"outputs\": []}]}], \"metadata\": {}}")))
    (unwind-protect
        (let ((nb (ejn-notebook-load tmpfile)))
          (should (eieio-object-p nb))
          (should (eql (class-of nb) 'ejn-notebook))
          (should (= (length (slot-value nb 'cells)) 2))
          (should (equal (slot-value (nth 0 (slot-value nb 'cells)) 'type) 'code))
          (should (equal (slot-value (nth 0 (slot-value nb 'cells)) 'source) "print(1)"))
          (should (equal (slot-value (nth 1 (slot-value nb 'cells)) 'type) 'markdown))
          (should (equal (slot-value (nth 1 (slot-value nb 'cells)) 'source) "# Heading")))
      (delete-file tmpfile))))

;;; Tests — P2-T6: ejn-shadow-write-cell

(ert-deftest ejn-core-p2-t6--creates-cache-directory ()
  "Verify `ejn-shadow-write-cell' creates `.ejn-cache/<stem>/' if missing."
  (let* ((tmpdir (make-temp-file "ejn-test-nb-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (cachedir (expand-file-name ".ejn-cache/mynotebook" tmpdir)))
    ;; Create a minimal notebook file so :path is valid
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    (let* ((nb (make-instance 'ejn-notebook :path nbpath))
           (cell (make-instance 'ejn-cell
                                :type 'code
                                :source "x = 1"))
           (_ (setf (slot-value nb 'cells) (list cell)))
           (_ (ejn-shadow-write-cell cell nb)))
      (should (file-directory-p cachedir)))
    ;; Cleanup
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t6--writes-source-to-shadow-file ()
  "Verify `ejn-shadow-write-cell' writes cell `:source' to the shadow file."
  (let* ((tmpdir (make-temp-file "ejn-test-nb-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (cachedir (expand-file-name ".ejn-cache/mynotebook" tmpdir))
         (shadow (expand-file-name "cell_000.py" cachedir)))
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    (let* ((nb (make-instance 'ejn-notebook :path nbpath))
           (cell (make-instance 'ejn-cell
                                :type 'code
                                :source "print('hello')"))
           (_ (setf (slot-value nb 'cells) (list cell)))
           (_ (ejn-shadow-write-cell cell nb)))
      (should (file-exists-p shadow))
      (with-temp-buffer
        (insert-file-contents shadow)
        (should (string= (buffer-substring-no-properties (point-min) (point-max))
                         "print('hello')"))))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t6--uses-correct-extension-for-code ()
  "Verify code cells get `.py' extension."
  (let* ((tmpdir (make-temp-file "ejn-test-nb-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (cachedir (expand-file-name ".ejn-cache/mynotebook" tmpdir))
         (shadow (expand-file-name "cell_000.py" cachedir)))
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    (let* ((nb (make-instance 'ejn-notebook :path nbpath))
           (cell (make-instance 'ejn-cell :type 'code :source "pass"))
           (_ (setf (slot-value nb 'cells) (list cell)))
           (_ (ejn-shadow-write-cell cell nb)))
      (should (file-exists-p shadow)))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t6--uses-correct-extension-for-markdown ()
  "Verify markdown cells get `.md' extension."
  (let* ((tmpdir (make-temp-file "ejn-test-nb-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (cachedir (expand-file-name ".ejn-cache/mynotebook" tmpdir))
         (shadow (expand-file-name "cell_000.md" cachedir)))
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    (let* ((nb (make-instance 'ejn-notebook :path nbpath))
           (cell (make-instance 'ejn-cell :type 'markdown :source "# Heading"))
           (_ (setf (slot-value nb 'cells) (list cell)))
           (_ (ejn-shadow-write-cell cell nb)))
      (should (file-exists-p shadow)))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t6--uses-correct-extension-for-raw ()
  "Verify raw cells get `.raw' extension."
  (let* ((tmpdir (make-temp-file "ejn-test-nb-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (cachedir (expand-file-name ".ejn-cache/mynotebook" tmpdir))
         (shadow (expand-file-name "cell_000.raw" cachedir)))
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    (let* ((nb (make-instance 'ejn-notebook :path nbpath))
           (cell (make-instance 'ejn-cell :type 'raw :source "raw content"))
           (_ (setf (slot-value nb 'cells) (list cell)))
           (_ (ejn-shadow-write-cell cell nb)))
      (should (file-exists-p shadow)))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t6--zero-pads-cell-index ()
  "Verify shadow filenames use 3-digit zero-padded indices."
  (let* ((tmpdir (make-temp-file "ejn-test-nb-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (cachedir (expand-file-name ".ejn-cache/mynotebook" tmpdir))
         (cell0 (make-instance 'ejn-cell :type 'code :source "a"))
         (cell1 (make-instance 'ejn-cell :type 'code :source "b"))
         (cell2 (make-instance 'ejn-cell :type 'code :source "c"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell0 cell1 cell2))))
    ;; Create notebook file
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    ;; Write each cell
    (ejn-shadow-write-cell cell0 nb)
    (ejn-shadow-write-cell cell1 nb)
    (ejn-shadow-write-cell cell2 nb)
    ;; Verify filenames
    (should (file-exists-p (expand-file-name "cell_000.py" cachedir)))
    (should (file-exists-p (expand-file-name "cell_001.py" cachedir)))
    (should (file-exists-p (expand-file-name "cell_002.py" cachedir)))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t6--returns-absolute-path ()
  "Verify `ejn-shadow-write-cell' returns an absolute path string."
  (let* ((tmpdir (make-temp-file "ejn-test-nb-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (cell (make-instance 'ejn-cell :type 'code :source "pass"))
         (_ (setf (slot-value nb 'cells) (list cell))))
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    (let ((result (ejn-shadow-write-cell cell nb)))
      (should (stringp result))
      (should (file-name-absolute-p result))
      (should (file-exists-p result)))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t6--updates-shadow-file-slot ()
  "Verify `ejn-shadow-write-cell' updates the cell's `:shadow-file' slot."
  (let* ((tmpdir (make-temp-file "ejn-test-nb-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (cell (make-instance 'ejn-cell :type 'code :source "pass"))
         (_ (setf (slot-value nb 'cells) (list cell))))
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    (should-not (slot-value cell 'shadow-file))
    (ejn-shadow-write-cell cell nb)
    (should (slot-value cell 'shadow-file))
    (should (stringp (slot-value cell 'shadow-file)))
    (should (file-name-absolute-p (slot-value cell 'shadow-file)))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t6--file-content-matches-source ()
  "Verify the shadow file content exactly matches the cell `:source'."
  (let* ((tmpdir (make-temp-file "ejn-test-nb-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (cachedir (expand-file-name ".ejn-cache/mynotebook" tmpdir))
         (shadow (expand-file-name "cell_000.py" cachedir))
         (source "line one\nline two\nline three"))
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    (let* ((nb (make-instance 'ejn-notebook :path nbpath))
           (cell (make-instance 'ejn-cell :type 'code :source source))
           (_ (setf (slot-value nb 'cells) (list cell)))
           (_ (ejn-shadow-write-cell cell nb)))
      (with-temp-buffer
        (insert-file-contents shadow)
        (should (string= (buffer-substring-no-properties (point-min) (point-max))
                         source))))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

;;; Tests — P2-T7: ejn-cell-dirty-p

(ert-deftest ejn-core-p2-t7--dirty-p-returns-nil-by-default ()
  "Verify `ejn-cell-dirty-p' returns nil when :dirty is not set."
  (let ((cell (make-instance 'ejn-cell :type 'code :source "")))
    (should-not (ejn-cell-dirty-p cell))))

(ert-deftest ejn-core-p2-t7--dirty-p-returns-t-when-dirty ()
  "Verify `ejn-cell-dirty-p' returns t when :dirty slot is set to t."
  (let ((cell (make-instance 'ejn-cell :type 'code :source ""
                              :dirty t)))
    (should (ejn-cell-dirty-p cell))))

(ert-deftest ejn-core-p2-t7--dirty-p-reflects-slot-value ()
  "Verify `ejn-cell-dirty-p' reflects current :dirty slot value after oset."
  (let ((cell (make-instance 'ejn-cell :type 'code :source "")))
    (should-not (ejn-cell-dirty-p cell))
    (oset cell dirty t)
    (should (ejn-cell-dirty-p cell))
    (oset cell dirty nil)
    (should-not (ejn-cell-dirty-p cell))))

;;; Tests — P2-T7: ejn-shadow-sync-cell

(ert-deftest ejn-core-p2-t7--sync-returns-nil-when-buffer-matches-source ()
  "Verify `ejn-shadow-sync-cell' returns nil when buffer content matches :source."
  (let* ((tmpdir (make-temp-file "ejn-test-sync-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"
                              :dirty t))
         (buf (with-temp-buffer
                (insert "x = 1")
                (current-buffer)))
         (_ (oset cell buffer buf))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (_ (setf (slot-value nb 'cells) (list cell)))
         (_ (ejn-shadow-write-cell cell nb)))
    (with-temp-buffer
      (insert "x = 1")
      (let ((synced-buf (current-buffer)))
        (oset cell buffer synced-buf)
        (let ((result (ejn-shadow-sync-cell cell)))
          (should-not result))))
    ;; Cleanup
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t7--sync-returns-t-when-buffer-differs ()
  "Verify `ejn-shadow-sync-cell' returns t when buffer content differs from :source."
  (let* ((tmpdir (make-temp-file "ejn-test-sync-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "x = 1"
                              :dirty t))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (_ (setf (slot-value nb 'cells) (list cell)))
         (_ (ejn-shadow-write-cell cell nb)))
    (with-temp-buffer
      (insert "x = 2")
      (let ((synced-buf (current-buffer)))
        (oset cell buffer synced-buf)
        (let ((result (ejn-shadow-sync-cell cell)))
          (should result))))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t7--sync-updates-source-from-buffer ()
  "Verify `ejn-shadow-sync-cell' updates :source slot from buffer content."
  (let* ((tmpdir (make-temp-file "ejn-test-sync-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "old content"
                              :dirty t))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (_ (setf (slot-value nb 'cells) (list cell)))
         (_ (ejn-shadow-write-cell cell nb)))
    (with-temp-buffer
      (insert "new content from buffer")
      (oset cell buffer (current-buffer))
      (ejn-shadow-sync-cell cell)
      (should (equal (slot-value cell 'source) "new content from buffer")))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t7--sync-writes-atomically-via-tmp-rename ()
  "Verify `ejn-shadow-sync-cell' writes via .tmp then rename-file."
  (let* ((tmpdir (make-temp-file "ejn-test-sync-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cachedir (expand-file-name ".ejn-cache/test" tmpdir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "original"
                              :dirty t))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (_ (setf (slot-value nb 'cells) (list cell)))
         (shadow-path (ejn-shadow-write-cell cell nb))
         (tmp-path (concat shadow-path ".tmp")))
    ;; Verify .tmp file does not exist after sync (it was renamed away)
    (with-temp-buffer
      (insert "modified content")
      (oset cell buffer (current-buffer))
      (ejn-shadow-sync-cell cell))
    ;; .tmp should not exist after sync completes
    (should-not (file-exists-p tmp-path))
    ;; shadow file should contain updated content
    (with-temp-buffer
      (insert-file-contents shadow-path)
      (should (string= (buffer-substring-no-properties (point-min) (point-max))
                       "modified content")))
    ;; Cleanup
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t7--sync-clears-dirty-flag ()
  "Verify `ejn-shadow-sync-cell' clears the :dirty flag after syncing."
  (let* ((tmpdir (make-temp-file "ejn-test-sync-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "before"
                              :dirty t))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (_ (setf (slot-value nb 'cells) (list cell)))
         (_ (ejn-shadow-write-cell cell nb)))
    (should (ejn-cell-dirty-p cell))
    (with-temp-buffer
      (insert "after")
      (oset cell buffer (current-buffer))
      (ejn-shadow-sync-cell cell))
    (should-not (ejn-cell-dirty-p cell))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t7--sync-returns-nil-when-no-buffer ()
  "Verify `ejn-shadow-sync-cell' returns nil when cell has no :buffer."
  (let* ((tmpdir (make-temp-file "ejn-test-sync-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell (make-instance 'ejn-cell
                              :type 'code
                              :source "content"
                              :dirty t))
         (nb (make-instance 'ejn-notebook :path nbpath))
         (_ (setf (slot-value nb 'cells) (list cell)))
         (_ (ejn-shadow-write-cell cell nb)))
    ;; :buffer is nil (default)
    (should-not (slot-value cell 'buffer))
    (let ((result (ejn-shadow-sync-cell cell)))
      (should-not result))
    ;; dirty flag should remain unchanged
    (should (ejn-cell-dirty-p cell))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

;;; Tests — P2-T9: ejn--flush-all-dirty-cells

(ert-deftest ejn-core-p2-t9--flushes-dirty-cells-with-live-buffers ()
  "Verify `ejn--flush-all-dirty-cells' flushes dirty cells that have live buffers."
  (let* ((tmpdir (make-temp-file "ejn-test-flush-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "original_a"))
         (cell-b (make-instance 'ejn-cell
                                :type 'code
                                :source "original_b"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell-a cell-b))))
    (ejn-shadow-write-cell cell-a nb)
    (ejn-shadow-write-cell cell-b nb)
    (oset cell-a dirty t)
    (oset cell-b dirty t)
    (oset cell-a buffer (get-buffer-create "*ejn-test-cell-a*"))
    (oset cell-b buffer (get-buffer-create "*ejn-test-cell-b*"))
    (with-current-buffer "*ejn-test-cell-a*"
      (erase-buffer)
      (insert "modified_a"))
    (with-current-buffer "*ejn-test-cell-b*"
      (erase-buffer)
      (insert "modified_b"))
    (ejn--flush-all-dirty-cells nb)
    (should (equal (slot-value cell-a 'source) "modified_a"))
    (should (equal (slot-value cell-b 'source) "modified_b"))
    (kill-buffer "*ejn-test-cell-a*")
    (kill-buffer "*ejn-test-cell-b*")
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t9--skips-clean-cells ()
  "Verify `ejn--flush-all-dirty-cells' does not call `ejn-shadow-sync-cell' on clean cells."
  (let* ((tmpdir (make-temp-file "ejn-test-flush-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (sync-call-count 0)
         (cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "not_dirty"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell-a))))
    (oset cell-a dirty nil)
    (ejn-shadow-write-cell cell-a nb)
    (oset cell-a buffer (get-buffer-create "*ejn-test-clean*"))
    (with-current-buffer "*ejn-test-clean*"
      (erase-buffer)
      (insert "modified_in_buffer"))
    (cl-flet ((ejn-shadow-sync-cell (_cell)
                (cl-incf sync-call-count)
                nil))
      (ejn--flush-all-dirty-cells nb)
      (should (= sync-call-count 0))
      (should (equal (slot-value cell-a 'source) "not_dirty")))
    (kill-buffer "*ejn-test-clean*")
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t9--skips-cells-without-live-buffers ()
  "Verify `ejn--flush-all-dirty-cells' skips dirty cells whose buffer is not live."
  (let* ((tmpdir (make-temp-file "ejn-test-flush-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (sync-call-count 0)
         (cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "content"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell-a))))
    (oset cell-a dirty t)
    (oset cell-a buffer nil)
    (ejn-shadow-write-cell cell-a nb)
    (cl-flet ((ejn-shadow-sync-cell (_cell)
                (cl-incf sync-call-count)
                nil))
      (ejn--flush-all-dirty-cells nb)
      (should (= sync-call-count 0)))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t9--calls-sync-on-each-dirty-cell-with-live-buffer ()
  "Verify `ejn--flush-all-dirty-cells' only processes dirty cells with live buffers.

  cell-a: dirty + live buffer → should be synced (source changed, dirty cleared)
  cell-b: dirty + no buffer → should be skipped (source unchanged, dirty stays)
  cell-c: dirty + live buffer → should be synced (source changed, dirty cleared)"
  (let* ((tmpdir (make-temp-file "ejn-test-flush-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "orig_a"))
         (cell-b (make-instance 'ejn-cell
                                :type 'code
                                :source "orig_b"))
         (cell-c (make-instance 'ejn-cell
                                :type 'code
                                :source "orig_c"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell-a cell-b cell-c))))
    (ejn-shadow-write-cell cell-a nb)
    (ejn-shadow-write-cell cell-b nb)
    (ejn-shadow-write-cell cell-c nb)
    (oset cell-a dirty t)
    (oset cell-a buffer (get-buffer-create "*ejn-flush-a*"))
    (with-current-buffer "*ejn-flush-a*"
      (erase-buffer)
      (insert "mod_a"))
    (oset cell-b dirty t)
    (oset cell-b buffer nil)
    (oset cell-c dirty t)
    (oset cell-c buffer (get-buffer-create "*ejn-flush-c*"))
    (with-current-buffer "*ejn-flush-c*"
      (erase-buffer)
      (insert "mod_c"))
    (ejn--flush-all-dirty-cells nb)
    (should (equal (slot-value cell-a 'source) "mod_a"))
    (should-not (ejn-cell-dirty-p cell-a))
    (should (equal (slot-value cell-b 'source) "orig_b"))
    (should (ejn-cell-dirty-p cell-b))
    (should (equal (slot-value cell-c 'source) "mod_c"))
    (should-not (ejn-cell-dirty-p cell-c))
    (kill-buffer "*ejn-flush-a*")
    (kill-buffer "*ejn-flush-c*")
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t9--dirty-flags-cleared-after-flush ()
  "Verify `ejn--flush-all-dirty-cells' clears :dirty flags after flushing."
  (let* ((tmpdir (make-temp-file "ejn-test-flush-" t))
         (nbpath (expand-file-name "test.ipynb" tmpdir))
         (cell-a (make-instance 'ejn-cell
                                :type 'code
                                :source "original"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell-a))))
    (ejn-shadow-write-cell cell-a nb)
    (oset cell-a dirty t)
    (oset cell-a buffer (get-buffer-create "*ejn-flush-dirty*"))
    (with-current-buffer "*ejn-flush-dirty*"
      (erase-buffer)
      (insert "modified"))
    (ejn--flush-all-dirty-cells nb)
    (should-not (ejn-cell-dirty-p cell-a))
    (kill-buffer "*ejn-flush-dirty*")
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t9--handles-empty-notebook ()
  "Verify `ejn--flush-all-dirty-cells' does not error on an empty cells list."
  (let* ((tmpdir (make-temp-file "ejn-test-flush-" t))
          (nbpath (expand-file-name "test.ipynb" tmpdir))
          (nb (make-instance 'ejn-notebook :path nbpath)))
    (should-not (slot-value nb 'cells))
    (let ((result (ejn--flush-all-dirty-cells nb)))
      (should-not result))
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

;;; Tests — P2-T15: ejn-notebook-of-buffer

(ert-deftest ejn-core-p2-t15--returns-notebook-from-buffer-with-ejn-notebook-set ()
  "Verify `ejn-notebook-of-buffer' returns the notebook from a buffer that has `ejn--notebook' set."
  (let* ((nb (make-instance 'ejn-notebook
                            :path "/tmp/test.ipynb"
                            :cells nil))
         (buf (get-buffer-create "*ejn-smoke-test*")))
    (with-current-buffer buf
      (set (make-local-variable 'ejn--notebook) nb))
    (let ((result (ejn-notebook-of-buffer buf)))
      (should (eql result nb))
      (should (eql (class-of result) 'ejn-notebook)))
    (kill-buffer buf)))

(ert-deftest ejn-core-p2-t15--returns-nil-for-buffer-without-notebook ()
  "Verify `ejn-notebook-of-buffer' returns nil for a buffer without `ejn--notebook' set."
  (let ((buf (get-buffer-create "*ejn-smoke-test-nil*")))
    (let ((result (ejn-notebook-of-buffer buf)))
      (should-not result))
    (kill-buffer buf)))

;;; Tests — P2-T33: ejn--reindex-shadow-files

(ert-deftest ejn-core-p2-t33--reindex-updates-shadow-files-after-cell-removal ()
  "Verify reindex corrects shadow files after a cell is removed from the middle.

Setup: 3 cells → write shadow files (000, 001, 002) → remove cell at index 1
→ reindex → cell_000.py and cell_001.py exist with correct content,
cell_002.py is deleted."
  (let* ((tmpdir (make-temp-file "ejn-test-reindex-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (cachedir (expand-file-name ".ejn-cache/mynotebook" tmpdir))
         (cell-0 (make-instance 'ejn-cell :type 'code :source "source-0"))
         (cell-1 (make-instance 'ejn-cell :type 'code :source "source-1"))
         (cell-2 (make-instance 'ejn-cell :type 'code :source "source-2"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell-0 cell-1 cell-2))))
    ;; Create notebook file on disk
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    ;; Write initial shadow files for all 3 cells
    (ejn-shadow-write-cell cell-0 nb)
    (ejn-shadow-write-cell cell-1 nb)
    (ejn-shadow-write-cell cell-2 nb)
    ;; Remove cell-1 from :cells (simulating a kill)
    (oset nb cells (list cell-0 cell-2))
    ;; Now cell-2 is at index 1 but its shadow-file still points to cell_002.py
    ;; Reindex should fix this
    (ejn--reindex-shadow-files nb)
    ;; Verify cell_000.py exists with source-0
    (should (file-exists-p (expand-file-name "cell_000.py" cachedir)))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "cell_000.py" cachedir))
      (should (string= (buffer-substring-no-properties (point-min) (point-max))
                       "source-0")))
    ;; Verify cell_001.py exists with source-2 (cell-2 moved to index 1)
    (should (file-exists-p (expand-file-name "cell_001.py" cachedir)))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "cell_001.py" cachedir))
      (should (string= (buffer-substring-no-properties (point-min) (point-max))
                       "source-2")))
    ;; Verify orphaned cell_002.py was deleted
    (should-not (file-exists-p (expand-file-name "cell_002.py" cachedir)))
    ;; Verify cell-2's :shadow-file slot was updated
    (should (string= (file-name-nondirectory (slot-value cell-2 'shadow-file))
                     "cell_001.py"))
    ;; Cleanup
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t33--reindex-cleans-stale-shadow-files ()
  "Verify reindex deletes old shadow files when cell's :shadow-file slot is stale.

Setup: 2 cells with :shadow-file pointing to incorrect paths.
Reindex should delete the stale files and write correct ones."
  (let* ((tmpdir (make-temp-file "ejn-test-reindex-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (cachedir (expand-file-name ".ejn-cache/mynotebook" tmpdir))
         (stale-0 (expand-file-name "stale_cell_999.py" cachedir))
         (stale-1 (expand-file-name "stale_cell_888.py" cachedir))
         (cell-0 (make-instance 'ejn-cell :type 'code :source "source-0"))
         (cell-1 (make-instance 'ejn-cell :type 'code :source "source-1"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell-0 cell-1))))
    ;; Create notebook file on disk
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    ;; Create cache dir and stale shadow files
    (make-directory cachedir t)
    (with-temp-file stale-0
      (insert "old-stale-content-0"))
    (with-temp-file stale-1
      (insert "old-stale-content-1"))
    ;; Manually set shadow-file slots to stale paths
    (oset cell-0 shadow-file stale-0)
    (oset cell-1 shadow-file stale-1)
    ;; Reindex should delete stale files and create correct ones
    (ejn--reindex-shadow-files nb)
    ;; Stale files should be deleted
    (should-not (file-exists-p stale-0))
    (should-not (file-exists-p stale-1))
    ;; Correct files should exist
    (should (file-exists-p (expand-file-name "cell_000.py" cachedir)))
    (should (file-exists-p (expand-file-name "cell_001.py" cachedir)))
    ;; Verify content
    (with-temp-buffer
      (insert-file-contents (expand-file-name "cell_000.py" cachedir))
      (should (string= (buffer-substring-no-properties (point-min) (point-max))
                       "source-0")))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "cell_001.py" cachedir))
      (should (string= (buffer-substring-no-properties (point-min) (point-max))
                       "source-1")))
    ;; Cleanup
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t33--reindex-is-idempotent ()
  "Verify running reindex twice on correct state has no side effects.

Setup: 2 cells with correct shadow files. Run reindex twice.
Second run should not delete/create anything differently."
  (let* ((tmpdir (make-temp-file "ejn-test-reindex-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (cachedir (expand-file-name ".ejn-cache/mynotebook" tmpdir))
         (cell-0 (make-instance 'ejn-cell :type 'code :source "source-0"))
         (cell-1 (make-instance 'ejn-cell :type 'markdown :source "source-1"))
         (nb (make-instance 'ejn-notebook
                            :path nbpath
                            :cells (list cell-0 cell-1))))
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    ;; Write initial shadow files
    (ejn-shadow-write-cell cell-0 nb)
    (ejn-shadow-write-cell cell-1 nb)
    ;; Capture shadow paths after first write
    (let ((shadow-0-after-first (slot-value cell-0 'shadow-file))
          (shadow-1-after-first (slot-value cell-1 'shadow-file)))
      ;; First reindex
      (ejn--reindex-shadow-files nb)
      ;; Second reindex
      (ejn--reindex-shadow-files nb)
      ;; Shadow paths should be unchanged
      (should (string= (slot-value cell-0 'shadow-file) shadow-0-after-first))
      (should (string= (slot-value cell-1 'shadow-file) shadow-1-after-first))
      ;; cell_000.py should exist (cell-0 is code at index 0)
      (should (file-exists-p (expand-file-name "cell_000.py" cachedir)))
      ;; cell_001.md should exist (cell-1 is markdown at index 1)
      (should (file-exists-p (expand-file-name "cell_001.md" cachedir)))
      ;; Spurious files should not exist
      (should-not (file-exists-p (expand-file-name "cell_000.md" cachedir)))
      (should-not (file-exists-p (expand-file-name "cell_001.py" cachedir))))
    ;; Cleanup
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

(ert-deftest ejn-core-p2-t33--reindex-handles-empty-notebook ()
  "Verify reindex does not error on a notebook with nil or empty cells."
  (let* ((tmpdir (make-temp-file "ejn-test-reindex-" t))
         (nbpath (expand-file-name "mynotebook.ipynb" tmpdir))
         (nb (make-instance 'ejn-notebook :path nbpath)))
    (with-temp-buffer
      (insert "{\"nbformat\": 4, \"cells\": [], \"metadata\": {}}")
      (write-file nbpath))
    ;; nil cells
    (should-not (slot-value nb 'cells))
    (should-not (ejn--reindex-shadow-files nb))
    ;; empty list
    (oset nb cells '())
    (should-not (ejn--reindex-shadow-files nb))
    ;; Cleanup
    (delete-file nbpath)
    (delete-directory tmpdir 'recursive)))

;;; ejn-core-tests.el ends here
