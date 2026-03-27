## Phase 5 — Execution Workflow Enhancements

At this stage, the kernel already works for single-cell execution. Phase 5 is about **workflow orchestration and output lifecycle management**—bringing EJN closer to real notebook ergonomics.

The core challenge here is **coordinating multiple asynchronous executions while keeping output consistent and controllable**.

We’ll decompose this into tightly scoped tasks.

---

# 1. Execution Queue & Multi-Cell Orchestration

---

### Task 5.1 — Introduce execution queue

**Goal:** Prevent overlapping execution chaos.

**Implement**

* `ejn--execution-queue` (FIFO)
* `ejn--enqueue-execution (cell)`
* `ejn--dequeue-execution`

**Behavior**

* Only one active execution at a time (MVP)

**Done when**

* Multiple execution requests are serialized

---

### Task 5.2 — Execution scheduler loop

**Goal:** Automatically process queued cells.

**Implement**

* `ejn--process-execution-queue`

**Behavior**

* If kernel idle:

  * dequeue next cell
  * execute it

**Done when**

* Queue drains automatically

---

### Task 5.3 — Hook into kernel idle event

**Goal:** Trigger next execution.

**Integrate**

* From Phase 4:

  * `status: idle`

**Done when**

* Next queued cell runs immediately after previous finishes

---

# 2. Execute-All Workflow

---

### Task 5.4 — Collect all executable cells

**Goal:** Define execution order.

**Implement**

* `ejn--all-cells-in-order`

**Filter**

* Only `code` cells

**Done when**

* Returns ordered list of cells

---

### Task 5.5 — Execute all cells command

**Command**

* `ejn:worksheet-execute-all-cells`

**Steps**

1. Clear queue
2. Enqueue all cells
3. Start scheduler

**Keybinding**

* `C-u C-c C-c`

**Done when**

* Entire notebook executes sequentially

---

# 3. Execute + Insert Below

---

### Task 5.6 — Insert new cell below current

(Reuse Phase 1/2 primitive)

---

### Task 5.7 — Execute and insert workflow

**Command**

* `ejn:worksheet-execute-cell-and-insert-below-km`

**Steps**

1. Execute current cell
2. After enqueue:

   * insert new cell below
   * move point there

**Keybinding**

* `M-S-<return>`

**Done when**

* Mimics Jupyter “Shift+Enter” behavior

---

# 4. Output Visibility Control (Per Cell)

---

### Task 5.8 — Add visibility state to cell

**Extend struct**

```elisp id="2q8d8n"
(output-visible-p)
```

**Done when**

* Each cell tracks visibility

---

### Task 5.9 — Toggle output visibility

**Command**

* `ejn:worksheet-toggle-output-km`

**Behavior**

* Hide/show overlay without deleting content

**Keybinding**

* `C-c C-e`

**Implementation detail**

* Use:

  * overlay `invisible` property

**Done when**

* Output can be collapsed/expanded instantly

---

# 5. Output Clearing (Per Cell)

---

### Task 5.10 — Clear output content

**Command**

* `ejn:worksheet-clear-output-km`

**Steps**

* Delete contents inside output overlay
* Preserve overlay itself

**Keybinding**

* `C-c C-l`

**Done when**

* Output disappears but cell remains executable

---

# 6. Clear All Outputs

---

### Task 5.11 — Iterate all cells

**Goal:** Bulk operations.

---

### Task 5.12 — Clear all outputs command

**Command**

* `ejn:worksheet-clear-all-output-km`

**Keybinding**

* `C-c C-S-l`

**Done when**

* Entire notebook output is cleared

---

# 7. Global Output Visibility Control

---

### Task 5.13 — Set visibility for all cells

**Command**

* `ejn:worksheet-set-output-visibility-all-km`

**Behavior**

* Prompt:

  * show all
  * hide all

**Keybinding**

* `C-c C-v`

**Done when**

* All outputs toggle consistently

---

# 8. Output Lifecycle Consistency

---

### Task 5.14 — Ensure output cleared before execution

**Goal:** Avoid accumulation bugs.

**Integrate into**

* execution pipeline

**Done when**

* Each run replaces output

---

### Task 5.15 — Prevent stale output rendering

**Goal:** Handle async race conditions.

**Strategy**

* Compare `msg_id`
* Ignore mismatched messages

**Done when**

* Old execution output never appears

---

# 9. Execution Count Tracking

---

### Task 5.16 — Increment execution counter

**Goal:** Match notebook semantics.

**Add**

* global counter or kernel-provided count

---

### Task 5.17 — Display execution count

**Options**

* Inline prefix:

  ```
  In [1]:
  ```
* Overlay header

**Done when**

* Each executed cell shows count

---

# 10. UX Feedback for Batch Execution

---

### Task 5.18 — Batch execution indicator

**Goal:** Show long-running workflows.

**Implement**

* Mode-line indicator OR echo area:

  * “Executing 3/10…”

**Done when**

* User sees progress during execute-all

---

### Task 5.19 — Interrupt queue safely

**Goal:** Allow user to stop execution.

**Hook**

* Later integrates with Phase 6 interrupt

**Done when**

* Queue can be cleared mid-run

---

# 11. Keymap Activation

Activate all Phase 5 bindings:

### Execution workflows

* `M-S-<return>` → execute + insert
* `C-u C-c C-c` → execute all

### Output control (cell)

* `C-c C-e` → toggle output
* `C-c C-l` → clear output

### Output control (global)

* `C-c C-S-l` → clear all
* `C-c C-v` → toggle all visibility

---

# Phase 5 Final Acceptance Criteria

You are done when:

### Execution workflows

* Execute-all runs entire notebook correctly
* Execution queue prevents overlap issues

### Output management

* Outputs can be:

  * toggled
  * cleared per cell
  * cleared globally

### UX parity with Jupyter

* “Execute + insert” behaves correctly
* Execution order is deterministic

### Stability

* No duplicated output
* No race-condition artifacts
* Queue recovers after errors

---

## Recommended Implementation Order

1. **Execution queue (5.1–5.3)** ← critical foundation
2. **Execute-all (5.4–5.5)**
3. **Output clearing (5.10–5.12)**
4. **Visibility toggling (5.8–5.9, 5.13)**
5. **Execute + insert (5.6–5.7)**
6. **Execution count + UX polish (5.16–5.18)**

---

## Key Architectural Insight

By the end of Phase 5, your system evolves from:

> “Execute a cell”
> → into
> “Schedule and manage a notebook execution graph”

Even though it's still linear, the **queue abstraction** sets you up for:

* parallel kernels (future)
* dependency-aware execution (advanced)

---
