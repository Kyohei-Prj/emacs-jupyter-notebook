# AGENTS.md — Emacs Lisp Development Agent Specification

> **Purpose:** This file governs all AI-assisted development for this Emacs Lisp package.
> Every rule here exists because AI agents make predictable, recurring mistakes in elisp projects.
> Read this file in full before touching any code. Follow every rule without exception.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Load Path and Require Rules](#2-load-path-and-require-rules)
3. [Elisp Syntax Rules](#3-elisp-syntax-rules)
4. [ERT Testing Rules](#4-ert-testing-rules)
5. [Iterative Development Protocol](#5-iterative-development-protocol)
6. [Validation Checkpoints](#6-validation-checkpoints)
7. [Forbidden Patterns](#7-forbidden-patterns)
8. [Quick Reference Checklists](#8-quick-reference-checklists)

---

## 1. Project Structure

### 1.1 Canonical Layout

The project **must** follow this exact directory structure. Do not invent alternative layouts.

```
my-package/
├── AGENTS.md                  ← this file
├── my-package.el              ← main package entry point
├── my-package-core.el         ← core logic (if split across files)
├── my-package-utils.el        ← utility functions (if applicable)
├── test/
│   ├── test-helper.el         ← shared test setup (load-path, requires)
│   ├── my-package-test.el     ← tests for my-package.el
│   └── my-package-core-test.el← tests for my-package-core.el
├── Makefile                   ← build and test targets
└── README.md
```

### 1.2 File Naming Rules

- All source files use **kebab-case**: `my-package-feature.el`
- All test files are named `<source-file-basename>-test.el`
- The test helper is **always** `test/test-helper.el`
- Never place test files in the project root

### 1.3 Package Header Format

Every `.el` source file **must** begin with this exact header block:

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

;; ... your code here ...

(provide 'my-package)
;;; my-package.el ends here
```

Rules:
- `lexical-binding: t` is **mandatory** in every file
- The `(provide 'FEATURE)` form **must** be the last expression before the closing comment
- The closing `;;; my-package.el ends here` comment is **mandatory**

---

## 2. Load Path and Require Rules

### 2.1 The Golden Rule of `load-path`

> **Never assume `load-path` contains your project directory. Always add it explicitly.**

AI agents frequently generate `(require 'my-package)` calls that fail at runtime because the project root is not on `load-path`. This causes silent failures that are difficult to diagnose.

### 2.2 Source File `require` Patterns

Within source files, use `require` for all dependencies:

```elisp
;;; my-package-feature.el --- Feature module -*- lexical-binding: t; -*-

;;; Code:

;; Require Emacs built-ins
(require 'cl-lib)
(require 'subr-x)

;; Require sibling package files
(require 'my-package-core)   ; This works ONLY if load-path is set correctly

(provide 'my-package-feature)
;;; my-package-feature.el ends here
```

### 2.3 Test Helper: The Single Source of Truth for `load-path`

The file `test/test-helper.el` is responsible for all `load-path` manipulation. It **must** be loaded first in every test run, before any other test file.

```elisp
;;; test/test-helper.el --- Test setup -*- lexical-binding: t; -*-

;;; Code:

;; Compute the project root relative to this test-helper file's location.
;; This is robust: it does not depend on where Emacs is launched from.
(defvar my-package-test-dir
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing this test-helper file (i.e., test/).")

(defvar my-package-root-dir
  (expand-file-name ".." my-package-test-dir)
  "Project root directory.")

;; Add the project root to load-path so (require 'my-package) works.
(add-to-list 'load-path my-package-root-dir)

;; Add the test directory itself to load-path so test files can require each other.
(add-to-list 'load-path my-package-test-dir)

;; Now require the package under test.
(require 'my-package)
(require 'my-package-core)   ; add other source modules as needed

;; Require ERT itself.
(require 'ert)

(provide 'test-helper)
;;; test/test-helper.el ends here
```

### 2.4 Test File `require` Pattern

Every test file **must** start by requiring `test-helper` — nothing else:

```elisp
;;; test/my-package-test.el --- Tests for my-package -*- lexical-binding: t; -*-

;;; Code:

(require 'test-helper)   ; This handles ALL load-path setup and requires.
                         ; Do NOT duplicate (add-to-list 'load-path ...) here.
(require 'ert)

;;; Tests below:

(ert-deftest my-package-basic-test ()
  "Test that my-package loads correctly."
  (should (featurep 'my-package)))

(provide 'my-package-test)
;;; test/my-package-test.el ends here
```

### 2.5 Prohibited Load-Path Patterns

```elisp
;; ❌ NEVER use hard-coded absolute paths:
(add-to-list 'load-path "/home/username/projects/my-package")

;; ❌ NEVER use relative paths without anchoring to a file:
(add-to-list 'load-path ".")
(add-to-list 'load-path "../")

;; ❌ NEVER omit load-path setup and hope it works:
(require 'my-package)  ; Will fail if load-path is not set

;; ✅ ALWAYS anchor paths to a file location:
(add-to-list 'load-path (expand-file-name ".." (file-name-directory load-file-name)))
```

---

## 3. Elisp Syntax Rules

### 3.1 Parenthesis Discipline

Unbalanced parentheses are the most common and destructive syntax error in AI-generated elisp. The following rules are mandatory.

**Rule 3.1.1 — Count before submitting.**
Before writing any code block, verify that every opening `(` has a matching `)`. Do this explicitly — count them if in doubt.

**Rule 3.1.2 — Use indentation as a structural guide.**
Correct indentation in elisp is not cosmetic — it reflects nesting depth. If your indentation looks wrong, your parentheses are likely wrong too.

**Rule 3.1.3 — One top-level form per logical unit.**
Do not concatenate multiple top-level forms without blank lines between them. Each `defun`, `defvar`, `defcustom`, etc., is a complete form and should be clearly separated.

```elisp
;; ✅ CORRECT — clear separation between top-level forms:

(defvar my-package-buffer-name "*My Package*"
  "Name of the My Package buffer.")

(defun my-package-get-buffer ()
  "Return the My Package buffer, creating it if necessary."
  (get-buffer-create my-package-buffer-name))

;; ❌ WRONG — forms run together, easy to lose track of nesting:
(defvar my-package-buffer-name "*My Package*"
  "Name of the My Package buffer.")(defun my-package-get-buffer ()
  "Return the My Package buffer."
  (get-buffer-create my-package-buffer-name))
```

### 3.2 `defun` Structure Template

Every function definition **must** follow this template exactly:

```elisp
(defun PACKAGE-function-name (ARG1 ARG2 &optional OPT-ARG)
  "Docstring: first sentence is a complete sentence ending with a period.

Second paragraph with more detail, if needed."
  (BODY-EXPRESSION-1)
  (BODY-EXPRESSION-2))
;;              ^^ closing paren of defun body
```

Rules:
- Docstrings are **mandatory** for all `defun`, `defvar`, `defcustom` forms
- The first line of the docstring must be a complete sentence
- `interactive` declarations come immediately after the docstring, before any other body forms

```elisp
;; ✅ CORRECT order:
(defun my-package-show ()
  "Display the My Package buffer."
  (interactive)
  (switch-to-buffer (my-package-get-buffer)))

;; ❌ WRONG — (interactive) is not the first body form:
(defun my-package-show ()
  "Display the My Package buffer."
  (let ((buf (my-package-get-buffer)))
    (interactive)            ; wrong position
    (switch-to-buffer buf)))
```

### 3.3 `let` and `let*` Forms

```elisp
;; ✅ CORRECT — binding list is a list of lists:
(let ((var1 value1)
      (var2 value2))
  (use var1)
  (use var2))

;; ❌ WRONG — common mistake: single binding not wrapped in extra parens:
(let (var1 value1)     ; wrong — this binds var1 to nil, value1 is interpreted as a form
  (use var1))

;; ❌ WRONG — forgetting the outer parens on the binding list:
(let var1 value1       ; invalid syntax
  (use var1))
```

Use `let*` when bindings depend on each other:

```elisp
(let* ((dir (expand-file-name "test" project-root))
       (file (expand-file-name "test-helper.el" dir)))
  (load-file file))
```

### 3.4 Quoting and Sharp-Quoting

```elisp
;; Quote data — use ' (single quote):
(setq my-list '(a b c))
(setq my-alist '((key1 . val1) (key2 . val2)))

;; Sharp-quote functions — use #' when passing a function as a value:
(mapcar #'upcase '("a" "b" "c"))
(add-hook 'after-save-hook #'my-package-on-save)

;; ❌ WRONG — quoting a function reference:
(mapcar 'upcase '("a" "b" "c"))   ; works but is incorrect style
(add-hook 'after-save-hook 'my-package-on-save)  ; works but incorrect

;; ❌ WRONG — sharp-quoting data:
(setq my-list #'(a b c))  ; invalid
```

### 3.5 Common Syntax Traps to Avoid

```elisp
;; ❌ Missing closing paren on cond clause:
(cond
  ((= x 1) "one")
  ((= x 2) "two")   ; ← easy to leave the outer paren unclosed
)

;; ✅ CORRECT cond:
(cond
  ((= x 1) "one")
  ((= x 2) "two")
  (t "other"))

;; ❌ when/unless with multiple body forms — missing outer paren:
(when condition
  (do-thing-1)
  (do-thing-2)   ; fine — when accepts multiple body forms

;; ❌ if with multiple "then" forms — this is a classic bug:
(if condition
    (do-thing-1)
    (do-thing-2))  ; THIS IS THE ELSE BRANCH, not a second then-form!

;; ✅ CORRECT — use progn for multiple then-forms in if:
(if condition
    (progn
      (do-thing-1)
      (do-thing-2))
  (else-form))
```

---

## 4. ERT Testing Rules

### 4.1 The Makefile: Your Test Runner Contract

Always define test invocation in the `Makefile`. This ensures the test command is deterministic and not dependent on the developer's current working directory or environment.

```makefile
# Makefile

EMACS ?= emacs
PACKAGE_NAME = my-package
TEST_DIR = test
SRC_FILES = my-package.el my-package-core.el

.PHONY: test lint clean

## Run all ERT tests in a clean batch Emacs session.
test:
	$(EMACS) -Q --batch \
	  --load "$(TEST_DIR)/test-helper.el" \
	  --load "$(TEST_DIR)/my-package-test.el" \
	  --load "$(TEST_DIR)/my-package-core-test.el" \
	  --eval "(ert-run-tests-batch-and-exit)"

## Run a single test file (usage: make test-one FILE=test/my-package-test.el)
test-one:
	$(EMACS) -Q --batch \
	  --load "$(TEST_DIR)/test-helper.el" \
	  --load "$(FILE)" \
	  --eval "(ert-run-tests-batch-and-exit)"

## Check for byte-compilation errors.
compile:
	$(EMACS) -Q --batch \
	  --eval "(add-to-list 'load-path default-directory)" \
	  --eval "(byte-compile-file \"my-package.el\")"

clean:
	rm -f *.elc test/*.elc
```

**Critical flags explained:**
- `-Q` — Start Emacs with no user config. Tests must be hermetic.
- `--batch` — Non-interactive mode. Errors cause non-zero exit.
- `--load FILE` — Load a file. Use this instead of `--eval (load-file ...)` for clarity.
- `(ert-run-tests-batch-and-exit)` — Run all loaded ERT tests and exit with code 0 (all pass) or 1 (any fail).

### 4.2 ERT Test Structure

```elisp
(ert-deftest PACKAGE-NAME-describes-what-is-tested ()
  "Docstring explaining what this test verifies."
  ;; Arrange
  (let ((input "some input"))
    ;; Act
    (let ((result (my-package-process input)))
      ;; Assert
      (should (stringp result))
      (should (string= result "expected output")))))
```

Rules:
- Test names follow `PACKAGE-NAME-description` pattern to avoid collisions with other packages
- Every test has a docstring
- Use `should`, `should-not`, `should-error` — never use `assert` or `cl-assert`
- Tests must be independent: no test may depend on side effects from another test
- Tests must be deterministic: no reliance on system time, random values, or external processes unless explicitly mocked

### 4.3 ERT Assertion Reference

```elisp
;; Value truthiness:
(should EXPR)                        ; EXPR must be non-nil
(should-not EXPR)                    ; EXPR must be nil

;; Expected errors:
(should-error (my-fn invalid-arg))           ; any error
(should-error (my-fn arg) :type 'wrong-type-argument)  ; specific error type

;; String equality:
(should (string= actual expected))

;; Numeric equality:
(should (= actual expected))
(should (< actual upper-bound))

;; List equality:
(should (equal actual-list expected-list))  ; equal compares structure

;; ❌ WRONG — these are not ERT forms:
(assert (= x 1))          ; this is cl-assert, not ERT
(assertEqual x 1)         ; does not exist in elisp
```

### 4.4 Setup and Teardown

```elisp
;; Use ert-deftest with let for scoped state:
(ert-deftest my-package-creates-buffer ()
  "Test that a buffer is created with the correct name."
  (let ((buf-name "*test-my-package*"))
    ;; Ensure clean state before test:
    (when (get-buffer buf-name)
      (kill-buffer buf-name))
    ;; Act:
    (my-package-create-buffer buf-name)
    ;; Assert:
    (should (get-buffer buf-name))
    ;; Cleanup (always run, even if test fails — use unwind-protect):
    (unwind-protect
        (should (get-buffer buf-name))
      (when (get-buffer buf-name)
        (kill-buffer buf-name)))))
```

For shared setup across multiple tests, define setup functions explicitly:

```elisp
(defun my-package-test-setup ()
  "Set up state for My Package tests."
  (setq my-package-test-buffer
        (get-buffer-create "*my-package-test*")))

(defun my-package-test-teardown ()
  "Clean up state after My Package tests."
  (when (buffer-live-p my-package-test-buffer)
    (kill-buffer my-package-test-buffer)))

(ert-deftest my-package-buffer-test ()
  "Test buffer operations."
  (my-package-test-setup)
  (unwind-protect
      (progn
        (should (buffer-live-p my-package-test-buffer)))
    (my-package-test-teardown)))
```

### 4.5 Running and Interpreting Tests

**To run all tests:**
```bash
make test
```

**To run a single file:**
```bash
make test-one FILE=test/my-package-test.el
```

**To run from the command line without Make:**
```bash
emacs -Q --batch \
  --load test/test-helper.el \
  --load test/my-package-test.el \
  --eval "(ert-run-tests-batch-and-exit)"
```

**Interpreting output:**
```
Running 5 tests (2024-01-01 00:00:00+0000)
   passed  1/5  my-package-basic-test
   passed  2/5  my-package-creates-buffer
   FAILED  3/5  my-package-process-string
   passed  4/5  my-package-error-handling
   passed  5/5  my-package-cleanup

Test my-package-process-string condition:
    (ert-test-failed
     ((should (string= result "expected")) :form ... :value nil))

Ran 5 tests, 4 results as expected, 1 unexpected (2024-01-01 00:00:00+0000)
1 unexpected results:
   FAILED  my-package-process-string
```

A non-zero exit code from `emacs --batch` means at least one test failed. A zero exit code means all tests passed.

---

## 5. Iterative Development Protocol

### 5.1 The Mandatory Development Loop

**Every change must follow this exact sequence. Do not skip steps.**

```
Step 1: Write or modify ONE unit of code
         (one function, one variable, one test)
         ↓
Step 2: Syntax-validate (byte-compile or check-parens)
         ↓ if error: fix and repeat Step 2
Step 3: Load the file in batch Emacs to check for load errors
         ↓ if error: fix and repeat from Step 2
Step 4: Run affected tests
         ↓ if failure: fix and repeat from Step 2
Step 5: Run full test suite
         ↓ if failure: fix and repeat from Step 2
Step 6: Proceed to next unit of code
```

### 5.2 Syntax Validation Commands

**Check parenthesis balance (fastest check):**
```bash
emacs -Q --batch \
  --eval "(find-file \"my-package.el\")" \
  --eval "(check-parens)"
```
If `check-parens` finds a mismatch, it signals an error with the location.

**Byte-compile for deeper syntax and warning checks:**
```bash
emacs -Q --batch \
  --eval "(add-to-list 'load-path default-directory)" \
  --eval "(byte-compile-file \"my-package.el\")"
```
Byte-compilation catches:
- Unbalanced parentheses
- Calls to undefined functions (warnings)
- Free variables (warnings)
- Wrong number of arguments

**Load-test a single file:**
```bash
emacs -Q --batch \
  --eval "(add-to-list 'load-path \".\")" \
  --load "my-package.el" \
  --eval "(message \"Load OK\")"
```

### 5.3 Change Granularity Rules

- **Add one function at a time.** Validate before adding the next.
- **Add one test at a time.** Run it before adding the next.
- **Never generate an entire file in one shot** without intermediate validation.
- When modifying an existing function, re-run its tests immediately after the change.
- If a change causes an existing test to fail, fix the regression before continuing.

### 5.4 Error Response Protocol

When a command fails:

1. **Read the error message completely.** Identify the file name, line number, and error type.
2. **Do not guess.** If the error says "Symbol's function definition is void: my-fn", the function `my-fn` is not loaded — check `require` statements and `load-path`.
3. **Fix exactly the error reported.** Do not make unrelated changes.
4. **Re-run the same validation command** after fixing to confirm the error is resolved.
5. **Then proceed to the next step** in the development loop.

---

## 6. Validation Checkpoints

### 6.1 Before Every Code Submission

Complete this checklist for every file you create or modify:

**Syntax:**
- [ ] Every `(` has a matching `)`
- [ ] Every `"` string is properly closed
- [ ] No use of `if` with multiple then-forms (use `progn`)
- [ ] `let` bindings use `((var val) ...)` form, not `(var val ...)`
- [ ] `interactive` is the first body form of all interactive functions

**Structure:**
- [ ] File begins with `;;; filename.el ---` header and `lexical-binding: t`
- [ ] File ends with `(provide 'feature-name)` and `;;; filename.el ends here`
- [ ] All `defun`/`defvar`/`defcustom` have docstrings
- [ ] `require` statements at top of file, after header, before any code

**Load path:**
- [ ] No hardcoded absolute paths
- [ ] `test-helper.el` is the only file that modifies `load-path`
- [ ] Test files require `test-helper` as their first `require`

**Tests:**
- [ ] Every new function has at least one corresponding ERT test
- [ ] Tests use `should`/`should-not`/`should-error` (not `assert`)
- [ ] Tests clean up after themselves (buffers killed, variables reset)
- [ ] `make test` passes with exit code 0

**Utilities**
- [ ] Always use `elisp-dev` MCP to facilitate Emacs Lisp (elisp) development.
- [ ] Use `serena` MCP to facilitate code base exploration.

### 6.2 Validation Commands Summary

```bash
# 1. Check parenthesis balance in a source file:
emacs -Q --batch \
  --eval "(find-file \"my-package.el\")" \
  --eval "(check-parens)"

# 2. Byte-compile a source file:
emacs -Q --batch \
  --eval "(add-to-list 'load-path \".\")" \
  --eval "(byte-compile-file \"my-package.el\")"

# 3. Verify a file loads without errors:
emacs -Q --batch \
  --eval "(add-to-list 'load-path \".\")" \
  --load "my-package.el" \
  --eval "(message \"OK\")"

# 4. Run all tests:
make test

# 5. Run a single test file:
make test-one FILE=test/my-package-test.el

# 6. Run a single named test:
emacs -Q --batch \
  --load test/test-helper.el \
  --load test/my-package-test.el \
  --eval "(ert-run-tests-batch-and-exit 'my-package-specific-test-name)"
```

---

## 7. Forbidden Patterns

The following patterns are **banned** unconditionally. Do not use them.

### 7.1 Load Path

```elisp
;; ❌ Hardcoded absolute paths:
(add-to-list 'load-path "/home/user/elisp/my-package")

;; ❌ Bare relative paths:
(add-to-list 'load-path ".")
(add-to-list 'load-path "../")

;; ❌ load-path manipulation outside test-helper.el (in test files):
;; In my-package-test.el:
(add-to-list 'load-path ...)  ; WRONG — only test-helper.el does this
```

### 7.2 Syntax

```elisp
;; ❌ Multiple then-forms in if without progn:
(if condition
    (form1)
    (form2))   ; form2 is the ELSE branch, not a second then-form

;; ❌ Malformed let binding:
(let (x 5)     ; wrong — binds x to nil, 5 is a body expression
  x)

;; ❌ Using assert instead of should in tests:
(assert (= x 1))   ; use (should (= x 1)) in ERT

;; ❌ Omitting docstrings:
(defun my-fn (x)
  (* x 2))   ; missing docstring

;; ❌ Mutable top-level state without defvar/defcustom:
(setq my-package-state nil)   ; use (defvar my-package-state nil "Docstring.")
```

### 7.3 Testing

```elisp
;; ❌ Tests that depend on each other:
(ert-deftest test-b ()
  "This test requires test-a to have run first."
  (should (boundp 'my-package-state-set-by-test-a)))  ; WRONG

;; ❌ Tests without cleanup:
(ert-deftest test-creates-buffer ()
  (my-package-create-buffer "*test*")
  (should (get-buffer "*test*")))
  ;; WRONG — buffer left behind, pollutes other tests

;; ❌ Hardcoded file paths in tests:
(ert-deftest test-load-file ()
  (load-file "/home/user/project/test/fixtures/data.el"))  ; WRONG
```

### 7.4 General

```elisp
;; ❌ Missing (provide ...) at end of file
;; ❌ Missing lexical-binding: t in header
;; ❌ Interactive functions without docstrings
;; ❌ Using (eval ...) to work around load-path issues — fix load-path instead
```

---

## 8. Quick Reference Checklists

### New Source File Checklist

```
[ ] Created at project root (not in test/)
[ ] Header: ;;; filename.el --- Description  -*- lexical-binding: t; -*-
[ ] Package-Requires includes minimum Emacs version
[ ] All requires at top of ;;; Code: section
[ ] All defun/defvar have docstrings
[ ] (provide 'feature-name) is last expression
[ ] ;;; filename.el ends here is final line
[ ] make compile passes (byte-compile check)
[ ] Corresponding test file created in test/
```

### New Test File Checklist

```
[ ] Created in test/ directory
[ ] Named <source-basename>-test.el
[ ] First require is (require 'test-helper)
[ ] Does NOT modify load-path directly
[ ] All test names prefixed with package name
[ ] All tests have docstrings
[ ] All tests clean up after themselves (unwind-protect)
[ ] All assertions use should/should-not/should-error
[ ] make test passes after adding file
```

### Before Submitting Any Change

```
[ ] emacs --batch check-parens passes on changed files
[ ] make compile passes (no byte-compile errors)
[ ] make test passes with exit code 0
[ ] No new warnings introduced by byte-compilation
[ ] No hardcoded paths introduced
[ ] No new globals introduced without defvar
```

---

## Appendix A: Minimal Working Example

This is a complete, minimal, working elisp package demonstrating all conventions:

**`my-package.el`:**
```elisp
;;; my-package.el --- Example minimal package  -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Author
;; Author: Author <author@example.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: tools

;;; Commentary:
;; A minimal example package demonstrating project conventions.

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
  (file-name-directory (or load-file-name buffer-file-name)))

(defvar my-package-root-dir
  (expand-file-name ".." my-package-test-dir))

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
  "Test that greet returns a properly formatted string."
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
make compile   # should exit 0 with no warnings
make test      # should exit 0, all tests passed
```

---
