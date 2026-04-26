### Directory Structure

Create the canonical directory layout for an Eask-based Emacs package:

```
ejn/
│── ejn.el
├── lisp/
│   ├── ejn-core.el
│   ├── ejn-network.el
│   └── ejn-lsp.el
├── test/
│   └── ejn-test.el
├── .ejn-cache/          ← gitignored; holds shadow files at runtime
├── Eask
├── Makefile
└── README.md
```

### Tips
- Use `elisp-dev` to refer to Emacs Lisp (elisp) document.
- Write one function/code block at a time. Do not write all at once.

## TDD Lessons

<!-- Each entry is appended by the tdd-lessons skill. Newest entries go at the top. -->

---

### [P2-T21] let vs let* — later bindings cannot reference earlier ones in let

**Date:** 2026-04-26
**Task:** Implement `ejn:worksheet-merge-cell` in `lisp/ejn-cell.el`

**Struggle:**
All 6 P2-T21 data-mutation tests failed at Step 4 with `(void-variable lower-cell)`, despite the implementation using a `let` form that defined `lower-cell` before referencing it in `lower-shadow` and `lower-buf` bindings.

**Root cause:**
In Emacs Lisp, `let` evaluates ALL init forms in the ORIGINAL environment (before any of the `let` bindings are established). Later init forms CANNOT reference earlier bindings. This differs from `let*`, which evaluates bindings sequentially and allows later bindings to reference earlier ones.

```elisp
;; WRONG — `x` is void when evaluating `y`'s init form
(let ((x 1)
      (y x))
  y)

;; CORRECT — `x` is bound before `y`'s init form evaluates
(let* ((x 1)
       (y x))
  y)
```

**Resolution:**
Changed `(let ((lower-cell ...) (lower-shadow (slot-value lower-cell 'shadow-file)) ...)` to `(let* ((lower-cell ...) (lower-shadow (slot-value lower-cell 'shadow-file)) ...)`.

**Pattern:** `let-vs-let*-binding-dependency`
When a `let` binding's init form references another binding from the same `let`, use `let*` instead. `let` evaluates all init forms in the pre-binding environment; `let*` evaluates sequentially.

---

### [P2-T18] Adjacent cell swap reuses old shadow file paths

**Date:** 2026-04-26
**Task:** Implement `ejn:worksheet-move-cell-up` and `ejn:worksheet-move-cell-down` in `lisp/ejn-cell.el`

**Struggle:**
The shadow file test failed at Step 4 with `(should-not (file-exists-p shadow-b-old))` returning t, despite the implementation correctly deleting old shadow files before writing new ones. The test expected old shadow files to not exist after the move, but they did.

**Root cause:**
When two adjacent cells swap positions, their shadow file paths are swapped too. Cell at index 0 has shadow `cell_000.py`, cell at index 1 has `cell_001.py`. After swap, the moved-down cell occupies index 0 (reusing `cell_000.py`) and the moved-up cell occupies index 1 (reusing `cell_001.py`). The old files were deleted, but new files with identical paths were immediately written. No "orphaned" old file exists.

