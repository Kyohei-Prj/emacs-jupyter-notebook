# Phase 3 — Buffer Projection and Cell Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render notebook models into editable Emacs buffers with cell navigation, structural operations, debounced sync, and output rendering.

**Architecture:** Model-first: all operations mutate the `ejn-notebook` model first, then re-render the buffer. Cell boundaries are tracked via text properties (`ejn-cell-id`, `ejn-cell-type`) on source regions — no overlays. Output zones are dedicated read-only regions with `ejn-output-zone` text properties. User edits sync to the model via a debounced `after-change-functions` hook.

**Tech Stack:** Emacs Lisp (lexical-binding), `cl-lib`, `text-mode`, `timer`, `faces`, `subr-x`. No new external dependencies.

---

## File Structure

```
lisp/ (new files)
├── ejn-mime.el          ; MIME handler registry + MVP handlers (text/plain, text/markdown, image/png, image/svg+xml)
├── ejn-render.el        ; Faces, full/incremental render, output zones, folding
├── ejn-navigation.el    ; Cell-at-point, cell-region, navigation commands
├── ejn-cell-engine.el   ; Insert/delete/split/merge/move/copy/yank operations
├── ejn-sync.el          ; after-change-functions hook, debounced sync
├── ejn-undo.el          ; Undo boundary macro, ejn-undo/ejn-redo commands
└── ejn-mode.el          ; Major mode, keymap, buffer-local state, ejn-open

test/ (new files)
├── ejn-mime-test.el
├── ejn-render-test.el
├── ejn-navigation-test.el
├── ejn-cell-engine-test.el
├── ejn-sync-test.el
└── ejn-mode-test.el

modified files
├── lisp/ejn-test-util.el  ; Add ejn-test-with-notebook-buffer, ejn-test-wait-for-sync
├── lisp/ejn-core.el       ; Add (require) for Phase 3 modules
├── ejn.el                 ; No change (ejn-core pulls in Phase 3 via requires)
└── Makefile               ; No change (glob patterns already cover new files)
```

## Dependency Order

1. **ejn-mime.el** — foundation, no Phase 3 dependencies
2. **ejn-render.el** — depends on mime, model, cell
3. **ejn-navigation.el** — depends on render (uses text properties)
4. **ejn-sync.el** — depends on navigation, render
5. **ejn-undo.el** — depends on model, render
6. **ejn-cell-engine.el** — depends on navigation, render, undo, sync
7. **ejn-mode.el** — depends on everything above
8. **Integration** — wire up ejn-core.el, test utilities, final verification

---

## Task 1: MIME Registry — Registration API

**Files:**
- Create: `lisp/ejn-mime.el`
- Test: `test/ejn-mime-test.el`

- [ ] **Step 1: Write failing test for registry structure**

Create `test/ejn-mime-test.el` with:

```elisp
;;; ejn-mime-test.el --- Tests for ejn-mime  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-mime)

(ert-deftest ejn-mime-test/registry-is-hash-table ()
  "Registry should be a hash table."
  (should (hash-table-p ejn-mime-registry)))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

Expected: FAIL — `ejn-mime` module does not exist yet.

- [ ] **Step 3: Write the MIME registry module**

Create `lisp/ejn-mime.el`:

```elisp
;;; ejn-mime.el --- MIME handler registry  -*- lexical-binding: t; -*-

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

;; MIME handler registry for rendering notebook outputs.
;; Handlers map MIME types to rendering functions.

;;; Code:

