## Phase 1 — Core Buffer Model & Cell Navigation

We’ll break this into **small, implementable tasks (1–3 hours each)** so you can iterate quickly and test continuously.

---

# 1. Project Skeleton & Mode Initialization

### Task 1.1 — Create package structure

**Goal:** Establish a clean foundation.

**Steps**

* Create files:

  * `ejn.el` (entry point)
  * `ejn-core.el` (cell model + buffer ops)
  * `ejn-mode.el` (major mode + keymap)
* Add package headers and `provide`

**Done when**

* `(require 'ejn)` works without errors

---

### Task 1.2 — Define major mode (`ejn-mode`)

**Goal:** Notebook buffer exists as a controlled environment.

**Steps**

* Define:

  * `ejn-mode` (derived from `fundamental-mode`)
  * Disable unwanted features (line wrapping, etc.)
* Set buffer-local vars:

  * `ejn--cells` (list or index structure)
* Create empty keymap: `ejn-mode-map`

**Done when**

* You can `M-x ejn-mode` in a buffer
* No errors, mode activates cleanly

---

### Task 1.3 — Notebook buffer creation command

**Goal:** User can start a notebook session.

**Steps**

* Implement:

  * `ejn:notebook-open-scratch` (temporary name OK)
* Behavior:

  * Create new buffer
  * Enable `ejn-mode`
  * Insert initial empty cell

**Done when**

* Running command opens a buffer with one visible cell

---

# 2. Cell Data Model (Minimal Version)

### Task 2.1 — Define cell structure

**Goal:** Represent cells programmatically.

**Design (keep simple)**

```elisp
(cl-defstruct ejn-cell
  id
  type        ;; 'code or 'markdown
  input-start
  input-end
  overlay)
```

**Done when**

* You can construct and inspect a cell object

---

### Task 2.2 — Generate unique cell IDs

**Goal:** Stable references for future phases.

**Steps**

* Implement:

  * `ejn--generate-cell-id`
* Use incrementing counter or UUID

**Done when**

* Every new cell gets a unique ID

---

### Task 2.3 — Store cells in buffer-local registry

**Goal:** Track all cells efficiently.

**Steps**

* Use:

  * `ejn--cells` (list, ordered)
* Add helper:

  * `ejn--register-cell`
  * `ejn--remove-cell`

**Done when**

* Creating/removing cells updates the registry correctly

---

# 3. Cell Rendering (Overlays)

### Task 3.1 — Create cell overlay

**Goal:** Visually distinguish cells.

**Steps**

* Use `make-overlay`
* Add:

  * face (subtle background)
  * `ejn-cell` property linking to struct

**Done when**

* Each cell region has an overlay

---

### Task 3.2 — Insert a new cell at point

**Goal:** Core primitive for all cell creation.

**Steps**

* Implement:

  * `ejn--insert-cell-at-point`
* Behavior:

  * Insert newline-separated region
  * Create overlay
  * Register cell

**Done when**

* Calling function inserts a valid tracked cell

---

### Task 3.3 — Define cell boundaries

**Goal:** Ensure reliable navigation later.

**Steps**

* Decide:

  * One blank line between cells
* Ensure:

  * No overlapping overlays
  * Regions are contiguous

**Done when**

* Multiple cells render cleanly without corruption

---

# 4. Cell Insertion Commands

### Task 4.1 — Insert cell below

**Command**

* `ejn:worksheet-insert-cell-below-km`

**Steps**

* Find current cell
* Move to end
* Insert new cell

**Keybinding**

* `C-c C-b`

**Done when**

* New cell appears below current one

---

### Task 4.2 — Insert cell above

**Command**

* `ejn:worksheet-insert-cell-above-km`

**Steps**

* Move to beginning of current cell
* Insert new cell before

**Keybinding**

* `C-c C-a`

**Done when**

* New cell appears above current one

---

# 5. Cell Navigation

### Task 5.1 — Locate current cell

**Goal:** Fundamental primitive.

**Steps**

* Implement:

  * `ejn--cell-at-point`
* Use overlay lookup:

  * `(overlays-at (point))`

**Done when**

* Returns correct cell or nil

---

### Task 5.2 — Navigate to next cell

**Command**

* `ejn:worksheet-goto-next-input-km`

**Steps**

* Find current cell index
* Move to next cell’s start

**Keybindings**

* `C-<down>`
* `C-c C-n`

**Done when**

* Cursor jumps to next cell reliably

---

### Task 5.3 — Navigate to previous cell

**Command**

* `ejn:worksheet-goto-prev-input-km`

**Keybindings**

* `C-<up>`
* `C-c C-p`

**Done when**

* Cursor jumps upward correctly

---

# 6. Cell Deletion

### Task 6.1 — Delete current cell

**Command**

* `ejn:worksheet-kill-cell-km`

**Steps**

* Identify current cell
* Delete region
* Remove overlay
* Update registry

**Keybinding**

* `C-c C-k`

**Done when**

* Cell disappears without breaking neighbors

---

# 7. Consistency & Safety Layer

### Task 7.1 — Add invariants checker

**Goal:** Prevent subtle corruption early.

**Checks**

* No overlapping overlays
* Cell list matches buffer order
* All overlays map to valid cells

**Done when**

* Debug function passes after every operation

---

### Task 7.2 — Wrap mutations in safe update macro

**Goal:** Avoid partial state corruption.

**Example**

```elisp
(defmacro ejn--with-cell-update (&rest body)
  `(progn
     ;; optional: inhibit modification hooks
     ,@body
     (ejn--validate-state)))
```

**Done when**

* All structural edits go through this wrapper

---

# 8. Keymap Wiring

### Task 8.1 — Bind all Phase 1 keys

Group bindings:

**Navigation**

* `C-<down>`
* `C-<up>`
* `C-c C-n`
* `C-c C-p`

**Insertion**

* `C-c C-a`
* `C-c C-b`

**Deletion**

* `C-c C-k`

**Done when**

* All bindings work interactively

---

# Phase 1 Final Acceptance Checklist

You are done when ALL of these work reliably:

* Open notebook buffer with one cell
* Insert cells above/below
* Navigate between cells (no edge-case bugs)
* Delete cells without corrupting structure
* Overlay boundaries remain correct after edits
* Internal cell list stays consistent with buffer

---
