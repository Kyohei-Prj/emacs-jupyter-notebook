## Phase 2 — Cell Editing & Structural Transformations

This phase is where the notebook becomes *editorially usable*. The key is to introduce **safe structural mutations** without breaking the invariants established in Phase 1.

We’ll decompose into **atomic, testable tasks**, grouped by feature.

---

# 1. Foundation: Structural Editing Primitives

Before adding user-facing commands, you need reliable internal operations.

---

### Task 2.1 — Cell boundary accessors

**Goal:** Stop recomputing boundaries ad hoc.

**Implement**

* `ejn--cell-start`
* `ejn--cell-end`
* `ejn--cell-region`

**Done when**

* All later operations use these helpers exclusively

---

### Task 2.2 — Cell index lookup

**Goal:** Enable ordering operations.

**Implement**

* `ejn--cell-index (cell)`
* `ejn--cell-at-index (i)`

**Done when**

* You can move from cell → index → cell deterministically

---

### Task 2.3 — Normalize spacing between cells

**Goal:** Prevent subtle bugs during split/merge.

**Rules**

* Exactly **one blank line between cells**
* No leading/trailing stray whitespace

**Implement**

* `ejn--normalize-buffer-layout`

**Done when**

* Running normalization repeatedly produces no changes (idempotent)

---

# 2. Cell Splitting

---

### Task 2.4 — Validate split position

**Goal:** Prevent invalid splits.

**Rules**

* Must be inside a cell
* Cannot split at:

  * very beginning
  * very end

**Implement**

* `ejn--split-valid-p`

**Done when**

* Returns correct boolean for edge cases

---

### Task 2.5 — Implement split operation

**Goal:** Core structural transformation.

**Command**

* `ejn:worksheet-split-cell-at-point-km`

**Steps**

1. Identify current cell
2. Capture content before/after point
3. Replace original cell with:

   * top cell (before)
   * bottom cell (after)
4. Create new overlays for both
5. Update registry

**Keybinding**

* `C-c C-s`

**Technical note**

* Do NOT mutate overlay in-place — create two fresh ones

**Done when**

* Splitting produces two valid, independently editable cells

---

# 3. Cell Merging

---

### Task 2.6 — Validate merge candidates

**Goal:** Avoid invalid merges.

**Rules**

* Must have a “next” cell
* Types must match (initially enforce this)

**Implement**

* `ejn--merge-valid-p`

**Done when**

* Prevents cross-type merges (for now)

---

### Task 2.7 — Merge current cell with next

**Command**

* `ejn:worksheet-merge-cell-km`

**Steps**

1. Get current + next cell
2. Concatenate contents with newline
3. Replace both with single new cell
4. Remove old overlays
5. Insert new overlay

**Keybinding**

* `C-c RET`

**Done when**

* Two cells become one without layout corruption

---

# 4. Cell Movement (Reordering)

---

### Task 2.8 — Extract cell as text block

**Goal:** Reuse for movement and copy.

**Implement**

* `ejn--extract-cell-text`

**Done when**

* Returns exact content including newlines

---

### Task 2.9 — Delete cell without losing content

**Goal:** Separate deletion from extraction.

**Implement**

* `ejn--delete-cell-internal`

**Done when**

* Cell removed, but text is handled externally

---

### Task 2.10 — Insert cell at index

**Goal:** Needed for reordering.

**Implement**

* `ejn--insert-cell-at-index`

**Done when**

* Cell can be inserted anywhere in list correctly

---

### Task 2.11 — Move cell down

**Command**

* `ejn:worksheet-move-cell-down-km`

**Steps**

1. Get current index
2. Swap with next:

   * Extract
   * Remove
   * Reinsert after next cell

**Keybindings**

* `C-c <down>`
* `M-<down>` (alias behavior)

**Done when**

* Cell swaps position with next one cleanly

---

### Task 2.12 — Move cell up

**Command**

* `ejn:worksheet-move-cell-up-km`

**Keybindings**

* `C-c <up>`
* `M-<up>`

**Done when**

* Cell swaps with previous one

---

# 5. Cell Copy / Paste (Notebook Clipboard)

---

### Task 2.13 — Define internal clipboard

**Goal:** Avoid interference with kill-ring initially.

**Implement**

```elisp
(defvar ejn--cell-clipboard nil)
```

**Done when**

* Clipboard holds structured cell data

---

### Task 2.14 — Copy cell

**Command**

* `ejn:worksheet-copy-cell-km`

**Steps**

* Serialize:

  * type
  * content

**Keybindings**

* `C-c C-w`
* `C-c M-w`

**Done when**

* Clipboard updated without modifying buffer

---

### Task 2.15 — Yank cell

**Command**

* `ejn:worksheet-yank-cell-km`

**Steps**

* Insert new cell below current
* Populate with clipboard content

**Keybinding**

* `C-c C-y`

**Done when**

* Duplicated cell appears correctly

---

# 6. Cell Type Management

---

### Task 2.16 — Toggle cell type

**Command**

* `ejn:worksheet-toggle-cell-type-km`

**Behavior**

* code ↔ markdown

**Keybinding**

* `C-c C-t`

**Done when**

* Cell metadata updates correctly

---

### Task 2.17 — Explicit type change

**Command**

* `ejn:worksheet-change-cell-type-km`

**Steps**

* Prompt user:

  * `code`
  * `markdown`

**Keybinding**

* `C-c C-u`

**Done when**

* User can set type explicitly

---

### Task 2.18 — Visual differentiation

**Goal:** Make types visible.

**Implement**

* Different overlay faces:

  * code: subtle gray
  * markdown: slightly tinted

**Done when**

* Users can visually distinguish cell types

---

# 7. Consistency Reinforcement

---

### Task 2.19 — Re-run normalization after every structural change

**Goal:** Prevent drift.

**Integrate into**

* split
* merge
* move
* yank

**Done when**

* Layout remains stable after many edits

---

### Task 2.20 — Extend invariant checks

**Add checks**

* Cell order matches buffer order
* No orphan overlays
* No duplicate IDs

**Done when**

* Debug validator catches structural issues early

---

# 8. Keymap Completion for Phase 2

Activate all:

### Structure

* `C-c C-s` → split
* `C-c RET` → merge

### Movement

* `C-c <up>`, `C-c <down>`
* `M-<up>`, `M-<down>`

### Clipboard

* `C-c C-w`, `C-c M-w`
* `C-c C-y`

### Typing

* `C-c C-t`
* `C-c C-u`

---

# Phase 2 Final Acceptance Criteria

You are done when:

### Structural editing

* Splitting works at arbitrary positions
* Merging preserves content exactly

### Movement

* Cells can be reordered repeatedly without corruption

### Clipboard

* Copy/paste duplicates cells faithfully

### Typing

* Code/markdown switching works and is visible

### Stability

* No overlay leaks
* No broken navigation after repeated edits
* Normalization remains idempotent

---
