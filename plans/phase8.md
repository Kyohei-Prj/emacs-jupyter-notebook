## Phase 8 — Rich Output & UI Enhancements

Phase 8 upgrades EJN from a “text-output notebook” into a **rich, inspectable document environment**. The core concerns are:

* Rendering **multi-format outputs** (HTML, images)
* Maintaining **safe, efficient display pipelines**
* Improving **user interaction with outputs**

We’ll break this into **rendering pipelines, UI behaviors, and interaction features**.

---

# 1. Output Type System Expansion

---

### Task 8.1 — Extend output model

**Goal:** Support multiple MIME types.

**Extend cell output representation**

```elisp
(output-data
 output-type   ;; 'text 'html 'image
 mime-type
)
```

**Done when**

* Output can represent structured data beyond plain text

---

### Task 8.2 — Parse Jupyter output messages

**Goal:** Extract rich output data.

**Handle message types**

* `execute_result`
* `display_data`

**Extract**

* `text/plain`
* `text/html`
* `image/png` (base64)

**Implement**

* `ejn--parse-output-message`

**Done when**

* Output payload is normalized into internal format

---

# 2. HTML Rendering Pipeline

---

### Task 8.3 — Convert HTML to Emacs-renderable form

**Goal:** Display HTML safely.

**Use**

* Emacs built-in HTML renderer (e.g., `shr`)

**Implement**

* `ejn--render-html`

**Done when**

* HTML content appears formatted in buffer

---

### Task 8.4 — Sandbox HTML rendering

**Goal:** Avoid unsafe behavior.

**Rules**

* Disable scripts
* Strip unsafe tags

**Done when**

* HTML cannot execute code

---

### Task 8.5 — Cache rendered HTML

**Goal:** Avoid re-rendering overhead.

**Implement**

* Store rendered result in overlay property

**Done when**

* Scrolling does not trigger re-render

---

# 3. Image Output Rendering

---

### Task 8.6 — Decode base64 image data

**Goal:** Convert Jupyter output to displayable image.

**Implement**

* base64 decode → binary → image object

**Done when**

* Image object created successfully

---

### Task 8.7 — Insert image into buffer

**Goal:** Display inline images.

**Use**

* `insert-image`

**Done when**

* Images render correctly in output area

---

### Task 8.8 — Scale and constrain images

**Goal:** Prevent layout breakage.

**Options**

* max width
* fit to window

**Done when**

* Large images don’t overflow buffer

---

# 4. Output Overlay Enhancements

---

### Task 8.9 — Multi-segment output support

**Goal:** Handle mixed outputs (text + image + HTML).

**Implement**

* Output overlay can contain:

  * multiple segments
  * each with its own rendering

**Done when**

* Complex outputs render correctly

---

### Task 8.10 — Output re-rendering mechanism

**Goal:** Support refresh.

**Implement**

* `ejn--rerender-output`

**Done when**

* Output updates cleanly when needed

---

# 5. Output ↔ Code Navigation

---

### Task 8.11 — Link output to originating cell

**Goal:** Enable reverse navigation.

**Store**

* reference from output → cell

**Done when**

* Output knows its source cell

---

### Task 8.12 — Jump from output to code

**Command**

* `ejn:shared-output-show-code-cell-at-point-km`

**Keybinding**

* `C-c C-;`

**Done when**

* Cursor jumps from output to input cell

---

# 6. Code Visibility Control

---

### Task 8.13 — Toggle code visibility per cell

**Goal:** Focus on results.

**Implement**

* hide/show input region

**Done when**

* Code can be collapsed independently of output

---

### Task 8.14 — Synchronize with output visibility

**Goal:** Avoid confusing states.

**Rule**

* Output visible even if code hidden

**Done when**

* Behavior is intuitive

---

# 7. Toolbar (Minimal UI Layer)

---

### Task 8.15 — Create toolbar overlay

**Goal:** Provide discoverable controls.

**Implement**

* Small inline toolbar per cell:

  * run
  * clear output
  * toggle visibility

**Command**

* `ejn:tb-show-km`

**Keybinding**

* `C-c C-$`

**Done when**

* Toolbar appears on demand

---

### Task 8.16 — Attach actions to toolbar

**Goal:** Interactive controls.

**Done when**

* Buttons trigger correct commands

---

# 8. Output Inspection Enhancements

---

### Task 8.17 — Expand/collapse large outputs

**Goal:** Manage long outputs.

**Implement**

* truncated view + expand button

**Done when**

* Large outputs don’t overwhelm buffer

---

### Task 8.18 — Scrollable output regions

**Goal:** Improve usability.

**Options**

* overlay with limited height + scroll

**Done when**

* User can scroll within output

---

# 9. Performance Optimization

---

### Task 8.19 — Lazy rendering

**Goal:** Avoid rendering off-screen content.

**Implement**

* render only visible outputs

**Done when**

* Large notebooks remain responsive

---

### Task 8.20 — Limit output size

**Goal:** Prevent memory issues.

**Rules**

* truncate extremely large outputs

**Done when**

* System remains stable under heavy output

---

# 10. Output Persistence Compatibility

---

### Task 8.21 — Preserve rich outputs for saving

**Goal:** Prepare for Phase 3 integration improvement.

**Ensure**

* output data stored in cell struct

**Done when**

* Outputs can be serialized later

---

# 11. Keymap Activation

---

### Output navigation

* `C-c C-;` → jump to code from output

### UI controls

* `C-c C-$` → show toolbar

---

# Phase 8 Final Acceptance Criteria

You are done when:

### Rendering

* HTML outputs render correctly
* Images display inline
* Mixed outputs work

### Interaction

* Can navigate between output and code
* Toolbar provides working controls

### Usability

* Large outputs manageable (collapse/scroll)
* Code visibility toggle works

### Performance

* No lag with medium-sized notebooks
* Rendering is efficient and cached

---

## Recommended Implementation Order

1. **Output parsing (8.1–8.2)** ← foundation
2. **Image rendering (8.6–8.8)**
3. **HTML rendering (8.3–8.5)**
4. **Overlay enhancements (8.9–8.10)**
5. **Navigation (8.11–8.12)**
6. **Toolbar (8.15–8.16)**
7. **Performance optimizations (8.19–8.20)**

---

## Critical Design Insight

Phase 8 introduces a subtle but important architectural shift:

> Output is no longer just “text under a cell”
> → it becomes a **structured, interactive UI layer**

This has implications:

* Your overlay system must support **heterogeneous content**
* Rendering must be **incremental and cache-aware**
* Output must be treated as a **first-class data model**

---
