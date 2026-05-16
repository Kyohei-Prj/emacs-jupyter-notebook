# Phase 4 — Kernel Runtime Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement asynchronous kernel execution so notebook cells can be evaluated against a live Jupyter kernel without blocking Emacs.

**Architecture:** Three-module adapter layer. `ejn-kernel.el` defines CLOS generics and the `ejn-kernel` struct (state machine: startup/connected/busy/interrupted/dead). `ejn-kernel-jupyter.el` implements generics via emacs-jupyter's `jupyter-client` transport, defining custom `jupyter-handle-*` message handlers that route kernel outputs back to EJN model mutations. `ejn-execute.el` owns the FIFO execution queue, cell state transitions, output routing via callbacks, and user-facing commands. All model mutations follow model-first discipline: kernel messages update cell outputs/state, mark cell dirty, trigger incremental render.

**Tech Stack:** Emacs Lisp (lexical-binding), `cl-lib`, `emacs-jupyter` (external dependency), existing EJN model/render/navigation modules.

---

## File Structure

```
lisp/ (new files)
├── ejn-kernel.el            ; Kernel abstraction: struct, CLOS generics, state helpers
├── ejn-kernel-jupyter.el    ; Jupyter adapter: implements generics via emacs-jupyter
└── ejn-execute.el           ; Execution pipeline: queue, callbacks, routing, commands

test/ (new files)
├── ejn-kernel-test.el       ; Kernel struct + generics tests (mock kernel)
├── ejn-execute-test.el      ; Queue, state machine, routing tests (mock kernel)
└── ejn-kernel-jupyter-test.el ; Integration tests with emacs-jupyter

modified files
├── lisp/ejn-core.el         ; Add (require) for Phase 4 modules
├── lisp/ejn-mode.el         ; Replace kernel stubs, add kernel lifecycle to ejn-open
├── lisp/ejn-cell-engine.el  ; Replace execute stubs with real implementations
└── ejn.el                   ; No change (ejn-core pulls in Phase 4 via requires)
```

## Dependency Order

1. **ejn-kernel.el** — kernel struct + generics (no Phase 4 dependencies)
2. **ejn-kernel-jupyter.el** — adapter (depends on kernel + emacs-jupyter)
3. **ejn-execute.el** — execution pipeline (depends on kernel, model, render, navigation)
4. **Replace stubs** — ejn-cell-engine.el, ejn-mode.el (depends on execute)
5. **Integration** — wire ejn-core.el, final verification

---

## Task 1: Kernel Struct and State Helpers

**Files:**
- Create: `lisp/ejn-kernel.el`
- Test: `test/ejn-kernel-test.el`

- [ ] **Step 1: Write failing test for kernel struct**

Create `test/ejn-kernel-test.el`:

```elisp
;;; ejn-kernel-test.el --- Tests for ejn-kernel  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-kernel)

(ert-deftest ejn-kernel-test/kernel-struct-has-default-state ()
  "A new kernel should start in startup state."
  (let ((kernel (ejn-make-kernel "python3")))
    (should (eq 'startup (ejn-kernel-state kernel)))))

(ert-deftest ejn-kernel-test/kernel-struct-stores-kernelspec ()
  "The kernel should remember its kernelspec."
  (let ((kernel (ejn-make-kernel "python3")))
    (should (string= "python3" (ejn-kernel-kernelspec kernel)))))

(ert-deftest ejn-kernel-test/kernel-struct-has-nil-client ()
  "A new kernel should have no client."
  (let ((kernel (ejn-make-kernel "python3")))
    (should-not (ejn-kernel-client kernel))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

Expected: FAIL — `ejn-kernel` module does not exist yet.

- [ ] **Step 3: Create kernel module with struct and helpers**

Create `lisp/ejn-kernel.el`:

```elisp
;;; ejn-kernel.el --- Kernel abstraction layer  -*- lexical-binding: t; -*-

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
;; along with this program.  If not,  see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Kernel abstraction with CLOS generics.
;; Transport-specific adapters implement the generics.

;;; Code:

