## Phase 3 — Notebook Persistence (File I/O)

This phase introduces **`.ipynb` compatibility**, which is the first real interoperability milestone. The complexity is not the JSON itself, but **faithful mapping between your in-memory cell model and nbformat**.

We’ll break it into **tight, verifiable tasks**, progressing from raw JSON handling → mapping → user commands.

---

# 1. File I/O Foundation

---

### Task 3.1 — Add JSON dependency and utilities

**Goal:** Reliable parsing/serialization.

**Steps**

* Use built-in:

  * `json-parse-buffer`
  * `json-serialize`
* Configure:

  * `:object-type 'plist`
  * `:array-type 'list`

**Implement helpers**

* `ejn--json-read-buffer`
* `ejn--json-write-buffer`

**Done when**

* You can parse and re-emit arbitrary JSON without data loss

---

### Task 3.2 — File read/write helpers

**Goal:** Abstract filesystem interaction.

**Implement**

* `ejn--read-file-contents (path)`
* `ejn--write-file-contents (path content)`

**Done when**

* Can read/write raw `.ipynb` file contents

---

# 2. nbformat Schema Handling (Minimal Subset)

---

### Task 3.3 — Define supported schema subset

**Goal:** Avoid over-engineering.

**Support initially**

* Top-level:

  * `cells`
  * `metadata`
  * `nbformat`
  * `nbformat_minor`
* Cell fields:

  * `cell_type`
  * `source`
  * `metadata`
  * (ignore outputs for now)

**Done when**

* You have a documented internal contract

---

### Task 3.4 — Normalize `source` field

**Problem**

* Jupyter stores source as:

  * string OR
  * list of strings

**Implement**

* `ejn--normalize-source (src)`

  * Always return a single string

**Done when**

* All cell content becomes a consistent string internally

---

# 3. Import Pipeline (JSON → Buffer)

---

### Task 3.5 — Convert nbformat cell → internal cell

**Goal:** Core transformation.

**Implement**

* `ejn--nb-cell->ejn-cell`

**Mapping**

* `cell_type` → `type`
* `source` → buffer content
* generate new `id`

**Done when**

* Returns a valid `ejn-cell` struct (without overlay yet)

---

### Task 3.6 — Clear existing notebook buffer

**Goal:** Prepare for loading.

**Implement**

* `ejn--reset-buffer`

  * erase buffer
  * clear overlays
  * reset `ejn--cells`

**Done when**

* Buffer is clean before import

---

### Task 3.7 — Render imported cells into buffer

**Goal:** Reuse Phase 1 primitives.

**Steps**

* Iterate nb cells:

  * insert cell
  * set content
  * assign type
* Recreate overlays

**Implement**

* `ejn--load-cells-into-buffer`

**Done when**

* Imported notebook visually matches structure

---

### Task 3.8 — Full notebook load pipeline

**Goal:** One entry point.

**Implement**

* `ejn--load-notebook-from-json`

**Flow**

1. Parse JSON
2. Reset buffer
3. Convert cells
4. Render into buffer

**Done when**

* Given JSON → fully populated notebook buffer

---

# 4. Export Pipeline (Buffer → JSON)

---

### Task 3.9 — Extract cell content from buffer

**Goal:** Prepare serialization.

**Implement**

* `ejn--cell-content-string`

**Done when**

* Returns exact cell text (no extra separators)

---

### Task 3.10 — Convert internal cell → nbformat cell

**Implement**

* `ejn--ejn-cell->nb-cell`

**Mapping**

* `type` → `cell_type`
* content → `source` (split into lines OR single string)
* metadata → `{}` (empty for now)

**Done when**

* Produces valid nbformat cell object

---

### Task 3.11 — Build full notebook JSON structure

**Implement**

* `ejn--build-notebook-json`

**Structure**

```json
{
  "cells": [...],
  "metadata": {},
  "nbformat": 4,
  "nbformat_minor": 5
}
```

**Done when**

* Produces complete notebook object

---

### Task 3.12 — Serialize notebook to string

**Implement**

* `ejn--serialize-notebook`

**Done when**

* Produces formatted JSON string

---

# 5. File Commands (User-Facing)

---

### Task 3.13 — Open notebook command

**Command**

* `ejn:notebook-open-km`

**Steps**

1. Prompt for file
2. Read contents
3. Load notebook into buffer
4. Enable `ejn-mode`

**Keybinding**

* `C-c C-o`

**Done when**

* Opening a `.ipynb` file populates buffer correctly

---

### Task 3.14 — Generic file open helper

**Command**

* `ejn:file-open-km`

**Purpose**

* Wrapper for opening notebook or other files later

**Keybinding**

* `C-c C-f`

**Done when**

* Delegates correctly to notebook open

---

### Task 3.15 — Save notebook

**Command**

* `ejn:notebook-save-notebook-command-km`

**Steps**

1. If buffer has file:

   * overwrite
2. Else:

   * prompt for path

**Keybinding**

* `C-x C-s`

**Done when**

* File is saved and reloadable

---

### Task 3.16 — Rename notebook

**Command**

* `ejn:notebook-rename-command-km`

**Steps**

* Prompt new filename
* Update buffer association
* Save under new name

**Keybinding**

* `C-x C-w`

**Done when**

* File is renamed without losing data

---

# 6. Metadata Handling (Minimal but Safe)

---

### Task 3.17 — Preserve top-level metadata

**Goal:** Avoid destructive edits.

**Steps**

* Store metadata in buffer-local:

  * `ejn--notebook-metadata`

**Done when**

* Metadata survives round-trip

---

### Task 3.18 — Preserve unknown fields

**Goal:** Future-proofing.

**Steps**

* When loading:

  * keep unrecognized keys
* When saving:

  * reinsert them

**Done when**

* Non-standard fields are not lost

---

# 7. Encoding & Formatting Safety

---

### Task 3.19 — Ensure UTF-8 handling

**Steps**

* Explicitly encode/decode as UTF-8

**Done when**

* Unicode notebooks load/save correctly

---

### Task 3.20 — Stable formatting (optional but recommended)

**Goal:** Avoid noisy diffs.

**Steps**

* Pretty-print JSON
* Consistent indentation

**Done when**

* Saving twice produces identical output

---

# 8. Round-Trip Validation

---

### Task 3.21 — Implement round-trip test helper

**Goal:** Guarantee correctness.

**Flow**

1. Load notebook
2. Save to temp file
3. Reload
4. Compare structure

**Done when**

* No structural differences

---

# 9. Keymap Activation

Activate:

### File operations

* `C-c C-o` → open notebook
* `C-c C-f` → file open
* `C-x C-s` → save
* `C-x C-w` → rename

---

# Phase 3 Final Acceptance Criteria

You are done when:

### Core functionality

* Can open real `.ipynb` files
* Cells render correctly in buffer
* Can save and reload without corruption

### Data integrity

* No loss of:

  * cell content
  * cell order
  * metadata

### Stability

* Repeated open/save cycles are identical
* Handles:

  * empty notebooks
  * markdown + code mixes

### Interoperability

* Files open correctly in:

  * Jupyter Notebook
  * JupyterLab

---

## Recommended Implementation Order (Critical Path)

If you want minimal friction:

1. **Import pipeline (3.5–3.8)**
2. **Export pipeline (3.9–3.12)**
3. **Open/save commands (3.13–3.16)**
4. **Metadata preservation (3.17–3.18)**

---
