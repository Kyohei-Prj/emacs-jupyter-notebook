## Phase 7 — LSP Integration (Code Intelligence Across Cells)

Phase 7 is where EJN stops being “just a notebook runner” and becomes a **programmable development environment**. The core technical problem is:

> Mapping a **multi-cell, non-contiguous buffer** into a **single coherent LSP document**.

You are effectively building a **virtual file system layer + synchronization engine** between EJN and an LSP client such as lsp-mode or Eglot.

---

# 1. LSP Integration Strategy

---

### Task 7.1 — Choose LSP client

**Goal:** Fix integration surface.

**Options**

* lsp-mode (feature-rich, complex)
* Eglot (minimal, simpler)

**Recommendation**

* Start with **Eglot** (less abstraction overhead)

**Done when**

* You commit to one API and document the choice

---

### Task 7.2 — Define integration architecture

**Goal:** Avoid ad hoc hacks.

**Design**

* Notebook buffer = **source of truth**
* Virtual document = **LSP-facing representation**

**Define module**

* `ejn-lsp.el`

**Done when**

* Architecture diagram is clear (even in comments)

---

# 2. Virtual Document Model

---

### Task 7.3 — Concatenate code cells into virtual text

**Goal:** Create LSP-compatible document.

**Rules**

* Only include `code` cells
* Insert separator between cells:

  ```python
  # --- cell boundary ---
  ```

**Implement**

* `ejn--build-virtual-document`

**Done when**

* Produces a single string representing notebook code

---

### Task 7.4 — Maintain cell → offset mapping

**Goal:** Enable position translation.

**Implement**

* `ejn--cell-offset-map`

**Structure**

```elisp
(cell-id
 start-offset
 end-offset)
```

**Done when**

* You can map any cell position → virtual file offset

---

### Task 7.5 — Reverse mapping (offset → cell)

**Goal:** Needed for diagnostics and jumps.

**Implement**

* `ejn--offset->cell-position`

**Done when**

* LSP positions can be translated back into buffer locations

---

# 3. Virtual Buffer / File Representation

---

### Task 7.6 — Create hidden virtual buffer

**Goal:** LSP must attach to a buffer.

**Implement**

* Create buffer:

  * `*ejn-lsp-virtual*`
* Insert virtual document text

**Done when**

* Buffer reflects notebook code

---

### Task 7.7 — Assign file identity

**Goal:** LSP servers expect a file.

**Options**

* Fake path:

  * `/tmp/ejn-<id>.py`
* Or buffer-local `buffer-file-name`

**Done when**

* LSP server accepts the document

---

### Task 7.8 — Set major mode for virtual buffer

**Goal:** Ensure correct language server.

**Example**

* `python-mode`

**Done when**

* LSP starts correctly

---

# 4. LSP Client Initialization

---

### Task 7.9 — Start LSP on virtual buffer

**Goal:** Attach language server.

**Implement**

* For Eglot:

  * `eglot-ensure`

**Done when**

* LSP server is running

---

### Task 7.10 — Manage lifecycle of virtual buffer

**Goal:** Avoid leaks.

**Handle**

* notebook close
* restart

**Done when**

* No orphan virtual buffers remain

---

# 5. Synchronization (Notebook → LSP)

---

### Task 7.11 — Full document sync (initial)

**Goal:** MVP correctness.

**Trigger**

* after any cell edit

**Steps**

1. Rebuild virtual document
2. Replace entire buffer contents
3. Notify LSP

**Done when**

* LSP reflects latest notebook state

---

### Task 7.12 — Hook into buffer changes

**Goal:** Keep LSP in sync.

**Use**

* `after-change-functions`

**Done when**

* Edits trigger LSP updates

---

### Task 7.13 — Debounce updates

**Goal:** Avoid performance issues.

**Implement**

* idle timer (e.g., 300ms)

**Done when**

* Rapid typing does not spam LSP

---

# 6. Navigation (Jump to Definition / Back)

---

### Task 7.14 — Jump to definition command

**Command**

* `ejn:pytools-jump-to-source-command`

**Steps**

1. Call LSP “definition”
2. Get virtual position
3. Map to notebook position
4. Move point

**Keybinding**

* `M-.`

**Done when**

* Jump works across cells

---

### Task 7.15 — Jump back stack

**Command**

* `ejn:pytools-jump-back-command`

**Steps**

* Maintain stack of previous positions

**Keybinding**

* `M-,`

**Done when**

* Navigation is reversible

---

# 7. Diagnostics (Errors & Warnings)

---

### Task 7.16 — Receive diagnostics from LSP

**Goal:** Surface errors.

**Done when**

* Diagnostics are available from LSP

---

### Task 7.17 — Map diagnostics to cells

**Goal:** Place errors correctly.

**Steps**

* Convert LSP range → cell position

**Done when**

* Errors appear in correct cell

---

### Task 7.18 — Render diagnostics in notebook

**Options**

* overlay underline
* fringe marker

**Done when**

* Errors visually appear in cells

---

# 8. Completion Integration

---

### Task 7.19 — Enable completion at point

**Goal:** Code intelligence.

**Use**

* `completion-at-point-functions`

**Done when**

* LSP completions appear in code cells

---

### Task 7.20 — Restrict completion to code cells

**Goal:** Avoid noise.

**Done when**

* Markdown cells do not trigger completion

---

# 9. Advanced Sync (Optional Optimization)

---

### Task 7.21 — Incremental sync

**Goal:** Performance improvement.

**Instead of**

* full document replacement

**Implement**

* patch-based updates

**Done when**

* Large notebooks remain responsive

---

# 10. Multi-Language Handling (Future-Ready)

---

### Task 7.22 — Per-kernel language detection

**Goal:** Support different kernels.

**Done when**

* Virtual buffer language matches kernel

---

# 11. Keymap Activation

---

### Navigation

* `M-.` → jump to definition
* `M-,` → jump back

---

# Phase 7 Final Acceptance Criteria

You are done when:

### Code intelligence

* Jump-to-definition works across cells
* Jump-back restores previous location

### Diagnostics

* Errors appear in correct cells
* Updates dynamically as code changes

### Completion

* LSP completion works in code cells
* No interference in markdown cells

### Synchronization

* Edits reflect in LSP within ~300ms
* No desync between notebook and LSP

### Stability

* No crashes from rapid edits
* Virtual buffer lifecycle is clean

---

## Recommended Implementation Order

1. **Virtual document + mapping (7.3–7.5)** ← hardest part
2. **Virtual buffer + LSP start (7.6–7.9)**
3. **Full sync (7.11–7.13)**
4. **Jump-to-definition (7.14–7.15)**
5. **Diagnostics (7.16–7.18)**
6. **Completion (7.19–7.20)**

---

## Critical Design Insight

The success of Phase 7 depends almost entirely on:

> **Correct, lossless position mapping between notebook cells and virtual document**

If that layer is solid:

* everything else (jump, diagnostics, completion) becomes straightforward

If it's flawed:

* you’ll see:

  * incorrect jumps
  * misaligned diagnostics
  * unusable UX

---