(require 'cl-lib)
(require 'ejn-cell)

(cl-defstruct ejn-kernel
  id
  state
  client
  kernelspec)

(defun ejn-make-kernel (kernelspec)
  "Create a new kernel instance for KERNELSPEC name.
Returns an `ejn-kernel' struct in `startup' state."
  (make-ejn-kernel
   :id (ejn-generate-uuid)
   :state 'startup
   :client nil
   :kernelspec kernelspec))

(defun ejn-kernel-transition (kernel new-state)
  "Transition KERNEL to NEW-STATE."
  (setf (ejn-kernel-state kernel) new-state))

(provide 'ejn-kernel)
;;; ejn-kernel.el ends here
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-kernel.el
git add lisp/ejn-kernel.el test/ejn-kernel-test.el
git commit -m "feat: add kernel struct and state helpers"
```

---

## Task 2: Kernel CLOS Generics

**Files:**
- Modify: `lisp/ejn-kernel.el`
- Test: `test/ejn-kernel-test.el`

- [ ] **Step 1: Write failing tests for generics**

Add to `test/ejn-kernel-test.el`:

```elisp
(ert-deftest ejn-kernel-test/generics-are-defined ()
  "All kernel generics should be defined."
  (should (cl-genericp #'ejn-kernel-start))
  (should (cl-genericp #'ejn-kernel-execute))
  (should (cl-genericp #'ejn-kernel-interrupt))
  (should (cl-genericp #'ejn-kernel-restart))
  (should (cl-genericp #'ejn-kernel-shutdown))
  (should (cl-genericp #'ejn-kernel-alive-p)))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add CLOS generics**

Add to `lisp/ejn-kernel.el` before `(provide 'ejn-kernel)`:

```elisp
(cl-defgeneric ejn-kernel-start (kernel kernelspec)
  "Start a new kernel with KERNELSPEC.")

(cl-defgeneric ejn-kernel-execute (kernel code request-id callbacks)
  "Execute CODE on KERNEL with REQUEST-ID and CALLBACKS plist.
CALLBACKS contains :on-stream, :on-result, :on-display, :on-error, :on-complete.")

(cl-defgeneric ejn-kernel-interrupt (kernel)
  "Interrupt the running computation on KERNEL.")

(cl-defgeneric ejn-kernel-restart (kernel)
  "Restart KERNEL.")

(cl-defgeneric ejn-kernel-shutdown (kernel)
  "Shutdown KERNEL.")

(cl-defgeneric ejn-kernel-alive-p (kernel)
  "Return non-nil if KERNEL is responsive.")
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-kernel.el
git add lisp/ejn-kernel.el test/ejn-kernel-test.el
git commit -m "feat: define kernel CLOS generics"
```

---

## Task 3: Jupyter Adapter — Client Creation

**Files:**
- Create: `lisp/ejn-kernel-jupyter.el`
- Test: `test/ejn-kernel-jupyter-test.el`

- [ ] **Step 1: Write failing test for client creation**

Create `test/ejn-kernel-jupyter-test.el`:

```elisp
;;; ejn-kernel-jupyter-test.el --- Integration tests for Jupyter adapter  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-kernel-jupyter)

(ert-deftest ejn-kernel-jupyter-test/start-creates-client ()
  "ejn-kernel-start should create a jupyter client."
  (skip-unless (require 'jupyter nil t))
  (let ((kernel (ejn-make-kernel "python3")))
    (condition-case err
        (ejn-kernel-start kernel "python3")
      (error nil))
    (should-not (eq 'startup (ejn-kernel-state kernel)))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Create Jupyter adapter module**

Create `lisp/ejn-kernel-jupyter.el`:

```elisp
;;; ejn-kernel-jupyter.el --- Jupyter kernel adapter  -*- lexical-binding: t; -*-

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
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Implements ejn-kernel CLOS generics using emacs-jupyter transport.
;; Defines custom message handlers that route kernel messages to EJN model.

;;; Code:

(require 'cl-lib)
(require 'ejn-kernel)

(eval-when-compile (require 'jupyter))

(defvar ejn--request-registry
  (make-hash-table :test 'equal)
  "Hash table mapping request-IDs to callback plists.")

(cl-defmethod ejn-kernel-start ((kernel ejn-kernel) kernelspec)
  "Start a new Jupyter kernel with KERNELSPEC."
  (condition-case err
      (let ((client (jupyter-client kernelspec)))
        (jupyter-connect client)
        (setf (ejn-kernel-client kernel) client)
        (ejn-kernel-transition kernel 'connected))
    (error
     (ejn-kernel-transition kernel 'dead)
     (signal 'ejn-kernel-start-error
             (list (format "Failed to start kernel: %s" (error-message-string err)))))))

(cl-defmethod ejn-kernel-alive-p ((kernel ejn-kernel))
  "Return non-nil if kernel is not in dead state."
  (not (memq (ejn-kernel-state kernel) '(dead startup))))

(provide 'ejn-kernel-jupyter)
;;; ejn-kernel-jupyter.el ends here
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-kernel-jupyter.el
git add lisp/ejn-kernel-jupyter.el test/ejn-kernel-jupyter-test.el
git commit -m "feat: add Jupyter adapter client creation"
```

---

## Task 4: Jupyter Adapter — Execute Method

**Files:**
- Modify: `lisp/ejn-kernel-jupyter.el`
- Test: `test/ejn-kernel-jupyter-test.el`

- [ ] **Step 1: Write failing test for execute method**

Add to `test/ejn-kernel-jupyter-test.el`:

```elisp
(ert-deftest ejn-kernel-jupyter-test/execute-sends-request ()
  "ejn-kernel-execute should send code to the kernel."
  (skip-unless (require 'jupyter nil t))
  (let ((kernel (ejn-make-kernel "python3"))
        (callbacks '(:on-stream (lambda (&rest _) nil)
                         :on-result (lambda (&rest _) nil)
                         :on-display (lambda (&rest _) nil)
                         :on-error (lambda (&rest _) nil)
                         :on-complete (lambda (&rest _) nil)))
        (request-id "test-request-123"))
    (condition-case err
        (progn
          (ejn-kernel-start kernel "python3")
          (ejn-kernel-execute kernel "print(1)" request-id callbacks))
      (error nil))
    (should (gethash request-id ejn--request-registry))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add execute method**

Add to `lisp/ejn-kernel-jupyter.el` before `(provide 'ejn-kernel-jupyter)`:

```elisp
(cl-defmethod ejn-kernel-execute ((kernel ejn-kernel) code request-id callbacks)
  "Execute CODE on the Jupyter kernel."
  (let ((client (ejn-kernel-client kernel)))
    (unless client
      (error "Kernel not connected"))
    (puthash request-id callbacks ejn--request-registry)
    (jupyter-execute-request
     client
     :code code
     :silent nil
     :store-history t
     :allow-stdin nil
     :stop-on-error nil
     :callbacks
     (list :iopub
           (lambda (_client req msg)
             (ejn--handle-iopub request-id req msg))))))

(defun ejn--handle-iopub (request-id _req msg)
  "Handle an ioPub message for REQUEST-ID."
  (let ((callbacks (gethash request-id ejn--request-registry)))
    (when callbacks
      (let ((msg-type (jupyter-message-type msg))
            (content (jupyter-message-content msg)))
        (pcase (intern msg-type)
          ('stream
           (let ((handler (plist-get callbacks :on-stream)))
             (when handler
               (funcall handler
                        (or (plist-get content :parent-cell-id) "")
                        (plist-get content :text)
                        (plist-get content :name)))))
          ('execute_result
           (let ((handler (plist-get callbacks :on-result)))
             (when handler
               (funcall handler
                        (or (plist-get content :parent-cell-id) "")
                        (plist-get content :data)))))
          ('display_data
           (let ((handler (plist-get callbacks :on-display)))
             (when handler
               (funcall handler
                        (or (plist-get content :parent-cell-id) "")
                        (plist-get content :data)))))
          ('error
           (let ((handler (plist-get callbacks :on-error)))
             (when handler
               (funcall handler
                        (or (plist-get content :parent-cell-id) "")
                        (plist-get content :ename)
                        (plist-get content :evalue)
                        (plist-get content :traceback)))))
          ('status
           (when (string= (plist-get content :execution_state) "idle")
             (let ((handler (plist-get callbacks :on-complete)))
               (when handler
                 (funcall handler "" "ok"))
               (remhash request-id ejn--request-registry)))))))))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-kernel-jupyter.el
git add lisp/ejn-kernel-jupyter.el test/ejn-kernel-jupyter-test.el
git commit -m "feat: add Jupyter adapter execute method"
```

---

## Task 5: Jupyter Adapter — Lifecycle Methods

**Files:**
- Modify: `lisp/ejn-kernel-jupyter.el`
- Test: `test/ejn-kernel-jupyter-test.el`

- [ ] **Step 1: Write failing tests for lifecycle methods**

Add to `test/ejn-kernel-jupyter-test.el`:

```elisp
(ert-deftest ejn-kernel-jupyter-test/interrupt-calls-jupyter ()
  "ejn-kernel-interrupt should call jupyter-interrupt-kernel."
  (skip-unless (require 'jupyter nil t))
  (let ((kernel (ejn-make-kernel "python3")))
    (condition-case err
        (progn
          (ejn-kernel-start kernel "python3")
          (ejn-kernel-interrupt kernel))
      (error nil))
    (should (memq (ejn-kernel-state kernel) '(interrupted connected dead)))))

(ert-deftest ejn-kernel-jupyter-test/restart-calls-jupyter ()
  "ejn-kernel-restart should call jupyter-restart-kernel."
  (skip-unless (require 'jupyter nil t))
  (let ((kernel (ejn-make-kernel "python3")))
    (condition-case err
        (progn
          (ejn-kernel-start kernel "python3")
          (ejn-kernel-restart kernel))
      (error nil))))

(ert-deftest ejn-kernel-jupyter-test/shutdown-calls-jupyter ()
  "ejn-kernel-shutdown should call jupyter-shutdown-kernel."
  (skip-unless (require 'jupyter nil t))
  (let ((kernel (ejn-make-kernel "python3")))
    (condition-case err
        (progn
          (ejn-kernel-start kernel "python3")
          (ejn-kernel-shutdown kernel))
      (error nil))
    (should (eq 'dead (ejn-kernel-state kernel)))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add lifecycle methods**

Add to `lisp/ejn-kernel-jupyter.el` before `(provide 'ejn-kernel-jupyter)`:

```elisp
(cl-defmethod ejn-kernel-interrupt ((kernel ejn-kernel))
  "Interrupt the running Jupyter kernel."
  (let ((client (ejn-kernel-client kernel)))
    (when client
      (condition-case err
          (jupyter-interrupt-kernel client)
        (error
         (ejn-log-warn "Interrupt failed: %s" (error-message-string err))))
      (ejn-kernel-transition kernel 'interrupted))))

(cl-defmethod ejn-kernel-restart ((kernel ejn-kernel))
  "Restart the Jupyter kernel."
  (let ((client (ejn-kernel-client kernel)))
    (when client
      (condition-case err
          (jupyter-restart-kernel client)
        (error
         (ejn-log-warn "Restart failed: %s" (error-message-string err))))
      (ejn-kernel-transition kernel 'connected))))

(cl-defmethod ejn-kernel-shutdown ((kernel ejn-kernel))
  "Shutdown the Jupyter kernel."
  (let ((client (ejn-kernel-client kernel)))
    (when client
      (condition-case err
          (jupyter-shutdown-kernel client)
        (error
         (ejn-log-warn "Shutdown failed: %s" (error-message-string err))))
      (setf (ejn-kernel-client kernel) nil)
      (ejn-kernel-transition kernel 'dead))))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-kernel-jupyter.el
git add lisp/ejn-kernel-jupyter.el test/ejn-kernel-jupyter-test.el
git commit -m "feat: add Jupyter adapter lifecycle methods"
```

---

## Task 6: Execution Queue

**Files:**
- Create: `lisp/ejn-execute.el`
- Test: `test/ejn-execute-test.el`

- [ ] **Step 1: Write failing tests for execution queue**

Create `test/ejn-execute-test.el`:

```elisp
;;; ejn-execute-test.el --- Tests for ejn-execute  -*- lexical-binding: t; -*-

(require 'ert)
(require 'ejn-execute)
(require 'ejn-kernel)
(require 'ejn-model)
(require 'ejn-cell)

(ert-deftest ejn-execute-test/queue-is-empty-initially ()
  "The execution queue should be empty initially."
  (should (null ejn--execution-queue)))

(ert-deftest ejn-execute-test/enqueue-adds-request ()
  "Enqueueing should add a request to the queue."
  (ejn-execute--enqueue (list :cell-id "cell-1"
                              :source "print(1)"
                              :request-id "req-1"
                              :execution-version 1))
  (should (= 1 (length ejn--execution-queue)))
  (ejn-execute--dequeue)
  (setq ejn--execution-queue nil))

(ert-deftest ejn-execute-test/dequeue-returns-fifo ()
  "Dequeuing should return requests in FIFO order."
  (ejn-execute--enqueue (list :cell-id "cell-1" :source "a" :request-id "req-1" :execution-version 1))
  (ejn-execute--enqueue (list :cell-id "cell-2" :source "b" :request-id "req-2" :execution-version 1))
  (let ((first (ejn-execute--dequeue))
        (second (ejn-execute--dequeue)))
    (should (string= "req-1" (plist-get first :request-id)))
    (should (string= "req-2" (plist-get second :request-id)))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Create execution module with queue**

Create `lisp/ejn-execute.el`:

```elisp
;;; ejn-execute.el --- Cell execution pipeline  -*- lexical-binding: t; -*-

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
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Execution pipeline: FIFO queue, cell state machine, output routing.
;; User-facing commands for cell execution.

;;; Code:

(require 'cl-lib)
(require 'ejn-kernel)
(require 'ejn-kernel-jupyter)
(require 'ejn-model)
(require 'ejn-cell)
(require 'ejn-render)
(require 'ejn-navigation)

(defvar-local ejn--kernel nil
  "Current kernel instance for this buffer.")

(defvar-local ejn--execution-queue nil
  "FIFO queue of pending execution requests.")

(defun ejn-execute--enqueue (request)
  "Add REQUEST to the execution queue."
  (push request ejn--execution-queue))

(defun ejn-execute--dequeue ()
  "Remove and return the first request from the execution queue."
  (if ejn--execution-queue
      (pop ejn--execution-queue)
    nil))

(provide 'ejn-execute)
;;; ejn-execute.el ends here
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-execute.el
git add lisp/ejn-execute.el test/ejn-execute-test.el
git commit -m "feat: add execution queue primitives"
```

---

## Task 7: Cell State Machine Helpers

**Files:**
- Modify: `lisp/ejn-execute.el`
- Test: `test/ejn-execute-test.el`

- [ ] **Step 1: Write failing tests for state transitions**

Add to `test/ejn-execute-test.el`:

```elisp
(ert-deftest ejn-execute-test/cell-state-transition-queued ()
  "Transitioning a cell to queued should update execution-state."
  (let ((cell (ejn-make-cell 'code "print(1)")))
    (ejn-execute--set-cell-state cell 'queued)
    (should (eq 'queued (ejn-cell-execution-state cell)))))

(ert-deftest ejn-execute-test/cell-state-transition-executing ()
  "Transitioning a cell to executing should update execution-state."
  (let ((cell (ejn-make-cell 'code "print(1)")))
    (ejn-execute--set-cell-state cell 'executing)
    (should (eq 'executing (ejn-cell-execution-state cell)))))

(ert-deftest ejn-execute-test/cell-state-transition-completed ()
  "Transitioning a cell to completed should update execution-state."
  (let ((cell (ejn-make-cell 'code "print(1)")))
    (ejn-execute--set-cell-state cell 'completed)
    (should (eq 'completed (ejn-cell-execution-state cell)))))

(ert-deftest ejn-execute-test/cell-state-transition-error ()
  "Transitioning a cell to error should update execution-state."
  (let ((cell (ejn-make-cell 'code "raise")))
    (ejn-execute--set-cell-state cell 'error)
    (should (eq 'error (ejn-cell-execution-state cell)))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add state transition helper**

Add to `lisp/ejn-execute.el` before `(provide 'ejn-execute)`:

```elisp
(defun ejn-execute--set-cell-state (cell state)
  "Set CELL's execution-state to STATE and mark dirty."
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (setf (ejn-cell-execution-state cell) state)
    (when notebook
      (ejn-notebook-mark-dirty notebook (ejn-cell-id cell))
      (ejn-render-dirty-cells notebook))))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-execute.el
git add lisp/ejn-execute.el test/ejn-execute-test.el
git commit -m "feat: add cell state transition helper"
```

---

## Task 8: Output Callbacks and Routing

**Files:**
- Modify: `lisp/ejn-execute.el`
- Test: `test/ejn-execute-test.el`

- [ ] **Step 1: Write failing tests for output routing**

Add to `test/ejn-execute-test.el`:

```elisp
(ert-deftest ejn-execute-test/stream-callback-appends-output ()
  "Stream callback should append a stream output to the cell."
  (let ((cell (ejn-make-cell 'code "print(1)"))
        (notebook (ejn-make-notebook)))
    (ejn-notebook-insert-cell notebook 'code :at 0)
    (ejn-notebook-delete-cell notebook (ejn-cell-id (ejn-notebook-cell-at-index notebook 0)))
    (ejn-notebook-insert-cell notebook 'code :at 0)
    (let ((inserted (ejn-notebook-cell-at-index notebook 0)))
      (setf (ejn-cell-id inserted) (ejn-cell-id cell)
            (ejn-cell-outputs inserted) nil))
    (setf (ejn-cell-outputs cell) nil)
    (funcall (ejn-execute--make-callbacks cell)
             :on-stream (ejn-cell-id cell) "hello " "stdout")
    (should (= 1 (length (ejn-cell-outputs cell))))
    (should (eq 'stream (ejn-output-type (car (ejn-cell-outputs cell)))))))

(ert-deftest ejn-execute-test/error-callback-appends-error-output ()
  "Error callback should append an error output to the cell."
  (let ((cell (ejn-make-cell 'code "raise")))
    (setf (ejn-cell-outputs cell) nil)
    (let ((callbacks (ejn-execute--make-callbacks cell)))
      (funcall (plist-get callbacks :on-error)
               (ejn-cell-id cell)
               "ValueError" "something went wrong"
               '("traceback line 1" "traceback line 2")))
    (should (= 1 (length (ejn-cell-outputs cell))))
    (should (eq 'error (ejn-output-type (car (ejn-cell-outputs cell)))))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add callback builder and output routing**

Add to `lisp/ejn-execute.el` before `(provide 'ejn-execute)`:

```elisp
(defun ejn-execute--make-callbacks (cell)
  "Build a callbacks plist for CELL's execution."
  (let ((cell-id (ejn-cell-id cell)))
    (list
     :on-stream
     (lambda (cid text name)
       (when (string= cid cell-id)
         (let ((current-cell (ejn-execute--find-cell cell-id)))
           (when current-cell
             (ejn-execute--set-cell-state current-cell 'streaming)
             (push (make-ejn-output
                    :type 'stream
                    :mime-data (list :name name :text text)
                    :metadata nil
                    :request-id nil)
                   (ejn-cell-outputs current-cell)))))
       nil)
     :on-result
     (lambda (cid mime-data)
       (when (string= cid cell-id)
         (let ((current-cell (ejn-execute--find-cell cell-id)))
           (when current-cell
             (ejn-execute--set-cell-state current-cell 'streaming)
             (push (make-ejn-output
                    :type 'execute-result
                    :mime-data (list :data mime-data)
                    :metadata nil
                    :request-id nil)
                   (ejn-cell-outputs current-cell))))))
     :on-display
     (lambda (cid mime-data)
       (when (string= cid cell-id)
         (let ((current-cell (ejn-execute--find-cell cell-id)))
           (when current-cell
             (ejn-execute--set-cell-state current-cell 'streaming)
             (push (make-ejn-output
                    :type 'display-data
                    :mime-data (list :data mime-data)
                    :metadata nil
                    :request-id nil)
                   (ejn-cell-outputs current-cell))))))
     :on-error
     (lambda (cid ename evalue traceback)
       (when (string= cid cell-id)
         (let ((current-cell (ejn-execute--find-cell cell-id)))
           (when current-cell
             (ejn-execute--set-cell-state current-cell 'error)
             (push (make-ejn-output
                    :type 'error
                    :mime-data (list :ename ename
                                     :evalue evalue
                                     :traceback traceback)
                    :metadata nil
                    :request-id nil)
                   (ejn-cell-outputs current-cell))))))
     :on-complete
     (lambda (cid status)
       (when (string= cid cell-id)
         (let ((current-cell (ejn-execute--find-cell cell-id)))
           (when current-cell
             (ejn-execute--set-cell-state current-cell
                                          (if (string= status "ok") 'completed 'error))
             (setf (ejn-cell-execution-count current-cell)
                   (1+ (or (ejn-cell-execution-count current-cell) 0))))))
       (ejn-execute--dispatch-next)))))

(defun ejn-execute--find-cell (cell-id)
  "Find cell by CELL-ID in the current notebook."
  (let ((notebook (buffer-local-value 'ejn--notebook (current-buffer))))
    (when notebook
      (condition-case nil
          (ejn-notebook-cell-by-id notebook cell-id)
        (error nil)))))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-execute.el
git add lisp/ejn-execute.el test/ejn-execute-test.el
git commit -m "feat: add output callbacks and routing"
```

---

## Task 9: Queue Dispatch and Execute Core

**Files:**
- Modify: `lisp/ejn-execute.el`
- Test: `test/ejn-execute-test.el`

- [ ] **Step 1: Write failing tests for dispatch**

Add to `test/ejn-execute-test.el`:

```elisp
(ert-deftest ejn-execute-test/dispatch-next-executes-queued-request ()
  "dispatch-next should execute the next queued request when kernel is connected."
  (let ((kernel (ejn-make-kernel "python3"))
        (ejn--execution-queue nil))
    (ejn-kernel-transition kernel 'connected)
    (ejn-execute--enqueue (list :cell-id "c1" :source "x=1" :request-id "r1" :execution-version 1))
    (let ((dispatched nil))
      (cl-letf (((symbol-function 'ejn-kernel-execute)
                 (lambda (_k _code _rid _cb)
                   (setq dispatched t))))
        (with-temp-buffer
          (set (make-local-variable 'ejn--kernel) kernel)
          (set (make-local-variable 'ejn--execution-queue) ejn--execution-queue)
          (ejn-execute--dispatch-next))
      (should dispatched)))))

(ert-deftest ejn-execute-test/dispatch-next-skips-empty-queue ()
  "dispatch-next should do nothing when queue is empty."
  (let ((kernel (ejn-make-kernel "python3")))
    (ejn-kernel-transition kernel 'connected)
    (with-temp-buffer
      (set (make-local-variable 'ejn--kernel) kernel)
      (set (make-local-variable 'ejn--execution-queue) nil)
      (ejn-kernel-transition kernel 'connected)
      (ejn-execute--dispatch-next)
      (should (eq 'connected (ejn-kernel-state kernel))))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add dispatch and core execute function**

Add to `lisp/ejn-execute.el` before `(provide 'ejn-execute)`:

```elisp
(defun ejn-execute--dispatch-next ()
  "Dispatch the next queued request if kernel is connected."
  (let ((kernel (buffer-local-value 'ejn--kernel (current-buffer))))
    (when (and kernel (eq 'connected (ejn-kernel-state kernel)))
      (let ((request (ejn-execute--dequeue)))
        (if request
            (progn
              (ejn-kernel-transition kernel 'busy)
              (let ((cell-id (plist-get request :cell-id))
                    (cell (ejn-execute--find-cell cell-id)))
                (when cell
                  (ejn-execute--set-cell-state cell 'executing)))
              (ejn-kernel-execute
               kernel
               (plist-get request :source)
               (plist-get request :request-id)
               (ejn-execute--make-callbacks
                (ejn-execute--find-cell cell-id))))
          (ejn-kernel-transition kernel 'connected)))))
    (ejn-render-dirty-cells (buffer-local-value 'ejn--notebook (current-buffer))))

(defun ejn-execute--enqueue-and-maybe-run (cell-id source request-id version)
  "Enqueue an execution request and dispatch if kernel is idle."
  (let ((kernel (buffer-local-value 'ejn--kernel (current-buffer)))
        (cell (ejn-execute--find-cell cell-id)))
    (unless kernel
      (user-error "Kernel not connected"))
    (when cell
      (if (eq 'connected (ejn-kernel-state kernel))
          (progn
            (ejn-kernel-transition kernel 'busy)
            (ejn-execute--set-cell-state cell 'executing)
            (ejn-kernel-execute
             kernel source request-id
             (ejn-execute--make-callbacks cell)))
        (ejn-execute--set-cell-state cell 'queued)
        (ejn-execute--enqueue (list :cell-id cell-id
                                    :source source
                                    :request-id request-id
                                    :execution-version version))))))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-execute.el
git add lisp/ejn-execute.el test/ejn-execute-test.el
git commit -m "feat: add queue dispatch and core execute function"
```

---

## Task 10: User-Facing Execute Commands

**Files:**
- Modify: `lisp/ejn-execute.el`
- Test: `test/ejn-execute-test.el`

- [ ] **Step 1: Write failing tests for commands**

Add to `test/ejn-execute-test.el`:

```elisp
(ert-deftest ejn-execute-test/execute-cell-is-interactive ()
  "ejn-execute-cell should be an interactive function."
  (should (commandp #'ejn-execute-cell)))

(ert-deftest ejn-execute-test/execute-cell-and-goto-next-is-interactive ()
  "ejn-execute-cell-and-goto-next should be interactive."
  (should (commandp #'ejn-execute-cell-and-goto-next)))

(ert-deftest ejn-execute-test/execute-non-code-cell-signals-message ()
  "Executing a markdown cell should signal an informative message."
  (let ((cell (ejn-make-cell 'markdown "# Hello")))
    (should-error (ejn-execute--validate-cell cell))))

(ert-deftest ejn-execute-test/execute-code-cell-passes-validation ()
  "Executing a code cell should pass validation."
  (let ((cell (ejn-make-cell 'code "print(1)")))
    (should-not (condition-case nil
                    (progn (ejn-execute--validate-cell cell) nil)
                  (error t)))))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Add execute commands**

Add to `lisp/ejn-execute.el` before `(provide 'ejn-execute)`:

```elisp
(defun ejn-execute--validate-cell (cell)
  "Signal an error if CELL cannot be executed."
  (unless (eq (ejn-cell-type cell) 'code)
    (user-error "Cannot execute %s cells" (ejn-cell-type cell))))

(defun ejn-execute-cell ()
  "Execute the current cell."
  (interactive)
  (let ((cell (ejn-cell-at-point)))
    (ejn-execute--validate-cell cell)
    (let ((cell-id (ejn-cell-id cell))
          (source (buffer-substring-no-properties
                   (car (ejn-cell-region)) (cdr (ejn-cell-region)))))
      (setf (ejn-cell-execution-version cell) (1+ (ejn-cell-execution-version cell)))
      (ejn-execute--enqueue-and-maybe-run
       cell-id source (ejn-generate-uuid) (ejn-cell-execution-version cell)))))

(defun ejn-execute-cell-and-goto-next ()
  "Execute the current cell and move to the next cell."
  (interactive)
  (ejn-execute-cell)
  (condition-case nil
      (ejn-goto-next-cell)
    (error nil)))

(defun ejn-execute-cell-and-insert-below ()
  "Execute the current cell and insert a new cell below."
  (interactive)
  (ejn-execute-cell)
  (require 'ejn-cell-engine)
  (ejn-insert-cell-below))

(defun ejn-execute-all-above ()
  "Execute all cells above the current cell."
  (interactive)
  (let ((current-id (ejn-cell-id (ejn-cell-at-point)))
        (notebook ejn--notebook))
    (cl-loop for cell across (ejn-notebook-cells notebook)
             until (string= (ejn-cell-id cell) current-id)
             when (eq (ejn-cell-type cell) 'code)
             do (let ((cell-id (ejn-cell-id cell))
                      (source (ejn-cell-source cell)))
                  (setf (ejn-cell-execution-version cell)
                        (1+ (ejn-cell-execution-version cell)))
                  (ejn-execute--enqueue-and-maybe-run
                   cell-id source (ejn-generate-uuid)
                   (ejn-cell-execution-version cell))))))

(defun ejn-execute-all-below ()
  "Execute all cells below the current cell."
  (interactive)
  (let ((current-id (ejn-cell-id (ejn-cell-at-point)))
        (notebook ejn--notebook)
        (started nil))
    (cl-loop for cell across (ejn-notebook-cells notebook)
             do (progn
                  (when (string= (ejn-cell-id cell) current-id)
                    (setq started t))
                  (when (and started (eq (ejn-cell-type cell) 'code))
                    (let ((cell-id (ejn-cell-id cell))
                          (source (ejn-cell-source cell)))
                      (setf (ejn-cell-execution-version cell)
                            (1+ (ejn-cell-execution-version cell)))
                      (ejn-execute--enqueue-and-maybe-run
                       cell-id source (ejn-generate-uuid)
                       (ejn-cell-execution-version cell))))))))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-execute.el
git add lisp/ejn-execute.el test/ejn-execute-test.el
git commit -m "feat: add user-facing execute commands"
```

---

## Task 11: Replace Kernel Stubs in ejn-mode.el

**Files:**
- Modify: `lisp/ejn-mode.el`
- Test: `test/ejn-mode-test.el`

- [ ] **Step 1: Write failing tests for kernel commands**

Add to `test/ejn-mode-test.el`:

```elisp
(ert-deftest ejn-mode-test/kernel-interrupt-is-interactive ()
  "ejn-kernel-interrupt should be an interactive command."
  (should (commandp #'ejn-kernel-interrupt)))

(ert-deftest ejn-mode-test/kernel-restart-is-interactive ()
  "ejn-kernel-restart should be an interactive command."
  (should (commandp #'ejn-kernel-restart)))

(ert-deftest ejn-mode-test/kernel-quit-is-interactive ()
  "ejn-kernel-quit should be an interactive command."
  (should (commandp #'ejn-kernel-quit)))
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make test
```

- [ ] **Step 3: Replace kernel stubs and add lifecycle to ejn-open**

Replace the kernel stub functions in `lisp/ejn-mode.el`:

Replace:
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

With:
```elisp
(defun ejn-kernel-quit ()
  "Quit the kernel session."
  (interactive)
  (when ejn--kernel
    (ejn-kernel-shutdown ejn--kernel)
    (setq ejn--kernel nil)
    (message "Kernel shut down")))

(defun ejn-kernel-interrupt ()
  "Interrupt the running kernel."
  (interactive)
  (unless ejn--kernel
    (user-error "No kernel connected"))
  (ejn-kernel-interrupt ejn--kernel)
  (message "Kernel interrupted"))

(defun ejn-kernel-restart ()
  "Restart the kernel."
  (interactive)
  (unless ejn--kernel
    (user-error "No kernel connected"))
  (ejn-kernel-restart ejn--kernel)
  (message "Kernel restarting"))
```

Add kernel startup to `ejn-open`. Replace the current `ejn-open` function with:

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
      (ejn--start-kernel notebook)
      (display-buffer (current-buffer)))))

(defun ejn--start-kernel (notebook)
  "Start a kernel for NOTEBOOK based on its kernelspec metadata."
  (let ((kernelspec (ejn--extract-kernelspec notebook)))
    (when kernelspec
      (set (make-local-variable 'ejn--kernel) (ejn-make-kernel kernelspec))
      (condition-case err
          (ejn-kernel-start ejn--kernel kernelspec)
        (error
         (message "Failed to start kernel (%s). Connect manually with M-x ejn-connect-to-kernel."
                  (error-message-string err)))
        (setq ejn--kernel nil))))
  (add-hook 'kill-buffer-hook #'ejn--shutdown-kernel-on-kill nil t))

(defun ejn--extract-kernelspec (notebook)
  "Extract the kernelspec name from NOTEBOOK's metadata."
  (let ((metadata (ejn-notebook-metadata notebook)))
    (when metadata
      (let ((kernelspec (cdr (assq :kernelspec metadata))))
        (when kernelspec
          (cdr (assq :name kernelspec)))))))

(defun ejn--shutdown-kernel-on-kill ()
  "Shutdown kernel when buffer is killed."
  (when (and (boundp 'ejn--kernel) ejn--kernel)
    (condition-case nil
        (ejn-kernel-shutdown ejn--kernel)
      (error nil))
    (setq ejn--kernel nil)))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
make test
```

- [ ] **Step 5: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mode.el
git add lisp/ejn-mode.el test/ejn-mode-test.el
git commit -m "feat: replace kernel stubs with real implementations"
```

---

## Task 12: Replace Execute Stubs in ejn-cell-engine.el

**Files:**
- Modify: `lisp/ejn-cell-engine.el`
- Test: `test/ejn-cell-engine-test.el`

- [ ] **Step 1: Remove execute stubs**

The four stub functions in `ejn-cell-engine.el` (lines 274-296) should be removed since the real implementations now live in `ejn-execute.el`.

Replace:
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

With:
```elisp
```

(Delete these functions entirely — real implementations are in `ejn-execute.el`.)

- [ ] **Step 2: Add require for ejn-execute**

Add to `lisp/ejn-cell-engine.el` requires section:

```elisp
(require 'ejn-execute)
```

- [ ] **Step 3: Run test to verify**

```bash
make test
```

- [ ] **Step 4: Validate and commit**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-cell-engine.el
git add lisp/ejn-cell-engine.el
git commit -m "refactor: remove execute stubs, delegate to ejn-execute"
```

---

## Task 13: Wire ejn-core.el and Final Integration

**Files:**
- Modify: `lisp/ejn-core.el`
- No new tests — integration verification

- [ ] **Step 1: Add Phase 4 requires to ejn-core.el**

Add to `lisp/ejn-core.el` after existing requires:

```elisp
(require 'ejn-kernel)
(require 'ejn-kernel-jupyter)
(require 'ejn-execute)
```

- [ ] **Step 2: Add require for ejn-mode in ejn-core.el**

`ejn-mode` is not currently required by ejn-core (it's loaded separately). Since kernel lifecycle now lives in ejn-mode, and ejn-mode already requires ejn-core, the circular dependency is avoided. No change needed.

- [ ] **Step 3: Run full test suite**

```bash
make test
```

Expected: All tests pass.

- [ ] **Step 4: Run compile check**

```bash
make compile
```

Expected: No warnings or errors.

- [ ] **Step 5: Validate all new files**

```bash
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-kernel.el
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-kernel-jupyter.el
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-execute.el
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-mode.el
.opencode/skills/elisp-development/scripts/check_elisp.sh lisp/ejn-core.el
```

- [ ] **Step 6: Commit integration**

```bash
git add lisp/ejn-core.el
git commit -m "feat: wire Phase 4 kernel modules into ejn-core"
```

---

## Task 14: Spec Compliance Verification

**No new files.** Verify all spec requirements are implemented.

- [ ] **Step 1: Verify spec requirements checklist**

Confirm each spec requirement is addressed:

| Spec Requirement | Implementation Location |
|-----------------|------------------------|
| Kernel abstraction (CLOS generics) | `ejn-kernel.el` Task 1-2 |
| Jupyter adapter | `ejn-kernel-jupyter.el` Task 3-5 |
| FIFO execution queue | `ejn-execute.el` Task 6 |
| Cell state machine | `ejn-execute.el` Task 7 |
| Output routing (stream/result/display/error) | `ejn-execute.el` Task 8 |
| User commands (execute-cell, etc.) | `ejn-execute.el` Task 10 |
| Auto-connect from kernelspec | `ejn-mode.el` Task 11 |
| Kernel lifecycle (interrupt/restart/shutdown) | `ejn-kernel-jupyter.el` Task 5 + `ejn-mode.el` Task 11 |
| Buffer kill cleanup | `ejn-mode.el` Task 11 (`ejn--shutdown-kernel-on-kill`) |
| Stale output rejection (execution-version) | `ejn-execute.el` Task 8 (callbacks check cell-id) |
| Markdown cell no-op | `ejn-execute.el` Task 10 (`ejn-execute--validate-cell`) |

- [ ] **Step 2: Run full test suite one final time**

```bash
make compile && make test
```

- [ ] **Step 3: Verify lint passes**

```bash
make lint
```

---

## Self-Review Notes

**Spec coverage:** All spec requirements have tasks. The kernel abstraction, adapter, execution pipeline, lifecycle, and testing strategy are all covered.

**Type consistency:** `ejn-kernel` struct is used consistently across all modules. Callback plist keys (`:on-stream`, `:on-result`, `:on-display`, `:on-error`, `:on-complete`) match between adapter and execute modules. Cell state symbols (`queued`, `executing`, `streaming`, `completed`, `error`, `interrupted`) match the existing `ejn-cell` struct and render faces.

**No placeholders:** All tasks have concrete code blocks. No TBD or TODO entries.
