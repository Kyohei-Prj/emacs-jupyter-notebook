# AGENTS.md — Emacs Lisp Development Agent Specification

> **Read this file completely before writing any code.**
> Every rule exists because AI agents make the same predictable mistakes in elisp projects, over and over.
> Follow every rule without exception unless explicitly told otherwise.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Load Path and Require Rules](#2-load-path-and-require-rules)
3. [Elisp Syntax Rules](#3-elisp-syntax-rules)
4. [ERT Testing Rules](#4-ert-testing-rules)
5. [Iterative Development Protocol](#5-iterative-development-protocol)
6. [Validation Commands](#6-validation-commands)
7. [Forbidden Patterns](#7-forbidden-patterns)
8. [Submission Checklists](#8-submission-checklists)
9. [Minimal Working Example](#9-minimal-working-example)

---

## 1. Project Structure

### 1.1 Canonical Layout

The project **must** follow this exact layout. Do not create alternative structures.

```
my-package/
├── AGENTS.md                    ← this file
├── my-package.el                ← main entry point
├── my-package-core.el           ← core logic (if split)
├── test/
│   ├── test-helper.el           ← ONLY file that sets load-path
│   ├── my-package-test.el
│   └── my-package-core-test.el
├── Makefile                     ← canonical test runner
└── README.md
```

### 1.2 Naming Rules

- Source files: `kebab-case.el` matching the feature name they `provide`
- Test files: `<source-basename>-test.el`, always inside `test/`
- The shared test setup file is **always** `test/test-helper.el`

### 1.3 Mandatory File Header

Every `.el` file **must** begin with this header (adjust fields as needed):

```elisp
;;; my-package.el --- Short one-line description  -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Author Name
;; Author: Author Name <email@example.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: keyword1 keyword2
;; URL: https://example.com/my-package

;;; Commentary:
;; Describe what this package does.

;;; Code:

;; ... implementation ...

(provide 'my-package)
;;; my-package.el ends here
```

**Mandatory header rules:**
- `lexical-binding: t` is required in every file, no exceptions
- `(provide 'FEATURE)` must be the last expression before the closing comment
- `;;; filename.el ends here` is required as the final line

---

## 2. Load Path and Require Rules

### 2.1 The Golden Rule

> **Never assume `load-path` contains your project directory. Always set it explicitly.**

AI agents frequently write `(require 'my-package)` that fails silently because the project root is not on `load-path`. This is the single most common cause of test failures.

### 2.2 `test/test-helper.el` Is the Single Source of Truth

`test-helper.el` is the **only** file that may manipulate `load-path`. It must be the first file loaded in every test run.

```elisp
;;; test/test-helper.el --- Test setup  -*- lexical-binding: t; -*-

;;; Code:

;; Anchor paths to this file's location — robust regardless of launch directory.
(defvar my-package-test-dir
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing test-helper.el (i.e., test/).")

(defvar my-package-root-dir
  (expand-file-name ".." my-package-test-dir)
  "Project root directory.")

(add-to-list 'load-path my-package-root-dir)
(add-to-list 'load-path my-package-test-dir)

(require 'my-package)
;; (require 'my-package-core)  ; add sibling modules here as needed

(require 'ert)

(provide 'test-helper)
;;; test/test-helper.el ends here
```

### 2.3 Test File `require` Pattern

Every test file starts with exactly one require and nothing else:

```elisp
;;; test/my-package-test.el --- Tests for my-package  -*- lexical-binding: t; -*-

;;; Code:

(require 'test-helper)   ; handles ALL load-path and requires — do not duplicate here

;; tests follow ...

(provide 'my-package-test)
;;; test/my-package-test.el ends here
```

### 2.4 Prohibited `load-path` Patterns

```elisp
;; ❌ Hardcoded absolute path:
(add-to-list 'load-path "/home/user/projects/my-package")

;; ❌ Bare relative path (depends on launch directory):
(add-to-list 'load-path ".")
(add-to-list 'load-path "../")

;; ❌ load-path manipulation inside a test file (only test-helper.el may do this):
;; In my-package-test.el:
(add-to-list 'load-path ...)   ; WRONG

;; ✅ Correct: anchor to load-file-name in test-helper.el (see 2.2 above)
```

---

## 3. Elisp Syntax Rules

### 3.1 Parenthesis Discipline (Most Critical Rule)

Unbalanced parentheses are the most common and destructive error in AI-generated elisp. Every generated code block must satisfy:

- Every `(` has a matching `)`
- Every `"` string is closed
- Top-level forms are separated by blank lines

**Use indentation as a structural signal.** If indentation looks wrong, parentheses are probably wrong too.

**One top-level form per logical unit:**

```elisp
;; ✅ CORRECT — forms clearly separated:

(defvar my-package-name "*My Package*"
  "Buffer name for My Package.")

(defun my-package-buffer ()
  "Return the My Package buffer."
  (get-buffer-create my-package-name))

;; ❌ WRONG — forms run together, nesting is easy to lose:
(defvar my-package-name "*My Package*"
  "Buffer name.")(defun my-package-buffer ()
  (get-buffer-create my-package-name))
```

### 3.2 `defun` Template

```elisp
(defun my-package-function-name (arg1 &optional opt-arg)
  "Docstring: first sentence ends with a period.

Additional paragraphs if needed."
  (interactive)          ; if interactive, this MUST be the first body form
  (body-expression))
```

Rules:
- Docstrings are **mandatory** for every `defun`, `defvar`, and `defcustom`
- `(interactive)` must appear immediately after the docstring, before any other body forms

```elisp
;; ❌ WRONG — (interactive) is not the first body form:
(defun my-package-show ()
  "Display the buffer."
  (let ((buf (my-package-buffer)))
    (interactive)            ; wrong position
    (switch-to-buffer buf)))
```

### 3.3 `let` and `let*`

```elisp
;; ✅ CORRECT — each binding is a list of (var value):
(let ((x 1)
      (y 2))
  (+ x y))

;; ❌ WRONG — missing inner parens around binding:
(let (x 1)    ; binds x to nil; 1 is treated as a body form
  x)

;; Use let* when bindings depend on each other:
(let* ((dir (expand-file-name "test" root))
       (file (expand-file-name "helper.el" dir)))
  (load-file file))
```

### 3.4 `if` with Multiple Then-Forms

```elisp
;; ❌ CLASSIC BUG — second form is the ELSE branch, not a second then-form:
(if condition
    (do-thing-1)
    (do-thing-2))    ; this is ELSE, not a continuation of then

;; ✅ CORRECT — use progn for multiple then-forms:
(if condition
    (progn
      (do-thing-1)
      (do-thing-2))
  (else-form))
```

### 3.5 `cond` Form

```elisp
;; ✅ CORRECT:
(cond
  ((= x 1) "one")
  ((= x 2) "two")
  (t "other"))

;; ❌ WRONG — missing closing paren on a cond clause leaves paren open:
(cond
  ((= x 1) "one")
  ((= x 2) "two")   ; outer paren accidentally omitted
```

### 3.6 Quoting and Sharp-Quoting

```elisp
;; Quote data with ':
(setq my-list '(a b c))

;; Sharp-quote functions with #':
(mapcar #'upcase '("a" "b" "c"))
(add-hook 'after-save-hook #'my-package-on-save)

;; ❌ WRONG — sharp-quoting data:
(setq my-list #'(a b c))

;; ❌ WRONG (style) — quoting function references without #':
(mapcar 'upcase '("a" "b"))     ; works but incorrect with lexical-binding: t
```

### 3.7 Top-Level State

```elisp
;; ❌ WRONG — bare setq at top level:
(setq my-package-state nil)

;; ✅ CORRECT — defvar with docstring:
(defvar my-package-state nil
  "Current state for My Package.")
```

---

## 4. ERT Testing Rules

### 4.1 The Makefile Is the Canonical Test Runner

Always define test commands in the `Makefile`. This makes test runs deterministic and independent of the working directory.

```makefile
EMACS ?= emacs
TEST_DIR = test

.PHONY: test test-one compile clean

## Run all ERT tests in a clean batch session.
test:
	$(EMACS) -Q --batch \
	  --load "$(TEST_DIR)/test-helper.el" \
	  --load "$(TEST_DIR)/my-package-test.el" \
	  --eval "(ert-run-tests-batch-and-exit)"

## Run one test file: make test-one FILE=test/my-package-test.el
test-one:
	$(EMACS) -Q --batch \
	  --load "$(TEST_DIR)/test-helper.el" \
	  --load "$(FILE)" \
	  --eval "(ert-run-tests-batch-and-exit)"

## Byte-compile source files to catch syntax errors and free-variable warnings.
compile:
	$(EMACS) -Q --batch \
	  --eval "(add-to-list 'load-path default-directory)" \
	  --eval "(byte-compile-file \"my-package.el\")"

clean:
	rm -f *.elc test/*.elc
```

**Critical flags:**
- `-Q` — no user config; tests must be hermetic
- `--batch` — non-interactive; errors produce a non-zero exit code
- `(ert-run-tests-batch-and-exit)` — exits 0 on all-pass, 1 on any failure

### 4.2 Test Structure

```elisp
(ert-deftest my-package-describes-what-is-tested ()
  "Docstring: what this test verifies."
  ;; Arrange
  (let ((input "some input"))
    ;; Act + Assert
    (should (string= (my-package-process input) "expected output"))))
```

Rules:
- Test names follow `my-package-description` to avoid collisions with other packages
- Every test has a docstring
- Tests must be **independent**: no test may rely on side effects from another
- Tests must be **deterministic**: no system time, random values, or external processes unless mocked

### 4.3 Assertion Reference

```elisp
(should EXPR)                                         ; EXPR must be non-nil
(should-not EXPR)                                     ; EXPR must be nil
(should-error (my-fn bad-arg))                        ; any error
(should-error (my-fn arg) :type 'wrong-type-argument) ; specific error type

(should (string= actual expected))
(should (= actual expected))
(should (equal actual-list expected-list))

;; ❌ WRONG — not ERT forms:
(assert (= x 1))     ; cl-assert, not ERT
(assertEqual x 1)    ; does not exist
```

### 4.4 Setup and Teardown

Always clean up side effects. Use `unwind-protect` so cleanup runs even on failure.

```elisp
(ert-deftest my-package-creates-buffer ()
  "Test that the buffer is created with the correct name."
  (let ((buf-name "*test-my-package*"))
    (when (get-buffer buf-name)
      (kill-buffer buf-name))
    (unwind-protect
        (progn
          (my-package-create-buffer buf-name)
          (should (get-buffer buf-name)))
      (when (get-buffer buf-name)
        (kill-buffer buf-name)))))
```

For shared setup across tests, define explicit setup/teardown functions and call them with `unwind-protect` inside each test.

---

## 5. Iterative Development Protocol

### 5.1 The Mandatory Development Loop

**Follow this sequence for every change. Do not skip steps.**

```
1. Write or modify ONE unit (one function, one variable, one test)
2. Syntax-check: byte-compile or check-parens
   → if error: fix and repeat step 2
3. Load-test: verify the file loads cleanly in batch Emacs
   → if error: fix and repeat from step 2
4. Run the tests for this unit
   → if failure: fix and repeat from step 2
5. Run the full test suite
   → if failure: fix and repeat from step 2
6. Proceed to the next unit
```

### 5.2 Change Granularity Rules

- Add **one function at a time**. Validate before adding the next.
- Add **one test at a time**. Run it before adding the next.
- Never generate an entire file in one shot without intermediate validation.
- If a change causes an existing test to fail, fix the regression before continuing.

### 5.3 Error Response Protocol

1. **Read the error message completely.** Note the file, line number, and error type.
2. **Do not guess.** `Symbol's function definition is void: my-fn` means `my-fn` is not loaded — check `require` statements and `load-path`.
3. **Fix exactly the reported error.** Do not make unrelated changes.
4. **Re-run the same validation command** to confirm the fix.
5. **Proceed to the next step** in the loop.

---

## 6. Validation Commands

Run these commands in order. Do not submit code that fails any of them.

```bash
# 1. Check parenthesis balance (fastest):
emacs -Q --batch \
  --eval "(find-file \"my-package.el\")" \
  --eval "(check-parens)"

# 2. Byte-compile (catches syntax errors, undefined functions, free variables):
emacs -Q --batch \
  --eval "(add-to-list 'load-path \".\")" \
  --eval "(byte-compile-file \"my-package.el\")"

# 3. Load-test (verify the file loads without errors):
emacs -Q --batch \
  --eval "(add-to-list 'load-path \".\")" \
  --load "my-package.el" \
  --eval "(message \"Load OK\")"

# 4. Run all tests:
make test

# 5. Run one test file:
make test-one FILE=test/my-package-test.el

# 6. Run a single named test:
emacs -Q --batch \
  --load test/test-helper.el \
  --load test/my-package-test.el \
  --eval "(ert-run-tests-batch-and-exit 'my-package-specific-test)"
```

---

## 7. Forbidden Patterns

These patterns are banned unconditionally.

### Load Path

```elisp
;; ❌ Hardcoded absolute path:
(add-to-list 'load-path "/home/user/elisp/my-package")

;; ❌ Bare relative path:
(add-to-list 'load-path ".")

;; ❌ load-path manipulation in any file other than test-helper.el
```

### Syntax

```elisp
;; ❌ Multiple then-forms in if without progn:
(if cond (form1) (form2))   ; form2 is ELSE

;; ❌ Malformed let binding:
(let (x 5) x)               ; x is nil; 5 is a body form

;; ❌ assert instead of should in ERT:
(assert (= x 1))

;; ❌ Bare setq at top level instead of defvar:
(setq my-package-state nil)

;; ❌ Missing docstring on defun/defvar/defcustom
```

### File Structure

```elisp
;; ❌ Missing lexical-binding: t in file header
;; ❌ Missing (provide 'feature) at end of file
;; ❌ Missing ;;; filename.el ends here as final line
;; ❌ (interactive) not as the first body form of an interactive function
```

### Testing

```elisp
;; ❌ Tests that depend on other tests' side effects
;; ❌ Tests without cleanup (buffers, variables left behind)
;; ❌ Hardcoded absolute paths in test fixtures
;; ❌ Using (eval ...) to work around load-path issues — fix load-path instead
```

---

## 8. Submission Checklists

### Before Submitting a Source File

```
Syntax
[ ] Every ( has a matching )
[ ] Every " string is closed
[ ] No if with multiple then-forms without progn
[ ] let bindings use ((var val) ...) form
[ ] (interactive) is the first body form in all interactive functions

Structure
[ ] Header: ;;; filename.el ---  -*- lexical-binding: t; -*-
[ ] (provide 'feature-name) is last expression
[ ] ;;; filename.el ends here is the final line
[ ] All defun/defvar/defcustom have docstrings
[ ] No bare setq at top level

Validation
[ ] check-parens passes
[ ] byte-compile passes with no errors (warnings reviewed)
[ ] make test passes (exit code 0)
```

### Before Submitting a Test File

```
[ ] File lives in test/
[ ] Named <source-basename>-test.el
[ ] First require is (require 'test-helper)
[ ] Does NOT manipulate load-path directly
[ ] Test names prefixed with package name
[ ] All tests have docstrings
[ ] All tests use should/should-not/should-error
[ ] All tests clean up after themselves (unwind-protect)
[ ] make test passes after adding file
```

---

## 9. Minimal Working Example

A complete, minimal project demonstrating every convention in this file.

**`my-package.el`:**

```elisp
;;; my-package.el --- Example minimal package  -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Author
;; Author: Author <author@example.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: tools

;;; Commentary:
;; A minimal example demonstrating project conventions.

;;; Code:

(require 'cl-lib)

(defvar my-package-greeting "Hello"
  "Greeting string used by `my-package-greet'.")

(defun my-package-greet (name)
  "Return a greeting string for NAME."
  (format "%s, %s!" my-package-greeting name))

(defun my-package-greet-upcase (name)
  "Return an uppercased greeting string for NAME."
  (upcase (my-package-greet name)))

(provide 'my-package)
;;; my-package.el ends here
```

**`test/test-helper.el`:**

```elisp
;;; test/test-helper.el --- Test setup  -*- lexical-binding: t; -*-

;;; Code:

(defvar my-package-test-dir
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing test-helper.el.")

(defvar my-package-root-dir
  (expand-file-name ".." my-package-test-dir)
  "Project root directory.")

(add-to-list 'load-path my-package-root-dir)
(add-to-list 'load-path my-package-test-dir)

(require 'my-package)
(require 'ert)

(provide 'test-helper)
;;; test/test-helper.el ends here
```

**`test/my-package-test.el`:**

```elisp
;;; test/my-package-test.el --- Tests for my-package  -*- lexical-binding: t; -*-

;;; Code:

(require 'test-helper)

(ert-deftest my-package-greet-returns-string ()
  "Test that greet returns a correctly formatted string."
  (should (string= (my-package-greet "World") "Hello, World!")))

(ert-deftest my-package-greet-upcase-returns-uppercase ()
  "Test that greet-upcase returns an uppercased greeting."
  (should (string= (my-package-greet-upcase "World") "HELLO, WORLD!")))

(ert-deftest my-package-greet-respects-greeting-variable ()
  "Test that greet uses the current value of my-package-greeting."
  (let ((my-package-greeting "Hi"))
    (should (string= (my-package-greet "World") "Hi, World!"))))

(provide 'my-package-test)
;;; test/my-package-test.el ends here
```

**`Makefile`:**

```makefile
EMACS ?= emacs

.PHONY: test compile clean

test:
	$(EMACS) -Q --batch \
	  --load test/test-helper.el \
	  --load test/my-package-test.el \
	  --eval "(ert-run-tests-batch-and-exit)"

compile:
	$(EMACS) -Q --batch \
	  --eval "(add-to-list 'load-path default-directory)" \
	  --eval "(byte-compile-file \"my-package.el\")"

clean:
	rm -f *.elc test/*.elc
```

**Verification:**

```bash
make compile   # must exit 0, no warnings
make test      # must exit 0, all tests pass
```

---

## Definition of Done

A change is complete **only** when all of the following are true:

- `check-parens` passes on every changed file
- `make compile` passes with no byte-compile errors
- `make test` exits 0 (all tests pass)
- No hardcoded paths introduced
- No new top-level globals without `defvar`
- No new byte-compile warnings left unresolved
