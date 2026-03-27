## Phase 9 — Notebook UX Completion & Utilities

Phase 9 is about **finishing the product surface**: multi-notebook workflows, lifecycle hygiene, and small but critical UX features that make EJN feel complete and reliable in daily use.

At this point, the core system already works. The focus here is:

* **Session isolation**
* **Multi-buffer coordination**
* **Lifecycle cleanup**
* **Convenience workflows**

We’ll decompose into **manageable operational tasks**.

---

# 1. Multi-Notebook Session Management

---

### Task 9.1 — Introduce notebook session object

**Goal:** Avoid global state conflicts.

**Define**

```elisp
(cl-defstruct ejn-session
  id
  buffer
  kernel
  lsp-context
  metadata)
```

**Done when**

* Each notebook has an independent session object

---

### Task 9.2 — Track active sessions

**Goal:** Manage multiple notebooks.

**Implement**

* `ejn--sessions` (list or hash table)

**Done when**

* Opening multiple notebooks creates multiple sessions

---

### Task 9.3 — Associate buffer ↔ session

**Goal:** Fast lookup.

**Implement**

* buffer-local reference:

  * `ejn--session`

**Done when**

* Any command can retrieve its session instantly

---

# 2. Scratch Notebook

---

### Task 9.4 — Create scratch notebook command

**Command**

* `ejn:notebook-scratchsheet-open-km`

**Behavior**

* Creates:

  * unnamed buffer
  * temporary session
  * kernel attached

**Keybinding**

* `C-c C-/`

**Done when**

* User can open disposable notebook instantly

---

### Task 9.5 — Mark scratch notebooks as ephemeral

**Goal:** Avoid accidental saves.

**Behavior**

* Prompt before saving
* Optional auto-delete on close

**Done when**

* Scratch buffers behave differently from file-backed ones

---

# 3. Notebook Closing & Cleanup

---

### Task 9.6 — Close notebook command

**Command**

* `ejn:notebook-close-km`

**Steps**

1. Confirm if unsaved changes
2. Shut down kernel (optional prompt)
3. Kill buffer
4. Remove session

**Keybinding**

* `C-c C-#`

**Done when**

* Notebook closes cleanly without leaks

---

### Task 9.7 — Detect unsaved changes

**Goal:** Prevent data loss.

**Implement**

* buffer modified flag integration

**Done when**

* User is prompted before closing unsaved notebook

---

# 4. Session Isolation Guarantees

---

### Task 9.8 — Isolate kernel per notebook

**Goal:** Avoid cross-notebook interference.

**Ensure**

* each session has its own kernel

**Done when**

* Executing in one notebook does not affect another

---

### Task 9.9 — Isolate LSP context per notebook

**Goal:** Prevent code intelligence conflicts.

**Ensure**

* separate virtual buffers per session

**Done when**

* Diagnostics/completions are scoped correctly

---

# 5. Resource Lifecycle Management

---

### Task 9.10 — Cleanup on buffer kill

**Goal:** Prevent orphan resources.

**Hook**

* `kill-buffer-hook`

**Cleanup**

* kernel
* LSP buffer
* overlays

**Done when**

* Killing buffer leaves no background processes

---

### Task 9.11 — Handle Emacs shutdown

**Goal:** Graceful exit.

**Hook**

* `kill-emacs-hook`

**Behavior**

* shut down all kernels

**Done when**

* No zombie kernels after Emacs exits

---

# 6. Notebook Switching UX

---

### Task 9.12 — List active notebooks

**Goal:** Improve navigation.

**Implement**

* `ejn:list-notebooks`

**Display**

* buffer name
* kernel status

**Done when**

* User can see all open notebooks

---

### Task 9.13 — Switch notebook command

**Goal:** Fast navigation.

**Done when**

* User can jump between notebooks quickly

---

# 7. Session Naming & Identity

---

### Task 9.14 — Assign session names

**Goal:** Improve UX clarity.

**Sources**

* filename OR
* generated ID for scratch

**Done when**

* Sessions have human-readable identifiers

---

### Task 9.15 — Display session info

**Goal:** Context awareness.

**Options**

* mode-line:

  * kernel status
  * session name

**Done when**

* User always knows current session context

---

# 8. Kernel Sharing (Optional Advanced)

---

### Task 9.16 — Support shared kernel (optional)

**Goal:** Advanced workflows.

**Behavior**

* multiple notebooks attach to same kernel

**Done when**

* Explicit opt-in sharing works safely

---

# 9. Autosave & Recovery (Optional but Valuable)

---

### Task 9.17 — Autosave notebooks

**Goal:** Prevent data loss.

**Implement**

* idle timer autosave

**Done when**

* Changes periodically saved

---

### Task 9.18 — Recovery mechanism

**Goal:** Crash resilience.

**Implement**

* restore from autosave

**Done when**

* User can recover unsaved work

---

# 10. Keymap Activation

---

### Notebook management

* `C-c C-/` → scratch notebook
* `C-c C-#` → close notebook

---

# Phase 9 Final Acceptance Criteria

You are done when:

### Multi-notebook support

* Multiple notebooks run simultaneously
* Each has isolated kernel and LSP

### Lifecycle management

* Closing notebook cleans up all resources
* No zombie processes or buffers

### UX completeness

* Scratch notebook workflow works
* Session switching is smooth

### Stability

* Emacs exit does not leave background processes
* Buffer kills are safe and predictable

---

## Recommended Implementation Order

1. **Session object + tracking (9.1–9.3)** ← foundation
2. **Notebook close + cleanup (9.6–9.10)**
3. **Scratch notebook (9.4–9.5)**
4. **Session isolation (9.8–9.9)**
5. **UX improvements (9.12–9.15)**
6. **Autosave (optional) (9.17–9.18)**

---

## Final Architectural Insight

Phase 9 completes the transformation:

From:

> “An Emacs buffer that can run notebook cells”

To:

> “A multi-session notebook environment with lifecycle guarantees”

The key invariant you must preserve:

> **Every resource created by a notebook must have a clear owner and a deterministic cleanup path**

If you enforce that strictly:

* your system will feel stable and professional
* users can trust it for long-running sessions

If you don’t:

* resource leaks and cross-session bugs will accumulate quickly

---