**Resolution:**
Changed the test to verify shadow file content correctness (matching each cell's `:source`) rather than checking for absence of old shadow files. The correct verification is: (1) shadow file paths match new indices, (2) files exist, (3) file content matches cell source.

**Pattern:** `adjacent-swap-shadow-path-reuse`
When testing cell movement that swaps adjacent indices, do not check for absence of old shadow files — the swapped cells will reuse each other's paths. Instead verify content correctness via `with-temp-buffer` + `insert-file-contents` + `string=`.

---

### [P2-T14] with-temp-buffer kills buffer before replace-buffer-contents can use it

**Date:** 2026-04-26
**Task:** Implement `ejn-cell-refresh-buffer` in `lisp/ejn-cell.el`

**Struggle:**
All 4 P2-T14 tests failed with `(error "Cannot replace a buffer with itself")` at Step 4, despite the implementation logically looking correct. The first implementation used `with-temp-buffer` to create a source buffer, then called `replace-buffer-contents` from within a `with-current-buffer` block targeting the cell buffer.

**Root cause:**
`with-temp-buffer` is a macro that wraps its body in `unwind-protect` and kills the temp buffer on exit. Because `with-current-buffer` was nested inside `with-temp-buffer`, the temp buffer was already killed by the time `replace-buffer-contents` tried to use it. Additionally, `(current-buffer)` inside the nested `with-current-buffer` referred to the cell buffer, not the temp buffer.

**Resolution:**
Replaced `with-temp-buffer` with explicit `generate-new-buffer` + `unwind-protect` + `kill-buffer`. The temp buffer is captured as a local variable and kept alive until `replace-buffer-contents` completes.

```elisp
(let ((temp-buf (generate-new-buffer " *ejn-refresh-temp*")))
  (unwind-protect
      (progn
        (with-current-buffer temp-buf
          (insert (slot-value cell 'source)))
        (with-current-buffer buf
          (save-excursion
            (replace-buffer-contents temp-buf))))
    (kill-buffer temp-buf)))
```

**Pattern:** `with-temp-buffer-lifecycle-with-replace-buffer-contents`
When you need `replace-buffer-contents` to reference a buffer containing fresh content, do NOT use `with-temp-buffer` — its implicit cleanup kills the buffer before the replacement can reference it. Use explicit `generate-new-buffer` with `unwind-protect`/`kill-buffer` instead, capturing the buffer in a local variable.

---

### [P2-T12] special-mode sets buffer-read-only; insert fails in master buffer

**Date:** 2026-04-26
**Task:** Implement `ejn--refresh-master-cells` in `lisp/ejn-master.el`

**Struggle:**
All 4 new P2-T12 tests failed with `(buffer-read-only #<buffer *ejn-master:...*>). The failure occurred during `ejn--create-master-view` itself (not the new `ejn--refresh-master-cells`), specifically when `ejn--render-master-cells` tried to `insert` buttons into the buffer. The existing P2-T10 and P2-T11 tests passed because P2-T10 doesn't check buffer contents, and P2-T11 uses `with-temp-buffer` (which creates a fresh non-read-only buffer).

**Root cause:**
`special-mode` sets `buffer-read-only` to `t`. `ejn--create-master-view` calls `(special-mode)` then immediately calls `(ejn--render-master-cells notebook)` which uses `insert` to create buttons. `insert` cannot write into a read-only buffer. This was a latent bug in `ejn--create-master-view` that was never caught because no prior test verified buffer contents after creation.

**Resolution:**
Added `(setq buffer-read-only nil)` immediately after `(special-mode)` in `ejn--create-master-view` to allow rendering. The master view buffer remains in `special-mode` but is writable, which is the intended behavior for a buffer that needs dynamic content updates.

**Pattern:** `special-mode-buffer-read-only`
When creating a buffer in `special-mode` that needs programmatic insertion (buttons, text, etc.), always set `buffer-read-only` to `nil` after calling `special-mode`, unless the buffer is truly meant to be read-only.

---

### [P2-T9] cl-flet does not shadow functions in lexical-binding files

**Date:** 2026-04-26
**Task:** Implement `ejn--flush-all-dirty-cells` in `lisp/ejn-core.el`

**Struggle:**
The test `ejn-core-p2-t9--calls-sync-on-each-dirty-cell-with-live-buffer` used `cl-flet` to shadow `ejn-shadow-sync-cell` and track call counts. The test showed 0 calls despite the implementation clearly calling `ejn-shadow-sync-cell` for 2 matching cells.

**Root cause:**
`cl-flet` sets up dynamic function bindings, but in files with `lexical-binding: t`, function calls may be compiled to use lexical lookup, bypassing `cl-flet`'s dynamic shadowing. The test file has `lexical-binding: t`, and the loaded `ejn-core.el` also has `lexical-binding: t`, causing the shadowed function to never be invoked.

**Resolution:**
Replaced the `cl-flet` approach with direct side-effect verification: instead of intercepting `ejn-shadow-sync-cell` calls, the test verifies the observable outcomes — dirty cells with live buffers have their `:source` updated and `:dirty` cleared, while skipped cells remain unchanged.

**Pattern:** `cl-flet-lexical-binding-incompatibility`
When testing in files with `lexical-binding: t`, do not use `cl-flet` to shadow/intercept function calls. Prefer verifying observable side effects or use `advice-add` with a named function (not an anonymous lambda).

---

### [P2-T8] add-local-hook not available; use add-hook with 'local flag

**Date:** 2026-04-26
**Task:** Attach after-change-functions hook in cell buffers in lisp/ejn-cell.el

**Struggle:**
All tests failed with `(void-function add-local-hook)` at Step 4, despite the Eask spec declaring Emacs 30.1 minimum (which includes add-local-hook since Emacs 29.1).

**Root cause:**
The Eask test environment runs an Emacs version that predates `add-local-hook` (added in Emacs 29.1). The Eask `depends-on` declaration doesn't guarantee the test runner's Emacs version matches.

**Resolution:**
Replaced `(add-local-hook 'HOOK FN)` with `(add-hook 'HOOK FN 'append 'local)` which has been available since Emacs 24 and achieves the same effect (buffer-local hook registration).

**Pattern:** `add-local-hook-version-mismatch`
When registering buffer-local hooks, prefer `(add-hook 'HOOK FN 'append 'local)` over `add-local-hook` for broader Emacs version compatibility.

---

### [P2-T8] void-function not caught by command-error handler

**Date:** 2026-04-26
**Task:** Attach after-change-functions hook in cell buffers in lisp/ejn-cell.el

**Struggle:**
The markdown-mode test failed with `(void-function markdown-mode)` despite having a `condition-case` handler for `command-error`. The fallback to `fundamental-mode` was never reached.

**Root cause:**
When a function is not defined (not installed), Emacs signals `void-function`, not `command-error`. These are distinct error conditions in Emacs Lisp.

**Resolution:**
Changed the condition-case error handler from `(command-error ...)` to `((command-error void-function) ...)`, grouping both error types.

**Pattern:** `void-function-vs-command-error`
When catching errors from calling optional functions, always include both `command-error` and `void-function` in the condition-case handler, since missing functions signal `void-function` not `command-error`.

---

### [P2-T6] Stale .elc hides new function definitions in ERT

**Date:** 2026-04-25
**Task:** Implement `ejn-shadow-write-cell` in `lisp/ejn-core.el`

**Struggle:**
All 9 new tests failed with `(void-function ejn-shadow-write-cell)` at Step 2, despite the function being correctly defined in the `.el` file. The failure appeared to be "missing implementation" but the implementation was already there.

**Root cause:**
A stale `lisp/ejn-core.elc` (byte-compiled artifact) was loaded by Eask/Emacs instead of the live `.el` file. Eask's `test ert` command loads the package from the `lisp/` directory, and Emacs prefers `.elc` over `.el`.

**Resolution:**
Removed the stale `.elc` file with `rm lisp/ejn-core.elc`. All tests passed on the next run. Going forward, always check for and remove `.elc` files before running tests after modifying `.el` files, or use `eask compile` to rebuild.

**Pattern:** `stale-elc-masking-changes`
After editing an `.el` file and seeing `(void-function ...)` or `(void-variable ...)` errors in ERT that don't match reality, always check for a stale `.elc` sibling and remove it before re-running tests.

---

