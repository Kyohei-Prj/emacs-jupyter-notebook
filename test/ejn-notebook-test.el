;;; ejn-notebook-test.el --- ERT tests for ejn-notebook  -*- lexical-binding: t; -*-

(require 'ert)

(add-to-list 'load-path
             (expand-file-name "lisp"
                               (file-name-directory
                                (or load-file-name buffer-file-name))))
(require 'ejn-core)
(require 'ejn-notebook)

;;; ===== P5-T2 B25: ejn--cell-to-json always emits "id" =====

(ert-deftest ejn-notebook-test-p5-t2--cell-to-json-emits-id ()
  "B25: `ejn--cell-to-json' always emits the `id' field.

The returned hash-table must contain the key \"id\" whose value
equals the cell's :id slot."
  (let ((cell (make-instance 'ejn-cell
                             :type 'code
                             :source "print(1)")))
    (let ((cell-json (ejn--cell-to-json cell)))
      (should (gethash "id" cell-json))
      (should (string= (gethash "id" cell-json)
                       (slot-value cell 'id))))))

;;; ===== P5-T2 B26: ejn--cell-to-json always emits "metadata" =====

(ert-deftest ejn-notebook-test-p5-t2--cell-to-json-emits-metadata ()
  "B26: `ejn--cell-to-json' always emits the `metadata' field as an empty hash-table.

The returned hash-table must contain the key \"metadata\" whose value
is a hash-table (suitable for JSON serialization as {}).
"
  (let ((cell (make-instance 'ejn-cell
                             :type 'code
                             :source "print(1)")))
    (let ((cell-json (ejn--cell-to-json cell)))
      (should (hash-table-p (gethash "metadata" cell-json)))
      (should (= (hash-table-count (gethash "metadata" cell-json)) 0)))))

;;; ===== P5-T2 B27: ejn--cell-to-json always emits "outputs" as vector =====

(ert-deftest ejn-notebook-test-p5-t2--cell-to-json-emits-empty-outputs ()
  "B27: `ejn--cell-to-json' emits `outputs' as an empty vector when the slot is nil.

When the cell's :outputs slot is nil, the JSON hash-table must contain
\"outputs\" mapped to a vector (so json-encode produces [] rather than null).
"
  (let ((cell (make-instance 'ejn-cell
                             :type 'code
                             :source "print(1)")))
    ;; Ensure outputs slot is nil (the default initform)
    (should-not (slot-value cell 'outputs))
    (let ((cell-json (ejn--cell-to-json cell)))
      (should (vectorp (gethash "outputs" cell-json)))
      (should (= (length (gethash "outputs" cell-json)) 0)))))

;;; ===== P5-T2: ejn--cell-to-json "source" defaults to "" when nil =====

(ert-deftest ejn-notebook-test-p5-t2--cell-to-json-source-defaults-to-empty-string ()
  "When the cell's :source slot is nil, the `source' field must be the empty string.

This prevents json-encode from producing null for the source field.
"
  (let ((cell (make-instance 'ejn-cell
                             :type 'markdown)))
    ;; Do not set :source — let it be nil (the default)
    (should-not (slot-value cell 'source))
    (let ((cell-json (ejn--cell-to-json cell)))
      (should (string= (gethash "source" cell-json) "")))))

;;; ===== P5-T2 B28: ejn--notebook-to-json nil-guard metadata =====

(ert-deftest ejn-notebook-test-p5-t2--notebook-to-json-metadata-nil-guard ()
  "B28: `ejn--notebook-to-json' emits `metadata' as an empty hash-table when the slot is nil.

When the notebook's :metadata slot is nil, the JSON hash-table must
contain \"metadata\" mapped to a hash-table (so json-encode produces {}
rather than null).
"
  (let ((notebook (make-instance 'ejn-notebook
                                 :path "/tmp/test.ipynb"
                                 :metadata nil
                                 :cells '())))
    (should-not (slot-value notebook 'metadata))
    (let ((nb-json (ejn--notebook-to-json notebook)))
      (should (hash-table-p (gethash "metadata" nb-json)))
      (should (= (hash-table-count (gethash "metadata" nb-json)) 0)))))

;;; ejn-notebook-test.el ends here
