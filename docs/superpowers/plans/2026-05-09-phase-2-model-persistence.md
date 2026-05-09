# Phase 2 — Notebook Model and Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the notebook engine independent of UI: data model structs, `.ipynb` parsing and serialization, dirty tracking, and a transactional mutation system.

**Architecture:** Three new modules built bottom-up: `ejn-cell.el` (leaf structs), `ejn-model.el` (container + transactions), `ejn-persistence.el` (CLOS generics + ipynb parser/serializer). Each layer is validated before proceeding. All testable without buffers or kernels.

**Tech Stack:** Emacs 29+, `cl-lib` (defstruct, defgeneric), built-in `json`, ERT, dash, s, f

---

## File Structure

```
lisp/
├── ejn-cell.el           ; NEW — ejn-cell and ejn-output structs, constructors
├── ejn-model.el          ; NEW — ejn-notebook struct, transactions, dirty tracker, cell API
├── ejn-persistence.el    ; NEW — CLOS persistence generics, backend registry, ipynb parser/writer
├── ejn-core.el           ; UNCHANGED
└── ejn-test-util.el      ; UNCHANGED

test/
├── ejn-cell-test.el           ; NEW
├── ejn-model-test.el          ; NEW
├── ejn-persistence-test.el    ; NEW
└── fixtures/
    ├── sample.ipynb           ; EXISTING
    ├── empty.ipynb            ; NEW
    ├── with-outputs.ipynb     ; NEW
    └── unknown-metadata.ipynb ; NEW

ejn.el                          ; MODIFY — add (require 'ejn-model) and (require 'ejn-persistence)
```

---

# Layer 1: Structs

## Task 1: Create additional test fixtures

**Files:**
- Create: `test/fixtures/empty.ipynb`
- Create: `test/fixtures/with-outputs.ipynb`
- Create: `test/fixtures/unknown-metadata.ipynb`

- [ ] **Step 1: Create empty.ipynb**

Write `test/fixtures/empty.ipynb`:

```json
{
  "cells": [],
  "metadata": {
    "kernelspec": {
      "display_name": "Python 3",
      "language": "python",
      "name": "python3"
    }
  },
  "nbformat": 4,
  "nbformat_minor": 5
}
```

- [ ] **Step 2: Create with-outputs.ipynb**

Write `test/fixtures/with-outputs.ipynb`:

```json
{
  "cells": [
    {
      "cell_type": "code",
      "execution_count": 1,
      "id": "cell-stream",
      "metadata": {},
      "outputs": [
        {
          "output_type": "stream",
          "name": "stdout",
          "text": ["hello\n", "world\n"]
        }
      ],
      "source": ["print(\"hello\")\nprint(\"world\")"]
    },
    {
      "cell_type": "code",
      "execution_count": 2,
      "id": "cell-execute-result",
      "metadata": {},
      "outputs": [
        {
          "output_type": "execute_result",
          "data": {
            "text/plain": ["42"],
            "text/html": ["<b>42</b>"]
          },
          "metadata": {},
          "execution_count": 2
        }
      ],
      "source": ["42"]
    },
    {
      "cell_type": "code",
      "execution_count": 3,
      "id": "cell-error",
      "metadata": {},
      "outputs": [
        {
          "output_type": "error",
          "ename": "ValueError",
          "evalue": "something went wrong",
          "traceback": ["Traceback (most recent call last)\n", "  File \"<stdin>\", line 1, in <module>\n", "ValueError: something went wrong\n"]
        }
      ],
      "source": ["raise ValueError(\"something went wrong\")"]
    },
    {
      "cell_type": "code",
      "execution_count": 4,
      "id": "cell-display-data",
      "metadata": {},
      "outputs": [
        {
          "output_type": "display_data",
          "data": {
            "text/plain": ["array([1, 2, 3])"],
            "image/png": ["iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="]
          },
          "metadata": {}
        }
      ],
      "source": ["import numpy as np; np.array([1, 2, 3])"]
    }
  ],
  "metadata": {
    "kernelspec": {
      "display_name": "Python 3",
      "language": "python",
      "name": "python3"
    }
  },
  "nbformat": 4,
  "nbformat_minor": 5
}
```

- [ ] **Step 3: Create unknown-metadata.ipynb**

Write `test/fixtures/unknown-metadata.ipynb`:

```json
{
  "cells": [
    {
      "cell_type": "code",
      "execution_count": null,
      "id": "cell-with-custom-meta",
      "metadata": {
        "custom-tag": "important",
        "tags": ["exercise", "hard"],
        "collapsed": false
      },
      "outputs": [],
      "source": ["# exercise cell"]
    },
    {
      "cell_type": "markdown",
      "id": "md-cell",
      "metadata": {
        "editable": false
      },
      "source": ["# Title"]
    }
  ],
  "metadata": {
    "kernelspec": {
      "display_name": "Python 3",
      "language": "python",
      "name": "python3"
    },
    "custom-notebook-property": "custom-value",
    "widgets": {
      "state": {},
      "version": "1.2.0"
    }
  },
  "nbformat": 4,
  "nbformat_minor": 5
}
```

- [ ] **Step 4: Verify fixtures are valid JSON**

Run:
```bash
python3 -c "import json; [json.load(open('test/fixtures/f')) for f in ['empty.ipynb','with-outputs.ipynb','unknown-metadata.ipynb']]"
```

Expected: No output (valid JSON).

- [ ] **Step 5: Commit**

```bash
git add test/fixtures/empty.ipynb test/fixtures/with-outputs.ipynb test/fixtures/unknown-metadata.ipynb
git commit -m "feat: add test fixtures for persistence tests"
```

---

## Task 2: ejn-output struct and constructor

**Files:**
- Create: `lisp/ejn-cell.el`
- Create: `test/ejn-cell-test.el`

- [ ] **Step 1: Write failing tests for ejn-output**

Create `test/ejn-cell-test.el`:

```elisp
;;; ejn-cell-test.el --- Tests for ejn-cell  -*- lexical-binding: t; -*-

(require 'ert)

;;; Code:

(ert-deftest ejn-cell-test/output-creation-with-valid-type ()
  "Creating an output with a valid type should succeed."
  (require 'ejn-cell)
  (let ((output (ejn-make-output 'stream)))
    (should (ejn-output-p output))
    (should (eq (ejn-output-type output) 'stream))))

(ert-deftest ejn-cell-test/output-defaults-are-nil ()
  "New outputs should have nil defaults for optional fields."
  (require 'ejn-cell)
  (let ((output (ejn-make-output 'display-data)))
    (should-not (ejn-output-mime-data output))
    (should-not (ejn-output-metadata output))
    (should-not (ejn-output-request-id output))))

(ert-deftest ejn-cell-test/output-rejects-invalid-type ()
  "Creating an output with an invalid type should signal an error."
  (require 'ejn-cell)
  (should-error (ejn-make-output 'invalid-type)))

(ert-deftest ejn-cell-test/output-accepts-all-valid-types ()
  "All valid output types should be accepted."
  (require 'ejn-cell)
  (dolist (type '(stream display-data execute-result error))
    (should (ejn-output-p (ejn-make-output type)))))

(provide 'ejn-cell-test)
;;; ejn-cell-test.el ends here
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
make test 2>&1
```

Expected: FAIL — `ejn-cell` module does not exist yet.

- [ ] **Step 3: Write minimal ejn-cell.el with output struct**

Create `lisp/ejn-cell.el`:

```elisp
;;; ejn-cell.el --- Notebook cell and output data structures  -*- lexical-binding: t; -*-

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

;;; Commentary:

;;; Code:

(require 'cl-lib)

(eval-when-compile (require 'subr-x))

(defconst ejn-valid-output-types
  '(stream display-data execute-result error)
  "List of valid output type keywords.")

(cl-defstruct ejn-output
  type
  mime-data
  metadata
  request-id)

(defun ejn-make-output (type &rest args)
  "Create an output struct of TYPE with optional ARGS.
TYPE must be one of `ejn-valid-output-types'."
  (unless (memq type ejn-valid-output-types)
    (error "Invalid output type: %s. Must be one of %s"
           type ejn-valid-output-types))
  (apply #'make-ejn-output :type type args))

(provide 'ejn-cell)
;;; ejn-cell.el ends here
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
make test 2>&1
```

Expected: All 4 new ejn-cell tests PASS. All existing tests still PASS.

- [ ] **Step 5: Verify byte-compilation**

Run:
```bash
make compile 2>&1
```

Expected: Compiles with no errors and no warnings.

- [ ] **Step 6: Validate with elisp-development skill**

Run:
```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-cell.el
```

Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lisp/ejn-cell.el test/ejn-cell-test.el
git commit -m "feat: add ejn-output struct and constructor with type validation"
```

---

## Task 3: ejn-cell struct and constructor

**Files:**
- Modify: `lisp/ejn-cell.el`
- Modify: `test/ejn-cell-test.el`

- [ ] **Step 1: Add failing tests for ejn-cell**

Add to `test/ejn-cell-test.el` (before the `provide` line):

```elisp
(ert-deftest ejn-cell-test/cell-creation-with-code-type ()
  "Creating a code cell should produce a valid cell struct."
  (require 'ejn-cell)
  (let ((cell (ejn-make-cell 'code)))
    (should (ejn-cell-p cell))
    (should (eq (ejn-cell-type cell) 'code))))

(ert-deftest ejn-cell-test/cell-accepts-all-types ()
  "All cell types should be accepted."
  (require 'ejn-cell)
  (dolist (type '(code markdown raw))
    (should (ejn-cell-p (ejn-make-cell type)))))

(ert-deftest ejn-cell-test/cell-rejects-invalid-type ()
  "Creating a cell with an invalid type should signal an error."
  (require 'ejn-cell)
  (should-error (ejn-make-cell 'invalid-type)))

(ert-deftest ejn-cell-test/cell-has-default-values ()
  "New cells should have correct default values."
  (require 'ejn-cell)
  (let ((cell (ejn-make-cell 'code)))
    (should (stringp (ejn-cell-id cell)))
    (should (string= "" (ejn-cell-source cell)))
    (should-not (ejn-cell-outputs cell))
    (should-not (ejn-cell-metadata cell))
    (should-not (ejn-cell-execution-count cell))
    (should (eq (ejn-cell-execution-state cell) 'idle))
    (should (= (ejn-cell-execution-version cell) 0))))

(ert-deftest ejn-cell-test/cell-ids-are-unique ()
  "Each created cell should have a unique ID."
  (require 'ejn-cell)
  (let ((cell1 (ejn-make-cell 'code))
        (cell2 (ejn-make-cell 'code)))
    (should-not (string= (ejn-cell-id cell1)
                         (ejn-cell-id cell2)))))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
make test 2>&1
```

Expected: FAIL — `ejn-make-cell` is not defined yet.

- [ ] **Step 3: Add cell struct and constructor to ejn-cell.el**

Add to `lisp/ejn-cell.el` (before the `provide` line):

```elisp
(defconst ejn-valid-cell-types
  '(code markdown raw)
  "List of valid cell type keywords.")

(cl-defstruct ejn-cell
  id
  type
  source
  outputs
  metadata
  execution-count
  execution-state
  execution-version)

(defun ejn-generate-uuid ()
  "Generate a simple UUID-like string for cell identification."
  (format "%08x-%04x-%04x-%04x-%012x"
          (random most-positive-fixnum)
          (random #x10000)
          (random #x10000)
          (random #x10000)
          (random (expt 2 48))))

(defun ejn-make-cell (type &optional source)
  "Create a cell of TYPE with optional SOURCE string.
TYPE must be one of `ejn-valid-cell-types'.
SOURCE defaults to an empty string."
  (unless (memq type ejn-valid-cell-types)
    (error "Invalid cell type: %s. Must be one of %s"
           type ejn-valid-cell-types))
  (make-ejn-cell
   :id (ejn-generate-uuid)
   :type type
   :source (or source "")
   :outputs nil
   :metadata nil
   :execution-count nil
   :execution-state 'idle
   :execution-version 0))
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
make test 2>&1
```

Expected: All 9 ejn-cell tests PASS. All existing tests still PASS.

- [ ] **Step 5: Verify byte-compilation**

Run:
```bash
make compile 2>&1
```

Expected: No errors or warnings.

- [ ] **Step 6: Validate**

Run:
```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-cell.el
```

Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lisp/ejn-cell.el test/ejn-cell-test.el
git commit -m "feat: add ejn-cell struct with UUID generation and defaults"
```

---

# Layer 2: Notebook Model and Transactions

## Task 4: ejn-notebook struct and constructor

**Files:**
- Create: `lisp/ejn-model.el`
- Create: `test/ejn-model-test.el`

- [ ] **Step 1: Write failing tests for ejn-notebook**

Create `test/ejn-model-test.el`:

```elisp
;;; ejn-model-test.el --- Tests for ejn-model  -*- lexical-binding: t; -*-

(require 'ert)

;;; Code:

(ert-deftest ejn-model-test/notebook-creation ()
  "Creating a notebook should produce a valid struct."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (should (ejn-notebook-p nb))))

(ert-deftest ejn-model-test/notebook-defaults ()
  "New notebook should have correct defaults."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (should (stringp (ejn-notebook-id nb)))
    (should-not (ejn-notebook-path nb))
    (should (vectorp (ejn-notebook-cells nb)))
    (should (= (length (ejn-notebook-cells nb)) 0))
    (should-not (ejn-notebook-dirty nb))
    (should (= (ejn-notebook-nbformat nb) 4))
    (should (= (ejn-notebook-nbformat-minor nb) 5))
    (should (hash-table-p (ejn-notebook-dirty-cells nb)))
    (should (listp (ejn-notebook-undo-history nb)))))

(provide 'ejn-model-test)
;;; ejn-model-test.el ends here
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
make test 2>&1
```

Expected: FAIL — `ejn-model` does not exist.

- [ ] **Step 3: Create ejn-model.el with notebook struct**

Create `lisp/ejn-model.el`:

```elisp
;;; ejn-model.el --- Notebook model and transaction system  -*- lexical-binding: t; -*-

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

;;; Commentary:

;;; Code:

(require 'cl-lib)
(require 'ejn-cell)

(cl-defstruct ejn-notebook
  id
  path
  metadata
  cells
  dirty
  nbformat
  nbformat-minor
  dirty-cells
  undo-history)

(defun ejn-make-notebook (&optional metadata)
  "Create a new notebook with optional METADATA alist.
Returns an `ejn-notebook' struct initialized with defaults."
  (make-ejn-notebook
   :id (ejn-generate-uuid)
   :path nil
   :metadata (or metadata nil)
   :cells #[]
   :dirty nil
   :nbformat 4
   :nbformat-minor 5
   :dirty-cells (make-hash-table :test 'equal)
   :undo-history nil))

(provide 'ejn-model)
;;; ejn-model.el ends here
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
make test 2>&1
```

Expected: All 2 ejn-model tests PASS.

- [ ] **Step 5: Verify byte-compilation**

Run:
```bash
make compile 2>&1
```

Expected: No errors or warnings.

- [ ] **Step 6: Validate**

Run:
```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-model.el
```

Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lisp/ejn-model.el test/ejn-model-test.el
git commit -m "feat: add ejn-notebook struct with defaults"
```

---

## Task 5: Dirty tracker

**Files:**
- Modify: `lisp/ejn-model.el`
- Modify: `test/ejn-model-test.el`

- [ ] **Step 1: Add failing tests for dirty tracker**

Add to `test/ejn-model-test.el` (before the `provide` line):

```elisp
(ert-deftest ejn-model-test/dirty-tracker-mark-cell ()
  "Marking a cell dirty should add it to the dirty set."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-mark-dirty nb "cell-1")
    (should (member "cell-1" (ejn-notebook-dirty-cells nb)))))

(ert-deftest ejn-model-test/dirty-tracker-multiple-cells ()
  "Marking multiple cells dirty should track all of them."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-mark-dirty nb "cell-1")
    (ejn-notebook-mark-dirty nb "cell-2")
    (let ((dirty (ejn-notebook-dirty-cells nb)))
      (should (= (length dirty) 2))
      (should (member "cell-1" dirty))
      (should (member "cell-2" dirty)))))

(ert-deftest ejn-model-test/dirty-tracker-clean-cell ()
  "Cleaning a cell should remove it from the dirty set."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-mark-dirty nb "cell-1")
    (ejn-notebook-mark-dirty nb "cell-2")
    (ejn-notebook-clean-cell nb "cell-1")
    (let ((dirty (ejn-notebook-dirty-cells nb)))
      (should (= (length dirty) 1))
      (should (member "cell-2" dirty))
      (should-not (member "cell-1" dirty)))))

(ert-deftest ejn-model-test/dirty-tracker-clean-all ()
  "Cleaning all should clear the entire dirty set."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-mark-dirty nb "cell-1")
    (ejn-notebook-mark-dirty nb "cell-2")
    (ejn-notebook-clean-all nb)
    (should (= (length (ejn-notebook-dirty-cells nb)) 0))))

(ert-deftest ejn-model-test/dirty-tracker-idempotent-mark ()
  "Marking an already-dirty cell should not duplicate it."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-mark-dirty nb "cell-1")
    (ejn-notebook-mark-dirty nb "cell-1")
    (should (= (length (ejn-notebook-dirty-cells nb)) 1))))

(ert-deftest ejn-model-test/dirty-flag-set-on-mark ()
  "Marking a cell dirty should set the notebook dirty flag."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (should-not (ejn-notebook-dirty nb))
    (ejn-notebook-mark-dirty nb "cell-1")
    (should (ejn-notebook-dirty nb))))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
make test 2>&1
```

Expected: FAIL — dirty tracker functions not defined yet.

- [ ] **Step 3: Implement dirty tracker functions**

Add to `lisp/ejn-model.el` (before the `provide` line):

```elisp
(defun ejn-notebook-mark-dirty (notebook cell-id)
  "Mark CELL-ID as dirty in NOTEBOOK.
Sets the overall dirty flag on NOTEBOOK."
  (puthash cell-id t (ejn-notebook-dirty-cells notebook))
  (setf (ejn-notebook-dirty notebook) t))

(defun ejn-notebook-clean-cell (notebook cell-id)
  "Remove CELL-ID from the dirty set in NOTEBOOK."
  (remhash cell-id (ejn-notebook-dirty-cells notebook))
  (when (zerop (hash-table-count (ejn-notebook-dirty-cells notebook)))
    (setf (ejn-notebook-dirty notebook) nil)))

(defun ejn-notebook-dirty-cells (notebook)
  "Return a list of dirty cell IDs in NOTEBOOK."
  (let ((result))
    (maphash (lambda (key _value)
               (push key result))
             (ejn-notebook-dirty-cells notebook))
    result))

(defun ejn-notebook-clean-all (notebook)
  "Clear all dirty cells and reset the dirty flag in NOTEBOOK."
  (clrhash (ejn-notebook-dirty-cells notebook))
  (setf (ejn-notebook-dirty notebook) nil))
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
make test 2>&1
```

Expected: All 6 new dirty tracker tests PASS.

- [ ] **Step 5: Verify byte-compilation**

Run:
```bash
make compile 2>&1
```

Expected: No errors or warnings.

- [ ] **Step 6: Commit**

```bash
git add lisp/ejn-model.el test/ejn-model-test.el
git commit -m "feat: add dirty tracker with mark, clean, and enumerate APIs"
```

---

## Task 6: Cell management API

**Files:**
- Modify: `lisp/ejn-model.el`
- Modify: `test/ejn-model-test.el`

- [ ] **Step 1: Add failing tests for cell management**

Add to `test/ejn-model-test.el` (before the `provide` line):

```elisp
(ert-deftest ejn-model-test/insert-cell-at-index ()
  "Inserting a cell at an index should place it correctly."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (should (= (length (ejn-notebook-cells nb)) 1))
    (should (eq (ejn-cell-type (ejn-notebook-cell-at-index nb 0)) 'code))))

(ert-deftest ejn-model-test/insert-cell-after-another ()
  "Inserting a cell after another should maintain order."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'markdown :at 0)
    (let ((first-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-notebook-insert-cell nb 'code :after first-id)
      (should (= (length (ejn-notebook-cells nb)) 2))
      (should (eq (ejn-cell-type (ejn-notebook-cell-at-index nb 1)) 'code)))))

(ert-deftest ejn-model-test/delete-cell-by-id ()
  "Deleting a cell should remove it from the notebook."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell (ejn-notebook-cell-at-index nb 0))
          (cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-notebook-delete-cell nb cell-id)
      (should (= (length (ejn-notebook-cells nb)) 0))
      (should-error (ejn-notebook-cell-by-id nb cell-id)))))

(ert-deftest ejn-model-test/set-cell-source ()
  "Setting cell source should update the source field."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-notebook-set-cell-source nb cell-id "print(42)")
      (should (string= (ejn-cell-source (ejn-notebook-cell-by-id nb cell-id))
                       "print(42))))))

(ert-deftest ejn-model-test/cell-by-id-lookup ()
  "Looking up a cell by ID should return the correct cell."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell (ejn-notebook-cell-at-index nb 0))
          (cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (should (eq (ejn-notebook-cell-by-id nb cell-id) cell)))))

(ert-deftest ejn-model-test/cell-index-lookup ()
  "Getting cell index by ID should return the correct index."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'markdown :at 0)
    (ejn-notebook-insert-cell nb 'code :at 1)
    (let ((code-cell (ejn-notebook-cell-at-index nb 1)))
      (should (= (ejn-notebook-cell-index nb (ejn-cell-id code-cell)) 1)))))

(ert-deftest ejn-model-test/insert-marks-notebook-dirty ()
  "Inserting a cell should mark the notebook dirty."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (should (ejn-notebook-dirty nb))))

(ert-deftest ejn-model-test/delete-marks-notebook-dirty ()
  "Deleting a cell should mark the notebook dirty."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-clean-all nb)
    (ejn-notebook-delete-cell nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)))
    (should (ejn-notebook-dirty nb))))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
make test 2>&1
```

Expected: FAIL — cell management functions not defined yet.

- [ ] **Step 3: Implement cell management API**

Add to `lisp/ejn-model.el` (before the `provide` line):

```elisp
(defun ejn-notebook-insert-cell (notebook type &key at after)
  "Insert a new cell of TYPE into NOTEBOOK.
Position is determined by AT (integer index) or AFTER (cell ID)."
  (let ((new-cell (ejn-make-cell type))
        (cells (ejn-notebook-cells notebook)))
    (let ((insert-index
           (cond
            (at at)
            (after
             (let ((idx (ejn-notebook-cell-index notebook after)))
               (if idx (1+ idx) 0)))
            (t (length cells)))))
      (setf (ejn-notebook-cells notebook)
            (vconcat (seq-take cells insert-index)
                     (vector new-cell)
                     (seq-drop cells insert-index))))
    (ejn-notebook-mark-dirty notebook (ejn-cell-id new-cell))
    new-cell))

(defun ejn-notebook-delete-cell (notebook cell-id)
  "Delete the cell with CELL-ID from NOTEBOOK."
  (let ((idx (ejn-notebook-cell-index notebook cell-id)))
    (unless idx
      (error "Cell not found: %s" cell-id))
    (let ((cells (ejn-notebook-cells notebook)))
      (setf (ejn-notebook-cells notebook)
            (vconcat (seq-take cells idx)
                     (seq-drop cells (1+ idx)))))
    (ejn-notebook-mark-dirty notebook cell-id)))

(defun ejn-notebook-set-cell-source (notebook cell-id source)
  "Set the source text of cell CELL-ID in NOTEBOOK to SOURCE."
  (let ((cell (ejn-notebook-cell-by-id notebook cell-id)))
    (setf (ejn-cell-source cell) source)
    (ejn-notebook-mark-dirty notebook cell-id)))

(defun ejn-notebook-cell-by-id (notebook cell-id)
  "Return the cell with CELL-ID from NOTEBOOK, or signal an error."
  (let ((cell nil))
    (cl-loop for c across (ejn-notebook-cells notebook)
             when (string= (ejn-cell-id c) cell-id)
             do (setq cell c))
    (unless cell
      (error "Cell not found: %s" cell-id))
    cell))

(defun ejn-notebook-cell-at-index (notebook index)
  "Return the cell at INDEX in NOTEBOOK, or nil."
  (let ((cells (ejn-notebook-cells notebook)))
    (when (< index (length cells))
      (aref cells index))))

(defun ejn-notebook-cell-index (notebook cell-id)
  "Return the index of cell CELL-ID in NOTEBOOK, or nil."
  (let ((idx 0))
    (cl-loop for c across (ejn-notebook-cells notebook)
             when (string= (ejn-cell-id c) cell-id)
             return idx
             do (cl-incf idx))
    nil))
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
make test 2>&1
```

Expected: All 8 cell management tests PASS.

- [ ] **Step 5: Verify byte-compilation**

Run:
```bash
make compile 2>&1
```

Expected: No errors or warnings.

- [ ] **Step 6: Commit**

```bash
git add lisp/ejn-model.el test/ejn-model-test.el
git commit -m "feat: add cell management API with insert, delete, and lookup"
```

---

## Task 7: Transaction macros

**Files:**
- Modify: `lisp/ejn-model.el`
- Modify: `test/ejn-model-test.el`

- [ ] **Step 1: Add failing tests for transactions**

Add to `test/ejn-model-test.el` (before the `provide` line):

```elisp
(ert-deftest ejn-model-test/transaction-marks-dirty ()
  "A completed transaction should mark the notebook dirty."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-clean-all nb)
    (let ((cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-with-transaction nb
        (ejn-notebook-set-cell-source nb cell-id "new source")))
    (should (ejn-notebook-dirty nb))))

(ert-deftest ejn-model-test/transaction-rollback-on-error ()
  "A transaction that errors should restore the previous state."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0)))
          (original-source (ejn-cell-source (ejn-notebook-cell-at-index nb 0))))
      (condition-case nil
          (ejn-with-transaction nb
            (ejn-notebook-set-cell-source nb cell-id "modified")
            (error "simulated error"))
        (error nil))
      (should (string= (ejn-cell-source (ejn-notebook-cell-by-id nb cell-id))
                       original-source)))))

(ert-deftest ejn-model-test/undo-group-records-snapshot ()
  "An undo group should record a snapshot in the undo history."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-with-undo-group "Edit source" nb
        (ejn-notebook-set-cell-source nb cell-id "new source")))
    (should (> (length (ejn-notebook-undo-history nb)) 0))))

(ert-deftest ejn-model-test/undo-restores-previous-state ()
  "Undo should restore the model to its previous state."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-with-undo-group "Edit source" nb
        (ejn-notebook-set-cell-source nb cell-id "new source"))
      (ejn-undo nb)
      (should (string= (ejn-cell-source (ejn-notebook-cell-by-id nb cell-id))
                       "")))))

(ert-deftest ejn-model-test/redo-reapplies-undone-change ()
  "Redo should reapply an undone change."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-with-undo-group "Edit source" nb
        (ejn-notebook-set-cell-source nb cell-id "new source"))
      (ejn-undo nb)
      (ejn-redo nb)
      (should (string= (ejn-cell-source (ejn-notebook-cell-by-id nb cell-id))
                       "new source")))))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
make test 2>&1
```

Expected: FAIL — transaction macros and undo functions not defined yet.

- [ ] **Step 3: Implement transaction and undo system**

Add to `lisp/ejn-model.el` (before the `provide` line):

```elisp
(defun ejn--notebook-snapshot (notebook)
  "Create a snapshot of the mutable state of NOTEBOOK.
Returns a list of plists, one per cell, capturing mutable fields."
  (cl-loop for cell across (ejn-notebook-cells notebook)
           collect (list :id (ejn-cell-id cell)
                         :source (ejn-cell-source cell)
                         :outputs (ejn-cell-outputs cell)
                         :execution-count (ejn-cell-execution-count cell)
                         :execution-state (ejn-cell-execution-state cell)
                         :execution-version (ejn-cell-execution-version cell))))

(defun ejn--notebook-apply-snapshot (notebook snapshot)
  "Apply SNAPSHOT to NOTEBOOK, restoring cell mutable state.
SNAPSHOT is a list of plists as produced by `ejn--notebook-snapshot'."
  (cl-loop for cell-plist in snapshot
           do (let ((cell (ejn-notebook-cell-by-id notebook
                                                   (plist-get cell-plist :id))))
                (setf (ejn-cell-source cell) (plist-get cell-plist :source)
                      (ejn-cell-outputs cell) (plist-get cell-plist :outputs)
                      (ejn-cell-execution-count cell) (plist-get cell-plist :execution-count)
                      (ejn-cell-execution-state cell) (plist-get cell-plist :execution-state)
                      (ejn-cell-execution-version cell) (plist-get cell-plist :execution-version)))))

(defmacro ejn-with-transaction (notebook &rest body)
  "Execute BODY as a transaction on NOTEBOOK.
If BODY errors, cell state is restored to its pre-transaction values.
Marks the notebook dirty on success."
  (declare (indent 1))
  `(let ((ejn--txn-notebook ,notebook)
         (ejn--txn-snapshot (ejn--notebook-snapshot ,notebook)))
     (condition-case err
         (progn ,@body)
       (error
        (ejn--notebook-apply-snapshot ejn--txn-notebook ejn--txn-snapshot)
        (signal (car err) (cdr err))))))

(defmacro ejn-with-undo-group (label notebook &rest body)
  "Execute BODY within an undoable transaction on NOTEBOOK.
LABEL is a human-readable description stored with the undo entry.
Records before/after snapshots for undo and redo."
  (declare (indent 2))
  `(let ((ejn--undo-notebook ,notebook)
         (ejn--undo-before (ejn--notebook-snapshot ,notebook)))
     (ejn-with-transaction ejn--undo-notebook
       ,@body)
     (let ((ejn--undo-after (ejn--notebook-snapshot ejn--undo-notebook)))
       (push (list :label ,label
                   :before ejn--undo-before
                   :after ejn--undo-after)
             (ejn-notebook-undo-history ejn--undo-notebook)))))

(defun ejn--undo-entry-p (entry)
  "Return non-nil if ENTRY is a regular undo entry (not a redo marker)."
  (and (consp entry)
       (eq (car entry) :label)))

(defun ejn--redo-entry-p (entry)
  "Return non-nil if ENTRY is a redo marker."
  (and (consp entry)
       (eq (car entry) 'redo)))

(defun ejn-undo (notebook)
  "Undo the last undoable operation on NOTEBOOK.
Restores cell state to the pre-operation snapshot."
  (let ((history (ejn-notebook-undo-history notebook)))
    (unless (cl-find-if #'ejn--undo-entry-p history)
      (user-error "Nothing to undo"))
    (let ((entry (cl-find-if #'ejn--undo-entry-p history)))
      (setf (ejn-notebook-undo-history notebook)
            (cl-remove entry history :count 1))
      (ejn--notebook-apply-snapshot notebook (plist-get entry :before))
      (push (cons 'redo entry)
            (ejn-notebook-undo-history notebook))
      (setf (ejn-notebook-dirty notebook) t))
    entry))

(defun ejn-redo (notebook)
  "Redo the last undone operation on NOTEBOOK.
Reapplies the post-operation snapshot from the undone entry."
  (let ((history (ejn-notebook-undo-history notebook))
        (redo-entry (cl-find-if #'ejn--redo-entry-p history)))
    (unless redo-entry
      (user-error "Nothing to redo"))
    (setf (ejn-notebook-undo-history notebook)
          (cl-remove-if #'ejn--redo-entry-p history))
    (let ((entry (cdr redo-entry)))
      (ejn--notebook-apply-snapshot notebook (plist-get entry :after))
      (push entry (ejn-notebook-undo-history notebook))
      (setf (ejn-notebook-dirty notebook) t)))
    redo-entry)
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
make test 2>&1
```

Expected: All 5 transaction/undo tests PASS.

- [ ] **Step 5: Verify byte-compilation**

Run:
```bash
make compile 2>&1
```

Expected: No errors or warnings.

- [ ] **Step 6: Commit**

```bash
git add lisp/ejn-model.el test/ejn-model-test.el
git commit -m "feat: add transaction macros and undo/redo system"
```

---

# Layer 3: Persistence

## Task 8: Persistence generics and backend registry

**Files:**
- Create: `lisp/ejn-persistence.el`
- Create: `test/ejn-persistence-test.el`

- [ ] **Step 1: Write failing tests for persistence registry**

Create `test/ejn-persistence-test.el`:

```elisp
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

(provide 'ejn-persistence-test)
;;; ejn-persistence-test.el ends here
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
make test 2>&1
```

Expected: FAIL — `ejn-persistence` does not exist.

- [ ] **Step 3: Create ejn-persistence.el with generics and registry**

Create `lisp/ejn-persistence.el`:

```elisp
;;; ejn-persistence.el --- Notebook persistence layer  -*- lexical-binding: t; -*-

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

;;; Commentary:

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'ejn-model)

(defvar ejn-persistence-backend-registry
  (make-hash-table :test 'equal)
  "Hash table mapping backend type symbols to backend configurations.")

(cl-defgeneric ejn-persistence-read (backend path)
  "Read a notebook from PATH using BACKEND."
  nil)

(cl-defgeneric ejn-persistence-write (backend notebook path)
  "Write NOTEBOOK to PATH using BACKEND."
  nil)

(cl-defgeneric ejn-persistence-can-handle-p (backend path)
  "Return non-nil if BACKEND can handle PATH."
  nil)

(defun ejn-register-persistence-backend (type constructor &key predicate)
  "Register a persistence backend of TYPE with CONSTRUCTOR.
PREDICATE is a function that takes a path and returns non-nil if
the backend can handle it."
  (puthash type (list :constructor constructor
                      :predicate (or predicate
                                     (lambda (_path) nil)))
           ejn-persistence-backend-registry))

(defun ejn-persistence-backend-for (path)
  "Return the best persistence backend for PATH, or nil."
  (let ((result nil))
    (maphash (lambda (_type config)
               (let ((predicate (plist-get config :predicate)))
                 (when (funcall predicate path)
                   (setq result
                         (funcall (plist-get config :constructor))))))
             ejn-persistence-backend-registry)
    result))

;; Define ipynb backend struct
(cl-defstruct ejn-ipynb-backend)

(provide 'ejn-persistence)
;;; ejn-persistence.el ends here
```

- [ ] **Step 4: Run tests — registry tests will still fail (no auto-registration yet)**

Run:
```bash
make test 2>&1
```

Expected: FAIL — `.ipynb` backend is not auto-registered yet (will be done in Task 9 after we implement the parser).

- [ ] **Step 5: Verify byte-compilation**

Run:
```bash
make compile 2>&1
```

Expected: No errors or warnings.

- [ ] **Step 6: Commit**

```bash
git add lisp/ejn-persistence.el test/ejn-persistence-test.el
git commit -m "feat: add persistence CLOS generics and backend registry"
```

---

## Task 9: ipynb parser

**Files:**
- Modify: `lisp/ejn-persistence.el`
- Modify: `test/ejn-persistence-test.el`

- [ ] **Step 1: Add error condition definitions**

Add to `lisp/ejn-persistence.el` (after the `require` statements, before `ejn-persistence-backend-registry`):

```elisp
(define-error 'ejn-invalid-notebook "Invalid notebook format" nil)
(define-error 'ejn-unsupported-format "Unsupported notebook format" 'ejn-invalid-notebook)
```

- [ ] **Step 2: Add failing tests for ipynb parsing**

Add to `test/ejn-persistence-test.el` (before the `provide` line):

```elisp
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
```

- [ ] **Step 3: Implement ipynb parser**

Add to `lisp/ejn-persistence.el` (before the `provide` line):

```elisp
(defun ejn-ipynb-parse-source (source)
  "Normalize nbformat SOURCE field to a string.
SOURCE can be a string or a list of strings (line segments)."
  (cond
   ((stringp source) source)
   ((listp source) (mapconcat #'identity source ""))
   (t "")))

(defun ejn-ipynb-parse-output (json-alist)
  "Parse a JSON output ALIST into an `ejn-output' struct."
  (let ((output-type (intern (cdr (assq :output_type json-alist)))))
    (make-ejn-output
     :type output-type
     :mime-data (cdr (assq :data json-alist))
     :metadata (cdr (assq :metadata json-alist))
     :request-id nil)))

(defun ejn-ipynb-parse-cell (json-alist)
  "Parse a JSON cell ALIST into an `ejn-cell' struct."
  (let ((cell-type (intern (cdr (assq :cell_type json-alist)))))
    (make-ejn-cell
     :id (cdr (assq :id json-alist))
     :type cell-type
     :source (ejn-ipynb-parse-source (cdr (assq :source json-alist)))
     :outputs (mapcar #'ejn-ipynb-parse-output
                      (cdr (assq :outputs json-alist)))
     :metadata (cdr (assq :metadata json-alist))
     :execution-count (cdr (assq :execution_count json-alist))
     :execution-state 'idle
     :execution-version 0)))

(defun ejn-ipynb-parse-notebook (path)
  "Parse an .ipynb file at PATH into an `ejn-notebook' struct.
Signals `ejn-invalid-notebook' for malformed files.
Signals `ejn-unsupported-format' for unsupported nbformat versions."
  (let ((json-data))
    (condition-case err
        (with-temp-buffer
          (insert-file-contents path)
          (setq json-data (json-read-object)))
      (error
       (signal 'ejn-invalid-notebook
               (list (format "Failed to parse %s: %s" path (error-message-string err)))))))
    (let ((nbformat (cdr (assq :nbformat json-data))))
      (unless (= nbformat 4)
        (signal 'ejn-unsupported-format
                (list (format "Unsupported nbformat version: %s (only v4 supported)"
                              nbformat)))))
    (make-ejn-notebook
     :id (cdr (assq :id json-data))
     :path path
     :metadata (cdr (assq :metadata json-data))
     :cells (cl-loop for cell-json in (cdr (assq :cells json-data))
                     collect (ejn-ipynb-parse-cell cell-json)
                     into cells-list
                     finally return (vconcat cells-list))
     :dirty nil
     :nbformat nbformat
     :nbformat-minor (cdr (assq :nbformat_minor json-data))
     :dirty-cells (make-hash-table :test 'equal)
     :undo-history nil))
```

Note: `json-read-object` returns keys as keywords (e.g. `:cells`, `:id`), so `assq` with keyword arguments is the correct lookup method.

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
make test 2>&1
```

Expected: All parsing tests PASS. The registry tests will still fail until auto-registration is added.

- [ ] **Step 5: Verify byte-compilation**

Run:
```bash
make compile 2>&1
```

Expected: No errors or warnings.

- [ ] **Step 6: Validate**

Run:
```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-persistence.el
```

Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lisp/ejn-persistence.el test/ejn-persistence-test.el
git commit -m "feat: add ipynb parser with source normalization and metadata preservation"
```

---

## Task 10: ipynb serializer

**Files:**
- Modify: `lisp/ejn-persistence.el`
- Modify: `test/ejn-persistence-test.el`

- [ ] **Step 1: Add failing tests for serialization**

Add to `test/ejn-persistence-test.el` (before the `provide` line):

```elisp
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
            (should (json-read-object))))
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
            (let ((data (json-read-object)))
              (let ((cells (cdr (assq :cells data))))
                (should (string= (cdr (assq :id (car cells)))
                                 "test-cell-1")))))
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
            (let ((data (json-read-object)))
              (let ((cell (car (cdr (assq :cells data)))))
                (should (stringp (cdr (assq :source cell)))))))
      (delete-file tmpfile)))))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
make test 2>&1
```

Expected: FAIL — `ejn-ipynb-serialize-notebook` not defined.

- [ ] **Step 3: Implement serializer functions**

Add to `lisp/ejn-persistence.el` (before the `provide` line, after the parser functions):

```elisp
(defun ejn-ipynb-serialize-output (output)
  "Serialize an `ejn-output' struct to a JSON-compatible plist."
  (let ((result (list :output_type (symbol-name (ejn-output-type output)))))
    (when (ejn-output-mime-data output)
      (plist-put result :data (ejn-output-mime-data output)))
    (when (ejn-output-metadata output)
      (plist-put result :metadata (ejn-output-metadata output)))
    result))

(defun ejn-ipynb-serialize-cell (cell)
  "Serialize an `ejn-cell' struct to a JSON-compatible plist."
  (let ((result (list :id (ejn-cell-id cell)
                      :cell_type (symbol-name (ejn-cell-type cell))
                      :source (ejn-cell-source cell)
                      :outputs (mapcar #'ejn-ipynb-serialize-output
                                       (ejn-cell-outputs cell))
                      :metadata (or (ejn-cell-metadata cell) nil)
                      :execution_count (ejn-cell-execution-count cell))))
    result))

(defun ejn-ipynb-serialize-notebook (notebook &optional path)
  "Serialize NOTEBOOK to nbformat v4 JSON.
If PATH is given, write to that file. Otherwise return the JSON string."
  (let ((data (list :nbformat (ejn-notebook-nbformat notebook)
                    :nbformat_minor (ejn-notebook-nbformat-minor notebook)
                    :metadata (or (ejn-notebook-metadata notebook) nil)
                    :cells (mapcar #'ejn-ipynb-serialize-cell
                                   (ejn-notebook-cells notebook)))))
    (when (ejn-notebook-id notebook)
      (plist-put data :id (ejn-notebook-id notebook)))
    (let ((json-string (json-encode data)))
      (if path
          (with-temp-buffer
            (insert json-string)
            (json-pretty-print (point-min) (point-max))
            (write-region (point-min) (point-max) path nil 'nomessage))
        json-string))))
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
make test 2>&1
```

Expected: All 3 serialization tests PASS.

- [ ] **Step 5: Verify byte-compilation**

Run:
```bash
make compile 2>&1
```

Expected: No errors or warnings.

- [ ] **Step 6: Commit**

```bash
git add lisp/ejn-persistence.el test/ejn-persistence-test.el
git commit -m "feat: add ipynb serializer with nbformat v4 output"
```

---

## Task 11: Round-trip tests, CLOS method implementation, and auto-registration

**Files:**
- Modify: `lisp/ejn-persistence.el`
- Modify: `test/ejn-persistence-test.el`

- [ ] **Step 1: Add round-trip tests**

Add to `test/ejn-persistence-test.el` (before the `provide` line):

```elisp
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
```

- [ ] **Step 2: Implement CLOS methods and convenience functions**

Add to `lisp/ejn-persistence.el` (before the `provide` line):

```elisp
(cl-defmethod ejn-persistence-read ((backend ejn-ipynb-backend) path)
  "Read an .ipynb notebook from PATH."
  (ejn-ipynb-parse-notebook path))

(cl-defmethod ejn-persistence-write ((backend ejn-ipynb-backend) notebook path)
  "Write NOTEBOOK to PATH as .ipynb."
  (ejn-ipynb-serialize-notebook notebook path))

(cl-defmethod ejn-persistence-can-handle-p ((backend ejn-ipynb-backend) path)
  "Return t if PATH ends with .ipynb."
  (string-suffix-p ".ipynb" path))

(defun ejn-model-from-file (path)
  "Load a notebook from PATH using the appropriate backend.
Signals an error if no backend can handle PATH or loading fails."
  (let ((backend (ejn-persistence-backend-for path)))
    (unless backend
      (error "No persistence backend for: %s" path))
    (ejn-persistence-read backend path)))

(defun ejn-model-to-file (notebook path)
  "Save NOTEBOOK to PATH using the appropriate backend.
Signals an error if no backend can handle PATH or saving fails."
  (let ((backend (ejn-persistence-backend-for path)))
    (unless backend
      (error "No persistence backend for: %s" path))
    (ejn-persistence-write backend notebook path)))

;; Auto-register the .ipynb backend
(ejn-register-persistence-backend 'ipynb #'make-ejn-ipynb-backend
                                  :predicate (lambda (path)
                                               (string-suffix-p ".ipynb" path)))
```

- [ ] **Step 3: Run all tests**

Run:
```bash
make test 2>&1
```

Expected: ALL tests PASS — including the previously failing registry tests and all new round-trip tests.

- [ ] **Step 4: Verify byte-compilation**

Run:
```bash
make compile 2>&1
```

Expected: No errors or warnings.

- [ ] **Step 5: Commit**

```bash
git add lisp/ejn-persistence.el test/ejn-persistence-test.el
git commit -m "feat: add CLOS methods, auto-registration, round-trip tests, and convenience functions"
```

---

## Task 12: Wire into ejn.el

**Files:**
- Modify: `ejn.el`

- [ ] **Step 1: Update ejn.el to load new modules**

Update `ejn.el` to add the new module requires after the existing requires:

```elisp
(require 'ejn-core)
(require 'ejn-log)
(require 'ejn-model)
(require 'ejn-persistence)
```

- [ ] **Step 2: Verify everything still compiles and tests pass**

Run:
```bash
make clean && make all 2>&1
```

Expected:
- compile: PASS (no warnings)
- lint: PASS (no errors)
- test: PASS (all tests pass)

- [ ] **Step 3: Verify test count**

Run:
```bash
make test 2>&1
```

Expected: Approximately 37+ tests total:
- 3 ejn-core tests
- 5 ejn-log tests
- 2 ejn-test-util tests
- 9 ejn-cell tests
- 19 ejn-model tests
- 14 ejn-persistence tests

- [ ] **Step 4: Validate all new files**

Run:
```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-cell.el
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-model.el
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-persistence.el
```

Expected: No errors for any file.

- [ ] **Step 5: Commit**

```bash
git add ejn.el
git commit -m "feat: wire model and persistence modules into package entry point"
```

---

## Task 13: Final verification

**Files:**
- All project files

- [ ] **Step 1: Run complete clean build**

Run:
```bash
make clean && make all 2>&1
```

Expected: Clean build, all linters pass, all tests pass.

- [ ] **Step 2: Verify project structure**

```bash
find . -not -path './.git/*' -not -path './.eask/*' -not -name '*.elc' -name '*.el' | sort
```

Expected to include at minimum:
```
./ejn.el
./lisp/ejn-cell.el
./lisp/ejn-core.el
./lisp/ejn-log.el
./lisp/ejn-model.el
./lisp/ejn-persistence.el
./lisp/ejn-test-util.el
./test/ejn-cell-test.el
./test/ejn-core-test.el
./test/ejn-log-test.el
./test/ejn-model-test.el
./test/ejn-persistence-test.el
./test/ejn-test-util-test.el
```

- [ ] **Step 3: Run package-lint**

Run:
```bash
make lint-pkg 2>&1
```

Expected: Zero errors.

- [ ] **Step 4: Final commit if needed**

If any verification step required changes:
```bash
git add -A && git commit -m "fix: Phase 2 verification fixes"
```

---

## Self-Review

**Spec coverage check:**

| Spec Requirement | Task(s) |
|---|---|
| `ejn-output` struct with type validation | Task 2 |
| `ejn-cell` struct with UUID generation | Task 3 |
| `ejn-notebook` struct | Task 4 |
| Dirty tracker (mark, clean, enumerate) | Task 5 |
| Cell management API (insert, delete, set-source, lookup) | Task 6 |
| `ejn-with-transaction` macro | Task 7 |
| `ejn-with-undo-group` macro | Task 7 |
| Undo/redo API | Task 7 |
| CLOS persistence generics | Task 8 |
| Backend registry with auto-registration | Tasks 8, 11 |
| ipynb parser with source normalization | Task 9 |
| ipynb serializer | Task 10 |
| Metadata preservation (notebook and cell level) | Tasks 9, 10 |
| MIME data preservation | Tasks 9, 10 |
| Error conditions (`ejn-invalid-notebook`, `ejn-unsupported-format`) | Task 9 |
| Convenience functions (`ejn-model-from-file`, `ejn-model-to-file`) | Task 11 |
| Round-trip tests | Task 11 |
| Test fixtures | Task 1 |
| Wire into ejn.el | Task 12 |

**Placeholder scan:** No TBDs, TODOs, or "implement later" patterns found. All code blocks are complete.

**Type consistency:**
- `ejn-cell-id` — string (UUID) throughout
- `ejn-cell-type` — keyword (`'code` | `'markdown` | `'raw`) throughout
- `ejn-output-type` — keyword (`'stream` | `'display-data` | `'execute-result` | `'error`) throughout
- `ejn-cell-source` — string throughout
- `ejn-output-mime-data` — alist throughout
- `ejn-cell-metadata` — alist or nil throughout
- `ejn-notebook-cells` — vector throughout
- `ejn-notebook-dirty-cells` — hash-table throughout
- Struct field names match between parser, serializer, and test code
- Function name prefix `ejn-` used consistently

**Dependency order verification:**
1. Task 1 (fixtures) — no code dependencies
2. Task 2 (output struct) — depends on ejn-core only
3. Task 3 (cell struct) — depends on Task 2
4. Task 4 (notebook struct) — depends on Task 3 (ejn-cell)
5. Task 5 (dirty tracker) — depends on Task 4
6. Task 6 (cell management) — depends on Tasks 4, 5
7. Task 7 (transactions) — depends on Tasks 5, 6
8. Task 8 (persistence generics) — depends on ejn-model
9. Task 9 (ipynb parser) — depends on Tasks 3, 8
10. Task 10 (serializer) — depends on Tasks 3, 4, 8
11. Task 11 (CLOS methods, round-trips) — depends on Tasks 9, 10
12. Task 12 (wire into ejn.el) — depends on all above
13. Task 13 (final verification) — depends on all above

Plan complete and saved to `docs/superpowers/plans/2026-05-09-phase-2-model-persistence.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