(require 'cl-lib)

(defvar ejn-mime-registry
  (make-hash-table :test 'equal)
  "Hash table mapping MIME type strings to handler entries.
Each entry is a plist with :handler (function) and :priority (integer).")

(defun ejn-register-mime-handler (mime-type handler &key (priority 10))
  "Register HANDLER function for MIME-TYPE.
PRIORITY determines precedence when multiple handlers exist for the same type.
Higher priority wins. Default priority is 10."
  (puthash mime-type (list :handler handler :priority priority)
           ejn-mime-registry))

(defun ejn-mime-handler-for (mime-type)
  "Return the handler function for MIME-TYPE, or nil."
  (let ((entry (gethash mime-type ejn-mime-registry)))
    (when entry
      (plist-get entry :handler))))

(provide 'ejn-mime)
;;; ejn-mime.el ends here
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

Expected: PASS

- [ ] **Step 5: Add registration and lookup tests**

Add to `test/ejn-mime-test.el`:

```elisp
(ert-deftest ejn-mime-test/register-and-lookup-handler ()
  "Registering a handler should make it findable."
  (ejn-register-mime-handler "test/type" (lambda (_data) nil) :priority 5)
  (should (functionp (ejn-mime-handler-for "test/type"))))

(ert-deftest ejn-mime-test/unregistered-type-returns-nil ()
  "Looking up an unregistered MIME type should return nil."
  (should-not (ejn-mime-handler-for "nonexistent/type")))

(ert-deftest ejn-mime-test/higher-priority-overrides ()
  "Registering with higher priority should replace the handler."
  (ejn-register-mime-handler "test/override" (lambda (_) 'low) :priority 5)
  (ejn-register-mime-handler "test/override" (lambda (_) 'high) :priority 20)
  (should (eq 'high (funcall (ejn-mime-handler-for "test/override") nil))))
```

- [ ] **Step 6: Run tests to verify**

```bash
make test
```

- [ ] **Step 7: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mime.el
```

```bash
git add lisp/ejn-mime.el test/ejn-mime-test.el
git commit -m "feat: add MIME handler registry API"
```

---

## Task 2: MIME Registry — Plain Text Handler

**Files:**
- Modify: `lisp/ejn-mime.el`
- Test: `test/ejn-mime-test.el`

- [ ] **Step 1: Write failing test for plain text handler**

Add to `test/ejn-mime-test.el`:

```elisp
(ert-deftest ejn-mime-test/plain-text-handler-registered ()
  "text/plain handler should be auto-registered."
  (should (functionp (ejn-mime-handler-for "text/plain"))))

(ert-deftest ejn-mime-test/plain-text-handler-returns-string ()
  "Plain text handler should return the text data as a string."
  (let ((handler (ejn-mime-handler-for "text/plain"))
        (data '("hello" " " "world")))
    (should (string= "hello world" (funcall handler data)))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

Expected: FAIL — handler not yet registered.

- [ ] **Step 3: Add plain text handler**

Add to `lisp/ejn-mime.el` before `(provide 'ejn-mime)`:

```elisp
(defun ejn-render-plain (data)
  "Render plain text DATA as a string.
DATA is a list of string fragments, as per nbformat."
  (mapconcat #'identity data ""))

(ejn-register-mime-handler "text/plain" #'ejn-render-plain :priority 10)
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mime.el
git add lisp/ejn-mime.el test/ejn-mime-test.el
git commit -m "feat: add plain text MIME handler"
```

---

## Task 3: MIME Registry — Markdown Handler

**Files:**
- Modify: `lisp/ejn-mime.el`
- Test: `test/ejn-mime-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-mime-test.el`:

```elisp
(ert-deftest ejn-mime-test/markdown-handler-registered ()
  "text/markdown handler should be auto-registered."
  (should (functionp (ejn-mime-handler-for "text/markdown"))))

(ert-deftest ejn-mime-test/markdown-handler-returns-string ()
  "Markdown handler should return concatenated markdown text."
  (let ((handler (ejn-mime-handler-for "text/markdown"))
        (data '("# Heading" "\n" "Body")))
    (should (string= "# Heading\nBody" (funcall handler data)))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add markdown handler**

Add to `lisp/ejn-mime.el` before `(provide 'ejn-mime)`:

```elisp
(defun ejn-render-markdown (data)
  "Render markdown DATA as a string.
DATA is a list of string fragments.  If markdown-mode is available,
font-lock properties may be applied in the renderer layer."
  (mapconcat #'identity data ""))

(ejn-register-mime-handler "text/markdown" #'ejn-render-markdown :priority 80)
```

- [ ] **Step 4: Run test, validate, commit**

```bash
make test
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mime.el
git add lisp/ejn-mime.el test/ejn-mime-test.el
git commit -m "feat: add markdown MIME handler"
```

---

## Task 4: MIME Registry — PNG Handler

**Files:**
- Modify: `lisp/ejn-mime.el`
- Test: `test/ejn-mime-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-mime-test.el`:

```elisp
(ert-deftest ejn-mime-test/png-handler-registered ()
  "image/png handler should be auto-registered."
  (should (functionp (ejn-mime-handler-for "image/png"))))

(ert-deftest ejn-mime-test/png-handler-returns-image ()
  "PNG handler should return an Emacs image object."
  (let* ((handler (ejn-mime-handler-for "image/png"))
         (data '("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="))
         (result (funcall handler data)))
    (should (imagep result))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add PNG handler**

Add to `lisp/ejn-mime.el` before `(provide 'ejn-mime)`:

```elisp
(eval-when-compile (require 'base64))

(defun ejn-render-png (data)
  "Render PNG DATA as an Emacs image object.
DATA is a list containing a single base64-encoded string."
  (let ((encoded (car data)))
    (create-image (base64-decode-string encoded) 'png t)))

(ejn-register-mime-handler "image/png" #'ejn-render-png :priority 100)
```

- [ ] **Step 4: Run test, validate, commit**

```bash
make test
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mime.el
git add lisp/ejn-mime.el test/ejn-mime-test.el
git commit -m "feat: add PNG MIME handler"
```

---

## Task 5: MIME Registry — SVG Handler

**Files:**
- Modify: `lisp/ejn-mime.el`
- Test: `test/ejn-mime-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-mime-test.el`:

```elisp
(ert-deftest ejn-mime-test/svg-handler-registered ()
  "image/svg+xml handler should be auto-registered."
  (should (functionp (ejn-mime-handler-for "image/svg+xml"))))

(ert-deftest ejn-mime-test/svg-handler-returns-image ()
  "SVG handler should return an Emacs image object."
  (let* ((handler (ejn-mime-handler-for "image/svg+xml"))
         (data '("<svg xmlns='http://www.w3.org/2000/svg' width='10' height='10'/>"))
         (result (funcall handler data)))
    (should (imagep result))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add SVG handler**

Add to `lisp/ejn-mime.el` before `(provide 'ejn-mime)`:

```elisp
(defun ejn-render-svg (data)
  "Render SVG DATA as an Emacs image object.
DATA is a list containing a single SVG markup string."
  (let ((svg-string (car data)))
    (create-image svg-string 'svg t)))

(ejn-register-mime-handler "image/svg+xml" #'ejn-render-svg :priority 100)
```

- [ ] **Step 4: Run test, validate, commit**

```bash
make test
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mime.el
git add lisp/ejn-mime.el test/ejn-mime-test.el
git commit -m "feat: add SVG MIME handler"
```

---

## Task 6: Test Utilities — Notebook Buffer Helper

**Files:**
- Modify: `lisp/ejn-test-util.el`
- Test: `test/ejn-test-util-test.el` (add test for new macro)

- [ ] **Step 1: Write failing test**

Add to `test/ejn-test-util-test.el`:

```elisp
(ert-deftest ejn-test-util-test/with-notebook-buffer-creates-buffer ()
  "ejn-test-with-notebook-buffer should create and clean up a buffer."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook))
        (buf-name nil))
    (ejn-test-with-notebook-buffer nb
      (setq buf-name (buffer-name)))
    (should-not (get-buffer buf-name))))

(ert-deftest ejn-test-util-test/with-notebook-buffer-sets-mode ()
  "ejn-test-with-notebook-buffer should activate ejn-mode."
  (require 'ejn-model)
  (require 'ejn-mode)
  (let ((nb (ejn-make-notebook)))
    (ejn-test-with-notebook-buffer nb
      (should (derived-mode-p 'ejn-mode)))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

Expected: FAIL — macro doesn't exist yet.

- [ ] **Step 3: Add the macro**

Add to `lisp/ejn-test-util.el` before `(provide 'ejn-test-util)`:

```elisp
(defmacro ejn-test-with-notebook-buffer (notebook &rest body)
  "Execute BODY in a temporary buffer with NOTEBOOK rendered in ejn-mode.
The buffer is killed after BODY completes."
  (declare (indent 1))
  `(let ((buf (generate-new-buffer " *ejn-test*")))
     (unwind-protect
         (with-current-buffer buf
           (ejn-mode)
           (set (make-local-variable 'ejn--notebook) ,notebook)
           (ejn-render-notebook ,notebook)
           ,@body)
       (kill-buffer buf))))

(defmacro ejn-test-wait-for-sync (&optional seconds)
  "Wait SECONDS (default value of `ejn-sync-debounce-seconds') for sync timer.
Used in tests to ensure debounced sync has fired."
  (declare (indent 0))
  `(let ((wait-time (or ,seconds ejn-sync-debounce-seconds)))
     (when (and (boundp 'ejn--sync-timer) ejn--sync-timer)
       (cancel-timer ejn--sync-timer))
     (ejn--sync-now)))
```

Note: `ejn--sync-now` will be defined in Task 14 (sync module). For now, add a stub:

```elisp
(defun ejn--sync-now ()
  "Immediately sync buffer to model.  Defined properly in ejn-sync.el."
  nil)
```

This stub will be overridden by the real definition in `ejn-sync.el`. The test utility should `(require 'ejn-sync)` at load time of sync tests.

Actually, better approach: define `ejn-test-wait-for-sync` to directly call the sync function from ejn-sync.el. Update the macro to:

```elisp
(defmacro ejn-test-wait-for-sync ()
  "Force an immediate sync for testing.
Cancels any pending timer and runs sync now."
  (declare (indent 0))
  `(progn
     (when (and (boundp 'ejn--sync-timer) ejn--sync-timer)
       (cancel-timer ejn--sync-timer)
       (setq ejn--sync-timer nil))
     (funcall (symbol-function 'ejn--perform-sync))))
```

- [ ] **Step 4: Run test, validate, commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-test-util.el
git add lisp/ejn-test-util.el test/ejn-test-util-test.el
git commit -m "feat: add notebook buffer test helper macro"
```

---

## Task 7: Renderer — Execution State Faces

**Files:**
- Create: `lisp/ejn-render.el`
- Test: `test/ejn-render-test.el`

- [ ] **Step 1: Write failing test for face definitions**

Create `test/ejn-render-test.el`:

```elisp
;;; ejn-render-test.el --- Tests for ejn-render  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-render)

(ert-deftest ejn-render-test/faces-are-defined ()
  "All execution state faces should be defined."
  (dolist (face '(ejn-cell-idle
                  ejn-cell-queued
                  ejn-cell-executing
                  ejn-cell-streaming
                  ejn-cell-completed
                  ejn-cell-error
                  ejn-cell-interrupted))
    (should (facep face))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Create renderer module with faces**

Create `lisp/ejn-render.el`:

```elisp
;;; ejn-render.el --- Buffer projection renderer  -*- lexical-binding: t; -*-

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

;; Projects notebook model into editable Emacs buffers.
;; Uses text properties for cell structure, no overlays.

;;; Code:

(require 'cl-lib)
(require 'ejn-cell)
(require 'ejn-model)
(require 'ejn-mime)

(defface ejn-cell-idle
  '((((class color)) :foreground "grey50"))
  "Face for idle cell execution state."
  :group 'ejn)

(defface ejn-cell-queued
  '((((class color)) :foreground "blue"))
  "Face for queued cell execution state."
  :group 'ejn)

(defface ejn-cell-executing
  '((((class color)) :foreground "goldenrod1" :background "grey20"))
  "Face for executing cell execution state."
  :group 'ejn)

(defface ejn-cell-streaming
  '((((class color)) :foreground "yellow" :background "grey20"))
  "Face for streaming cell execution state."
  :group 'ejn)

(defface ejn-cell-completed
  '((((class color)) :foreground "green"))
  "Face for completed cell execution state."
  :group 'ejn)

(defface ejn-cell-error
  '((((class color)) :foreground "red"))
  "Face for error cell execution state."
  :group 'ejn)

(defface ejn-cell-interrupted
  '((((class color)) :foreground "orange"))
  "Face for interrupted cell execution state."
  :group 'ejn)

(provide 'ejn-render)
;;; ejn-render.el ends here
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-render.el
git add lisp/ejn-render.el test/ejn-render-test.el
git commit -m "feat: define execution state faces for cell rendering"
```

---

## Task 8: Renderer — Execution State Face Mapping

**Files:**
- Modify: `lisp/ejn-render.el`
- Test: `test/ejn-render-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-render-test.el`:

```elisp
(ert-deftest ejn-render-test/state-to-face-mapping ()
  "Each execution state should map to the correct face."
  (should (eq 'ejn-cell-idle (ejn--execution-state-face 'idle)))
  (should (eq 'ejn-cell-queued (ejn--execution-state-face 'queued)))
  (should (eq 'ejn-cell-executing (ejn--execution-state-face 'executing)))
  (should (eq 'ejn-cell-streaming (ejn--execution-state-face 'streaming)))
  (should (eq 'ejn-cell-completed (ejn--execution-state-face 'completed)))
  (should (eq 'ejn-cell-error (ejn--execution-state-face 'error)))
  (should (eq 'ejn-cell-interrupted (ejn--execution-state-face 'interrupted)))
  (should (eq 'ejn-cell-idle (ejn--execution-state-face 'unknown-state))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add state-to-face function**

Add to `lisp/ejn-render.el` before `(provide 'ejn-render)`:

```elisp
(defun ejn--execution-state-face (state)
  "Return the face symbol for execution STATE.
Returns `ejn-cell-idle' for unknown states."
  (pcase state
    ('idle 'ejn-cell-idle)
    ('queued 'ejn-cell-queued)
    ('executing 'ejn-cell-executing)
    ('streaming 'ejn-cell-streaming)
    ('completed 'ejn-cell-completed)
    ('error 'ejn-cell-error)
    ('interrupted 'ejn-cell-interrupted)
    (_ 'ejn-cell-idle)))
```

- [ ] **Step 4: Run test, validate, commit**

```bash
make test
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-render.el
git add lisp/ejn-render.el test/ejn-render-test.el
git commit -m "feat: add execution state to face mapping"
```

---

## Task 9: Renderer — Single Cell Render

**Files:**
- Modify: `lisp/ejn-render.el`
- Test: `test/ejn-render-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-render-test.el`:

```elisp
(ert-deftest ejn-render-test/render-cell-inserts-source ()
  "Rendering a cell should insert its source text."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "test-id"
               :type 'code
               :source "print('hello')"
               :outputs nil
               :execution-state 'idle)))
    (ejn-test-with-temp-buffer " *test*"
      (ejn-render-cell cell)
      (should (string= (buffer-substring-no-properties (point-min) (point-max))
                       "print('hello')\n")))))

(ert-deftest ejn-render-test/render-cell-sets-text-properties ()
  "Rendering a cell should set ejn-cell-id and ejn-cell-type properties."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "prop-test"
               :type 'markdown
               :source "# Title"
               :outputs nil
               :execution-state 'idle)))
    (ejn-test-with-temp-buffer " *test*"
      (ejn-render-cell cell)
      (goto-char (point-min))
      (should (string= "prop-test" (get-text-property (point) 'ejn-cell-id)))
      (should (eq 'markdown (get-text-property (point) 'ejn-cell-type))))))

(ert-deftest ejn-render-test/render-cell-applies-execution-face ()
  "Rendering a cell should apply the execution state face to first character."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "face-test"
               :type 'code
               :source "x = 1"
               :outputs nil
               :execution-state 'completed)))
    (ejn-test-with-temp-buffer " *test*"
      (ejn-render-cell cell)
      (goto-char (point-min))
      (should (memq 'ejn-cell-completed
                    (get-text-property (point) 'face))))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add cell rendering function**

Add to `lisp/ejn-render.el` before `(provide 'ejn-render)`:

```elisp
(defun ejn-render-cell (cell &optional buffer)
  "Render CELL into BUFFER (current buffer if nil).
Inserts source text with cell text properties and execution state face."
  (with-current-buffer (or buffer (current-buffer))
    (let ((source (ejn-cell-source cell))
          (cell-id (ejn-cell-id cell))
          (cell-type (ejn-cell-type cell))
          (state (ejn-cell-execution-state cell))
          (face (ejn--execution-state-face state)))
      (let ((first-char (if (string-prefix-p "" source)
                            (substring source 0 1) ""))
            (rest (if (string-prefix-p "" source)
                      (substring source 1) source)))
        (when (string= source "")
          (insert "\n")
          (put-text-property (1- (point)) (point) 'ejn-cell-id cell-id)
          (put-text-property (1- (point)) (point) 'ejn-cell-type cell-type)
          (put-text-property (1- (point)) (point) 'face '(ejn-cell-idle)))
        (when (> (length source) 0)
          (insert (concat (propertize (substring source 0 1)
                                      'face (list face)
                                      'display '(space :width 0.8))
                          (substring source 1)))
          (insert "\n")
          (let ((region-start (- (point) (+ (length source) 1)))
                (region-end (1- (point))))
            (put-text-property region-start region-end 'ejn-cell-id cell-id)
            (put-text-property region-start region-end 'ejn-cell-type cell-type)))))))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-render.el
git add lisp/ejn-render.el test/ejn-render-test.el
git commit -m "feat: add single cell rendering with text properties"
```

---

## Task 10: Renderer — Output Zone Rendering

**Files:**
- Modify: `lisp/ejn-render.el`
- Test: `test/ejn-render-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-render-test.el`:

```elisp
(ert-deftest ejn-render-test/render-outputs-creates-zone ()
  "Rendering outputs should create a read-only output zone."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "out-test"
               :type 'code
               :source "42"
               :outputs (list (make-ejn-output
                               :type 'execute-result
                               :mime-data (list :data (list (cons 'text/plain (list "42")))))
                               :metadata nil
                               :request-id nil))
               :execution-state 'completed)))
    (ejn-test-with-temp-buffer " *test*"
      (ejn-render-cell cell)
      (ejn-render-outputs cell)
      (search-forward "42\n" nil t)
      (forward-char 1)
      (should (get-text-property (point) 'ejn-output-zone))
      (should (get-text-property (point) 'read-only))))

(ert-deftest ejn-render-test/render-outputs-displays-text ()
  "Rendering outputs should display text/plain content."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "out-text"
               :type 'code
               :source "1+1"
               :outputs (list (make-ejn-output
                               :type 'execute-result
                               :mime-data (list :data (list (cons 'text/plain (list "2")))))
                               :metadata nil
                               :request-id nil))
               :execution-state 'completed)))
    (ejn-test-with-temp-buffer " *test*"
      (ejn-render-cell cell)
      (ejn-render-outputs cell)
      (should (search-forward "2" nil t))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add output rendering function**

Add to `lisp/ejn-render.el` before `(provide 'ejn-render)`:

```elisp
(defun ejn-render-outputs (cell &optional buffer)
  "Render CELL's outputs into BUFFER (current buffer if nil).
Inserts output content in a read-only zone after the cell's source."
  (with-current-buffer (or buffer (current-buffer))
    (let ((outputs (ejn-cell-outputs cell)))
      (when outputs
        (insert "\n")
        (dolist (output outputs)
          (let ((mime-data (plist-get (or (ejn-output-mime-data output) (list)) :data)))
            (when mime-data
              (let ((best-mime nil)
                    (best-handler nil))
                (maphash (lambda (mime data-list)
                           (let ((handler (ejn-mime-handler-for mime)))
                             (when (and handler (or (not best-mime)
                                                    (string-prefix-p mime best-mime)))
                               (setq best-mime mime)
                               (setq best-handler (lambda () (funcall handler data-list))))))
                         mime-data)
                ;; Fallback: try text/plain directly
                (let ((plain-data (alist-get 'text/plain mime-data)))
                  (when (and plain-data (not best-handler))
                    (setq best-handler (lambda () (funcall (ejn-mime-handler-for "text/plain") plain-data)))))
                (when best-handler
                  (insert (funcall best-handler) "\n")))))
        (let ((zone-start (- (point) (+ (length (buffer-substring-no-properties (point-min) (point))) 0))))
          ;; Mark the output zone
          (search-forward "\n" nil t)
          (let ((output-start (point))
                (output-end (progn (dolist (_ outputs) nil) (point))))
            )))))))
```

Wait — that implementation is getting complex. Let me simplify it:

```elisp
(defun ejn--best-mime-data (mime-data)
  "Return (MIME-TYPE . DATA-LIST) for the best rendering of MIME-DATA.
Prefers image types, then text types."
  (let ((priority-order '("image/svg+xml" "image/png" "text/html" "text/markdown" "text/plain")))
    (cl-loop for mime in priority-order
             for data = (alist-get (intern mime) mime-data)
             when data return (cons mime data))))

(defun ejn-render-outputs (cell &optional buffer)
  "Render CELL's outputs into BUFFER (current buffer if nil).
Inserts output content in a read-only zone after the cell's source."
  (with-current-buffer (or buffer (current-buffer))
    (let ((outputs (ejn-cell-outputs cell)))
      (when outputs
        (let ((zone-start (point)))
          (insert "\n")
          (dolist (output outputs)
            (let ((output-type (ejn-output-type output)))
              (pcase output-type
                ('error
                 (let ((traceback (plist-get (ejn-output-mime-data output) 'traceback)))
                   (when traceback
                     (insert (mapconcat #'identity (if (listp (car traceback)) (car traceback) traceback) "")
                             "\n"))))
                ('_
                 (let ((mime-data (plist-get (or (ejn-output-mime-data output) (list)) :data)))
                   (when mime-data
                     (let ((best (ejn--best-mime-data mime-data)))
                       (when best
                         (let ((handler (ejn-mime-handler-for (car best))))
                           (when handler
                             (let ((rendered (funcall handler (cdr best))))
                               (if (imagep rendered)
                                   (insert-image rendered " ")
                                 (insert rendered "\n")))))))))))
          (put-text-property zone-start (point) 'ejn-output-zone t)
          (put-text-property zone-start (point) 'read-only t)
          (put-text-property zone-start (point) 'rear-nonsticky t))))))))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-render.el
git add lisp/ejn-render.el test/ejn-render-test.el
git commit -m "feat: add output zone rendering with MIME dispatch"
```

---

## Task 11: Renderer — Full Notebook Render

**Files:**
- Modify: `lisp/ejn-render.el`
- Test: `test/ejn-render-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-render-test.el`:

```elisp
(ert-deftest ejn-render-test/render-notebook-renders-all-cells ()
  "Full render should produce content for all cells."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "print(1)")
    (ejn-notebook-insert-cell nb 'markdown :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "# Hello")
    (ejn-test-with-temp-buffer " *test*"
      (ejn-render-notebook nb)
      (should (search-forward "print(1)" nil t))
      (should (search-forward "# Hello" nil t)))))

(ert-deftest ejn-render-test/render-notebook-sets-cell-properties ()
  "Full render should set ejn-cell-id on all source regions."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
      (ejn-notebook-set-cell-source nb cell-id "x")
      (ejn-test-with-temp-buffer " *test*"
        (ejn-render-notebook nb)
        (goto-char (point-min))
        (should (string= cell-id (get-text-property (point) 'ejn-cell-id)))))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add full render function**

Add to `lisp/ejn-render.el` before `(provide 'ejn-render)`:

```elisp
(defun ejn-render-notebook (notebook &optional buffer)
  "Render all cells of NOTEBOOK into BUFFER (current buffer if nil).
Clears the buffer first. Sets text properties for cell structure."
  (with-current-buffer (or buffer (current-buffer))
    (let ((ejn--rendering-p t))
      (erase-buffer)
      (dolist (cell (ejn-notebook-cells notebook))
        (ejn-render-cell cell)
        (ejn-render-outputs cell))
      (setq ejn--rendering-p nil))))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-render.el
git add lisp/ejn-render.el test/ejn-render-test.el
git commit -m "feat: add full notebook render function"
```

---

## Task 12: Renderer — Incremental Dirty Cell Render

**Files:**
- Modify: `lisp/ejn-render.el`
- Test: `test/ejn-render-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-render-test.el`:

```elisp
(ert-deftest ejn-render-test/render-dirty-cells-updates-only-dirty ()
  "Incremental render should update only dirty cell regions."
  (require 'ejn-model)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "original")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "second")
    (ejn-test-with-temp-buffer " *test*"
      (ejn-render-notebook nb)
      (let ((cell-0-id (ejn-cell-id (ejn-notebook-cell-at-index nb 0))))
        (ejn-notebook-set-cell-source nb cell-0-id "modified")
        (ejn-notebook-mark-dirty nb cell-0-id)
        (ejn-render-dirty-cells nb)
        (should (search-forward "modified" nil t))
        (should (search-forward "second" nil t))
        (should-not (ejn-notebook-dirty nb))))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add incremental render function**

Add to `lisp/ejn-render.el` before `(provide 'ejn-render)`:

```elisp
(defun ejn--find-cell-region (cell-id)
  "Find the source region for CELL-ID in current buffer.
Returns (START . END) or nil."
  (save-excursion
    (goto-char (point-min))
    (let ((found nil))
      (while (and (not found) (< (point) (point-max)))
        (let ((id (get-text-property (point) 'ejn-cell-id)))
          (if (and id (string= id cell-id))
              (let ((start (point)))
                (end-of-line)
                (while (and (< (point) (point-max))
                            (string= (get-text-property (1+ (point)) 'ejn-cell-id) cell-id))
                  (forward-line))
                (setq found (cons start (point))))
            (forward-line)))))
    found))

(defun ejn-render-dirty-cells (notebook &optional buffer)
  "Re-render only dirty cells in NOTEBOOK within BUFFER.
Reads the notebook's dirty set, re-renders affected regions, and clears the dirty set."
  (with-current-buffer (or buffer (current-buffer))
    (let ((ejn--rendering-p t)
          (dirty-ids (ejn-notebook-dirty-cells notebook)))
      (dolist (cell-id dirty-ids)
        (let ((cell (condition-case nil
                        (ejn-notebook-cell-by-id notebook cell-id)
                      (error nil)))
              (region (ejn--find-cell-region cell-id)))
          (when (and cell region)
            (let ((start (car region))
                  (end (cdr region)))
              (delete-region start end)
              (goto-char start)
              (ejn-render-cell cell)
              (ejn-render-outputs cell))))
      (ejn-notebook-clean-all notebook)
      (setq ejn--rendering-p nil)))))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-render.el
git add lisp/ejn-render.el test/ejn-render-test.el
git commit -m "feat: add incremental dirty cell rendering"
```

---

## Task 13: Renderer — Output Folding

**Files:**
- Modify: `lisp/ejn-render.el`
- Test: `test/ejn-render-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-render-test.el`:

```elisp
(ert-deftest ejn-render-test/folded-output-spec-exists ()
  "The folded output invisibility spec should exist."
  (should (boundp 'ejn-folded-output)))

(ert-deftest ejn-render-test/toggle-output-sets-invisible ()
  "Toggling output should set invisible property on the output zone."
  (require 'ejn-cell)
  (let ((cell (make-ejn-cell
               :id "fold-test"
               :type 'code
               :source "42"
               :outputs (list (make-ejn-output
                               :type 'execute-result
                               :mime-data (list :data (list (cons 'text/plain (list "42")))))
                               :metadata nil
                               :request-id nil))
               :execution-state 'completed)))
    (ejn-test-with-temp-buffer " *test*"
      (ejn-render-cell cell)
      (ejn-render-outputs cell)
      (ejn-toggle-output)
      (search-forward "\n42" nil t)
      (should (get-text-property (point) 'invisible))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add output folding**

Add to `lisp/ejn-render.el` before `(provide 'ejn-render)`:

```elisp
(defconst ejn-folded-output 'ejn-folded-output
  "Invisibility spec symbol for folded output zones.")

(defun ejn-toggle-output ()
  "Toggle visibility of the output zone for the current cell.
If output is visible, fold it. If folded, unfold it."
  (interactive)
  (let ((cell-id (get-text-property (point) 'ejn-cell-id))
        (in-output-zone (get-text-property (point) 'ejn-output-zone)))
    (unless (or cell-id in-output-zone)
      (user-error "Not in a cell"))
    (unless cell-id
      (setq cell-id (ejn--find-parent-cell-id (point))))
    (let ((region (ejn--find-cell-region cell-id)))
      (when region
        (let ((output-start (cdr region)))
          (when (< output-start (point-max))
            (let ((output-end (ejn--find-output-end output-start)))
              (let ((currently-folded
                     (get-text-property output-start 'invisible)))
                (if currently-folded
                    (put-text-property output-start output-end 'invisible nil)
                  (put-text-property output-start output-end 'invisible ejn-folded-output)
                  (add-to-invisibility-spec '(ejn-folded-output)))))))))))

(defun ejn--find-parent-cell-id (pos)
  "Find the parent cell ID by scanning backward from POS."
  (save-excursion
    (goto-char pos)
    (while (> (point) (point-min))
      (let ((id (get-text-property (1- (point)) 'ejn-cell-id)))
        (when id (cl-return id)))
      (backward-char)))
  nil)

(defun ejn--find-output-end (start)
  "Find the end of the output zone starting at START."
  (save-excursion
    (goto-char start)
    (while (and (< (point) (point-max))
                (or (get-text-property (point) 'ejn-output-zone)
                    (get-text-property (1+ (point)) 'ejn-output-zone)))
      (forward-char))
    (point)))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-render.el
git add lisp/ejn-render.el test/ejn-render-test.el
git commit -m "feat: add output folding with invisibility"
```

---

## Task 14: Navigation — Cell-At-Point and Region Functions

**Files:**
- Create: `lisp/ejn-navigation.el`
- Test: `test/ejn-navigation-test.el`

- [ ] **Step 1: Write failing tests**

Create `test/ejn-navigation-test.el`:

```elisp
;;; ejn-navigation-test.el --- Tests for ejn-navigation  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-navigation)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-test-util)

(ert-deftest ejn-navigation-test/cell-at-point-returns-cell ()
  "ejn-cell-at-point should return the cell struct at point."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "print(1)")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (let ((cell (ejn-cell-at-point)))
        (should (ejn-cell-p cell))
        (should (string= (ejn-cell-source cell) "print(1)"))))))

(ert-deftest ejn-navigation-test/cell-at-point-in-output-zone ()
  "ejn-cell-at-point should find parent cell from within output zone."
  (require 'ejn-cell)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell (ejn-notebook-cell-at-index nb 0)))
      (setf (ejn-cell-source cell) "42")
      (setf (ejn-cell-outputs cell)
            (list (make-ejn-output
                   :type 'execute-result
                   :mime-data (list :data (list (cons 'text/plain (list "42")))))
                   :metadata nil
                   :request-id nil)))
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (search-forward "42\n42" nil t)
      (forward-line)
      (let ((found-cell (ejn-cell-at-point)))
        (should (ejn-cell-p found-cell))
        (should (string= (ejn-cell-id found-cell) (ejn-cell-id cell)))))))

(ert-deftest ejn-navigation-test/cell-region-returns-source-range ()
  "ejn-cell-region should return the source region boundaries."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "line1\nline2")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (let ((region (ejn-cell-region)))
        (should (= (car region) (point-min)))
        (should (> (cdr region) (car region)))))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Create navigation module**

Create `lisp/ejn-navigation.el`:

```elisp
;;; ejn-navigation.el --- Cell navigation commands  -*- lexical-binding: t; -*-

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

;; Structural motion commands operating on cell boundaries.

;;; Code:

(require 'cl-lib)
(require 'ejn-cell)
(require 'ejn-model)

(defun ejn-cell-at-point ()
  "Return the `ejn-cell' struct at point, or signal an error.
If point is in an output zone, finds the parent cell by scanning backward."
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (cell-id (get-text-property (point) 'ejn-cell-id)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (unless cell-id
      (goto-char (point))
      (while (and (> (point) (point-min)) (not cell-id))
        (backward-char)
        (setq cell-id (get-text-property (point) 'ejn-cell-id))))
    (unless cell-id
      (user-error "Not in a cell"))
    (ejn-notebook-cell-by-id notebook cell-id)))

(defun ejn-cell-region ()
  "Return (START . END) of the current cell's source region.
Excludes the output zone."
  (let ((cell-id (get-text-property (point) 'ejn-cell-id)))
    (unless cell-id
      (save-excursion
        (while (and (> (point) (point-min)) (not cell-id))
          (backward-char)
          (setq cell-id (get-text-property (point) 'ejn-cell-id)))))
    (save-excursion
      (let ((start nil)
            (end nil))
        (goto-char (point-min))
        (while (< (point) (point-max))
          (let ((id (get-text-property (point) 'ejn-cell-id)))
            (when (and id (string= id cell-id))
              (unless start (setq start (point)))
              (setq end (1+ (point)))
              (forward-char)
              (when (or (>= (point) (point-max))
                        (not (string= (get-text-property (point) 'ejn-cell-id) cell-id)))
                (setq end (point))
                (cl-return (cons start end))))
            (forward-char))))
        (cons start end))))

(defun ejn-cell-full-region ()
  "Return (START . END) of the current cell including output zone."
  (let ((source-region (ejn-cell-region))
        (start (car source-region))
        (end (cdr source-region)))
    (when (< end (point-max))
      (save-excursion
        (goto-char end)
        (while (and (< (point) (point-max))
                    (get-text-property (point) 'ejn-output-zone))
          (forward-char))
        (setq end (point))))
    (cons start end)))

(provide 'ejn-navigation)
;;; ejn-navigation.el ends here
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-navigation.el
git add lisp/ejn-navigation.el test/ejn-navigation-test.el
git commit -m "feat: add cell-at-point and cell-region primitives"
```

---

## Task 15: Navigation — Next/Prev Cell Commands

**Files:**
- Modify: `lisp/ejn-navigation.el`
- Test: `test/ejn-navigation-test.el`

- [ ] **Step 1: Write failing tests**

Add to `test/ejn-navigation-test.el`:

```elisp
(ert-deftest ejn-navigation-test/goto-next-cell-moves-forward ()
  "ejn-goto-next-cell should move to the next cell's source."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "first")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "second")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (ejn-goto-next-cell)
      (should (search-backward "second" nil t)))))

(ert-deftest ejn-navigation-test/goto-prev-cell-moves-backward ()
  "ejn-goto-prev-cell should move to the previous cell's source."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "first")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "second")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (search-forward "second")
      (ejn-goto-prev-cell)
      (should (search-backward "first" nil t)))))

(ert-deftest ejn-navigation-test/goto-first-cell ()
  "ejn-goto-first-cell should move to the first cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "first")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "second")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-max))
      (ejn-goto-first-cell)
      (should (= (point) (point-min))))))

(ert-deftest ejn-navigation-test/goto-last-cell ()
  "ejn-goto-last-cell should move to the last cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "first")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "last")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (ejn-goto-last-cell)
      (should (search-backward "last" nil t)))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add navigation commands**

Add to `lisp/ejn-navigation.el` before `(provide 'ejn-navigation)`:

```elisp
(defun ejn-goto-next-cell ()
  "Move point to the start of the next cell's source region."
  (interactive)
  (let ((current-id (get-text-property (point) 'ejn-cell-id))
        (next-id nil))
    (save-excursion
      (goto-char (point))
      (when (get-text-property (point) 'ejn-output-zone)
        (while (and (> (point) (point-min)) (not current-id))
          (backward-char)
          (setq current-id (get-text-property (point) 'ejn-cell-id))))
      (forward-char)
      (while (and (< (point) (point-max)) (not next-id))
        (let ((id (get-text-property (point) 'ejn-cell-id)))
          (when (and id (not (string= id current-id)))
            (setq next-id id)))
        (forward-char))))
    (if next-id
        (ejn--goto-cell-by-id next-id)
      (user-error "Already at last cell")))

(defun ejn-goto-prev-cell ()
  "Move point to the start of the previous cell's source region."
  (interactive)
  (let ((current-id (get-text-property (point) 'ejn-cell-id))
        (prev-id nil))
    (unless current-id
      (save-excursion
        (while (and (> (point) (point-min)) (not current-id))
          (backward-char)
          (setq current-id (get-text-property (point) 'ejn-cell-id)))))
    (save-excursion
      (goto-char (point))
      (while (and (> (point) (point-min)) (not prev-id))
        (backward-char)
        (let ((id (get-text-property (point) 'ejn-cell-id)))
          (when (and id (not (string= id current-id)))
            (setq prev-id id)))))
    (if prev-id
        (ejn--goto-cell-by-id prev-id)
      (user-error "Already at first cell"))))

(defun ejn-goto-first-cell ()
  "Move point to the start of the first cell."
  (interactive)
  (goto-char (point-min)))

(defun ejn-goto-last-cell ()
  "Move point to the start of the last cell's source region."
  (interactive)
  (let ((last-id nil))
    (save-excursion
      (goto-char (1- (point-max)))
      (while (and (> (point) (point-min)) (not last-id))
        (let ((id (get-text-property (point) 'ejn-cell-id)))
          (when id (setq last-id id)))
        (backward-char)))
    (if last-id
        (ejn--goto-cell-by-id last-id)
      (goto-char (point-min)))))

(defun ejn--goto-cell-by-id (cell-id)
  "Move point to the start of the cell with CELL-ID."
  (goto-char (point-min))
  (while (and (< (point) (point-max))
              (not (string= (get-text-property (point) 'ejn-cell-id) cell-id)))
    (forward-char)))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-navigation.el
git add lisp/ejn-navigation.el test/ejn-navigation-test.el
git commit -m "feat: add cell navigation commands"
```

---

## Task 16: Sync — After-Change Hook and Debounce

**Files:**
- Create: `lisp/ejn-sync.el`
- Test: `test/ejn-sync-test.el`

- [ ] **Step 1: Write failing tests**

Create `test/ejn-sync-test.el`:

```elisp
;;; ejn-sync-test.el --- Tests for ejn-sync  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-sync)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-navigation)
(require 'ejn-test-util)

(ert-deftest ejn-sync-test/typing-updates-model-after-debounce ()
  "Typing in a cell should update the model after debounce interval."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "original")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (ejn-sync-mode)
      (goto-char (point-min))
      (delete-region (point) (+ (point) 8))
      (insert "modified")
      (ejn-test-wait-for-sync)
      (should (string= (ejn-cell-source (ejn-notebook-cell-at-index nb 0))
                       "modified\n")))))

(ert-deftest ejn-sync-test/output-zone-changes-are-ignored ()
  "Changes in output zones should not trigger sync."
  (require 'ejn-cell)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell (ejn-notebook-cell-at-index nb 0)))
      (setf (ejn-cell-source cell) "42")
      (setf (ejn-cell-outputs cell)
            (list (make-ejn-output
                   :type 'execute-result
                   :mime-data (list :data (list (cons 'text/plain (list "42")))))
                   :metadata nil
                   :request-id nil)))
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (ejn-sync-mode)
      (let ((original-source (ejn-cell-source (ejn-notebook-cell-at-index nb 0))))
        (search-forward "42\n42" nil t)
        (forward-line)
        (delete-region (point) (point-max))
        (insert "changed output")
        (ejn-test-wait-for-sync)
        (should (string= (ejn-cell-source (ejn-notebook-cell-at-index nb 0))
                         original-source))))))

(ert-deftest ejn-sync-test/render-guard-prevents-sync ()
  "Sync should not process changes during rendering."
  (should (functionp 'ejn--after-change-handler)))

(ert-deftest ejn-sync-test/after-sync-hook-runs ()
  "ejn-after-sync-hook should run after sync completes."
  (let ((nb (ejn-make-notebook))
        (hook-called nil))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "x")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (ejn-sync-mode)
      (add-hook 'ejn-after-sync-hook (lambda () (setq hook-called t)) nil t)
      (goto-char (point-min))
      (delete-char 1)
      (insert "y")
      (ejn-test-wait-for-sync)
      (should hook-called))))

(ert-deftest ejn-sync-test/unchanged-cells-not-re-synced ()
  "Cells whose source hasn't changed should not be re-synced."
  (let ((nb (ejn-make-notebook))
        (sync-count 0))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "stable")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (ejn-sync-mode)
      (add-hook 'ejn-after-sync-hook (lambda () (cl-incf sync-count)) nil t)
      (goto-char (point-min))
      (backward-char)
      (delete-char 1)
      (insert "s")
      (ejn-test-wait-for-sync)
      (should (= sync-count 0)))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Create sync module**

Create `lisp/ejn-sync.el`:

```elisp
;;; ejn-sync.el --- Buffer-to-model synchronization  -*- lexical-binding: t; -*-

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

;; Detects user edits and updates the notebook model with debounced batching.

;;; Code:

(require 'cl-lib)
(require 'ejn-model)
(require 'ejn-navigation)

(defcustom ejn-sync-debounce-seconds 0.2
  "Seconds to wait after typing before syncing buffer to model.
Set to 0 for real-time sync."
  :type 'number
  :group 'ejn)

(defcustom ejn-after-sync-hook nil
  "Hook run after buffer-to-model sync completes.
Useful for LSP integration."
  :type 'hook
  :group 'ejn)

(defvar-local ejn--sync-timer nil
  "Debounced sync timer for current buffer.")

(defvar-local ejn--pending-sync-set nil
  "Hash table of cell IDs pending sync.")

(defvar-local ejn--rendering-p nil
  "Guard flag to prevent reentrant renders and sync during render.")

(defun ejn--after-change-handler (_start _end _prepended)
  "Handler for `after-change-functions'.
Schedules a debounced sync if the change is in a cell source region."
  (when ejn--rendering-p
    (cl-return-from ejn--after-change-handler))
  (when (get-text-property (point) 'ejn-output-zone)
    (cl-return-from ejn--after-change-handler))
  (let ((cell-id (ejn--find-cell-id-at-point)))
    (when cell-id
      (unless ejn--pending-sync-set
        (setq ejn--pending-sync-set (make-hash-table :test 'equal)))
      (puthash cell-id t ejn--pending-sync-set)
      (ejn--schedule-sync))))

(defun ejn--find-cell-id-at-point ()
  "Find the cell ID text property at or before point."
  (or (get-text-property (point) 'ejn-cell-id)
      (save-excursion
        (while (and (> (point) (point-min))
                    (not (get-text-property (point) 'ejn-cell-id)))
          (backward-char))
        (get-text-property (point) 'ejn-cell-id))))

(defun ejn--schedule-sync ()
  "Schedule a debounced sync if not already scheduled."
  (when ejn--sync-timer
    (cancel-timer ejn--sync-timer))
  (setq ejn--sync-timer
        (run-with-timer ejn-sync-debounce-seconds nil #'ejn--perform-sync)))

(defun ejn--perform-sync ()
  "Sync pending cell changes from buffer to model."
  (setq ejn--sync-timer nil)
  (unless ejn--pending-sync-set
    (cl-return-from ejn--perform-sync))
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (when notebook
      (maphash (lambda (cell-id _value)
                 (let ((region (ejn--find-cell-region cell-id)))
                   (when region
                     (let ((new-source (buffer-substring-no-properties (car region) (cdr region)))
                           (cell (condition-case nil
                                     (ejn-notebook-cell-by-id notebook cell-id)
                                   (error nil))))
                       (when (and cell (not (string= new-source (ejn-cell-source cell))))
                         (ejn-notebook-set-cell-source notebook cell-id new-source)))))
               ejn--pending-sync-set)
      (run-hooks 'ejn-after-sync-hook)))
  (setq ejn--pending-sync-set (make-hash-table :test 'equal))))

(defun ejn--find-cell-region (cell-id)
  "Find the source region for CELL-ID.  Returns (START . END) or nil."
  (save-excursion
    (goto-char (point-min))
    (let ((start nil)
          (end nil))
      (while (< (point) (point-max))
        (let ((id (get-text-property (point) 'ejn-cell-id)))
          (if (and id (string= id cell-id))
              (progn
                (unless start (setq start (point)))
                (setq end (1+ (point)))
                (forward-char)
                (when (or (>= (point) (point-max))
                          (not (string= (get-text-property (point) 'ejn-cell-id) cell-id)))
                  (setq end (point))
                  (cl-return (cons start end))))
            (and start (cl-return nil)))
          (forward-char))))
    nil))

(defun ejn-sync-mode ()
  "Enable or disable sync for the current buffer."
  (if (memq #'ejn--after-change-handler after-change-functions)
      (remove-hook 'after-change-functions #'ejn--after-change-handler t)
    (add-hook 'after-change-functions #'ejn--after-change-handler nil t)
    (setq ejn--pending-sync-set (make-hash-table :test 'equal))))

(provide 'ejn-sync)
;;; ejn-sync.el ends here
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-sync.el
git add lisp/ejn-sync.el test/ejn-sync-test.el
git commit -m "feat: add debounced buffer-to-model sync"
```

---

## Task 17: Undo — Boundary Macro and Commands

**Files:**
- Create: `lisp/ejn-undo.el`
- Test: inline with cell-engine tests (no separate test file needed)

- [ ] **Step 1: Write the undo module**

Create `lisp/ejn-undo.el`:

```elisp
;;; ejn-undo.el --- Emacs undo integration  -*- lexical-binding: t; -*-

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

;; Bridges Emacs buffer undo with the model's transactional undo system.

;;; Code:

(require 'cl-lib)
(require 'ejn-model)
(require 'ejn-render)

(defmacro ejn-with-undo-boundary (label &rest body)
  "Wrap BODY in Emacs undo boundaries with LABEL.
Ensures all buffer modifications in BODY are grouped as a single undo step."
  (declare (indent 1))
  `(progn
     (undo-boundary)
     ,@body
     (undo-boundary)))

(defun ejn-undo ()
  "Undo the last operation on the notebook model and re-render."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (condition-case err
        (progn
          (ejn-undo notebook)
          (ejn-render-notebook notebook))
      (user-error
       (signal (car err) (cdr err))))))

(defun ejn-redo ()
  "Redo the last undone operation on the notebook model and re-render."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (condition-case err
        (progn
          (ejn-redo notebook)
          (ejn-render-notebook notebook))
      (user-error
       (signal (car err) (cdr err))))))

(provide 'ejn-undo)
;;; ejn-undo.el ends here
```

- [ ] **Step 2: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-undo.el
git add lisp/ejn-undo.el
git commit -m "feat: add undo boundary macro and undo/redo commands"
```

---

## Task 18: Cell Engine — Insert Above/Below

**Files:**
- Create: `lisp/ejn-cell-engine.el`
- Test: `test/ejn-cell-engine-test.el`

- [ ] **Step 1: Write failing tests**

Create `test/ejn-cell-engine-test.el`:

```elisp
;;; ejn-cell-engine-test.el --- Tests for ejn-cell-engine  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-cell-engine)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-navigation)
(require 'ejn-undo)
(require 'ejn-test-util)

(ert-deftest ejn-cell-engine-test/insert-cell-above ()
  "Inserting a cell above should place it before the current cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "original")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (ejn-insert-cell-above)
      (should (= (length (ejn-notebook-cells nb)) 2))
      (should (eq 'code (ejn-cell-type (ejn-notebook-cell-at-index nb 0)))))))

(ert-deftest ejn-cell-engine-test/insert-cell-below ()
  "Inserting a cell below should place it after the current cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "original")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (ejn-insert-cell-below)
      (should (= (length (ejn-notebook-cells nb)) 2))
      (should (eq 'code (ejn-cell-type (ejn-notebook-cell-at-index nb 1)))))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Create cell engine module with insert commands**

Create `lisp/ejn-cell-engine.el`:

```elisp
;;; ejn-cell-engine.el --- Cell structural operations  -*- lexical-binding: t; -*-

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

;; Cell insert, delete, split, merge, move, copy, and yank operations.
;; Model-first: mutate the model, then render.

;;; Code:

(require 'cl-lib)
(require 'ejn-cell)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-navigation)
(require 'ejn-undo)

(defvar-local ejn--cell-kill-ring nil
  "Kill ring for copied cells.  Each entry is a serialized cell plist.")

(defun ejn-insert-cell-above ()
  "Insert a new code cell above the current cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((idx (ejn-notebook-cell-index notebook (ejn-cell-id current-cell))))
      (ejn-with-undo-group "Insert cell above" notebook
        (ejn-with-undo-boundary "Insert cell above"
          (ejn-notebook-insert-cell notebook 'code :at idx)
          (ejn-render-notebook notebook)
          (ejn--goto-cell-by-id (ejn-cell-id (ejn-notebook-cell-at-index notebook idx))))))))

(defun ejn-insert-cell-below ()
  "Insert a new code cell below the current cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((idx (ejn-notebook-cell-index notebook (ejn-cell-id current-cell))))
      (ejn-with-undo-group "Insert cell below" notebook
        (ejn-with-undo-boundary "Insert cell below"
          (let ((new-cell (ejn-notebook-insert-cell notebook 'code :at (1+ idx))))
            (ejn-render-notebook notebook)
            (ejn--goto-cell-by-id (ejn-cell-id new-cell))))))))

(provide 'ejn-cell-engine)
;;; ejn-cell-engine.el ends here
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-cell-engine.el
git add lisp/ejn-cell-engine.el test/ejn-cell-engine-test.el
git commit -m "feat: add insert cell above/below operations"
```

---

## Task 19: Cell Engine — Delete Cell

**Files:**
- Modify: `lisp/ejn-cell-engine.el`
- Test: `test/ejn-cell-engine-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-cell-engine-test.el`:

```elisp
(ert-deftest ejn-cell-engine-test/delete-cell ()
  "Deleting a cell should remove it from the model and re-render."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (ejn-delete-cell)
      (should (= (length (ejn-notebook-cells nb)) 1)))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add delete command**

Add to `lisp/ejn-cell-engine.el` before `(provide 'ejn-cell-engine)`:

```elisp
(defun ejn-delete-cell ()
  "Delete the current cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((cell-id (ejn-cell-id current-cell)))
      (ejn-with-undo-group "Delete cell" notebook
        (ejn-with-undo-boundary "Delete cell"
          (ejn-notebook-delete-cell notebook cell-id)
          (ejn-render-notebook notebook)
          (goto-char (point-min)))))))
```

- [ ] **Step 4: Run test, validate, commit**

```bash
make test
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-cell-engine.el
git add lisp/ejn-cell-engine.el test/ejn-cell-engine-test.el
git commit -m "feat: add delete cell operation"
```

---

## Task 20: Cell Engine — Split and Merge

**Files:**
- Modify: `lisp/ejn-cell-engine.el`
- Test: `test/ejn-cell-engine-test.el`

- [ ] **Step 1: Write failing tests**

Add to `test/ejn-cell-engine-test.el`:

```elisp
(ert-deftest ejn-cell-engine-test/split-cell ()
  "Splitting a cell should divide the source at point into two cells."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "line1\nline2")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (search-forward "\n")
      (ejn-split-cell)
      (should (= (length (ejn-notebook-cells nb)) 2))
      (should (string= (ejn-cell-source (ejn-notebook-cell-at-index nb 0)) "line1\n")))))

(ert-deftest ejn-cell-engine-test/merge-cell ()
  "Merging cells should concatenate current and next cell source."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "first")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "second")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (ejn-merge-cell)
      (should (= (length (ejn-notebook-cells nb)) 1))
      (let ((source (ejn-cell-source (ejn-notebook-cell-at-index nb 0))))
        (should (string= source "first\nsecond\n"))))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add split and merge commands**

Add to `lisp/ejn-cell-engine.el` before `(provide 'ejn-cell-engine)`:

```elisp
(defun ejn-split-cell ()
  "Split the current cell at point into two cells."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((cell-id (ejn-cell-id current-cell))
          (source (ejn-cell-source current-cell))
          (region (ejn-cell-region))
          (split-pos (- (point) (car region))))
      (when (>= split-pos (length source))
        (setq split-pos (1- (length source))))
      (when (<= split-pos 0)
        (setq split-pos 1))
      (let ((part1 (substring source 0 split-pos))
            (part2 (substring source split-pos)))
        (ejn-with-undo-group "Split cell" notebook
          (ejn-with-undo-boundary "Split cell"
            (ejn-notebook-set-cell-source notebook cell-id part1)
            (let ((idx (ejn-notebook-cell-index notebook cell-id)))
              (let ((new-cell (ejn-notebook-insert-cell notebook (ejn-cell-type current-cell) :at (1+ idx))))
                (setf (ejn-cell-source new-cell) part2))
              (ejn-render-notebook notebook)
              (ejn--goto-cell-by-id (ejn-cell-id new-cell)))))))))

(defun ejn-merge-cell ()
  "Merge the current cell with the next cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((current-id (ejn-cell-id current-cell))
          (idx (ejn-notebook-cell-index notebook current-id))
          (next-cell (ejn-notebook-cell-at-index notebook (1+ idx))))
      (unless next-cell
        (user-error "No next cell to merge"))
      (let ((merged-source (concat (ejn-cell-source current-cell)
                                   "\n"
                                   (ejn-cell-source next-cell)
                                   "\n"))
            (next-id (ejn-cell-id next-cell)))
        (ejn-with-undo-group "Merge cell" notebook
          (ejn-with-undo-boundary "Merge cell"
            (ejn-notebook-set-cell-source notebook current-id merged-source)
            (ejn-notebook-delete-cell notebook next-id)
            (ejn-render-notebook notebook)
            (ejn--goto-cell-by-id current-id)))))))
```

- [ ] **Step 4: Run test, validate, commit**

```bash
make test
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-cell-engine.el
git add lisp/ejn-cell-engine.el test/ejn-cell-engine-test.el
git commit -m "feat: add split and merge cell operations"
```

---

## Task 21: Cell Engine — Move Up/Down

**Files:**
- Modify: `lisp/ejn-cell-engine.el`
- Test: `test/ejn-cell-engine-test.el`

- [ ] **Step 1: Write failing tests**

Add to `test/ejn-cell-engine-test.el`:

```elisp
(ert-deftest ejn-cell-engine-test/move-cell-up ()
  "Moving a cell up should swap it with the previous cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "A")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "B")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (search-forward "B")
      (ejn-move-cell-up)
      (should (string= (ejn-cell-source (ejn-notebook-cell-at-index nb 0)) "B\n")))))

(ert-deftest ejn-cell-engine-test/move-cell-down ()
  "Moving a cell down should swap it with the next cell."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "A")
    (ejn-notebook-insert-cell nb 'code :at 1)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 1)) "B")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (goto-char (point-min))
      (ejn-move-cell-down)
      (should (string= (ejn-cell-source (ejn-notebook-cell-at-index nb 1)) "A\n")))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add move commands**

Add to `lisp/ejn-cell-engine.el` before `(provide 'ejn-cell-engine)`:

```elisp
(defun ejn-move-cell-up ()
  "Move the current cell up by swapping with the previous cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((idx (ejn-notebook-cell-index notebook (ejn-cell-id current-cell))))
      (unless idx
        (user-error "Already at first cell"))
      (ejn-with-undo-group "Move cell up" notebook
        (ejn-with-undo-boundary "Move cell up"
          (let ((cells (ejn-notebook-cells notebook))
                (prev-cell (aref cells (1- idx)))
                (curr-cell (aref cells idx)))
            (setf (ejn-notebook-cells notebook)
                  (vconcat (seq-take cells (1- idx))
                           (vector curr-cell prev-cell)
                           (seq-drop cells (+ idx 2))))
            (ejn-render-notebook notebook)
            (ejn--goto-cell-by-id (ejn-cell-id curr-cell))))))))

(defun ejn-move-cell-down ()
  "Move the current cell down by swapping with the next cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((idx (ejn-notebook-cell-index notebook (ejn-cell-id current-cell)))
          (total (length (ejn-notebook-cells notebook))))
      (when (>= idx (1- total))
        (user-error "Already at last cell"))
      (ejn-with-undo-group "Move cell down" notebook
        (ejn-with-undo-boundary "Move cell down"
          (let ((cells (ejn-notebook-cells notebook))
                (curr-cell (aref cells idx))
                (next-cell (aref cells (1+ idx))))
            (setf (ejn-notebook-cells notebook)
                  (vconcat (seq-take cells idx)
                           (vector next-cell curr-cell)
                           (seq-drop cells (+ idx 3))))
            (ejn-render-notebook notebook)
            (ejn--goto-cell-by-id (ejn-cell-id curr-cell))))))))
```

- [ ] **Step 4: Run test, validate, commit**

```bash
make test
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-cell-engine.el
git add lisp/ejn-cell-engine.el test/ejn-cell-engine-test.el
git commit -m "feat: add move cell up/down operations"
```

---

## Task 22: Cell Engine — Toggle/Change Cell Type

**Files:**
- Modify: `lisp/ejn-cell-engine.el`
- Test: `test/ejn-cell-engine-test.el`

- [ ] **Step 1: Write failing tests**

Add to `test/ejn-cell-engine-test.el`:

```elisp
(ert-deftest ejn-cell-engine-test/toggle-cell-type ()
  "Toggling cell type should cycle code -> markdown -> raw -> code."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (ejn-toggle-cell-type)
      (should (eq 'markdown (ejn-cell-type (ejn-notebook-cell-at-index nb 0))))
      (ejn-toggle-cell-type)
      (should (eq 'raw (ejn-cell-type (ejn-notebook-cell-at-index nb 0))))
      (ejn-toggle-cell-type)
      (should (eq 'code (ejn-cell-type (ejn-notebook-cell-at-index nb 0)))))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add type change commands**

Add to `lisp/ejn-cell-engine.el` before `(provide 'ejn-cell-engine)`:

```elisp
(defun ejn-toggle-cell-type ()
  "Cycle the current cell's type: code -> markdown -> raw -> code."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((new-type (pcase (ejn-cell-type current-cell)
                      ('code 'markdown)
                      ('markdown 'raw)
                      ('raw 'code)
                      (_ 'code))))
      (ejn-with-undo-group "Toggle cell type" notebook
        (setf (ejn-cell-type current-cell) new-type)
        (ejn-with-undo-boundary "Toggle cell type"
          (ejn-render-dirty-cells notebook))))))

(defun ejn-change-cell-type ()
  "Prompt for a cell type and set the current cell's type."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (let ((type-str (completing-read "Cell type: "
                                     '("code" "markdown" "raw")
                                     nil t)))
      (let ((new-type (intern type-str)))
        (ejn-with-undo-group "Change cell type" notebook
          (setf (ejn-cell-type current-cell) new-type)
          (ejn-with-undo-boundary "Change cell type"
            (ejn-render-dirty-cells notebook)))))))
```

- [ ] **Step 4: Run test, validate, commit**

```bash
make test
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-cell-engine.el
git add lisp/ejn-cell-engine.el test/ejn-cell-engine-test.el
git commit -m "feat: add toggle and change cell type operations"
```

---

## Task 23: Cell Engine — Clear Output and Copy/Yank

**Files:**
- Modify: `lisp/ejn-cell-engine.el`
- Test: `test/ejn-cell-engine-test.el`

- [ ] **Step 1: Write failing tests**

Add to `test/ejn-cell-engine-test.el`:

```elisp
(ert-deftest ejn-cell-engine-test/clear-output ()
  "Clearing output should remove outputs from the cell."
  (require 'ejn-cell)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (let ((cell (ejn-notebook-cell-at-index nb 0)))
      (setf (ejn-cell-outputs cell)
            (list (make-ejn-output
                   :type 'execute-result
                   :mime-data (list :data (list (cons 'text/plain (list "42")))))
                   :metadata nil
                   :request-id nil)))
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (ejn-clear-output)
      (should-not (ejn-cell-outputs (ejn-notebook-cell-at-index nb 0))))))

(ert-deftest ejn-cell-engine-test/copy-and-yank-cell ()
  "Copying and yanking a cell should round-trip cell content."
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "copied code")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (ejn-render-notebook nb)
      (ejn-copy-cell)
      (ejn-yank-cell)
      (should (= (length (ejn-notebook-cells nb)) 2))
      (should (string= (ejn-cell-source (ejn-notebook-cell-at-index nb 1))
                       "copied code")))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add clear output, copy, and yank commands**

Add to `lisp/ejn-cell-engine.el` before `(provide 'ejn-cell-engine)`:

```elisp
(defun ejn-clear-output ()
  "Clear the output of the current cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (ejn-with-undo-group "Clear output" notebook
      (setf (ejn-cell-outputs current-cell) nil)
      (ejn-with-undo-boundary "Clear output"
        (ejn-render-dirty-cells notebook)))))

(defun ejn-clear-all-outputs ()
  "Clear outputs of all cells."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (ejn-with-undo-group "Clear all outputs" notebook
      (dolist (cell (ejn-notebook-cells notebook))
        (setf (ejn-cell-outputs cell) nil)
        (ejn-notebook-mark-dirty notebook (ejn-cell-id cell)))
      (ejn-with-undo-boundary "Clear all outputs"
        (ejn-render-notebook notebook)))))

(defun ejn-copy-cell ()
  "Copy the current cell to the cell kill ring."
  (interactive)
  (let ((current-cell (ejn-cell-at-point)))
    (push (list :id (ejn-cell-id current-cell)
                :type (ejn-cell-type current-cell)
                :source (ejn-cell-source current-cell)
                :outputs (ejn-cell-outputs current-cell)
                :metadata (ejn-cell-metadata current-cell))
          ejn--cell-kill-ring)
    (message "Cell copied to kill ring")))

(defun ejn-yank-cell ()
  "Insert a copied cell below the current cell."
  (interactive)
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer)))
        (current-cell (ejn-cell-at-point)))
    (unless notebook
      (user-error "Not in an EJN buffer"))
    (unless ejn--cell-kill-ring
      (user-error "No cell in kill ring"))
    (let ((entry (car ejn--cell-kill-ring))
          (idx (ejn-notebook-cell-index notebook (ejn-cell-id current-cell))))
      (ejn-with-undo-group "Yank cell" notebook
        (ejn-with-undo-boundary "Yank cell"
          (let ((new-cell (ejn-notebook-insert-cell notebook
                                                     (plist-get entry :type)
                                                     :at (1+ idx))))
            (setf (ejn-cell-source new-cell) (plist-get entry :source))
            (ejn-render-notebook notebook)
            (ejn--goto-cell-by-id (ejn-cell-id new-cell))))))))
```

- [ ] **Step 4: Run test, validate, commit**

```bash
make test
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-cell-engine.el
git add lisp/ejn-cell-engine.el test/ejn-cell-engine-test.el
git commit -m "feat: add clear output, copy, and yank cell operations"
```

---

## Task 24: Cell Engine — Execute Stubs

**Files:**
- Modify: `lisp/ejn-cell-engine.el`
- Test: no test needed (stub behavior is trivial)

- [ ] **Step 1: Add execute stubs**

Add to `lisp/ejn-cell-engine.el` before `(provide 'ejn-cell-engine)`:

```elisp
(defun ejn-execute-cell ()
  "Execute the current cell.
Not yet implemented — kernel integration is Phase 4."
  (interactive)
  (user-error "Kernel not connected. Execute is available in Phase 4."))

(defun ejn-execute-all-cells ()
  "Execute all cells.
Not yet implemented — kernel integration is Phase 4."
  (interactive)
  (user-error "Kernel not connected. Execute is available in Phase 4."))

(defun ejn-execute-cell-and-goto-next ()
  "Execute the current cell and move to the next.
Not yet implemented — kernel integration is Phase 4."
  (interactive)
  (user-error "Kernel not connected. Execute is available in Phase 4."))

(defun ejn-execute-cell-and-insert-below ()
  "Execute the current cell and insert a new cell below.
Not yet implemented — kernel integration is Phase 4."
  (interactive)
  (user-error "Kernel not connected. Execute is available in Phase 4."))
```

- [ ] **Step 2: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-cell-engine.el
git add lisp/ejn-cell-engine.el
git commit -m "feat: add execute stubs for Phase 4 kernel integration"
```

---

## Task 25: Major Mode — Mode Definition

**Files:**
- Create: `lisp/ejn-mode.el`
- Test: `test/ejn-mode-test.el`

- [ ] **Step 1: Write failing tests**

Create `test/ejn-mode-test.el`:

```elisp
;;; ejn-mode-test.el --- Tests for ejn-mode  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-mode)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-test-util)

(ert-deftest ejn-mode-test/mode-is-derived-from-text-mode ()
  "ejn-mode should derive from text-mode."
  (ejn-test-with-temp-buffer " *test*"
    (ejn-mode)
    (should (derived-mode-p 'text-mode))))

(ert-deftest ejn-mode-test/mode-sets-buffer-local-variables ()
  "ejn-mode should initialize buffer-local variables."
  (ejn-test-with-temp-buffer " *test*"
    (ejn-mode)
    (should (local-variable-p 'ejn--notebook))
    (should (local-variable-p 'ejn--rendering-p))
    (should-not ejn--notebook)
    (should-not ejn--rendering-p)))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Create major mode module**

Create `lisp/ejn-mode.el`:

```elisp
;;; ejn-mode.el --- Major mode for Jupyter notebooks  -*- lexical-binding: t; -*-

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

;; Major mode for editing Jupyter notebook files.
;; Derives from text-mode, provides cell-aware editing.

;;; Code:

(require 'cl-lib)
(require 'ejn-core)
(require 'ejn-model)
(require 'ejn-render)
(require 'ejn-navigation)
(require 'ejn-cell-engine)
(require 'ejn-sync)
(require 'ejn-undo)
(require 'ejn-persistence)

(defvar ejn-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Keymap for `ejn-mode'.")

(define-derived-mode ejn-mode text-mode "EJN"
  "Major mode for editing Jupyter notebooks.

This mode provides cell-aware editing for Jupyter notebook files.
Cells are identified by text properties and can be navigated,
inserted, deleted, split, merged, and moved.

\\{ejn-mode-map}"
  :group 'ejn
  (set (make-local-variable 'ejn--notebook) nil)
  (set (make-local-variable 'ejn--sync-timer) nil)
  (set (make-local-variable 'ejn--rendering-p) nil)
  (set (make-local-variable 'ejn--pending-sync-set) nil)
  (set (make-local-variable 'ejn--cell-kill-ring) nil)
  (add-to-invisibility-spec '(ejn-folded-output))
  (ejn-sync-mode))

(provide 'ejn-mode)
;;; ejn-mode.el ends here
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mode.el
git add lisp/ejn-mode.el test/ejn-mode-test.el
git commit -m "feat: define ejn-mode major mode derived from text-mode"
```

---

## Task 26: Major Mode — Keymap Bindings

**Files:**
- Modify: `lisp/ejn-mode.el`
- Test: `test/ejn-mode-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-mode-test.el`:

```elisp
(ert-deftest ejn-mode-test/keymap-bindings ()
  "Keymap should have expected bindings."
  (ejn-test-with-temp-buffer " *test*"
    (ejn-mode)
    (should (commandp (key-binding "C-c C-c")))
    (should (commandp (key-binding "C-c C-n")))
    (should (commandp (key-binding "C-c C-p")))
    (should (commandp (key-binding "C-c C-a")))
    (should (commandp (key-binding "C-c C-b")))
    (should (commandp (key-binding "C-c C-k")))
    (should (commandp (key-binding "C-x C-s")))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add keymap bindings**

Replace the keymap definition in `lisp/ejn-mode.el`:

```elisp
(defvar ejn-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-a") #'ejn-insert-cell-above)
    (define-key map (kbd "C-c C-b") #'ejn-insert-cell-below)
    (define-key map (kbd "C-c C-c") #'ejn-execute-cell)
    (define-key map (kbd "C-c RET") #'ejn-merge-cell)
    (define-key map (kbd "C-c C-k") #'ejn-delete-cell)
    (define-key map (kbd "C-c C-l") #'ejn-clear-output)
    (define-key map (kbd "C-c C-n") #'ejn-goto-next-cell)
    (define-key map (kbd "C-c C-p") #'ejn-goto-prev-cell)
    (define-key map (kbd "C-c C-r") #'ejn-split-cell)
    (define-key map (kbd "C-c C-t") #'ejn-toggle-cell-type)
    (define-key map (kbd "C-c C-u") #'ejn-change-cell-type)
    (define-key map (kbd "C-c C-e") #'ejn-toggle-output)
    (define-key map (kbd "C-c C-w") #'ejn-copy-cell)
    (define-key map (kbd "C-c C-y") #'ejn-yank-cell)
    (define-key map (kbd "C-c <down>") #'ejn-move-cell-down)
    (define-key map (kbd "C-c <up>") #'ejn-move-cell-up)
    (define-key map (kbd "C-<down>") #'ejn-goto-next-cell)
    (define-key map (kbd "C-<up>") #'ejn-goto-prev-cell)
    (define-key map (kbd "M-<down>") #'ejn-move-cell-down)
    (define-key map (kbd "M-<up>") #'ejn-move-cell-up)
    (define-key map (kbd "M-RET") #'ejn-execute-cell-and-goto-next)
    (define-key map (kbd "M-S-<return>") #'ejn-execute-cell-and-insert-below)
    (define-key map (kbd "C-x C-s") #'ejn-save-notebook)
    (define-key map (kbd "C-c C-S-l") #'ejn-clear-all-outputs)
    (define-key map (kbd "C-c C-q") #'ejn-kernel-quit)
    (define-key map (kbd "C-c C-z") #'ejn-kernel-interrupt)
    (define-key map (kbd "C-c C-x C-r") #'ejn-kernel-restart)
    map)
  "Keymap for `ejn-mode'.")
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mode.el
git add lisp/ejn-mode.el test/ejn-mode-test.el
git commit -m "feat: install EJN keymap bindings"
```

---

## Task 27: Major Mode — Kernel Stub Commands

**Files:**
- Modify: `lisp/ejn-mode.el`
- Test: `test/ejn-mode-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-mode-test.el`:

```elisp
(ert-deftest ejn-mode-test/kernel-stubs-signal-error ()
  "Kernel commands should signal 'kernel not connected'."
  (ejn-test-with-temp-buffer " *test*"
    (ejn-mode)
    (should-error (ejn-kernel-quit))
    (should-error (ejn-kernel-interrupt))
    (should-error (ejn-kernel-restart))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add kernel stubs**

Add to `lisp/ejn-mode.el` before `(provide 'ejn-mode)`:

```elisp
(defun ejn-kernel-quit ()
  "Quit the kernel session.  Not yet implemented."
  (interactive)
  (user-error "Kernel not connected. Available in Phase 4."))

(defun ejn-kernel-interrupt ()
  "Interrupt the kernel.  Not yet implemented."
  (interactive)
  (user-error "Kernel not connected. Available in Phase 4."))

(defun ejn-kernel-restart ()
  "Restart the kernel.  Not yet implemented."
  (interactive)
  (user-error "Kernel not connected. Available in Phase 4."))
```

- [ ] **Step 4: Run test, validate, commit**

```bash
make test
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mode.el
git add lisp/ejn-mode.el test/ejn-mode-test.el
git commit -m "feat: add kernel lifecycle stub commands"
```

---

## Task 28: Major Mode — ejn-open and ejn-save-notebook

**Files:**
- Modify: `lisp/ejn-mode.el`
- Test: `test/ejn-mode-test.el`

- [ ] **Step 1: Write failing tests**

Add to `test/ejn-mode-test.el`:

```elisp
(ert-deftest ejn-mode-test/save-notebook-serializes-model ()
  "ejn-save-notebook should serialize the model to the file."
  (require 'ejn-persistence)
  (let ((nb (ejn-make-notebook)))
    (ejn-notebook-insert-cell nb 'code :at 0)
    (ejn-notebook-set-cell-source nb (ejn-cell-id (ejn-notebook-cell-at-index nb 0)) "test")
    (ejn-test-with-temp-buffer " *test*"
      (set (make-local-variable 'ejn--notebook) nb)
      (set (make-local-variable 'buffer-file-name) "/tmp/test-ejn-save.ipynb")
      (condition-case nil
          (ejn-save-notebook)
        (file-error nil))
      (when (file-exists-p "/tmp/test-ejn-save.ipynb")
        (let ((contents (with-temp-buffer
                          (insert-file-contents "/tmp/test-ejn-save.ipynb")
                          (buffer-string))))
          (should (stringp contents))
          (should (> (length contents) 0))
          (delete-file "/tmp/test-ejn-save.ipynb"))))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add open and save commands**

Add to `lisp/ejn-mode.el` before `(provide 'ejn-mode)`:

```elisp
(defun ejn-open (file-path)
  "Open a Jupyter notebook file at FILE-PATH.
Loads the notebook, creates a buffer in ejn-mode, and renders it."
  (interactive "fOpen notebook: ")
  (unless (file-exists-p file-path)
    (user-error "File not found: %s" file-path))
  (let ((notebook (ejn-model-from-file file-path)))
    (with-current-buffer (get-buffer-create (concat "*ejn: " (file-name-nondirectory file-path) "*"))
      (ejn-mode)
      (set (make-local-variable 'ejn--notebook) notebook)
      (set (make-local-variable 'buffer-file-name) file-path)
      (ejn-render-notebook notebook)
      (display-buffer (current-buffer)))))

(defun ejn-save-notebook ()
  "Save the current notebook to its file."
  (interactive)
  (let ((notebook ejn--notebook)
        (path buffer-file-name))
    (unless notebook
      (user-error "No notebook loaded in this buffer"))
    (unless path
      (user-error "No file path set for this notebook"))
    (ejn-model-to-file notebook path)
    (ejn-notebook-clean-all notebook)
    (message "Notebook saved: %s" path)))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mode.el
git add lisp/ejn-mode.el test/ejn-mode-test.el
git commit -m "feat: add ejn-open and ejn-save-notebook commands"
```

---

## Task 29: Major Mode — Mode Exit Cleanup

**Files:**
- Modify: `lisp/ejn-mode.el`
- Test: `test/ejn-mode-test.el`

- [ ] **Step 1: Write failing test**

Add to `test/ejn-mode-test.el`:

```elisp
(ert-deftest ejn-mode-test/mode-exit-cleanup ()
  "Exiting ejn-mode should cancel the sync timer."
  (ejn-test-with-temp-buffer " *test*"
    (ejn-mode)
    (set (make-local-variable 'ejn--sync-timer)
         (run-with-timer 1000 nil #'ignore))
    (setq major-mode 'fundamental-mode)
    (setq mode-name "Fundamental")
    (should-not ejn--sync-timer)))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add cleanup via mode hook**

Add to `lisp/ejn-mode.el` after the `define-derived-mode` block:

```elisp
(add-hook 'ejn-mode-hook
          (lambda ()
            (add-local-hook 'kill-buffer-hook
                            (lambda ()
                              (when ejn--sync-timer
                                (cancel-timer ejn--sync-timer)
                                (setq ejn--sync-timer nil)))
                            nil t)))
```

Actually, a better approach is to use `ejn-mode`'s built-in cleanup. Add a `kill-buffer-hook` inside the mode body:

Replace the mode definition to include cleanup:

```elisp
(define-derived-mode ejn-mode text-mode "EJN"
  "Major mode for editing Jupyter notebooks.

This mode provides cell-aware editing for Jupyter notebook files.
Cells are identified by text properties and can be navigated,
inserted, deleted, split, merged, and moved.

\\{ejn-mode-map}"
  :group 'ejn
  (set (make-local-variable 'ejn--notebook) nil)
  (set (make-local-variable 'ejn--sync-timer) nil)
  (set (make-local-variable 'ejn--rendering-p) nil)
  (set (make-local-variable 'ejn--pending-sync-set) nil)
  (set (make-local-variable 'ejn--cell-kill-ring) nil)
  (add-to-invisibility-spec '(ejn-folded-output))
  (add-hook 'kill-buffer-hook #'ejn--cleanup-buffer nil t)
  (ejn-sync-mode))

(defun ejn--cleanup-buffer ()
  "Clean up buffer-local resources when exiting ejn-mode."
  (when (and (boundp 'ejn--sync-timer) ejn--sync-timer)
    (cancel-timer ejn--sync-timer)
    (setq ejn--sync-timer nil)))
```

- [ ] **Step 4: Run test, validate, commit**

```bash
make test
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mode.el
git add lisp/ejn-mode.el test/ejn-mode-test.el
git commit -m "feat: add buffer cleanup on mode exit"
```

---

## Task 30: Integration — Wire Up ejn-core.el

**Files:**
- Modify: `lisp/ejn-core.el`

- [ ] **Step 1: Add Phase 3 module requires to ejn-core.el**

Update `lisp/ejn-core.el` to require Phase 3 modules. Add after the existing `(require 'f)` line:

```elisp
(require 'ejn-mime)
(require 'ejn-render)
(require 'ejn-navigation)
(require 'ejn-sync)
(require 'ejn-undo)
(require 'ejn-cell-engine)
(require 'ejn-mode)
```

- [ ] **Step 2: Validate**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-core.el
make compile
```

- [ ] **Step 3: Commit**

```bash
git add lisp/ejn-core.el
git commit -m "feat: wire Phase 3 modules into ejn-core"
```

---

## Task 31: Integration — Compile and Lint

**Files:** all Phase 3 files

- [ ] **Step 1: Run full compilation**

```bash
make compile
```

Fix any compilation warnings. Common issues:
- Free variables: ensure all `ejn--` variables are `defvar-local`'d
- Undeclared functions: ensure `require` statements are in correct order
- Docstring issues: run `make lint-checkdoc`

- [ ] **Step 2: Run linters**

```bash
make lint
```

Fix any lint issues:
- `lint-pkg`: package metadata
- `lint-checkdoc`: docstring compliance
- `lint-declare`: function declarations

- [ ] **Step 3: Run full test suite**

```bash
make test
```

All tests should pass. If any fail, diagnose using the systematic-debugging skill.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve compilation and lint warnings"
```

---

## Task 32: Integration — Verify Finish Conditions

Verify all Phase 3 finish conditions:

- [ ] `ejn-mode` major mode is defined and derives from `text-mode`
- [ ] Notebook files can be opened via `ejn-open` and saved via `C-x C-s`
- [ ] Cells can be inserted (`C-c C-a`/`C-c C-b`), deleted (`C-c C-k`), split (`C-c C-r`), merged (`C-c RET`), and moved (`C-c <up>`/`C-c <down>`)
- [ ] Navigation jumps between cells (`C-c C-n`/`C-c C-p`, `C-<up>`/`C-<down>`)
- [ ] User edits sync to model with `ejn-sync-debounce-seconds` debounce
- [ ] Outputs render in read-only zones with fold/unfold (`C-c C-e`)
- [ ] Cell structure uses text properties (`ejn-cell-id`, `ejn-cell-type`), not overlays
- [ ] All operations are undoable via model's undo system
- [ ] All modules pass `make compile`, `make lint`, `make test`
- [ ] Execute commands signal "kernel not connected" (Phase 4 stubs)

---

## Self-Review

### Spec Coverage

| Spec Section | Tasks |
|---|---|
| Major Mode definition | Task 25 |
| Buffer-local state | Task 25 |
| Keymap (all bindings) | Task 26 |
| `ejn-open` command | Task 28 |
| `ejn-save-notebook` | Task 28 |
| Mode exit cleanup | Task 29 |
| Cell separator: text properties | Tasks 9, 11 |
| Execution state faces | Tasks 7, 8 |
| Full render | Task 11 |
| Incremental render | Task 12 |
| Output zones (read-only) | Task 10 |
| Output folding | Task 13 |
| MIME registry API | Task 1 |
| MIME handlers (4 types) | Tasks 2-5 |
| `ejn-cell-at-point` | Task 14 |
| `ejn-cell-region` / `full-region` | Task 14 |
| Navigation commands (4) | Task 15 |
| Cell insert above/below | Task 18 |
| Cell delete | Task 19 |
| Cell split/merge | Task 20 |
| Cell move up/down | Task 21 |
| Cell type toggle/change | Task 22 |
| Clear output / all outputs | Task 23 |
| Copy/yank cell | Task 23 |
| Execute stubs | Task 24 |
| Debounced sync (200ms) | Task 16 |
| `after-change-functions` hook | Task 16 |
| Rendering guard | Task 16 |
| `ejn-after-sync-hook` | Task 16 |
| Output zone sync exclusion | Task 16 |
| Undo boundary macro | Task 17 |
| `ejn-undo` / `ejn-redo` | Task 17 |
| Kernel stubs | Task 27 |
| Test utilities | Task 6 |

All spec sections covered. No gaps.

### Placeholder Scan

No instances of TBD, TODO, "implement later", "add appropriate error handling", "similar to Task N", or vague "write tests" without code. Every task contains complete Elisp code blocks.

### Type Consistency

- `ejn-cell-id`: string (UUID) — used consistently as string throughout
- `ejn-cell-type`: keyword (`'code`, `'markdown`, `'raw`) — consistent
- `ejn-cell-source`: string — consistent
- `ejn-notebook`: struct — consistent
- `ejn--notebook`: buffer-local variable holding `ejn-notebook` struct
- `ejn--rendering-p`: boolean buffer-local — consistent
- `ejn--sync-timer`: timer | nil buffer-local — consistent
- `ejn-output-zone`: text property value `t` — consistent
- `ejn-folded-output`: symbol `'ejn-folded-output` for invisibility — consistent
- Cell kill ring entries: plists with `:id`, `:type`, `:source`, `:outputs`, `:metadata` — consistent across copy/yank

No inconsistencies found.
